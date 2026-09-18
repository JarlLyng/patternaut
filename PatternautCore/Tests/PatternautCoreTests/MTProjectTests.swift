import Foundation
import Testing
@testable import PatternautCore

@Suite("MT project")
struct MTProjectTests {
    // MARK: Fixtures

    struct Vectors: Codable { let cases: [Case] }
    struct Case: Codable {
        let name: String
        let header: Header
        let projectName: String
        let playlist: [UInt8]
        let playlistPos: UInt8
        let globalTempo: Float
        let trackNames: [String]
        let delay: DelaySpec
        let reverb: ReverbSpec
        let expectedBase64: String
    }
    struct Header: Codable { let idFile: String; let type: Int; let fwVersion: [UInt8]; let fileStructureVersion: [UInt8]; let size: Int }
    struct DelaySpec: Codable { let feedback: UInt8; let time: UInt16; let params: UInt8; let volume: UInt8; let mute: UInt8 }
    struct ReverbSpec: Codable { let size: Float; let damp: Float; let predelay: Float; let diffusion: Float; let volume: UInt8; let mute: UInt8 }

    static func loadVectors() throws -> Vectors {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/mt_vectors.json")
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }

    func makeProject(_ c: Case) -> MTProject {
        MTProject(
            header: MTProject.Header(
                idFile: c.header.idFile, type: c.header.type, fwVersion: c.header.fwVersion,
                fileStructureVersion: c.header.fileStructureVersion, size: c.header.size
            ),
            projectName: c.projectName,
            playlist: c.playlist,
            playlistPos: c.playlistPos,
            globalTempo: c.globalTempo,
            trackNames: c.trackNames,
            delay: MTProject.Delay(feedback: c.delay.feedback, time: c.delay.time, params: c.delay.params, volume: c.delay.volume, mute: c.delay.mute),
            reverb: MTProject.Reverb(size: c.reverb.size, damp: c.reverb.damp, predelay: c.reverb.predelay, diffusion: c.reverb.diffusion, volume: c.reverb.volume, mute: c.reverb.mute)
        )
    }

    // MARK: Byte-exact vs tracker-lib

    @Test("Project export matches tracker-lib byte-for-byte")
    func matchesOracle() throws {
        let vectors = try Self.loadVectors()
        #expect(vectors.cases.count == 2)
        for c in vectors.cases {
            let data = MTProjectExporter.export(makeProject(c))
            let expected = Data(base64Encoded: c.expectedBase64)!
            #expect(data.count == 2324)
            #expect(data == expected, "\(c.name): differs from tracker-lib")
        }
    }

    // MARK: Round-trip

    @Test("Parse recovers the written project fields")
    func roundTrip() throws {
        let vectors = try Self.loadVectors()
        for c in vectors.cases {
            let project = makeProject(c)
            let parsed = try MTProjectImporter.parse(MTProjectExporter.export(project))
            #expect(parsed == project, "\(c.name): round-trip mismatch")
        }
    }

    @Test("Default project matches createProject defaults")
    func defaults() {
        let p = MTProject.new(name: "MyTrack", device: .trackerPlus)
        #expect(p.globalTempo == 130)
        #expect(p.playlist[0] == 1)
        #expect(p.playlist.count == 255)
        #expect(p.trackNames == ["Track 1", "Track 2", "Track 3", "Track 4", "Track 5", "Track 6", "Track 7", "Track 8",
                                 "Midi 9", "Midi 10", "Midi 11", "Midi 12", "Midi 13", "Midi 14", "Midi 15", "Midi 16"])
        #expect(p.header.fileStructureVersion == [17, 17, 17, 17])
    }

    @Test("Bad signature and short data throw")
    func errors() throws {
        #expect(throws: MTError.self) { try MTProjectImporter.parse(Data(count: 10)) }
        var bytes = MTProjectTemplate.bytes
        bytes[0] = UInt8(ascii: "X")
        #expect(throws: MTError.self) { try MTProjectImporter.parse(Data(bytes)) }
    }
}

