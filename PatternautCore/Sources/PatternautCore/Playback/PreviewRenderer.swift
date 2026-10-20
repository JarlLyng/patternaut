import Foundation

/// Two channels of float audio.
public struct StereoAudio: Sendable, Equatable {
    public var left: [Float]
    public var right: [Float]

    public init(frames: Int) {
        left = [Float](repeating: 0, count: frames)
        right = [Float](repeating: 0, count: frames)
    }

    public var frameCount: Int { left.count }
}

/// Plays a pattern through its sample instruments, a block of audio at a time,
/// so the app can let you hear what you made before it goes to the card.
///
/// A sketch of the Tracker's sound, not its engine. It plays notes and their
/// instruments, the three note-offs, and the Volume, Chance, Micro-move,
/// Panning, Tune, Micro-tune and Reverse effects, through each instrument's
/// volume, panning, tuning, start and end points. Every other effect is
/// silent here, and MIDI and synth instruments make no sound. Each track plays
/// one note at a time, as on the device: a new note takes over from the last.
public struct PreviewRenderer: Sendable {
    /// Steps per beat: a step is a sixteenth, as on the device.
    public static let stepsPerBeat = 4.0
    /// How far Micro-move 100 pushes a note, in steps. The manual describes the
    /// shift as small without saying how small, so this is an estimate.
    static let microMoveSpan = 0.5
    /// Fades, in seconds: a note giving way to the next one on its track, CUT,
    /// and FAD.
    static let takeoverFade = 0.004
    static let cutFade = 0.002
    static let fadeOutTime = 0.25
    /// Headroom, so sixteen tracks at full volume do not clip straight away.
    static let masterGain: Float = 0.5

    public let sampleRate: Double
    /// Where the last block began, in steps from the top of the pattern, and
    /// how long a step was then: enough to tell which row is being heard.
    public private(set) var lastBlock = BlockTiming(startStep: 0, framesPerStep: 1, length: 1)
    /// Playback runs on whole frames from the top of the pattern, so a note
    /// lands on the same frame however the audio is split into blocks.
    private var frame = 0
    private var framesPerStep: Double?
    /// A step asked for by ``seek(toStep:)``, placed once the tempo is known.
    private var pendingStep: Double? = 0
    private var voices: [Voice] = []
    private var rng: SeededGenerator

    public struct BlockTiming: Sendable, Equatable {
        public var startStep: Double
        public var framesPerStep: Double
        public var length: Int
    }

    public init(sampleRate: Double, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.sampleRate = sampleRate
        self.rng = SeededGenerator(seed: seed)
    }

    /// Frames in one step at `tempo` beats per minute.
    public static func framesPerStep(tempo: Double, sampleRate: Double) -> Double {
        sampleRate * 60 / (max(tempo, 1) * stepsPerBeat)
    }

    /// The pattern's length in steps: its longest track.
    public static func length(of pattern: Pattern) -> Int {
        max(1, pattern.tracks.map { min($0.length, $0.steps.count) }.max() ?? 1)
    }

    /// Moves playback to `step` and silences whatever was sounding.
    public mutating func seek(toStep step: Double) {
        pendingStep = max(0, step)
        voices.removeAll()
    }

    /// The frame a step time falls on, counted from the top of the pattern.
    private static func frame(atStep step: Double, framesPerStep: Double) -> Int {
        Int((step * framesPerStep).rounded(.up))
    }

