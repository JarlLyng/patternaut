import Foundation
import Testing
@testable import PatternautCore

@Suite("Preview renderer")
struct PreviewRendererTests {
    let rate = 44_100.0
    /// At 120 BPM a sixteenth is 5512.5 frames.
    let tempo = 120.0
    var framesPerStep: Double { PreviewRenderer.framesPerStep(tempo: tempo, sampleRate: rate) }
    /// The frame a step time starts on: the renderer rounds up to a whole frame.
    func onset(_ step: Double) -> Int { Int((step * framesPerStep).rounded(.up)) }

    /// A pattern of `steps` steps with `notes` placed on track 0.
    func pattern(steps: Int = 16, _ notes: [Int: Step] = [:], track: Int = 0) -> Pattern {
        var pattern = DeviceModel.trackerPlus.profile.makeEmptyPattern(name: "Test", tempo: tempo, stepCount: steps)
        for (index, step) in notes { pattern.tracks[track].steps[index] = step }
        return pattern
    }

    func note(_ pitch: UInt8 = 60, instrument: Int = 0, fx: [FXCommand] = []) -> Step {
        Step(note: .pitch(pitch), instrument: instrument, fx: fx)
    }

    /// A sample of `frames` frames at a constant level, which makes onsets and
    /// lengths easy to read off the output.
    func flat(_ frames: Int, level: Float = 1, release: Double = 0.1) -> PlayableSample {
        PlayableSample(left: [Float](repeating: level, count: frames), release: release)
    }

    func render(_ pattern: Pattern, frames: Int, samples: [PlayableSample?], seed: UInt64 = 7) -> StereoAudio {
        var renderer = PreviewRenderer(sampleRate: rate, seed: seed)
        return renderer.render(frames, pattern: pattern, tempo: tempo, samples: samples)
    }

    func soundingFrames(_ channel: [Float]) -> Int { channel.filter { abs($0) > 1e-6 }.count }

    @Test("The root note plays the sample as it is, from the first frame")
    func rootPitch() {
        let ramp = PlayableSample(left: (0..<64).map { Float($0) / 64 })
        let out = render(pattern([0: note()]), frames: 128, samples: [ramp])
        let gain = PreviewRenderer.masterGain
        for frame in 0..<64 {
            #expect(abs(out.left[frame] - ramp.left[frame] * gain) < 1e-6)
        }
        #expect(out.left[64...].allSatisfy { $0 == 0 })
    }

    @Test("A note starts on its own step, at the tempo")
    func timing() {
        let out = render(pattern([2: note()]), frames: 20_000, samples: [flat(100)])
        #expect(out.left[onset(2) - 1] == 0)
        #expect(out.left[onset(2)] > 0)
    }

    @Test("An octave up plays the sample twice as fast")
    func octaveUp() {
        let out = render(pattern([0: note(72)]), frames: 2_000, samples: [flat(1_000)])
        #expect(abs(soundingFrames(out.left) - 500) <= 1)
    }

    @Test("Volume scales the note, and Chance 0 silences it while 100 always plays")
    func volumeAndChance() {
        let full = render(pattern([0: note()]), frames: 10, samples: [flat(10)])
        let half = render(pattern([0: note(fx: [FXCommand(type: .volume, value: 50)])]), frames: 10, samples: [flat(10)])
        #expect(abs(half.left[0] - full.left[0] / 2) < 1e-6)

        let never = render(pattern([0: note(fx: [FXCommand(type: .chance, value: 0)])]), frames: 10, samples: [flat(10)])
        #expect(soundingFrames(never.left) == 0)
        for seed in 1...20 {
            let always = render(pattern([0: note(fx: [FXCommand(type: .chance, value: 100)])]), frames: 10,
                                samples: [flat(10)], seed: UInt64(seed))
            #expect(soundingFrames(always.left) == 10)
        }
    }

    @Test("Chance lets some passes through and not others")
    func chanceVaries() {
        // One step in a one-step pattern: every step-length block is a fresh roll.
        var renderer = PreviewRenderer(sampleRate: rate, seed: 99)
        let p = pattern(steps: 8, [0: note(fx: [FXCommand(type: .chance, value: 50)])])
        var played = 0
        for _ in 0..<200 {
            let block = renderer.render(Int(8 * framesPerStep), pattern: p, tempo: tempo, samples: [flat(50)])
            if soundingFrames(block.left) > 0 { played += 1 }
        }
        #expect((60...140).contains(played))
    }

    @Test("OFF dies away over the instrument's release, CUT at once")
    func noteOffs() {
        let sample = flat(40_000, release: 0.01)
        let off = render(pattern([0: note(), 1: Step(note: .off)]), frames: 20_000, samples: [sample])
        let stepOne = onset(1)
        let releaseFrames = Int(0.01 * rate)
        #expect(off.left[stepOne + releaseFrames / 2] > 0)
        #expect(off.left[stepOne + releaseFrames + 2] == 0)

        let cut = render(pattern([0: note(), 1: Step(note: .offCut)]), frames: 20_000, samples: [sample])
        #expect(cut.left[stepOne + Int(PreviewRenderer.cutFade * rate) + 2] == 0)
    }

    @Test("A new note takes over its track from the last one")
    func monophonic() {
        let quiet = flat(40_000, level: 0.25)
        let loud = flat(40_000, level: 1)
        var p = pattern([0: note(instrument: 0)])
        p.tracks[0].steps[1] = note(instrument: 1)
        let out = render(p, frames: 15_000, samples: [quiet, loud])
        let gain = PreviewRenderer.masterGain
        let afterFade = onset(1) + Int(PreviewRenderer.takeoverFade * rate) + 2
        #expect(abs(out.left[afterFade] - 1 * gain) < 1e-6)
    }

