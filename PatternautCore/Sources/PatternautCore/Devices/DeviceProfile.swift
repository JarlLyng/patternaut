import Foundation

/// A device profile: the constraints and capabilities of a target device.
///
/// The internal pattern model is device-neutral; a profile defines the limits
/// (track count, per-track type, step range, supported effects) used to
/// validate a pattern and, later, to generate device-specific output.
///
/// Profiles are versioned so the app can track firmware differences — including
/// the effect set and file-format schema.
public struct DeviceProfile: Sendable, Identifiable {
    public let model: DeviceModel
    public let displayName: String
    /// Total sequencer tracks in the format.
    public let trackCount: Int
    /// Role per track index; `count == trackCount`.
    public let trackRoles: [TrackRole]
    /// Valid per-track step lengths.
    public let stepRange: ClosedRange<Int>
    public let maxPatterns: Int
    public let songSlots: Int
    public let instrumentCount: Int
    public let maxFXPerStep: Int
    /// Effects this device understands. Versioned per firmware.
    public let supportedFX: Set<FXType>
    /// The format's track-count generation.
    public let formatGeneration: TrackerFormat.TrackGeneration
    /// Human-readable note about firmware/scope caveats.
    public let firmwareNote: String

    public var id: DeviceModel { model }

    /// The role assigned to a given track index (clamped defensively).
    public func role(forTrack index: Int) -> TrackRole {
        guard index >= 0 && index < trackRoles.count else { return .midiSynth }
        return trackRoles[index]
    }

    /// Standard track names for this profile: "Track 1"…"Track 8", then
    /// "Midi 9"…"Midi 16", mirroring the file-format layout.
    public var defaultTrackNames: [String] {
        (0..<trackCount).map { index in
            index < TrackerFormat.universalTrackCount ? "Track \(index + 1)" : "Midi \(index + 1)"
        }
    }

    // MARK: - Profile registry

    public static func profile(for model: DeviceModel) -> DeviceProfile {
        switch model {
        case .trackerMini: return .trackerMini
        case .trackerPlus: return .trackerPlus
        }
    }

    /// The 16-track role layout shared by the modern devices: 8 universal
    /// tracks followed by 8 MIDI/synth-only tracks.
    static let modernTrackRoles: [TrackRole] =
        Array(repeating: .universal, count: TrackerFormat.universalTrackCount) +
        Array(repeating: .midiSynth, count: TrackerFormat.TrackGeneration.miniPlus.trackCount - TrackerFormat.universalTrackCount)

    public static let trackerMini = DeviceProfile(
        model: .trackerMini,
        displayName: "Tracker Mini",
        trackCount: TrackerFormat.TrackGeneration.miniPlus.trackCount,
        trackRoles: modernTrackRoles,
        stepRange: TrackerFormat.minSteps...TrackerFormat.maxSteps,
        maxPatterns: TrackerFormat.maxPatterns,
        songSlots: TrackerFormat.songSlots,
        instrumentCount: TrackerFormat.instrumentCount,
        maxFXPerStep: TrackerFormat.maxFXPerStep,
        supportedFX: Set(FXType.allCases),
        formatGeneration: .miniPlus,
        firmwareNote: "Firmware 2.0+ (16-track format, project-compatible with Tracker+). Pre-2.0 Mini had 8 tracks."
    )

    public static let trackerPlus = DeviceProfile(
        model: .trackerPlus,
        displayName: "Tracker+",
        trackCount: TrackerFormat.TrackGeneration.miniPlus.trackCount,
        trackRoles: modernTrackRoles,
        stepRange: TrackerFormat.minSteps...TrackerFormat.maxSteps,
        maxPatterns: TrackerFormat.maxPatterns,
        songSlots: TrackerFormat.songSlots,
        instrumentCount: TrackerFormat.instrumentCount,
        maxFXPerStep: TrackerFormat.maxFXPerStep,
        supportedFX: Set(FXType.allCases),
        formatGeneration: .miniPlus,
        firmwareNote: "16 tracks. Tracks 9-16 are named for MIDI, but play samples too: Polyend's own demo projects do it."
    )

    // MARK: - Pattern construction

    /// Builds an empty pattern sized for this device: `trackCount` tracks, each
    /// with `stepCount` empty steps, named and role-assigned per the layout.
    public func makeEmptyPattern(
        name: String,
        tempo: Double = 120,
        meter: Meter = .fourFour,
        stepCount: Int = 32
    ) -> Pattern {
        let length = min(max(stepCount, stepRange.lowerBound), stepRange.upperBound)
        let names = defaultTrackNames
        let tracks = (0..<trackCount).map { index in
            Track.empty(name: names[index], role: role(forTrack: index), length: length)
        }
        return Pattern(
            metadata: PatternMetadata(name: name),
            device: model,
            tempo: tempo,
            meter: meter,
            tracks: tracks
        )
    }
}
