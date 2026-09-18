import Foundation

/// A scale, as semitone offsets from its root.
///
/// Only pitched material is affected by this. Drum tracks trigger samples, so
/// their "notes" pick a sample rather than a pitch and are left alone.
public enum Scale: String, CaseIterable, Codable, Sendable {
    case major
    case minor
    case harmonicMinor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case minorPentatonic
    case majorPentatonic
    case blues
    case chromatic

    /// Semitones above the root, one octave.
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .chromatic: return Array(0...11)
        }
    }

    public var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .harmonicMinor: return "Harmonic minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .minorPentatonic: return "Minor pentatonic"
        case .majorPentatonic: return "Major pentatonic"
        case .blues: return "Blues"
        case .chromatic: return "Chromatic"
        }
    }
}

/// A root note plus a scale: what pitched generated material is built from.
public struct MusicalKey: Equatable, Codable, Sendable {
    /// Pitch class of the root, `0` = C through `11` = B.
    public var root: Int
    public var scale: Scale

    public init(root: Int = 0, scale: Scale = .minor) {
        self.root = ((root % 12) + 12) % 12
        self.scale = scale
    }

    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public var rootName: String { MusicalKey.noteNames[root] }
    public var displayName: String { "\(rootName) \(scale.displayName.lowercased())" }

    /// `count` scale pitches going up from `lowest`, starting at the key's root
    /// at or above it.
    public func pitches(from lowest: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let intervals = scale.intervals
        var start = lowest - ((lowest % 12) - root)
        if start < lowest { start += 12 }
        return (0..<count).map { step in
            let octave = step / intervals.count
            let degree = step % intervals.count
            return min(max(start + octave * 12 + intervals[degree], 0), 127)
        }
    }

    /// Moves `pitch` to the nearest note in the key, preferring downwards on a
    /// tie so a line keeps its shape.
    public func snap(_ pitch: Int) -> Int {
        let clamped = min(max(pitch, 0), 127)
        let pitchClass = ((clamped % 12) - root + 12) % 12
        if scale.intervals.contains(pitchClass) { return clamped }
        let nearest = scale.intervals
            .map { (interval: $0, distance: abs($0 - pitchClass)) }
            .min { ($0.distance, $0.interval) < ($1.distance, $1.interval) }
        guard let nearest else { return clamped }
        let result = clamped + (nearest.interval - pitchClass)
        return min(max(result, 0), 127)
    }
}
