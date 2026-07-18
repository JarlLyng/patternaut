import Foundation

/// A fixed-capacity ring buffer of log lines. Pure and testable; the app wraps
/// it with timestamps and unified logging.
public struct LogBuffer: Sendable, Equatable {
    public private(set) var lines: [String] = []
    public let capacity: Int

    public init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    /// Appends a line, dropping the oldest lines beyond `capacity`.
    public mutating func append(_ line: String) {
        lines.append(line)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
    }

    /// All lines joined with newlines (for copy/share).
    public var text: String { lines.joined(separator: "\n") }

    public mutating func clear() { lines.removeAll() }
}