    /// The next `frames` of the pattern, looping at its end. `samples` are the
    /// sample instruments in slot order, so index 0 is instrument 00.
    public mutating func render(_ frames: Int, pattern: Pattern, tempo: Double,
                                samples: [PlayableSample?]) -> StereoAudio {
        var out = StereoAudio(frames: frames)
        guard frames > 0 else { return out }
        let perStep = Self.framesPerStep(tempo: tempo, sampleRate: sampleRate)
        let length = Self.length(of: pattern)
        if let step = pendingStep {
            frame = Self.frame(atStep: step, framesPerStep: perStep)
            pendingStep = nil
        } else if let previous = framesPerStep, previous != perStep {
            // A tempo change keeps the place in the pattern, not the frame.
            frame = Int((Double(frame) / previous * perStep).rounded())
        }
        framesPerStep = perStep
        let loopFrames = max(1, Self.frame(atStep: Double(length), framesPerStep: perStep))
        frame %= loopFrames
        let start = frame
        let end = start + frames
        lastBlock = BlockTiming(startStep: Double(start) / perStep, framesPerStep: perStep, length: length)

        // Every note and note-off that lands in this block. A micro-moved note
        // on the last step lands in the next pass, hence starting a pass early.
        var events: [Event] = []
        for (trackIndex, track) in pattern.tracks.enumerated() {
            for index in 0..<min(track.length, track.steps.count) {
                let step = track.steps[index]
                guard step.note != .empty else { continue }
                var time = Double(index)
                if step.isActive, let micro = step.microtiming {
                    time += Double(min(max(micro, 0), 100)) / 100 * Self.microMoveSpan
                }
                let onset = Self.frame(atStep: time, framesPerStep: perStep)
                var pass = -1
                while pass * loopFrames + onset < end {
                    let at = pass * loopFrames + onset
                    if at >= start {
                        events.append(Event(frame: at - start, track: trackIndex, step: step))
                    }
                    pass += 1
                }
            }
        }
        events.sort { $0.frame != $1.frame ? $0.frame < $1.frame : $0.track < $1.track }

        var cursor = 0
        for event in events {
            mix(into: &out, from: cursor, to: event.frame)
            cursor = event.frame
            apply(event.step, track: event.track, samples: samples, rollChance: true)
        }
        mix(into: &out, from: cursor, to: frames)
        voices.removeAll { $0.isFinished }

        frame = end % loopFrames
        return out
    }

    /// One or more steps sounding together, from their first frame until they
    /// have played out: what you hear when you click a step or a row. Chance
    /// and Micro-move are left out, so a click always answers at once. `nil`
    /// when none of the steps makes a sound.
    public static func audition(_ steps: [(track: Int, step: Step)], samples: [PlayableSample?],
                                sampleRate: Double, maxSeconds: Double = 4) -> StereoAudio? {
        var renderer = PreviewRenderer(sampleRate: sampleRate, seed: 1)
        for (track, step) in steps {
            renderer.apply(step, track: track, samples: samples, rollChance: false)
        }
        guard !renderer.voices.isEmpty else { return nil }
        let longest = renderer.voices.map { $0.framesLeft }.max() ?? 0
        let frames = min(longest, Int(maxSeconds * sampleRate))
        guard frames > 0 else { return nil }
        var out = StereoAudio(frames: frames)
        renderer.mix(into: &out, from: 0, to: frames)
        return out
    }

    // MARK: - Voices

    private struct Event {
        let frame: Int
        let track: Int
        let step: Step
    }

    private struct Voice: Sendable {
        let track: Int
        let sample: PlayableSample
        /// Frame in the sample, between frames while pitched.
        var position: Double
        /// Frames of sample per frame of output; negative plays it backwards.
        let increment: Double
        let gainLeft: Float
        let gainRight: Float
        var level: Float = 1
        /// Per-frame change in `level` once the voice is fading.
        var fade: Float = 0
        var isFinished = false

        /// Frames until the voice reaches the end of its sample.
        var framesLeft: Int {
            let remaining = increment >= 0
                ? Double(sample.endFrame - 1) - position
                : position - Double(sample.startFrame)
            return max(0, Int((remaining / abs(increment)).rounded(.up)) + 1)
        }

        mutating func fadeOut(over seconds: Double, sampleRate: Double) {
            let frames = max(1, seconds * sampleRate)
            let step = -Float(1 / frames)
            fade = fade == 0 ? step : min(fade, step)
        }
    }

