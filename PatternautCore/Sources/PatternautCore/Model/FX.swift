import Foundation

/// A scaled value range some effects present to the user (e.g. Panning stores
/// `0...100` but displays `-50...+50`).
public struct ScaledRange: Equatable, Sendable, Codable {
    public let min: Int
    public let max: Int
    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }
}

/// Static metadata for an effect: how it is stored and how it is presented.
///
/// Ported 1:1 from `tracker-lib` `PatternFX`. `index` is what is stored in the
/// pattern; `symbol` is what the device shows the user.
public struct FXDescriptor: Equatable, Sendable {
    public let index: Int
    public let symbol: Character
    public let name: String
    public let min: Int
    public let max: Int
    public let `default`: Int
    public let scaled: ScaledRange?
}

/// The full set of per-step effects, in stored-index order (`0...42`).
///
/// Authoritative source: `tracker-lib` `src/types/patterns.ts` `PatternFX`
/// (Tracker Mini 2.0 / Tracker+ firmware line). Symbols differ from the
/// original Tracker manual 1.7.0 — always treat this as the source of truth.
public enum FXType: Int, Codable, CaseIterable, Sendable {
    case none = 0
    case off
    case microMove
    case roll
    case chance
    case randomNote
    case randomInstrument
    case randomVolume
    case midiCCA
    case midiCCB
    case midiCCC
    case midiCCD
    case midiCCE
    case breakPattern
    case midiChord
    case tempo
    case randomFXValue
    case swing
    case volume
    case glide
    case gateLength
    case arp
    case position
    case volumeLFO
    case panningLFO
    case slice
    case reverse
    case lowPass
    case highPass
    case bandPass
    case delaySend
    case panning
    case reverbSend
    case finetuneLFO
    case microTune
    case filterLFO
    case positionLFO
    case midiCCF
    case overdrive
    case bitDepth
    case tune
    case slideUp
    case slideDown

    /// The metadata record for this effect.
    public var descriptor: FXDescriptor { FXType.catalog[rawValue] }

    /// True for the two non-effect entries (`none`, `off`).
    public var isEffect: Bool { self != .none && self != .off }

