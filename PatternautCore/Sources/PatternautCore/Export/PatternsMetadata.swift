import Foundation

/// The `patternsMetadata` file that sits beside the `.mtp` files in a project's
/// `patterns` folder and names each pattern slot.
///
/// `tracker-lib` refuses to load a project without it ("Missing essential
/// project files"), so a bundle we write has to include one. Ported from
/// `tracker-lib` `Metadata.writePatternsMetadata` and its `PatternsMeta`
/// constants.
public struct PatternsMetadata: Equatable, Sendable {
    public static let fileIdentifier = "PAMD"
    public static let version: UInt16 = 1
    public static let headerSize = 16
    /// Each record is 50 bytes; the name occupies the first 31.
    public static let recordSize = 50
    public static let nameLength = 31

    /// One name per pattern slot, in slot order. Empty names are allowed.
    public var patternNames: [String]
    /// Kept for round-tripping; `tracker-lib` writes 0.
    public var controlFlags: UInt32

    public init(patternNames: [String], controlFlags: UInt32 = 0) {
        self.patternNames = patternNames
        self.controlFlags = controlFlags
    }

    /// The file's bytes: 16-byte header followed by one record per pattern.
    public func data() -> Data {
        var b = [UInt8]()
        b.append(contentsOf: Array(PatternsMetadata.fileIdentifier.utf8.prefix(4)))
        appendU16LE(&b, PatternsMetadata.version)
        b.append(contentsOf: [0, 0]) // unused
        appendU32LE(&b, UInt32(PatternsMetadata.headerSize + patternNames.count * PatternsMetadata.recordSize))
        appendU32LE(&b, controlFlags)

        for name in patternNames {
            var record = [UInt8](repeating: 0, count: PatternsMetadata.recordSize)
            for (index, byte) in Array(name.utf8.prefix(PatternsMetadata.nameLength)).enumerated() {
                record[index] = byte
            }
            b.append(contentsOf: record)
        }
        return Data(b)
    }

    /// Parses a `patternsMetadata` file.
    public static func parse(_ data: Data) throws -> PatternsMetadata {
        let b = [UInt8](data)
        guard b.count >= headerSize else { throw MetadataError.tooShort }
        guard String(decoding: b[0..<4], as: UTF8.self) == fileIdentifier else {
            throw MetadataError.badIdentifier(String(decoding: b[0..<4], as: UTF8.self))
        }
        let fileVersion = UInt16(b[4]) | (UInt16(b[5]) << 8)
        guard fileVersion == version else { throw MetadataError.unsupportedVersion(fileVersion) }
        let flags = UInt32(b[12]) | (UInt32(b[13]) << 8) | (UInt32(b[14]) << 16) | (UInt32(b[15]) << 24)

        var names: [String] = []
        var offset = headerSize
        while offset + recordSize <= b.count {
            let field = b[offset..<offset + nameLength]
            let end = field.firstIndex(of: 0) ?? field.endIndex
            names.append(String(decoding: field[field.startIndex..<end], as: UTF8.self))
            offset += recordSize
        }
        return PatternsMetadata(patternNames: names, controlFlags: flags)
    }

    public enum MetadataError: Error, Equatable {
        case tooShort
        case badIdentifier(String)
        case unsupportedVersion(UInt16)
    }

    private func appendU16LE(_ b: inout [UInt8], _ v: UInt16) {
        b.append(UInt8(v & 0xFF)); b.append(UInt8(v >> 8))
    }

    private func appendU32LE(_ b: inout [UInt8], _ v: UInt32) {
        b.append(UInt8(v & 0xFF)); b.append(UInt8((v >> 8) & 0xFF))
        b.append(UInt8((v >> 16) & 0xFF)); b.append(UInt8((v >> 24) & 0xFF))
    }
}
