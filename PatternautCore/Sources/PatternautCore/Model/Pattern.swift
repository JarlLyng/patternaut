import Foundation

/// The device-neutral internal representation of a pattern.
///
/// This is Patternaut's source of truth. It serializes cleanly to JSON so
/// patterns can be backed up and shared independently of the app's database,
/// and a device profile converts it into hardware-specific output.
public struct Pattern: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var metadata: PatternMetadata
    /// The device this pattern currently targets. The internal model is
    /// device-neutral; this only selects the profile for validation/export.
    public var device: DeviceModel
    public var tempo: Double
    public var meter: Meter
    public var tracks: [Track]

    public init(
        id: UUID = UUID(),
        metadata: PatternMetadata,
        device: DeviceModel,
        tempo: Double = 120,
        meter: Meter = .fourFour,
        tracks: [Track] = []
    ) {
        self.id = id
        self.metadata = metadata
        self.device = device
        self.tempo = tempo
        self.meter = meter
        self.tracks = tracks
    }

    /// The profile for this pattern's target device.
    public var profile: DeviceProfile { device.profile }

    // MARK: - JSON serialization

    /// Encodes the pattern as stable, pretty-printed JSON (ISO-8601 dates,
    /// sorted keys) suitable for backup and sharing.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decodes a pattern from JSON produced by ``jsonData()``.
    public static func decoded(from data: Data) throws -> Pattern {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Pattern.self, from: data)
    }
}
