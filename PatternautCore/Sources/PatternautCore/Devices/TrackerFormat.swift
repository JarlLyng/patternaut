import Foundation

/// Authoritative constants for the Polyend pattern/project file format,
/// ported from `tracker-lib` (`ProjectConstants`, `PatternConstants`).
///
/// These describe the on-disk format shared by Tracker Mini 2.0 and Tracker+.
public enum TrackerFormat {
    // Steps
    public static let minSteps = 1
    public static let maxSteps = 128
    public static let stepSizeBytes = 6
    public static let maxFXPerStep = 2

    // Project
    public static let instrumentCount = 48
    public static let maxPatterns = 255 // PATTERN_INDEX_MAX
    public static let songSlots = 255 // PLAYLIST_SIZE (value 0 = empty slot)

    // Name lengths
    public static let projectNameLength = 32
    public static let trackNameLength = 21
    public static let patternNameLength = 30

    // File identifiers
    public static let metadataFileIdentifier = "PAMD"
    public static let metadataVersion = 1
    public static let patternFileType = 2

    // Instrument index layout (shared modern format)
    public static let sampleInstrumentRange = 0...47
    public static let midiInstrumentRange = 48...63
    public static let synthInstrumentRange = 64...66
    public static var instrumentRange: ClosedRange<Int> { 0...66 }

    /// Track-count generations as encoded by the format.
    public enum TrackGeneration: Int, Sendable, CaseIterable {
        /// Earliest firmware.
        case old = 8
        /// Original Tracker.
        case og = 12
        /// Tracker Mini 2.0 and Tracker+.
        case miniPlus = 16

        public var trackCount: Int { rawValue }
    }

    /// Number of universal (sample-capable) tracks in the 16-track layout.
    /// Tracks beyond this are MIDI/synth only.
    public static let universalTrackCount = 8
}
