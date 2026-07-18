import PatternsmithCore

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

    static func fx(_ command: FXCommand?) -> String {
        guard let command, command.type != .none else { return "···" }
        let d = command.type.descriptor
        return "\(d.symbol)\(String(format: "%02d", min(command.value, 99)))"
    }

    static func fxLane(_ step: Step?, lane: Int) -> String {
        guard let step, step.fx.count > lane else { return "···" }
        return fx(step.fx[lane])
    }
}
