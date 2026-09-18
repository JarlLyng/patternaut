import Foundation

/// Options controlling the `.mtp` file header and trailer. Defaults match the
/// values `tracker-lib` `createPattern` emits, so output is byte-identical to
/// the official library.
/// Header values written into a `.mtp` file.
///
/// The defaults are what a Tracker+ on firmware 1.9.2 writes itself, read off a
/// real SD card: signature `KS`, type 2, and a `size` field holding the actual
/// file size. `tracker-lib`'s own writer defaults differ (`PM`, type 0, size 0);
/// the device is the authority here, so those values are passed explicitly when
/// checking our bytes against that library.
public struct MTPExportOptions: Sendable, Equatable {
    /// 2-byte ASCII file signature. The device writes `"KS"`.
    public var idFile: String
    /// Header `type` field (uint16). The device writes `2`.
    public var type: Int
    /// Firmware version bytes `[major, minor, patch, beta]`.
    public var fwVersion: [UInt8]
    /// File-structure version bytes (stored as 4 bytes). `5` is the 16-track layout.
    public var fileStructureVersion: [UInt8]
    /// Header `size` field (uint16). `nil` writes the file's actual size, which
    /// is what the device does; `tracker-lib` writes `0`.
    public var size: Int?
    /// Trailer CRC. `tracker-lib` stores `0` (see ``CRC32``).
    public var crc: UInt32

    public init(
        idFile: String = "KS",
        type: Int = 2,
        fwVersion: [UInt8] = [1, 9, 2, 1],
        fileStructureVersion: [UInt8] = [5, 5, 5, 5],
        size: Int? = nil,
        crc: UInt32 = 0
    ) {
        self.idFile = idFile
        self.type = type
        self.fwVersion = fwVersion
        self.fileStructureVersion = fileStructureVersion
        self.size = size
        self.crc = crc
    }

    public static let `default` = MTPExportOptions()
}

/// Serializes a ``Pattern`` to Polyend `.mtp` bytes.
///
/// The byte layout is ported from `tracker-lib` `Pattern.write` and verified
/// byte-for-byte against it (see the export tests). Layout:
///
/// ```
/// Header (14 B): idFile[2] · type(u16LE) · fwVersion[4] · fileStructureVersion[4] · size(u16LE)
/// Padding (2 B, 0) · Unused (12 B, 0)
/// Per track: lastStepIndex(u8, = steps - 1) · 128 × step(6 B)
///   step: note(i8) · instrument(u8) · fx1Type(u8) · fx1Val(u8) · fx0Type(u8) · fx0Val(u8)
/// CRC (4 B, u32LE)
/// ```
///
/// Note the effect lanes are stored **reversed** (fx1 before fx0), and a lane
/// whose type is `none` (index 0) always writes value `0`.
public enum MTPExporter {
    /// Number of steps every track slot occupies on disk, regardless of the
    /// track's active length.
    static let stepsPerTrack = TrackerFormat.maxSteps // 128

    /// Serializes `pattern` to `.mtp` bytes.
    public static func export(_ pattern: Pattern, options: MTPExportOptions = .default) -> Data {
        export(tracks: pattern.tracks, options: options)
    }

    /// Serializes a raw track list with explicit header/trailer options. This is
    /// the core serializer; ``MTPImporter`` produces inputs for it that
    /// round-trip byte-for-byte.
    public static func export(tracks: [Track], options: MTPExportOptions = .default) -> Data {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(estimatedSize(trackCount: tracks.count))

        // The device stores the finished file's size in the header, so resolve
        // `nil` to what this file will actually weigh.
        writeHeader(into: &bytes, options: options,
                    size: options.size ?? estimatedSize(trackCount: tracks.count))

        // Padding (2) + reserved/unused (12), all zero.
        bytes.append(contentsOf: repeatElement(0, count: TrackerFormatLayout.paddingSize + TrackerFormatLayout.unusedSize))

        for track in tracks {
            writeTrack(track, into: &bytes)
        }

        appendUInt32LE(options.crc, into: &bytes)
        return Data(bytes)
    }

