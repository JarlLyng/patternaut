import Foundation

/// The hardware devices Patternaut targets.
///
/// The original Tracker is intentionally excluded from the primary set: it
/// cannot run the modern firmware (CPU/RAM) and would be a separate legacy
/// profile if ever supported.
public enum DeviceModel: String, Codable, CaseIterable, Sendable, Identifiable {
    case trackerMini
    case trackerPlus

    public var id: String { rawValue }

    /// The validation/export profile for this device.
    public var profile: DeviceProfile { DeviceProfile.profile(for: self) }

    public var displayName: String {
        switch self {
        case .trackerMini: return "Tracker Mini"
        case .trackerPlus: return "Tracker+"
        }
    }
}
