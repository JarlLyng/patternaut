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
    /// The step layout the file was in: `5` for the 6-byte steps every stock
    /// firmware writes, `6` for Tracker CE's 8-byte steps.
    public var layoutVersion: Int
    /// Step Volume and Micro-move values from a version 6 file that found no
    /// free effect lane, and so were left out.
    public var droppedStepValues: Int

    public init(options: MTPExportOptions, tracks: [Track], layoutVersion: Int = 5, droppedStepValues: Int = 0) {
        self.options = options
        self.tracks = tracks
        self.layoutVersion = layoutVersion
        self.droppedStepValues = droppedStepValues
    }

    /// Re-serializes this document. For a version 5 file,
    /// `MTPImporter.parse(doc.data()) == doc` and `doc.data()` equals the bytes
    /// it was parsed from. A version 6 file is written back as version 5, the
    /// only layout ``MTPExporter`` writes, with its step values in the lanes.
    public func data() -> Data {
        guard layoutVersion > 5 else { return MTPExporter.export(tracks: tracks, options: options) }
        var options = options
        options.fileStructureVersion = MTPExportOptions.default.fileStructureVersion
        options.size = nil
        return MTPExporter.export(tracks: tracks, options: options)
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
///
/// It also reads version 6, which Tracker CE writes
/// ([polyend/tracker-ce](https://github.com/polyend/tracker-ce)). Each step
/// there has two more bytes after the effects: a Volume and a Micro-move value,
/// `-1` when empty. The model has no place for them besides the effect lanes,
/// and the firmware treats them as those effects with the same values, so each
/// goes into a free lane. A lane already holding the same effect wins on the
/// device anyway, so the value is dropped then. With both lanes taken by other
/// effects, it is dropped and counted in ``MTPDocument/droppedStepValues``.
public enum MTPImporter {
    /// Bytes per step in a version 6 file.
    static let version6StepSize = 8

    public static func parse(_ data: Data) throws -> MTPDocument {
        let bytes = [UInt8](data)
        let (trackCount, stepSize) = try detectLayout(fileSize: bytes.count)
        let isVersion6 = stepSize == version6StepSize
        var dropped = 0

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
            // The stored byte is the last step index; the model counts steps.
            let length = Int(bytes[cursor]) + 1; cursor += 1
            var steps: [Step] = []
            steps.reserveCapacity(MTPExporter.stepsPerTrack)
            for _ in 0..<MTPExporter.stepsPerTrack {
                var step = readStep(bytes, &cursor)
                if isVersion6 {
                    let volume = Int(Int8(bitPattern: bytes[cursor]))
                    let microMove = Int(Int8(bitPattern: bytes[cursor + 1]))
                    cursor += 2
                    if volume >= 0, !place(.volume, volume, in: &step) { dropped += 1 }
                    if microMove >= 0, !place(.microMove, microMove, in: &step) { dropped += 1 }
                }
                steps.append(step)
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
        return MTPDocument(options: options, tracks: tracks,
                           layoutVersion: isVersion6 ? 6 : 5, droppedStepValues: dropped)
    }

    // MARK: - Private

    /// Track count and step size, from the file size alone. The header's
    /// version byte is not trusted for this: the sizes of the two layouts never
    /// coincide, and the size is what the bytes actually are.
    private static func detectLayout(fileSize: Int) throws -> (tracks: Int, stepSize: Int) {
        let base = TrackerFormatLayout.headerSize + TrackerFormatLayout.paddingSize + TrackerFormatLayout.unusedSize
        guard fileSize >= base + TrackerFormatLayout.crcSize else { throw MTPError.tooSmall(fileSize) }

        for stepSize in [TrackerFormat.stepSizeBytes, version6StepSize] {
            let trackSize = TrackerFormatLayout.trackHeaderSize + stepSize * TrackerFormat.maxSteps
            for count in [TrackerFormat.TrackGeneration.old, .og, .miniPlus].map(\.trackCount) {
                if fileSize == base + trackSize * count + TrackerFormatLayout.crcSize {
                    return (count, stepSize)
                }
            }
        }
        throw MTPError.unexpectedSize(fileSize)
    }

    /// Puts a version 6 step value into an effect lane. Returns false only when
    /// it was lost: both lanes hold other effects.
    private static func place(_ type: FXType, _ value: Int, in step: inout Step) -> Bool {
        if step.fx.contains(where: { $0.type == type }) { return true }
        guard let free = step.fx.firstIndex(where: { $0.type == .none }) else { return false }
        step.fx[free] = FXCommand(type: type, value: value)
        return true
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
