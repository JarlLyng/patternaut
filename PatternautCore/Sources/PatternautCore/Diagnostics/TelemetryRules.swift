import Foundation

/// What the app's anonymous crash reports and feature counts may carry, kept
/// apart from the Sentry SDK so it can be tested.
///
/// The rules: no identifier leaves the device, nothing is stored just to
/// measure, only counts and coarse facts are sent, and never anything the user
/// made: no pattern, project name, instrument name or file path.
public enum TelemetryRules {
    /// The one user every install reports as, so nothing falls back to an
    /// installation ID.
    public static let anonymousUser = "anonymous"

    /// The name of the one feature count: a project written for the Tracker.
    public static let exportMetric = "project.exported"

    /// The only attributes a metric may keep: the SDK's coarse facts plus
    /// `device`. Anything else, `user.id` included, is dropped.
    public static let allowedMetricAttributes: Set<String> = [
        "sentry.sdk.name", "sentry.sdk.version", "sentry.environment", "sentry.release",
        "os.name", "os.version", "device.brand", "device.model", "device.family",
        "device",
    ]

    /// The `device` attribute of the export count. Fixed values, never anything
    /// the user typed.
    public static func deviceAttribute(_ device: DeviceModel) -> String {
        switch device {
        case .trackerMini: return "tracker_mini"
        case .trackerPlus: return "tracker_plus"
        }
    }

    /// Keeps only the allowed attributes of a metric.
    public static func allowedAttributes<Value>(_ attributes: [String: Value]) -> [String: Value] {
        attributes.filter { allowedMetricAttributes.contains($0.key) }
    }

    /// Removes the account name from a path a crash report lists for the app or
    /// one of its libraries, which is under the user's home folder when the app
    /// is run from Downloads, say. The rest of such a path names the app, not
    /// anything the user made.
    public static func scrubbingAccount(_ path: String) -> String {
        path.replacingOccurrences(of: #"/Users/[^/\s"']+"#, with: "/Users/~", options: .regularExpression)
    }

    /// Replaces every path under a home folder or on a card in free text, such as
    /// an exception message, with `<path>`. Those paths name the user's files and
    /// projects. A path runs to the next quote or the end of the line, so this
    /// takes too much rather than too little.
    public static func redactingPaths(_ text: String) -> String {
        text.replacingOccurrences(of: #"/(?:Users|Volumes)/[^"'“”\n]*"#, with: "<path>", options: .regularExpression)
    }

    /// Where crash reports say they came from. `production` only for App Store
    /// builds, so debug, TestFlight and unidentified runs aren't read as real
    /// crashes.
    public enum Environment: String, Sendable {
        case debug
        case testflight
        case production
        /// A release build before the App Store has said which kind it is.
        case release
    }
}
