import Foundation

/// Keyboard and menu lookup for effects.
///
/// The device labels each effect with a single symbol (see ``FXType/catalog``),
/// so typing that symbol in an FX column is the fastest way to place one. Two
/// entries share the symbol `x` (Break Pattern and Random FX Value); the lower
/// stored index wins for typing, and the other stays reachable from the menu.
public enum FXKeyMap {
    /// Symbol to effect, case-sensitive (`L` low-pass vs `l` finetune LFO are
    /// different effects on the device).
    public static let bySymbol: [Character: FXType] = {
        var map: [Character: FXType] = [:]
        for descriptor in FXType.catalog {
            guard let type = FXType(rawValue: descriptor.index), type.isEffect else { continue }
            if map[descriptor.symbol] == nil { map[descriptor.symbol] = type }
        }
        return map
    }()

    /// The effect typed by `key`, or `nil` if the key is not an effect symbol.
    public static func fx(for key: Character) -> FXType? { bySymbol[key] }

    /// Every placeable effect sorted by name, for pickers and menus. Excludes
    /// ``FXType/none``; keeps ``FXType/off`` because muting a step is a real edit.
    public static let menuOrder: [FXType] = FXType.allCases
        .filter { $0 != .none }
        .sorted { $0.descriptor.name.localizedCompare($1.descriptor.name) == .orderedAscending }

    /// A short human label, e.g. `"L  Low-pass  0…100"`.
    public static func label(for type: FXType) -> String {
        let d = type.descriptor
        guard type.isEffect else { return "\(d.symbol)  \(d.name)" }
        let range = d.scaled ?? ScaledRange(min: d.min, max: d.max)
        return "\(d.symbol)  \(d.name)  \(range.min)…\(range.max)"
    }
}
