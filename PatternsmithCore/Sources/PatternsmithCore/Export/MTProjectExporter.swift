import Foundation

/// Serializes an ``MTProject`` to `.mt` bytes by patching known fields into a
/// copy of the embedded template. Ported from `tracker-lib` `Project.write`
/// and verified byte-for-byte against it.
///
/// Absolute field offsets (matching the file structure v17+):
/// header@0, song@16, delay@0x11a, tempo@0x1c0, reverb floats@0x418,
/// track names@0x428 (8×21) and @0x603 (8×8), volumes@0x538, project name@0x810.
public enum MTProjectExporter {
    public static func export(_ project: MTProject) -> Data {
        var b = MTProjectTemplate.bytes

        // Header @0
        let id = Array(project.header.idFile.utf8.prefix(2))
        b[0] = id.first ?? 0
        b[1] = id.count > 1 ? id[1] : 0
        writeU16LE(&b, 2, UInt16(truncatingIfNeeded: project.header.type))
        for i in 0..<4 { b[4 + i] = i < project.header.fwVersion.count ? project.header.fwVersion[i] : 0 }
        for i in 0..<4 { b[8 + i] = i < project.header.fileStructureVersion.count ? project.header.fileStructureVersion[i] : 0 }
        writeU16LE(&b, 12, UInt16(truncatingIfNeeded: project.header.size))

        // Song @16: 255 playlist bytes + playlistPos
        for i in 0..<TrackerFormat.songSlots {
            b[16 + i] = i < project.playlist.count ? project.playlist[i] : 0
        }
        b[16 + TrackerFormat.songSlots] = project.playlistPos

        // Global tempo
        writeF32LE(&b, 0x1C0, project.globalTempo)

        // Delay
        b[0x11A] = project.delay.feedback
        writeU16LE(&b, 0x11C, project.delay.time)
        b[0x11F] = project.delay.params

        // Reverb
        writeF32LE(&b, 0x418, project.reverb.size)
        writeF32LE(&b, 0x41C, project.reverb.damp)
        writeF32LE(&b, 0x420, project.reverb.predelay)
        writeF32LE(&b, 0x424, project.reverb.diffusion)

        // Volumes / mutes
        b[0x538] = project.reverb.volume
        b[0x539] = project.delay.volume
        b[0x53A] = project.reverb.mute
        b[0x53B] = project.delay.mute

        // Track names: first 8 × 21 bytes @0x428, next 8 × 8 bytes @0x603
        for i in 0..<8 {
            writeASCII(&b, 0x428 + i * TrackerFormat.trackNameLength, name(project, i), length: TrackerFormat.trackNameLength)
        }
        for i in 0..<8 {
            writeASCII(&b, 0x603 + i * TrackerFormatShort.trackNameLength, name(project, 8 + i), length: TrackerFormatShort.trackNameLength)
        }

        // Project name @0x810 (v17+)
        writeASCII(&b, 0x810, project.projectName, length: TrackerFormat.projectNameLength)

        return Data(b)
    }

    // MARK: - Helpers

    private static func name(_ project: MTProject, _ index: Int) -> String {
        index < project.trackNames.count ? project.trackNames[index] : ""
    }

    private static func writeU16LE(_ b: inout [UInt8], _ off: Int, _ v: UInt16) {
        b[off] = UInt8(v & 0xFF)
        b[off + 1] = UInt8((v >> 8) & 0xFF)
    }

    private static func writeF32LE(_ b: inout [UInt8], _ off: Int, _ v: Float) {
        let bits = v.bitPattern
        b[off] = UInt8(bits & 0xFF)
        b[off + 1] = UInt8((bits >> 8) & 0xFF)
        b[off + 2] = UInt8((bits >> 16) & 0xFF)
        b[off + 3] = UInt8((bits >> 24) & 0xFF)
    }

    /// Writes ASCII into `length` bytes, truncating or zero-padding — matching
    /// `tracker-lib`'s per-character write.
    private static func writeASCII(_ b: inout [UInt8], _ off: Int, _ s: String, length: Int) {
        let bytes = Array(s.utf8)
        for j in 0..<length {
            b[off + j] = j < bytes.count ? bytes[j] : 0
        }
    }
}

/// The 8-byte short track-name field used for tracks 9–16.
enum TrackerFormatShort {
    static let trackNameLength = 8 // TRACK_NAME_SIZE_SHORT
}
