import Foundation
import Testing
@testable import PatternautCore

@Suite("Patterns metadata")
struct PatternsMetadataTests {
    struct Case: Codable { let names: [String]; let bytes: String }

    static func loadCases() throws -> [Case] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/patternsMetadata.json")
        return try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }

    @Test("Matches tracker-lib byte-for-byte")
    func matchesOracle() throws {
        for testCase in try Self.loadCases() {
            let expected = Data(base64Encoded: testCase.bytes)!
            let actual = PatternsMetadata(patternNames: testCase.names).data()
            #expect(actual == expected, "names: \(testCase.names)")
        }
    }

    @Test("Header says what it should")
    func header() {
        let data = [UInt8](PatternsMetadata(patternNames: ["A", "B"]).data())
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "PAMD")
        #expect(data[4] == 1 && data[5] == 0)            // version
        #expect(data[6] == 0 && data[7] == 0)            // unused
        let size = UInt32(data[8]) | (UInt32(data[9]) << 8) | (UInt32(data[10]) << 16) | (UInt32(data[11]) << 24)
        #expect(size == 16 + 2 * 50)
        #expect(data.count == Int(size))
    }

    @Test("Names round-trip, long ones truncate at the record's name field")
    func roundTrip() throws {
        let long = String(repeating: "x", count: 60)
        let original = PatternsMetadata(patternNames: ["Kick", "", "Break 3", long])
        let parsed = try PatternsMetadata.parse(original.data())
        #expect(parsed.patternNames.count == 4)
        #expect(parsed.patternNames[0] == "Kick")
        #expect(parsed.patternNames[1] == "")
        #expect(parsed.patternNames[2] == "Break 3")
        #expect(parsed.patternNames[3] == String(repeating: "x", count: 31))
    }

    @Test("A file that isn't patterns metadata is rejected")
    func rejectsGarbage() {
        #expect(throws: PatternsMetadata.MetadataError.tooShort) {
            try PatternsMetadata.parse(Data([0, 1, 2]))
        }
        var wrong = [UInt8](PatternsMetadata(patternNames: []).data())
        wrong[0] = UInt8(ascii: "X")
        #expect(throws: PatternsMetadata.MetadataError.badIdentifier("XAMD")) {
            try PatternsMetadata.parse(Data(wrong))
        }
        var oldVersion = [UInt8](PatternsMetadata(patternNames: []).data())
        oldVersion[4] = 9
        #expect(throws: PatternsMetadata.MetadataError.unsupportedVersion(9)) {
            try PatternsMetadata.parse(Data(oldVersion))
        }
    }
}
