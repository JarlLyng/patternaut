import Foundation

/// Euclidean rhythm generation via Bjorklund's algorithm, which distributes a
/// number of pulses as evenly as possible across a number of steps.
///
/// Produces the canonical patterns musicians expect, e.g. `E(3,8)` = the
/// tresillo `x..x..x.` and `E(5,8)` = the cinquillo `x.xx.xx.`.
public enum Euclidean {
    /// A length-`steps` array where `true` marks a pulse. `pulses` are spread
    /// evenly; `rotation` rotates the result left (wrapping).
    public static func rhythm(pulses: Int, steps: Int, rotation: Int = 0) -> [Bool] {
        guard steps > 0 else { return [] }
        let k = max(0, min(pulses, steps))
        if k == 0 { return Array(repeating: false, count: steps) }
        if k == steps { return Array(repeating: true, count: steps) }

        var pattern = bjorklund(pulses: k, steps: steps)

        if rotation != 0 {
            let r = ((rotation % steps) + steps) % steps
            pattern = (0..<steps).map { pattern[($0 + r) % steps] }
        }
        return pattern
    }

    /// Bjorklund's necklace-pairing construction. `0 < pulses < steps`.
    private static func bjorklund(pulses: Int, steps: Int) -> [Bool] {
        var a: [[Bool]] = Array(repeating: [true], count: pulses)
        var b: [[Bool]] = Array(repeating: [false], count: steps - pulses)

        while b.count > 1 {
            let m = min(a.count, b.count)
            var newA: [[Bool]] = []
            newA.reserveCapacity(m)
            for i in 0..<m { newA.append(a[i] + b[i]) }

            var newB: [[Bool]] = []
            if a.count > b.count {
                newB.append(contentsOf: a[m...])
            } else {
                newB.append(contentsOf: b[m...])
            }
            a = newA
            b = newB
        }

        var result: [Bool] = []
        result.reserveCapacity(steps)
        for group in a { result.append(contentsOf: group) }
        for group in b { result.append(contentsOf: group) }
        return result
    }
}
