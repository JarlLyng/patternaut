import Foundation
import Testing
@testable import PatternautCore

@Suite("MTP round-trip")
struct MTPRoundTripTests {
    /// Effective (non-none) FX as sortable ints, for content comparison.
    func effectiveFX(_ s: Step) -> [Int] {
        s.fx.filter { $0.type != .none }.map { $0.type.rawValue * 1000 + $0.value }.sorted()
    }

    // MARK: Byte-level inverse

    @Test("Parsing then re-exporting the reference file is byte-identical")
    func fixtureByteRoundTrip() throws {
        let vectors = try MTPExporterTests.loadVectors()
        // Only the 16-track case is a realistic, parseable device file.
        let data = Data(base64Encoded: vectors.cases[0].expectedBase64)!

        let doc = try MTPImporter.parse(data)
        #expect(doc.data() == data)
    }

    @Test("Export → parse → re-export is byte-identical for a generated pattern")
    func generatedByteRoundTrip() throws {
        let kick = RhythmGenerator.euclidean(pulses: 4, steps: 16, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let hat = RhythmGenerator.euclidean(pulses: 11, steps: 16, rotation: 2, note: .pitch(42), instrument: 1, velocity: 70, name: "Hat")
        let pattern = PatternGenerator.assemble(device: .trackerPlus, name: "BB", steps: 16, seed: 1, tracks: [kick, hat])

        let bytes = MTPExporter.export(pattern)
        let doc = try MTPImporter.parse(bytes)
        #expect(doc.data() == bytes)
    }

    // MARK: Header/options recovery

    @Test("Default and custom header/CRC options are recovered")
    func optionsRoundTrip() throws {
        let pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "X", stepCount: 16)

        let defaultDoc = try MTPImporter.parse(MTPExporter.export(pattern))
        #expect(defaultDoc.options == MTPExportOptions.default)

        let custom = MTPExportOptions(
            idFile: "PM", type: 2, fwVersion: [1, 9, 2, 3],
            fileStructureVersion: [7, 7, 7, 7], size: 1234, crc: 0xDEAD_BEEF
        )
        let customDoc = try MTPImporter.parse(MTPExporter.export(pattern, options: custom))
        #expect(customDoc.options == custom)
    }

    // MARK: Semantic decode

    @Test("Parsed fields match known reference content")
    func semanticParse() throws {
        let vectors = try MTPExporterTests.loadVectors()
        let doc = try MTPImporter.parse(Data(base64Encoded: vectors.cases[0].expectedBase64)!)

        #expect(doc.tracks.count == 16)
        let s = doc.tracks[0].steps[0]
        #expect(s.note == .pitch(60))
        #expect(s.instrument == 1)
        // fx[0] = fx0 = Chance(50); fx[1] = fx1 = Roll(2) — reversed lanes decoded.
        #expect(s.fx[0].type == .chance && s.fx[0].value == 50)
        #expect(s.fx[1].type == .roll && s.fx[1].value == 2)

        let midi = doc.tracks[8].steps[3]
        #expect(midi.note == .pitch(48))
        #expect(midi.fx[0].type == .midiCCA && midi.fx[0].value == 100)
    }

    // MARK: Musical content survives

    @Test("Generated musical content survives a round-trip")
    func contentRoundTrip() throws {
        let kick = RhythmGenerator.euclidean(pulses: 5, steps: 16, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let pattern = PatternGenerator.assemble(device: .trackerMini, name: "X", steps: 16, seed: 9, tracks: [kick])
        let doc = try MTPImporter.parse(MTPExporter.export(pattern))

        let original = pattern.tracks[0]
        let parsed = doc.tracks[0]
        #expect(parsed.length == original.length)

        for i in 0..<original.length {
            #expect(parsed.steps[i].note == original.steps[i].note)
            if original.steps[i].isActive {
                #expect((parsed.steps[i].instrument ?? 0) == (original.steps[i].instrument ?? 0))
                #expect(effectiveFX(parsed.steps[i]) == effectiveFX(original.steps[i]))
            }
        }
    }

    // MARK: Errors

    @Test("Malformed input throws descriptive errors")
    func errors() throws {
        #expect(throws: MTPError.self) { try MTPImporter.parse(Data([0, 1, 2])) }
        #expect(throws: MTPError.self) { try MTPImporter.parse(Data(count: 100)) }

        // Valid size, bad signature.
        let vectors = try MTPExporterTests.loadVectors()
        var bytes = [UInt8](Data(base64Encoded: vectors.cases[0].expectedBase64)!)
        bytes[0] = UInt8(ascii: "X")
        #expect(throws: MTPError.self) { try MTPImporter.parse(Data(bytes)) }
    }
}
