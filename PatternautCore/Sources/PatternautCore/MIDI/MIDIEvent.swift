import Foundation

/// A single MIDI event positioned in musical time (beats from the start).
/// Tempo-independent; a transport converts `beat` to wall-clock via the tempo.
public struct MIDIEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case noteOn(note: UInt8, velocity: UInt8)
        case noteOff(note: UInt8)
    }

    /// Time from the start, in beats (quarter notes).
    public var beat: Double
    /// MIDI channel `0...15`.
    public var channel: UInt8
    public var kind: Kind

    public init(beat: Double, channel: UInt8, kind: Kind) {
        self.beat = beat
        self.channel = channel
        self.kind = kind
    }

    public var isNoteOff: Bool {
        if case .noteOff = kind { return true }
        return false
    }

    /// The 3 raw MIDI bytes for this event.
    public var bytes: [UInt8] {
        switch kind {
        case .noteOn(let note, let velocity): return [0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F]
        case .noteOff(let note): return [0x80 | (channel & 0x0F), note & 0x7F, 0]
        }
    }
}
