import Foundation

/// Assembles complete, device-sized patterns from generated tracks.
public enum PatternGenerator {
    /// Places `tracks` into the first slots of a device-sized pattern, fills the
    /// remaining slots with empty tracks, and records the `seed` in metadata so
    /// the result is reproducible.
    ///
    /// Empty fill tracks take their name and role from the device layout;
    /// provided tracks are placed as-is.
    public static func assemble(
        device: DeviceModel,
        name: String,
        tempo: Double = 120,
        meter: Meter = .fourFour,
        steps: Int = 32,
        seed: UInt64,
        tracks: [Track]
    ) -> Pattern {
        let profile = device.profile
        let length = min(max(steps, profile.stepRange.lowerBound), profile.stepRange.upperBound)
        let names = profile.defaultTrackNames

        let assembled = (0..<profile.trackCount).map { index -> Track in
            if index < tracks.count {
                return tracks[index]
            }
            return Track.empty(name: names[index], role: profile.role(forTrack: index), length: length)
        }

        var metadata = PatternMetadata(name: name)
        metadata.seed = seed

        return Pattern(metadata: metadata, device: device, tempo: tempo, meter: meter, tracks: assembled)
    }
}