    // MARK: - Private

    private static func estimatedSize(trackCount: Int) -> Int {
        let trackSize = TrackerFormatLayout.trackHeaderSize + TrackerFormat.stepSizeBytes * stepsPerTrack
        return TrackerFormatLayout.headerSize
            + TrackerFormatLayout.paddingSize
            + TrackerFormatLayout.unusedSize
            + trackSize * trackCount
            + TrackerFormatLayout.crcSize
    }

    private static func writeHeader(into bytes: inout [UInt8], options: MTPExportOptions, size: Int) {
        // id_file: exactly 2 ASCII bytes.
        let idBytes = Array(options.idFile.utf8.prefix(2))
        bytes.append(contentsOf: idBytes)
        bytes.append(contentsOf: repeatElement(0, count: max(0, 2 - idBytes.count)))

        appendUInt16LE(options.type, into: &bytes)

        for i in 0..<4 { bytes.append(i < options.fwVersion.count ? options.fwVersion[i] : 0) }
        for i in 0..<4 { bytes.append(i < options.fileStructureVersion.count ? options.fileStructureVersion[i] : 0) }

        appendUInt16LE(size, into: &bytes)
    }

    private static func writeTrack(_ track: Track, into bytes: inout [UInt8]) {
        // On disk this byte is the LAST STEP INDEX, not the step count: every
        // pattern file on a real card uses 7, 31, 63 or 127 for 8, 32, 64 or 128
        // steps, and `tracker-lib`'s own `createPattern` stores `numSteps - 1`.
        // Our model counts steps, so subtract one on the way out.
        bytes.append(UInt8(clamping: max(0, track.length - 1)))
        for i in 0..<stepsPerTrack {
            if i < track.steps.count {
                writeStep(track.steps[i], into: &bytes)
            } else {
                bytes.append(contentsOf: repeatElement(0, count: TrackerFormat.stepSizeBytes))
            }
        }
    }

    private static func writeStep(_ step: Step, into bytes: inout [UInt8]) {
        bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: step.note.rawValue)))
        bytes.append(UInt8(clamping: step.instrument ?? 0))

        let fx0 = step.fx.count > 0 ? step.fx[0] : nil
        let fx1 = step.fx.count > 1 ? step.fx[1] : nil

        let (fx1Type, fx1Value) = laneBytes(fx1)
        let (fx0Type, fx0Value) = laneBytes(fx0)

        // Reversed on disk: fx1 first, then fx0.
        bytes.append(fx1Type)
        bytes.append(fx1Value)
        bytes.append(fx0Type)
        bytes.append(fx0Value)
    }

    /// Resolves a lane to `(typeIndex, value)`. A `none` lane forces value `0`.
    private static func laneBytes(_ command: FXCommand?) -> (UInt8, UInt8) {
        guard let command else { return (0, 0) }
        let typeIndex = command.type.rawValue
        if typeIndex == 0 { return (0, 0) }
        return (UInt8(clamping: typeIndex), UInt8(clamping: command.value))
    }

    private static func appendUInt16LE(_ value: Int, into bytes: inout [UInt8]) {
        let v = UInt16(truncatingIfNeeded: value)
        bytes.append(UInt8(v & 0xFF))
        bytes.append(UInt8((v >> 8) & 0xFF))
    }

    private static func appendUInt32LE(_ value: UInt32, into bytes: inout [UInt8]) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 24) & 0xFF))
    }
}

/// Fixed byte sizes for the `.mtp` framing (from `tracker-lib` `PatternConstants`).
enum TrackerFormatLayout {
    static let headerSize = 14
    static let paddingSize = 2
    static let unusedSize = 12
    static let trackHeaderSize = 1
    static let crcSize = 4
}
