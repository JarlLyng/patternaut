import Foundation
import Testing
@testable import PatternautCore

@Suite("PTI importer")
struct PTIImporterTests {
    /// A WAV of `frames` frames whose samples are recognisable per channel.
    func wav(frames: Int, channels: Int) -> Data {
        var pcm = [UInt8]()
        for frame in 0..<frames {
            for channel in 0..<channels {
                let value = Int16(truncatingIfNeeded: channel == 0 ? frame : -frame)
                let bits = UInt16(bitPattern: value)
                pcm.append(UInt8(bits & 0xFF)); pcm.append(UInt8(bits >> 8))
            }
        }
        return WavFile.make(pcm: Data(pcm), channels: channels)
    }

    @Test("A written instrument reads back as the same instrument")
    func roundTripMono() throws {
        let original = try Instrument.new(wav: wav(frames: 300, channels: 1), filename: "kick808")
        let reloaded = try PTIImporter.parse(original.data())

        #expect(reloaded.sample.filename == "kick808")
        #expect(reloaded.sample.length == 300)
        #expect(reloaded.sample.channels == 1)
        #expect(reloaded.pcm == original.pcm)
        #expect(reloaded.playmode == original.playmode)
        #expect(reloaded.isActive == original.isActive)
        #expect(reloaded.header.idFile == "TI")
    }

    @Test("Stereo audio comes back interleaved, with the channels the right way round")
    func roundTripStereo() throws {
        let original = try Instrument.new(wav: wav(frames: 128, channels: 2), filename: "pad")
        let reloaded = try PTIImporter.parse(original.data())

        #expect(reloaded.sample.channels == 2)
        #expect(reloaded.sample.length == 128)
        #expect(reloaded.pcm == original.pcm)

        // Left counts up, right counts down: not swapped, not smeared.
        let samples = [UInt8](reloaded.pcm)
        func sample(_ index: Int) -> Int16 {
            Int16(bitPattern: UInt16(samples[index * 2]) | (UInt16(samples[index * 2 + 1]) << 8))
        }
        #expect(sample(0) == 0 && sample(1) == 0)
        #expect(sample(2 * 5) == 5)       // left of frame 5
        #expect(sample(2 * 5 + 1) == -5)  // right of frame 5
    }

    @Test("The parameters the app cares about survive")
    func parameters() throws {
        var original = try Instrument.new(wav: wav(frames: 64, channels: 1), filename: "lead")
        original.volume = 1
        original.panning = 0.5
        original.tune = -12
        original.finetune = 7
        original.filterEnabled = true
        original.filterType = .highPass
        original.reverbSend = 0.3
        original.delaySend = 0.2
        original.overdrive = 0.4
        original.numSlices = 3
        original.slices = (0..<48).map { $0 * 10 }

        let reloaded = try PTIImporter.parse(original.data())
        #expect(reloaded.volume == 1)
        #expect(abs(reloaded.panning - 0.5) < 0.05)
        #expect(reloaded.tune == -12)
        #expect(reloaded.finetune == 7)
        #expect(reloaded.filterEnabled)
        #expect(reloaded.filterType == .highPass)
        #expect(abs(reloaded.reverbSend - 0.3) < 0.02)
        #expect(abs(reloaded.delaySend - 0.2) < 0.02)
        #expect(abs(reloaded.overdrive - 0.4) < 0.02)
        #expect(reloaded.numSlices == 3)
        #expect(reloaded.slices.prefix(4) == [0, 10, 20, 30])
    }

    @Test("Instrument audio can be turned back into a WAV")
    func backToWav() throws {
        let original = try Instrument.new(wav: wav(frames: 200, channels: 2), filename: "loop")
        let reloaded = try PTIImporter.parse(original.data())
        let rebuilt = WavFile.make(pcm: reloaded.pcm, channels: reloaded.sample.channels)
        let info = try WavFile.info(rebuilt)
        #expect(info.channels == 2)
        #expect(info.frames == 200)
        #expect(info.bitsPerSample == 16)
    }

    @Test("Something that isn't an instrument is refused clearly")
    func rejectsGarbage() throws {
        #expect(throws: PTIImporter.PTIError.tooSmall(3)) {
            try PTIImporter.parse(Data([1, 2, 3]))
        }
        var wrong = [UInt8](try Instrument.new(wav: wav(frames: 8, channels: 1)).data())
        wrong[0] = UInt8(ascii: "X")
        #expect(throws: PTIImporter.PTIError.invalidSignature("XI")) {
            try PTIImporter.parse(Data(wrong))
        }
    }
}
