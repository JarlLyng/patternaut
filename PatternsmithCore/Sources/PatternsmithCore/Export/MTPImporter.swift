import Foundation

/// A decoded `.mtp` file: the recovered header/trailer options plus tracks.
///
/// The `.mtp` format carries only per-track step data — track names, roles,
/// tempo, meter and metadata live in the `.mt` project, so they are not
/// recoverable here. Each track therefore has 128 steps (the on-disk count) and
/// a layout-derived placeholder name.
public struct MTPDocument: Sendable, Equatable {
    public var options: MTPExportOptions
    public var tracks: [Track]

    public init(options: MTPExportOptions, tracks: [Track]) {
        self.options = options
        self.tracks = tracks
    }

    /// Re-serializes this document. `MTPImporter.parse(doc.data()) == doc`, and
    /// `doc.data()` equals the bytes it was parsed from.
    public func data() -> Data {
        MTPExporter.export(tracks: tracks, options: options)
    }

    /// Wraps the decoded tracks into a full ``Pattern`` with app-level context
    /// the file itself cannot provide.
    public func makePattern(device: DeviceModel, name: String, tempo: Double = 120, meter: Meter = .fourFour) -> Pattern {
        Pattern(metadata: PatternMetadata(name: name), device: device, tempo: tempo, meter: meter, tracks: tracks)
    }
}

/// Errors thrown while parsing a `.mtp` file.
public enum MTPError: Error, Equatable {
    case tooSmall(Int)
    /// File size does not correspond to a valid 8/12/16-track pattern.
    case unexpectedSize(Int)
    case invalidSignature(String)
}

/// Parses Polyend `.mtp` bytes into an ``MTPDocument``.
///
/// The inverse of ``MTPExporter``; ported from `tracker-lib` `Pattern.parse`.
public enum MTPImporter {
    public static func parse(_ data: Data) throws -> MTPDocument {
        let bytes = [UInt8](data)
        let trackCount = try detectTrackCount(fileSize: bytes.count)

        var cursor = 0

        // Header
        let idFile = String(decoding: bytes[cursor..<cursor + 2], as: UTF8.self)
        cursor += 2
        guard idFile == "PM" || idFile == "KS" else {
            throw MTPError.invalidSignature(idFile)
        }
        let type = Int(readUInt16LE(bytes, cursor)); cursor += 2
        let fwVersion = Array(bytes[cursor..<cursor + 4]); cursor += 4
        let fileStructureVersion = Array(bytes[cursor..<cursor + 4]); cursor += 4
        let size = Int(readUInt16LE(bytes, cursor)); cursor += 2

        // Padding + unused
        cursor += TrackerFormatLayout.paddingSize + TrackerFormatLayout.unusedSize

        // Tracks
        let names = trackNames(count: trackCount)
        var tracks: [Track] = []
        tracks.reserveCapacity(trackCount)
        for i in 0..<trackCount {
            let length = Int(bytes[cursor]); cursor += 1
            var steps: [Step] = []
            steps.reserveCapacity(MTPExporter.stepsPerTrack)
            for _ in 0..<MTPExporter.stepsPerTrack {
                steps.append(readStep(bytes, &cursor))
            }
            let role: TrackRole = i < TrackerFormat.universalTrackCount ? .universal : .midiSynth
            tracks.append(Track(name: names[i], role: role, length: length, steps: steps))
        }

        // CRC
        let crc = readUInt32LE(bytes, cursor)

        let options = MTPExportOptions(
            idFile: idFile,
            type: type,
            fwVersion: fwVersion,
            fileStructureVersion: fileStructureVersion,
            size: size,
            crc: crc
        )
        return MTPDocument(options: options, tracks: tracks)
    }

    // MARK: - Private

    private static func detectTrackCount(fileSize: Int) throws -> Int {
        let base = TrackerFormatLayout.headerSize + TrackerFormatLayout.paddingSize + TrackerFormatLayout.unusedSize
        let trackSize = TrackerFormatLayout.trackHeaderSize + TrackerFormat.stepSizeBytes * TrackerFormat.maxSteps
        guard fileSize >= base + TrackerFormatLayout.crcSize else { throw MTPError.tooSmall(fileSize) }

        for count in [TrackerFormat.TrackGeneration.old, .og, .miniPlus].map(\.trackCount) {
            if fileSize == base + trackSize * count + TrackerFormatLayout.crcSize {
                return count
            }
        }
        throw MTPError.unexpectedSize(fileSize)
    }

    private static func readStep(_ bytes: [UInt8], _ cursor: inout Int) -> Step {
        let noteRaw = Int(Int8(bitPattern: bytes[cursor])); cursor += 1
        let instrument = Int(bytes[cursor]); cursor += 1
        let fx1Type = Int(bytes[cursor]); cursor += 1
        let fx1Value = Int(bytes[cursor]); cursor += 1
        let fx0Type = Int(bytes[cursor]); cursor += 1
        let fx0Value = Int(bytes[cursor]); cursor += 1

        // On disk fx1 precedes fx0; the model stores fx[0]=fx0, fx[1]=fx1.
        let fx = [
            lane(type: fx0Type, value: fx0Value),
            lane(type: fx1Type, value: fx1Value),
        ]
        return Step(note: Note(rawValue: noteRaw) ?? .empty, instrument: instrument, fx: fx)
    }

    private static func lane(type: Int, value: Int) -> FXCommand {
        let fxType = FXType(rawValue: type) ?? .none
        return FXCommand(type: fxType, value: fxType == .none ? 0 : value)
    }

    private static func trackNames(count: Int) -> [String] {
        (0..<count).map { $0 < TrackerFormat.universalTrackCount ? "Track \($0 + 1)" : "Midi \($0 + 1)" }
    }

    private static func readUInt16LE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
