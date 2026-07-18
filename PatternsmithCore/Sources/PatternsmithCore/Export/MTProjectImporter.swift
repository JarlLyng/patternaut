import Foundation

/// Parses Polyend `.mt` bytes into an ``MTProject``. The inverse of
/// ``MTProjectExporter``; ported from `tracker-lib` `Project.parse`.
///
/// Only the fields `tracker-lib` understands are recovered; unknown regions are
/// ignored (they survive an export because it patches a template copy).
public enum MTProjectImporter {
    public static func parse(_ data: Data) throws -> MTProject {
        let b = [UInt8](data)
        guard b.count >= 0x810 + TrackerFormat.projectNameLength else {
            throw MTError.tooSmall(b.count)
        }

        // Header @0
        let idFile = String(decoding: b[0..<2], as: UTF8.self)
        guard idFile == "MT" else { throw MTError.invalidSignature(idFile) }
        let type = Int(readU16LE(b, 2))
        let fwVersion = Array(b[4..<8])
        let fileStructureVersion = Array(b[8..<12])
        let size = Int(readU16LE(b, 12))

        // Song @16
        var playlist = [UInt8](repeating: 0, count: TrackerFormat.songSlots)
        for i in 0..<TrackerFormat.songSlots { playlist[i] = b[16 + i] }
        let playlistPos = b[16 + TrackerFormat.songSlots]

        // Global tempo
        let globalTempo = readF32LE(b, 0x1C0)

        // Track names
        var trackNames: [String] = []
        for i in 0..<8 {
            trackNames.append(readASCII(b, 0x428 + i * TrackerFormat.trackNameLength, length: TrackerFormat.trackNameLength))
        }
        let version = Int(fileStructureVersion.first ?? 0)
        let legacy = version <= 15
        if !legacy {
            for i in 0..<8 {
                trackNames.append(readASCII(b, 0x603 + i * TrackerFormatShort.trackNameLength, length: TrackerFormatShort.trackNameLength))
            }
        }

        // Delay
        let delay = MTProject.Delay(
            feedback: b[0x11A],
            time: readU16LE(b, 0x11C),
            params: b[0x11F],
            volume: b[0x539],
            mute: b[0x53B]
        )

        // Reverb
        let reverb = MTProject.Reverb(
            size: readF32LE(b, 0x418),
            damp: readF32LE(b, 0x41C),
            predelay: readF32LE(b, 0x420),
            diffusion: readF32LE(b, 0x424),
            volume: b[0x538],
            mute: b[0x53A]
        )

        // Project name (v17+ → 0x810; older layouts differ)
        let projectNameOffset = version > 16 ? 0x810 : (version > 15 ? 0x80C : 0x600)
        let projectName = readASCII(b, projectNameOffset, length: TrackerFormat.projectNameLength)

        return MTProject(
            header: MTProject.Header(
                idFile: idFile, type: type, fwVersion: fwVersion,
                fileStructureVersion: fileStructureVersion, size: size
            ),
            projectName: projectName,
            playlist: playlist,
            playlistPos: playlistPos,
            globalTempo: globalTempo,
            trackNames: trackNames,
            delay: delay,
            reverb: reverb
        )
    }

    // MARK: - Helpers

    private static func readU16LE(_ b: [UInt8], _ off: Int) -> UInt16 {
        UInt16(b[off]) | (UInt16(b[off + 1]) << 8)
    }

    private static func readF32LE(_ b: [UInt8], _ off: Int) -> Float {
        let bits = UInt32(b[off])
            | (UInt32(b[off + 1]) << 8)
            | (UInt32(b[off + 2]) << 16)
            | (UInt32(b[off + 3]) << 24)
        return Float(bitPattern: bits)
    }

    private static func readASCII(_ b: [UInt8], _ off: Int, length: Int) -> String {
        let slice = b[off..<off + length]
        let trimmed = slice.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }
}

/// Errors thrown while parsing a `.mt` file.
public enum MTError: Error, Equatable {
    case tooSmall(Int)
    case invalidSignature(String)
}
