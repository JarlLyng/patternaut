import Foundation

/// Non-destructive groove operations. Each returns a new ``Track``; the input
/// is never mutated.
public enum Groove {
    /// Applies swing by nudging off-beat hits later via the Micro-move FX (`m`).
    ///
    /// - Parameters:
    ///   - amount: Micro-move value `0...100` applied to off-beats.
    ///   - every: Off-beat spacing; `2` (default) swings every other step.
    public static func swing(_ track: Track, amount: Int, every: Int = 2) -> Track {
        guard every > 1 else { return track }
        var result = track
        for index in result.steps.indices where result.steps[index].isActive {
            if index % every == every - 1 {
                result.steps[index].microtiming = amount
            }
        }
        return result
    }

    /// Adds bounded random variation to active hits, seeded for reproducibility.
    ///
    /// - Parameters:
    ///   - timing: Max Micro-move (`m`) added, `0...100` (lateness only, matching
    ///     the hardware nudge direction).
    ///   - velocity: Max +/- variation applied around each hit's velocity (`V`).
    public static func humanize(
        _ track: Track,
        timing: Int = 0,
        velocity: Int = 0,
        using rng: inout SeededGenerator
    ) -> Track {
        var result = track
        for index in result.steps.indices where result.steps[index].isActive {
            if timing > 0 {
                let nudge = Int.random(in: 0...timing, using: &rng)
                if nudge > 0 { result.steps[index].microtiming = nudge }
            }
            if velocity > 0 {
                let base = result.steps[index].velocity ?? 100
                let delta = Int.random(in: -velocity...velocity, using: &rng)
                result.steps[index].velocity = min(max(base + delta, 0), 100)
            }
        }
        return result
    }
}