    /// Starts or ends notes for one step.
    private mutating func apply(_ step: Step, track: Int, samples: [PlayableSample?], rollChance: Bool) {
        switch step.note {
        case .empty:
            return
        case .off:
            for index in voices.indices where voices[index].track == track {
                voices[index].fadeOut(over: voices[index].sample.release, sampleRate: sampleRate)
            }
            return
        case .offFade:
            fadeTrack(track, over: Self.fadeOutTime)
            return
        case .offCut:
            fadeTrack(track, over: Self.cutFade)
            return
        case .pitch(let note):
            if rollChance, let chance = step.probability, Int.random(in: 0..<100, using: &rng) >= chance {
                return
            }
            // A track plays one note at a time, whatever the instrument.
            fadeTrack(track, over: Self.takeoverFade)
            // The card stores a missing instrument as 0, so the device plays 00.
            let slot = step.instrument ?? 0
            guard TrackerFormat.sampleInstrumentRange.contains(slot), slot < samples.count,
                  let sample = samples[slot], sample.endFrame > sample.startFrame else { return }
            if let voice = makeVoice(note: Int(note), step: step, track: track, sample: sample) {
                voices.append(voice)
            }
        }
    }

    private mutating func fadeTrack(_ track: Int, over seconds: Double) {
        for index in voices.indices where voices[index].track == track {
            voices[index].fadeOut(over: seconds, sampleRate: sampleRate)
        }
    }

    private func makeVoice(note: Int, step: Step, track: Int, sample: PlayableSample) -> Voice? {
        var semitones = Double(note - PlayableSample.rootNote) + sample.tune
        if let tune = step.fx.first(where: { $0.type == .tune }) { semitones += Double(tune.displayValue) }
        if let micro = step.fx.first(where: { $0.type == .microTune }) { semitones += Double(micro.displayValue) / 100 }
        let reverse = (step.fxValue(.reverse) ?? 0) > 0
        let rate = pow(2, semitones / 12) * PlayableSample.sampleRate / sampleRate
        guard rate.isFinite, rate > 0 else { return nil }

        let velocity = Float(min(max(step.velocity ?? 100, 0), 100)) / 100
        let gain = sample.gain * velocity * Self.masterGain
        var pan = sample.panning
        if let panning = step.fx.first(where: { $0.type == .panning }) { pan += Float(panning.displayValue) / 50 }
        pan = min(max(pan, -1), 1)
        return Voice(
            track: track, sample: sample,
            position: reverse ? Double(sample.endFrame - 1) : Double(sample.startFrame),
            increment: reverse ? -rate : rate,
            gainLeft: gain * min(1, 1 - pan),
            gainRight: gain * min(1, 1 + pan)
        )
    }

    /// Adds every voice into `out` over `start..<end`.
    private mutating func mix(into out: inout StereoAudio, from start: Int, to end: Int) {
        guard end > start else { return }
        for index in voices.indices where !voices[index].isFinished {
            var voice = voices[index]
            let left = voice.sample.left
            let right = voice.sample.right
            let first = voice.sample.startFrame
            let last = voice.sample.endFrame - 1
            out.left.withUnsafeMutableBufferPointer { outLeft in
                out.right.withUnsafeMutableBufferPointer { outRight in
                    for frame in start..<end {
                        let position = voice.position
                        guard position >= Double(first), position <= Double(last) else {
                            voice.isFinished = true
                            break
                        }
                        let index = Int(position)
                        let next = min(index + 1, last)
                        let fraction = Float(position - Double(index))
                        let l = left[index] + (left[next] - left[index]) * fraction
                        let r = right[index] + (right[next] - right[index]) * fraction
                        outLeft[frame] += l * voice.gainLeft * voice.level
                        outRight[frame] += r * voice.gainRight * voice.level
                        voice.position += voice.increment
                        if voice.fade != 0 {
                            voice.level += voice.fade
                            if voice.level <= 0 {
                                voice.isFinished = true
                                break
                            }
                        }
                    }
                }
            }
            voices[index] = voice
        }
    }
}
