import Foundation

/// A single step in a track: a note, an optional instrument, and up to a
/// device-defined number of effect lanes.
///
/// Semantic concepts the spec treats as "first-class" (velocity, probability,
/// microtiming, gate) are stored as effects and surfaced through convenience
/// accessors. This keeps one source of truth and makes hardware export a
/// near-identity mapping — the 2-FX-per-step limit is enforced by
/// ``DeviceProfile/validate(_:)`` rather than silently hidden.
public struct Step: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var note: Note
    /// Instrument index in the shared modern layout: `0...47` sample,
    /// `48...63` MIDI, `64...66` synth. `nil` means no instrument.
    public var instrument: Int?
    /// Effect lanes on this step. The device caps the count (see
    /// ``DeviceProfile/maxFXPerStep``); the model itself stays tolerant.
    public var fx: [FXCommand]

    public init(id: UUID = UUID(), note: Note = .empty, instrument: Int? = nil, fx: [FXCommand] = []) {
        self.id = id
        self.note = note
        self.instrument = instrument
        self.fx = fx
    }

    /// An empty step.
    public static var empty: Step { Step() }

    /// True when this step triggers a pitched note.
    public var isActive: Bool { note.isPitched }

    /// The instrument's kind, derived from its index, or `nil` if unset/invalid.
    public var instrumentKind: InstrumentKind? {
        guard let instrument else { return nil }
        return InstrumentKind(index: instrument)
    }

    // MARK: - Effect access

    /// The stored value of the given effect on this step, if present.
    public func fxValue(_ type: FXType) -> Int? {
        fx.first(where: { $0.type == type })?.value
    }

    /// Sets (or, with `nil`, removes) the given effect. Updates in place if the
    /// effect already occupies a lane; otherwise appends a new lane.
    public mutating func setFX(_ type: FXType, _ value: Int?) {
        if let value {
            if let index = fx.firstIndex(where: { $0.type == type }) {
                fx[index].value = value
            } else {
                fx.append(FXCommand(type: type, value: value))
            }
        } else {
            fx.removeAll { $0.type == type }
        }
    }

    // MARK: - Semantic conveniences (backed by effect lanes)

    /// Volume/velocity (`V`), `0...100`.
    public var velocity: Int? {
        get { fxValue(.volume) }
        set { setFX(.volume, newValue) }
    }

    /// Probability the note plays (`C` Chance), `0...100`.
    public var probability: Int? {
        get { fxValue(.chance) }
        set { setFX(.chance, newValue) }
    }

    /// Microtiming nudge (`m` Micro-move), `0...100`.
    public var microtiming: Int? {
        get { fxValue(.microMove) }
        set { setFX(.microMove, newValue) }
    }

    /// Gate length (`q`), `0...100`.
    public var gateLength: Int? {
        get { fxValue(.gateLength) }
        set { setFX(.gateLength, newValue) }
    }
}

/// The category of an instrument, derived from its index in the shared layout.
public enum InstrumentKind: String, Codable, Sendable, CaseIterable {
    case sample
    case midi
    case synth

    /// Classifies an instrument index, or returns `nil` if out of range.
    public init?(index: Int) {
        switch index {
        case TrackerFormat.sampleInstrumentRange: self = .sample
        case TrackerFormat.midiInstrumentRange: self = .midi
        case TrackerFormat.synthInstrumentRange: self = .synth
        default: return nil
        }
    }
}
