import Foundation

/// Descriptive, non-musical information attached to a pattern. Everything the
/// Pattern Library and Collections need to organize and version work.
public struct PatternMetadata: Equatable, Sendable, Codable {
    public var name: String
    public var notes: String
    public var tags: [String]
    /// Seed used by the generator, when the pattern was generated. Enables
    /// reproducible regeneration.
    public var seed: UInt64?
    public var isFavorite: Bool
    public var createdAt: Date
    public var modifiedAt: Date
    /// The pattern this one was derived from (mutation/transformation lineage).
    public var parentID: UUID?
    /// Monotonic version counter for this pattern's history.
    public var version: Int

    public init(
        name: String,
        notes: String = "",
        tags: [String] = [],
        seed: UInt64? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        parentID: UUID? = nil,
        version: Int = 1
    ) {
        self.name = name
        self.notes = notes
        self.tags = tags
        self.seed = seed
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.parentID = parentID
        self.version = version
    }
}
