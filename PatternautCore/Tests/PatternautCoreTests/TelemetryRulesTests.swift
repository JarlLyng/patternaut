import Foundation
import Testing
@testable import PatternautCore

@Suite("Telemetry rules")
struct TelemetryRulesTests {
    @Test("A metric keeps only the coarse facts and the device")
    func attributeAllowlist() {
        let attributes: [String: String] = [
            "device": "tracker_plus",
            "os.version": "14.5",
            "sentry.release": "1.2.0",
            "user.id": "1F0C2D3E-installation",
            "project": "Night Bus",
            "path": "/Users/someone/Music/Night Bus",
        ]
        let kept = TelemetryRules.allowedAttributes(attributes)
        #expect(Set(kept.keys) == ["device", "os.version", "sentry.release"])
    }

    @Test("The device attribute is one of two fixed values")
    func deviceValues() {
        #expect(DeviceModel.allCases.map(TelemetryRules.deviceAttribute) == ["tracker_mini", "tracker_plus"])
    }

    @Test("A library's path loses the account name")
    func scrubsAccount() {
        #expect(TelemetryRules.scrubbingAccount("/Users/jarl/Downloads/Patternaut.app/Contents/MacOS/Patternaut")
                == "/Users/~/Downloads/Patternaut.app/Contents/MacOS/Patternaut")
        #expect(TelemetryRules.scrubbingAccount("/Applications/Patternaut.app/Contents/MacOS/Patternaut")
                == "/Applications/Patternaut.app/Contents/MacOS/Patternaut")
    }

    @Test("Paths to the user's files go from free text altogether")
    func redactsPaths() {
        #expect(TelemetryRules.redactingPaths("could not open \"/Users/a.b/Desktop/Night Bus.patternaut\"")
                == "could not open \"<path>\"")
        #expect(TelemetryRules.redactingPaths("read /Volumes/TRACKER/Projects/User/Night Bus/patterns/pattern_01.mtp")
                == "read <path>")
        #expect(TelemetryRules.redactingPaths("index out of range") == "index out of range")
    }
}
