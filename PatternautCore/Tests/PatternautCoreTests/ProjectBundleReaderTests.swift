import Foundation
import Testing
@testable import PatternautCore

@Suite("Project bundle reader")
struct ProjectBundleReaderTests {
    func temporaryRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patternaut-read-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("A project we wrote reads back with its patterns, names and tempo")
    func roundTrip() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        var first = BeatGenerator.beat(device: .trackerPlus, name: "Opener", steps: 32, seed: 5)
        first.tracks[0].name = "Kick"
        let second = BeatGenerator.beat(device: .trackerPlus, name: "Break", steps: 16, seed: 6)
        let wav = WavFile.make(pcm: Data([UInt8](repeating: 3, count: 200)), channels: 1)
        let instrument = try Instrument.new(wav: wav, filename: "kick")

        _ = try ProjectBundleWriter.write(
            patterns: [first, second], projectName: "Night Bus", device: .trackerPlus, tempo: 142,
            instruments: [.init(name: "kick", instrument: instrument)], to: root
        )

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("Night Bus"))
        #expect(result.projectName == "Night Bus")
        #expect(result.tempo == 142)
        #expect(result.patterns.count == 2)
        #expect(result.patterns[0].metadata.name == "Opener")
        #expect(result.patterns[1].metadata.name == "Break")
        // Track names come from project.mt, since the pattern files hold none.
        #expect(result.patterns[0].tracks[0].name == "Kick")
        #expect(result.instrumentNames == ["1 kick"])
    }

    @Test("The notes and effects survive the trip to disk and back")
    func musicSurvives() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let pattern = BeatGenerator.beat(device: .trackerPlus, name: "P", steps: 32, seed: 21)
        _ = try ProjectBundleWriter.write(patterns: [pattern], projectName: "X", device: .trackerPlus, to: root)

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("X"))
        let reloaded = result.patterns[0]
        #expect(reloaded.tracks.count == pattern.tracks.count)
        for (a, b) in zip(pattern.tracks, reloaded.tracks) {
            #expect(a.length == b.length)
            let hitsA = a.steps.prefix(a.length).filter(\.isActive).map(\.note)
            let hitsB = b.steps.prefix(b.length).filter(\.isActive).map(\.note)
            #expect(hitsA == hitsB)
        }
        let fx = reloaded.tracks.flatMap { $0.steps.prefix($0.length) }.flatMap { $0.fx }
        #expect(fx.contains { $0.type == .volume })
    }

    @Test("A folder that isn't a project says so")
    func rejectsNonProject() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: ProjectBundleReader.ReadError.notAProject(root.lastPathComponent)) {
            try ProjectBundleReader.read(at: root)
        }
    }

    @Test("macOS companion files are not mistaken for patterns")
    func ignoresAppleDouble() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let pattern = BeatGenerator.beat(device: .trackerPlus, name: "P", steps: 16, seed: 3)
        let written = try ProjectBundleWriter.write(patterns: [pattern], projectName: "Y", device: .trackerPlus, to: root)
        let patternsDir = written.patternFiles[0].deletingLastPathComponent()
        try Data([0, 5, 22]).write(to: patternsDir.appendingPathComponent("._pattern_01.mtp"))

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("Y"))
        #expect(result.patterns.count == 1)
    }
}
