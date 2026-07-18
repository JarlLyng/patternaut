import Foundation

/// Non-destructive structural transforms on a track. Each returns a new
/// ``Track``.
public enum Transform {
    /// Rotates steps left by `amount`, wrapping. Negative rotates right.
    public static func rotate(_ track: Track, by amount: Int) -> Track {
        let n = track.steps.count
        guard n > 0 else { return track }
        let r = ((amount % n) + n) % n
        guard r != 0 else { return track }
        var result = track
        result.steps = (0..<n).map { track.steps[($0 + r) % n] }
        return result
    }

    /// Reverses the order of steps.
    public static func reverse(_ track: Track) -> Track {
        var result = track
        result.steps = track.steps.reversed()
        return result
    }
}