    /// Every effect record, index-ordered so `catalog[i].index == i`.
    public static let catalog: [FXDescriptor] = [
        FXDescriptor(index: 0, symbol: "-", name: "None", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 1, symbol: "!", name: "Off", min: 0, max: 0, default: 0, scaled: nil),
        FXDescriptor(index: 2, symbol: "m", name: "Micro-move", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 3, symbol: "R", name: "Roll", min: 0, max: 47, default: 1, scaled: nil),
        FXDescriptor(index: 4, symbol: "C", name: "Chance", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 5, symbol: "n", name: "Random Note", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 6, symbol: "i", name: "Random Instrument", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 7, symbol: "v", name: "Random Volume", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 8, symbol: "a", name: "MIDI CC A", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 9, symbol: "b", name: "MIDI CC B", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 10, symbol: "c", name: "MIDI CC C", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 11, symbol: "d", name: "MIDI CC D", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 12, symbol: "e", name: "MIDI CC E", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 13, symbol: "x", name: "Break Pattern", min: 1, max: 1, default: 1, scaled: nil),
        FXDescriptor(index: 14, symbol: "0", name: "MIDI Chord", min: 0, max: 15, default: 0, scaled: nil),
        FXDescriptor(index: 15, symbol: "T", name: "Tempo", min: 4, max: 200, default: 60, scaled: ScaledRange(min: 8, max: 400)),
        FXDescriptor(index: 16, symbol: "x", name: "Random FX Value", min: 0, max: 255, default: 0, scaled: nil),
        FXDescriptor(index: 17, symbol: "I", name: "Swing", min: 25, max: 75, default: 50, scaled: ScaledRange(min: -25, max: 25)),
        FXDescriptor(index: 18, symbol: "V", name: "Volume/Velocity", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 19, symbol: "G", name: "Glide", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 20, symbol: "q", name: "Gate Length", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 21, symbol: "A", name: "Arp", min: 0, max: 33, default: 0, scaled: nil),
        FXDescriptor(index: 22, symbol: "p", name: "Position", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 23, symbol: "g", name: "Volume LFO", min: 0, max: 24, default: 0, scaled: nil),
        FXDescriptor(index: 24, symbol: "h", name: "Panning LFO", min: 0, max: 30, default: 0, scaled: nil),
        FXDescriptor(index: 25, symbol: "S", name: "Slice", min: 0, max: 47, default: 0, scaled: ScaledRange(min: 1, max: 48)),
        FXDescriptor(index: 26, symbol: "r", name: "Reverse Playback", min: 0, max: 1, default: 0, scaled: nil),
        FXDescriptor(index: 27, symbol: "L", name: "Low-pass", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 28, symbol: "H", name: "High-pass", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 29, symbol: "B", name: "Band-pass", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 30, symbol: "s", name: "Delay Send", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 31, symbol: "P", name: "Panning", min: 0, max: 100, default: 0, scaled: ScaledRange(min: -50, max: 50)),
        FXDescriptor(index: 32, symbol: "t", name: "Reverb Send", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 33, symbol: "l", name: "Finetune LFO", min: 0, max: 30, default: 0, scaled: nil),
        FXDescriptor(index: 34, symbol: "M", name: "Micro-tune/Pitchbend", min: 0, max: 198, default: 0, scaled: ScaledRange(min: -99, max: 99)),
        FXDescriptor(index: 35, symbol: "j", name: "Filter LFO", min: 0, max: 30, default: 0, scaled: nil),
        FXDescriptor(index: 36, symbol: "k", name: "Position LFO", min: 0, max: 30, default: 0, scaled: nil),
        FXDescriptor(index: 37, symbol: "f", name: "MIDI CC F", min: 0, max: 127, default: 0, scaled: nil),
        FXDescriptor(index: 38, symbol: "D", name: "Overdrive", min: 0, max: 100, default: 0, scaled: nil),
        FXDescriptor(index: 39, symbol: "E", name: "Bit Depth", min: 1, max: 16, default: 0, scaled: nil),
        FXDescriptor(index: 40, symbol: "U", name: "Tune", min: 0, max: 48, default: 0, scaled: ScaledRange(min: -24, max: 24)),
        FXDescriptor(index: 41, symbol: "F", name: "Slide Up", min: 0, max: 255, default: 0, scaled: nil),
        FXDescriptor(index: 42, symbol: "J", name: "Slide Down", min: 0, max: 255, default: 0, scaled: nil),
    ]
}

/// A single effect placed on a step lane: an effect type plus its stored value.
public struct FXCommand: Equatable, Sendable, Codable {
    public var type: FXType
    public var value: Int

    public init(type: FXType, value: Int) {
        self.type = type
        self.value = value
    }

    /// Convenience initializer that defaults the value to the effect's default.
    public init(_ type: FXType) {
        self.type = type
        self.value = type.descriptor.default
    }

    /// `value` clamped to the effect's stored `min...max` range.
    public var clampedValue: Int {
        let d = type.descriptor
        return Swift.min(Swift.max(value, d.min), d.max)
    }

    /// True if `value` is within the effect's stored range.
    public var isInRange: Bool {
        let d = type.descriptor
        return value >= d.min && value <= d.max
    }

    /// The range the device shows the user, which for some effects differs from
    /// the stored range (Panning stores `0...100` and shows `-50...+50`).
    public var displayRange: ScaledRange {
        let d = type.descriptor
        return d.scaled ?? ScaledRange(min: d.min, max: d.max)
    }

    /// ``value`` translated into the displayed range, so the app shows what the
    /// device would show.
    public var displayValue: Int {
        let d = type.descriptor
        guard let scaled = d.scaled, d.max > d.min else { return clampedValue }
        let position = Double(clampedValue - d.min) / Double(d.max - d.min)
        return scaled.min + Int((position * Double(scaled.max - scaled.min)).rounded())
    }

    /// Sets ``value`` from a number in the displayed range (the inverse of
    /// ``displayValue``), clamped.
    public mutating func setDisplayValue(_ displayed: Int) {
        let d = type.descriptor
        guard let scaled = d.scaled, scaled.max > scaled.min else {
            value = Swift.min(Swift.max(displayed, d.min), d.max)
            return
        }
        let clamped = Swift.min(Swift.max(displayed, scaled.min), scaled.max)
        let position = Double(clamped - scaled.min) / Double(scaled.max - scaled.min)
        value = d.min + Int((position * Double(d.max - d.min)).rounded())
    }
}
