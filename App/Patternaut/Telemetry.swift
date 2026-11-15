import Foundation
import PatternautCore
// The SDK predates strict concurrency: SentrySDK.metrics is a class property
// it doesn't mark as safe to share, though the SDK guards it itself.
@preconcurrency import Sentry
import StoreKit

/// Anonymous crash reports, crash-free sessions, MetricKit diagnostics and one
/// feature count, sent to Sentry (#33).
///
/// Anonymous is a recipe, not Sentry's default: out of the box sentry-cocoa
/// sends a random installation ID as the user, as every session's `did` and on
/// every metric, plus a hash of the vendor ID on every event. Everything here
/// exists so that no ID leaves the device, and nothing the user made does
/// either: no pattern, project name, instrument name or file path. What may be
/// sent is in ``TelemetryRules``; how to check it is in `App/SENTRY.md`.
enum Telemetry {
    /// Starts Sentry if the build has a DSN. A build without one sends nothing.
    static func start() {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return }
        guard let dsn = dsn(environment) else { return }

        let options = Options()
        options.dsn = dsn
        #if DEBUG
        options.environment = TelemetryRules.Environment.debug.rawValue
        options.debug = environment["PATTERNAUT_SENTRY_DEBUG"] == "1"
        #else
        // Until the App Store says which kind of build this is; see
        // resolveEnvironment().
        options.environment = TelemetryRules.Environment.release.rawValue
        #endif
        options.sendDefaultPii = false
        // No performance tracing: crash reports, sessions, MetricKit and the one
        // count are what the policy names. Tracing would also record file I/O.
        options.tracesSampleRate = 0
        options.enableAutoPerformanceTracing = false
        options.enableFileIOTracing = false
        // No breadcrumbs at all. They are a trail of what happened before a
        // crash, and on the Mac that trail can hold window titles, which name the
        // user's documents.
        options.enableAutoBreadcrumbTracking = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false
        options.beforeBreadcrumb = { _ in nil }
        options.enableAutoSessionTracking = true
        options.enableMetricKit = true
        options.beforeSend = { anonymize($0) }
        options.beforeSendMetric = { anonymize($0) }

        // Sessions can't be given a user: sentry-cocoa sets every session's `did`
        // from the INSTALLATION file in its cache directory, and creates that
        // file with a random UUID when it is missing. Writing the shared user
        // into the file before the SDK starts makes every install report the
        // same `did`. Checked against the outgoing envelope with sentry-cocoa
        // 9.32.0, which project.yml pins; check again after an upgrade.
        pinInstallationID(cacheDirectoryPath: options.cacheDirectoryPath)

        SentrySDK.start(options: options)
        // Before any event or metric, so nothing falls back to an installation ID.
        SentrySDK.setUser(User(userId: TelemetryRules.anonymousUser))

        #if DEBUG
        if environment["PATTERNAUT_SENTRY_PROBE"] == "1" { probe() }
        #else
        resolveEnvironment()
        #endif
    }

    // MARK: - Feature count

    /// A project written for the Tracker: the moment the app has done its job.
    static func exported(for device: DeviceModel) {
        guard SentrySDK.isEnabled else { return }
        SentrySDK.metrics.count(
            TelemetryRules.exportMetric, value: 1,
            options: SentryMetricOptions(attributes: ["device": TelemetryRules.deviceAttribute(device)])
        )
    }

    // MARK: - Setup

    /// The DSN from the environment (for a run from Xcode) or from the build
    /// (Sentry.xcconfig through Info.plist), if it looks like one. An xcconfig
    /// that wrote it as `https://...` leaves only `https:`, which counts as none.
    private static func dsn(_ environment: [String: String]) -> String? {
        let candidates = [environment["SENTRY_DSN"], Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("http") && $0.contains("://") && $0.contains("@") }
    }

    static func pinInstallationID(cacheDirectoryPath: String) {
        let url = URL(fileURLWithPath: cacheDirectoryPath).appendingPathComponent("INSTALLATION")
        let pinned = Data(TelemetryRules.anonymousUser.utf8)
        guard (try? Data(contentsOf: url)) != pinned else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? pinned.write(to: url, options: .atomic)
    }

    /// `production` only for App Store builds. On the Mac a TestFlight build
    /// looks like an App Store one from the inside, so ask StoreKit. Until it
    /// answers, events say `release`. Sessions keep the environment they started
    /// with, so they say `release` too.
    private static func resolveEnvironment() {
        Task.detached(priority: .utility) {
            guard let result = try? await AppTransaction.shared else { return }
            let transaction: AppTransaction
            switch result {
            case .verified(let value), .unverified(let value, _): transaction = value
            }
            let resolved: TelemetryRules.Environment
            switch transaction.environment {
            case .production: resolved = .production
            case .sandbox: resolved = .testflight
            default: resolved = .debug
            }
            SentrySDK.configureScope { $0.setEnvironment(resolved.rawValue) }
        }
    }

    #if DEBUG
    /// Sends one event and two counts, one of them with an attribute that must
    /// not survive, so the outgoing envelopes can be read (App/SENTRY.md).
    private static func probe() {
        SentrySDK.capture(message: "Patternaut Sentry probe (Debug build)")
        exported(for: .trackerPlus)
        SentrySDK.metrics.count(
            TelemetryRules.exportMetric, value: 1,
            options: SentryMetricOptions(attributes: ["device": "tracker_mini", "project": "must not be sent"])
        )
    }
    #endif

    // MARK: - Anonymizing

    /// Covers errors, crashes, app hangs and MetricKit diagnostics: one shared
    /// user, no device or vendor-ID hash, no host name, and no account name or
    /// path to the user's files.
    static func anonymize(_ event: Event) -> Event {
        event.user = User(userId: TelemetryRules.anonymousUser)
        event.serverName = nil
        if var context = event.context {
            context["app"]?.removeValue(forKey: "device_app_hash")
            context["device"]?.removeValue(forKey: "id")
            event.context = context
        }
        if let message = event.message {
            event.message = SentryMessage(formatted: TelemetryRules.redactingPaths(message.formatted))
        }
        for exception in event.exceptions ?? [] {
            exception.value = exception.value.map(TelemetryRules.redactingPaths)
            scrub(exception.stacktrace)
        }
        for thread in event.threads ?? [] {
            scrub(thread.stacktrace)
        }
        for image in event.debugMeta ?? [] {
            image.codeFile = image.codeFile.map(TelemetryRules.scrubbingAccount)
        }
        return event
    }

    private static func scrub(_ stacktrace: SentryStacktrace?) {
        for frame in stacktrace?.frames ?? [] {
            frame.package = frame.package.map(TelemetryRules.scrubbingAccount)
        }
    }

    static func anonymize(_ metric: SentryMetric) -> SentryMetric {
        var metric = metric
        metric.attributes = TelemetryRules.allowedAttributes(metric.attributes)
        return metric
    }
}