    @Test("Notes on different tracks sound together")
    func tracksMix() {
        var p = pattern([0: note()])
        p.tracks[1].steps[0] = note()
        let out = render(p, frames: 10, samples: [flat(10)])
        #expect(abs(out.left[0] - 2 * PreviewRenderer.masterGain) < 1e-6)
    }

    @Test("MIDI and synth instruments, and empty slots, make no sound")
    func silentInstruments() {
        let samples = [flat(10)]
        #expect(soundingFrames(render(pattern([0: note(instrument: 48)]), frames: 10, samples: samples).left) == 0)
        #expect(soundingFrames(render(pattern([0: note(instrument: 64)]), frames: 10, samples: samples).left) == 0)
        #expect(soundingFrames(render(pattern([0: note(instrument: 3)]), frames: 10, samples: samples).left) == 0)
        #expect(soundingFrames(render(pattern([0: note(instrument: 0)]), frames: 10, samples: [nil]).left) == 0)
    }

    @Test("A note without an instrument plays 00, as the card stores it")
    func missingInstrument() {
        let step = Step(note: .pitch(60), instrument: nil)
        #expect(soundingFrames(render(pattern([0: step]), frames: 10, samples: [flat(10)]).left) == 10)
    }

    @Test("The pattern loops at its end")
    func loops() {
        let p = pattern(steps: 4, [0: note()])
        let loop = onset(4)
        let out = render(p, frames: loop + 200, samples: [flat(100)])
        #expect(out.left[loop - 1] == 0)
        #expect(out.left[loop + 1] > 0)
    }

    @Test("Rendering in blocks gives the same audio as all at once")
    func blockBoundaries() {
        var p = pattern(steps: 8, [0: note(), 3: note(67), 5: Step(note: .off)])
        p.tracks[2].steps[1] = note(fx: [FXCommand(type: .microMove, value: 40)])
        let samples = [PlayableSample(left: (0..<9_000).map { sin(Float($0) * 0.05) })]
        let total = 60_000

        let whole = render(p, frames: total, samples: samples)
        var renderer = PreviewRenderer(sampleRate: rate, seed: 7)
        var left: [Float] = []
        let sizes = [512, 1_000, 4_096, 333]
        var remaining = total
        var turn = 0
        while remaining > 0 {
            let block = renderer.render(min(sizes[turn % sizes.count], remaining), pattern: p, tempo: tempo, samples: samples)
            left += block.left
            remaining -= block.frameCount
            turn += 1
        }
        let largest = zip(whole.left, left).map { abs($0 - $1) }.max() ?? 0
        #expect(left.count == total)
        #expect(largest < 1e-4)
    }

    @Test("Micro-move 100 pushes a note half a step late")
    func microMove() {
        let out = render(pattern([0: note(fx: [FXCommand(type: .microMove, value: 100)])]), frames: 10_000, samples: [flat(100)])
        #expect(out.left[onset(0.5) - 1] == 0)
        #expect(out.left[onset(0.5)] > 0)
    }

    @Test("Panning, Tune and Reverse shape the note")
    func effects() {
        // Panning stores 0...100 and shows -50...+50; 0 stored is hard left.
        let left = render(pattern([0: note(fx: [FXCommand(type: .panning, value: 0)])]), frames: 10, samples: [flat(10)])
        #expect(soundingFrames(left.left) == 10)
        #expect(soundingFrames(left.right) == 0)

        // Tune stores 0...48 for -24...+24: 36 is an octave up.
        let tuned = render(pattern([0: note(fx: [FXCommand(type: .tune, value: 36)])]), frames: 2_000, samples: [flat(1_000)])
        #expect(abs(soundingFrames(tuned.left) - 500) <= 1)

        let ramp = PlayableSample(left: (1...10).map { Float($0) })
        let backwards = render(pattern([0: note(fx: [FXCommand(type: .reverse, value: 1)])]), frames: 10, samples: [ramp])
        #expect(backwards.left[0] > backwards.left[9])
    }

    @Test("Clicking a step plays it out in full, and an empty step plays nothing")
    func audition() {
        let heard = PreviewRenderer.audition([(track: 0, step: note())], samples: [flat(300)], sampleRate: rate)
        #expect(heard?.frameCount == 300)
        #expect(PreviewRenderer.audition([(track: 0, step: .empty)], samples: [flat(300)], sampleRate: rate) == nil)
        // Chance does not apply to a click.
        let chancy = note(fx: [FXCommand(type: .chance, value: 0)])
        #expect(PreviewRenderer.audition([(track: 0, step: chancy)], samples: [flat(300)], sampleRate: rate) != nil)
    }

    @Test("An instrument's audio and settings come across from the .pti")
    func fromInstrument() throws {
        let pcm = Data([Int16(16_384), Int16(-16_384), Int16(0)].flatMap { value in
            withUnsafeBytes(of: value.littleEndian, Array.init)
        })
        var instrument = try Instrument.new(wav: WavFile.make(pcm: pcm, channels: 1), filename: "t")
        instrument.tune = 2
        instrument.finetune = 50
        instrument.volume = 0.5
        let sample = PlayableSample(instrument: instrument)
        #expect(sample.left == [0.5, -0.5, 0])
        #expect(sample.right == sample.left)
        #expect(sample.tune == 2.5)
        #expect(sample.gain == 0.5)
        #expect(sample.startFrame == 0 && sample.endFrame == 3)
        #expect(abs(sample.release - 1) < 1e-9)
    }
}
