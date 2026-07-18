import Foundation

/// What a track is allowed to sequence. On Tracker+ (and the shared 16-track
/// format) tracks 1–8 are universal, tracks 9–16 are MIDI/synth only.
public enum TrackRole: String, Codable, Sendable, CaseIterable {
    /// Audio (samples), MIDI, or internal synth.
    case universal
    /// MIDI or internal synth only — no sample playback.
    case midiSynth
}

/// One track of a pattern: an ordered list of steps with its own length.
///
/// Each track carries its own `length` (`1...128`), mirroring the hardware
/// where tracks in a pattern can differ in length.
public struct Track: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var role: TrackRole
    /// Number of active steps, `1...128`. May be shorter than `steps.count`.
    public var length: Int
    public var steps: [Step]

    public init(id: UUID = UUID(), name: String, role: TrackRole = .universal, length: Int, steps: [Step]) {
        self.id = id
        self.name = name
        self.role = role
        self.length = length
        self.steps = steps
    }

    /// Creates a track of `length` empty steps.
    public static func empty(name: String, role: TrackRole = .universal, length: Int) -> Track {
        Track(name: name, role: role, length: length, steps: Array(repeating: .empty, count: length))
    }

    /// True if this track can play sample-based instruments.
    public var allowsSamples: Bool { role == .universal }
}
