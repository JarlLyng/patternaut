import PatternautCore

/// Display strings for grid cells, tracker-style (fixed width, dots for empty).
enum StepFormatting {
    static func note(_ note: Note) -> String {
        switch note {
        case .empty: return "···"
        case .off: return "OFF"
        case .offCut: return "CUT"
        case .offFade: return "FAD"
        case .pitch: return (note.scientificName ?? "···").padding(toLength: 3, withPad: " ", startingAt: 0)
        }
    }

    static func instrument(_ instrument: Int?) -> String {
        guard let instrument else { return "··" }
        return String(format: "%02d", instrument)
    }

    /// Symbol plus the value as the *device* shows it, so a Panning of 0 reads
    /// `P  0` in the app and on the hardware rather than `P 50`.
    static func fx(_ command: FXCommand?) -> String {
        guard let command, command.type != .none else { return "····" }
        guard command.type.isEffect else { return "\(command.type.descriptor.symbol)   " }
        return "\(command.type.descriptor.symbol)\(String(format: "%3d", command.displayValue))"
    }

    static func fxLane(_ step: Step?, lane: Int) -> String {
        guard let step, step.fx.count > lane else { return "····" }
        return fx(step.fx[lane])
    }
}
