import Foundation
import Observation
import OSLog
import PatternautCore

/// App diagnostics: records recent activity/errors both to the unified log
/// (Console.app / `log stream --predicate 'subsystem == "com.iamjarl.patternaut"'`)
/// and to an in-memory buffer shown in the in-app log panel (handy on TestFlight).
@Observable
final class Diagnostics {
    enum Level: String { case info, warning, error }

    private var buffer = LogBuffer(capacity: 500)

    var lines: [String] { buffer.lines }
    var text: String { buffer.text }

    func log(_ message: String, level: Level = .info, category: String = "app") {
        let line = "\(Self.timeFormatter.string(from: Date())) [\(level.rawValue)] \(category): \(message)"
        buffer.append(line)

        let logger = Logger(subsystem: "com.iamjarl.patternaut", category: category)
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }

    func clear() { buffer.clear() }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
