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
        // Instruments come back with their audio, in slot order, and without the
        // slot number, which the writer puts back on.
        #expect(result.instrumentNames == ["kick"])
        #expect(result.instruments.count == 1)
        #expect(result.instruments[0].instrument.sample.filename == "kick")
        #expect(result.instruments[0].instrument.pcm == instrument.pcm)
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

    @Test("An imported project can be written straight back out unchanged")
    func importExportImport() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let wav = WavFile.make(pcm: Data((0..<400).map { UInt8($0 % 256) }), channels: 1)
        let instrument = try Instrument.new(wav: wav, filename: "clap")
        let pattern = BeatGenerator.beat(device: .trackerPlus, name: "Verse", steps: 32, seed: 12)
        _ = try ProjectBundleWriter.write(patterns: [pattern], projectName: "Cycle",
                                          device: .trackerPlus, tempo: 138,
                                          instruments: [.init(name: "clap", instrument: instrument)], to: root)

        let first = try ProjectBundleReader.read(at: root.appendingPathComponent("Cycle"))
        let out = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: out) }
        _ = try ProjectBundleWriter.write(
            patterns: first.patterns, projectName: first.projectName, device: .trackerPlus,
            tempo: Float(first.tempo),
            instruments: first.instruments.map { .init(name: $0.name, instrument: $0.instrument) },
            to: out
        )
        let second = try ProjectBundleReader.read(at: out.appendingPathComponent("Cycle"))

        // Names do not accumulate slot prefixes, and nothing musical changes.
        #expect(second.instrumentNames == ["clap"])
        #expect(second.instruments[0].instrument.pcm == first.instruments[0].instrument.pcm)
        #expect(second.tempo == first.tempo)
        #expect(second.patterns.map { $0.metadata.name } == first.patterns.map { $0.metadata.name })
        #expect(second.patterns[0].tracks.map(\.name) == first.patterns[0].tracks.map(\.name))
    }

    @Test("A project from older firmware still gives up its patterns")
    func olderFirmware() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let pattern = BeatGenerator.beat(device: .trackerPlus, name: "Old", steps: 16, seed: 9)
        let written = try ProjectBundleWriter.write(patterns: [pattern], projectName: "Legacy",
                                                    device: .trackerPlus, tempo: 175, to: root)
        // A 1572-byte project.mt, the size older firmware wrote.
        let truncated = try Data(contentsOf: written.projectFile).prefix(1572)
        try truncated.write(to: written.projectFile)

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("Legacy"))
        #expect(result.patterns.count == 1)
        #expect(result.patterns[0].metadata.name == "Old")
        #expect(result.projectName == "Legacy")           // falls back to the folder
        #expect(result.tempo == ProjectBundleReader.defaultTempo)
        #expect(result.warnings.contains { $0.contains("older firmware") })
    }

    @Test("An 8-track pattern is padded to the device it is imported into")
    func padsShortPatterns() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // Write a pattern with only 8 tracks, as older hardware did.
        let short = Pattern(metadata: PatternMetadata(name: "Old"), device: .trackerPlus,
                            tracks: Array(BeatGenerator.beat(device: .trackerPlus, steps: 16, seed: 4).tracks.prefix(8)))
        let dir = root.appendingPathComponent("Short/patterns", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try MTPExporter.export(short).write(to: dir.appendingPathComponent("pattern_01.mtp"))
        try MTProject.new(name: "Short", device: .trackerPlus).data()
            .write(to: root.appendingPathComponent("Short/project.mt"))

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("Short"))
        #expect(result.patterns[0].tracks.count == DeviceProfile.trackerPlus.trackCount)
        #expect(result.patterns[0].tracks[0].steps.contains { $0.isActive })
        #expect(result.patterns[0].tracks[15].steps.allSatisfy { !$0.isActive })
        #expect(result.warnings.contains { $0.contains("8 tracks") })
    }

    @Test("Picking the patterns folder, or a file in it, still finds the project")
    func forgivingSelection() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let pattern = BeatGenerator.beat(device: .trackerPlus, name: "P", steps: 16, seed: 8)
        let written = try ProjectBundleWriter.write(patterns: [pattern], projectName: "Inside",
                                                    device: .trackerPlus, to: root)
        let patternsDir = written.patternFiles[0].deletingLastPathComponent()

        #expect(try ProjectBundleReader.read(at: patternsDir).projectName == "Inside")
        #expect(try ProjectBundleReader.read(at: written.patternFiles[0]).projectName == "Inside")
        #expect(try ProjectBundleReader.read(at: written.projectFile).projectName == "Inside")
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
