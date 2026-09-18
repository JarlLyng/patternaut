import Foundation
import Testing
@testable import PatternautCore

@Suite("Project file")
struct ProjectFileTests {
    func sampleWav() -> Data {
        WavFile.make(pcm: Data([UInt8](repeating: 7, count: 400)), channels: 1)
    }

    func file() -> ProjectFile {
        ProjectFile(
            projectName: "Night Bus",
            device: .trackerMini,
            tempo: 148,
            baseOctave: 3,
            key: MusicalKey(root: 5, scale: .dorian),
            patterns: [BeatGenerator.beat(device: .trackerMini, steps: 32, seed: 77)],
            instruments: [.init(name: "kick", wav: sampleWav())]
        )
    }

    @Test("A document survives a save and load unchanged")
    func roundTrip() throws {
        let original = file()
        let reloaded = try ProjectFile.decoded(from: original.data())
        #expect(reloaded == original)
    }

    @Test("Everything that shapes the work is kept, not just the notes")
    func keepsContext() throws {
        let reloaded = try ProjectFile.decoded(from: file().data())
        #expect(reloaded.projectName == "Night Bus")
        #expect(reloaded.device == .trackerMini)
        #expect(reloaded.tempo == 148)
        #expect(reloaded.baseOctave == 3)
        #expect(reloaded.key == MusicalKey(root: 5, scale: .dorian))
        // The seed matters: it is how a generated pattern can be made again.
        #expect(reloaded.patterns[0].metadata.seed == 77)
        #expect(reloaded.patterns[0].tracks.count == DeviceProfile.trackerMini.trackCount)
        // Track names and FX come back too.
        #expect(reloaded.patterns[0].tracks[0].name == "Kick")
        let fx = reloaded.patterns[0].tracks.flatMap { $0.steps }.flatMap { $0.fx }
        #expect(fx.contains { $0.type == .volume })
    }

    @Test("Audio travels inside the document, so moving the file keeps the sample")
    func carriesAudio() throws {
        let reloaded = try ProjectFile.decoded(from: file().data())
        #expect(reloaded.instruments.count == 1)
        #expect(reloaded.instruments[0].wav == sampleWav())
        // And it is still loadable as an instrument.
        let instrument = try Instrument.new(wav: reloaded.instruments[0].wav, filename: "kick")
        #expect(instrument.sample.length == 200)
    }

    @Test("A file from a newer build is refused, not half-read")
    func refusesNewerVersion() throws {
        var future = file()
        future.version = ProjectFile.currentVersion + 1
        #expect(throws: ProjectFile.DocumentError.newerVersion(ProjectFile.currentVersion + 1)) {
            try ProjectFile.decoded(from: future.data())
        }
    }

    @Test("Something that isn't a document gives a readable error")
    func refusesGarbage() {
        #expect(throws: ProjectFile.DocumentError.unreadable) {
            try ProjectFile.decoded(from: Data("not json".utf8))
        }
        #expect(throws: ProjectFile.DocumentError.unreadable) {
            try ProjectFile.decoded(from: Data())
        }
    }

    @Test("An empty document is valid")
    func emptyDocument() throws {
        let reloaded = try ProjectFile.decoded(from: ProjectFile().data())
        #expect(reloaded.patterns.isEmpty)
        #expect(reloaded.instruments.isEmpty)
        #expect(reloaded.version == ProjectFile.currentVersion)
    }
}