@Suite("Project bundle")
struct ProjectBundleTests {
    @Test("Writing a bundle produces a loadable project folder")
    func writeBundle() throws {
        let kick = RhythmGenerator.euclidean(pulses: 4, steps: 16, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let hat = RhythmGenerator.euclidean(pulses: 11, steps: 16, note: .pitch(42), instrument: 1, velocity: 70, name: "Hat")
        let p1 = PatternGenerator.assemble(device: .trackerPlus, name: "A", steps: 16, seed: 1, tracks: [kick])
        let p2 = PatternGenerator.assemble(device: .trackerPlus, name: "B", steps: 16, seed: 2, tracks: [hat])

        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patternsmith-test-\(UInt64(abs(kick.id.hashValue)))", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try ProjectBundleWriter.write(
            patterns: [p1, p2], projectName: "Breakbeat", device: .trackerPlus, tempo: 160, to: root
        )

        // Files exist.
        #expect(FileManager.default.fileExists(atPath: result.projectFile.path))
        #expect(result.patternFiles.count == 2)
        #expect(result.patternFiles[0].lastPathComponent == "pattern_01.mtp")
        #expect(result.patternFiles[1].lastPathComponent == "pattern_02.mtp")
        // The names and cases tracker-lib reads back, including the metadata file
        // it treats as essential.
        #expect(result.patternFiles[0].deletingLastPathComponent().lastPathComponent == "patterns")
        #expect(FileManager.default.fileExists(atPath: result.metadataFile.path))

        // The device writes the full 256-slot table; ours names the slots in use.
        let metadata = try PatternsMetadata.parse(Data(contentsOf: result.metadataFile))
        #expect(metadata.patternNames.count == PatternsMetadata.slotCount)
        #expect(Array(metadata.patternNames.prefix(2)) == ["A", "B"])
        #expect(metadata.patternNames[2...].allSatisfy { $0.isEmpty })

        // project.mt parses with the expected song + tempo.
        let project = try MTProjectImporter.parse(Data(contentsOf: result.projectFile))
        #expect(project.projectName == "Breakbeat")
        #expect(project.globalTempo == 160)
        #expect(project.playlist[0] == 1)
        #expect(project.playlist[1] == 2)
        #expect(project.playlist[2] == 0)

        // The length byte is the last step index, the way every pattern file on a
        // real card stores it: a 16-step pattern writes 15.
        let raw = [UInt8](try Data(contentsOf: result.patternFiles[0]))
        #expect(raw[28] == 15)

        // pattern_01.mtp parses to 16 tracks with the kick on track 0.
        let pattern = try MTPImporter.parse(Data(contentsOf: result.patternFiles[0]))
        #expect(pattern.tracks.count == 16)
        #expect(pattern.tracks[0].steps[0].note == .pitch(36))
    }

    @Test("Bundle writes .pti instruments into the instruments folder")
    func writeBundleWithInstruments() throws {
        let pcm = Data([UInt8]([0, 0, 0x10, 0x27, 0xF0, 0xD8])) // 3 mono frames
        let wav = WavFile.make(pcm: pcm, channels: 1)
        let instrument = try Instrument.new(wav: wav, filename: "kick808")

        let kick = RhythmGenerator.euclidean(pulses: 4, steps: 16, note: .pitch(36), instrument: 0, name: "Kick")
        let pattern = PatternGenerator.assemble(device: .trackerMini, name: "X", steps: 16, seed: 1, tracks: [kick])

        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patternsmith-inst-\(UInt64(abs(kick.id.hashValue)))", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try ProjectBundleWriter.write(
            patterns: [pattern], projectName: "WithInst", device: .trackerMini,
            instruments: [.init(name: "kick808", instrument: instrument)], to: root
        )

        #expect(result.instrumentFiles.count == 1)
        // The device's own convention: the 1-based slot number prefixes the name,
        // so this file is instrument 0 in the pattern grid.
        #expect(result.instrumentFiles[0].lastPathComponent == "1 kick808.pti")
        #expect(result.instrumentFiles[0].deletingLastPathComponent().lastPathComponent == "instruments")
        let onDisk = try Data(contentsOf: result.instrumentFiles[0])
        #expect(onDisk == instrument.data())
        #expect(String(decoding: [UInt8](onDisk)[0..<2], as: UTF8.self) == "TI")
    }
}
