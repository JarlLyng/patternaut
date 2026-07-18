import Foundation

/// A note value in a step. Device-neutral, but its raw representation matches
/// the Polyend `.mtp` encoding so export is a near-identity mapping.
///
/// Raw values (from `tracker-lib` `StepData.note`):
/// `0...127` pitch, `-1` empty, `-2` off/fade, `-3` off/cut, `-4` off (default).
public enum Note: Equatable, Hashable, Sendable {
    /// No note in this step.
    case empty
    /// Note-off with a fade-out.
    case offFade
    /// Note-off with a hard cut.
    case offCut
    /// Note-off (the device default off marker).
    case off
    /// A pitched note, MIDI number `0...127`.
    case pitch(UInt8)

    /// The raw integer stored in the pattern format.
    public var rawValue: Int {
        switch self {
        case .empty: return -1
        case .offFade: return -2
        case .offCut: return -3
        case .off: return -4
        case .pitch(let p): return Int(p)
        }
    }

    /// Creates a note from its raw pattern-format integer. Returns `nil` for
    /// out-of-range values.
    public init?(rawValue: Int) {
        switch rawValue {
        case -1: self = .empty
        case -2: self = .offFade
        case -3: self = .offCut
        case -4: self = .off
        case 0...127: self = .pitch(UInt8(rawValue))
        default: return nil
        }
    }

    /// True when this step actually triggers a pitched note.
    public var isPitched: Bool {
        if case .pitch = self { return true }
        return false
    }

    /// Scientific pitch name (e.g. `C4`, `F#3`) using 12-TET with MIDI 60 = C4.
    ///
    /// Note: the Tracker's displayed middle C is configurable (default C-5);
    /// this helper uses the common MIDI convention and can be offset in the UI.
    public var scientificName: String? {
        guard case .pitch(let p) = self else { return nil }
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(p) / 12 - 1
        return "\(names[Int(p) % 12])\(octave)"
    }
}

extension Note: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        guard let note = Note(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid note raw value \(raw)"
            )
        }
        self = note
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
