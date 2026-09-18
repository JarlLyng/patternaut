import CoreMIDI
import Foundation
import PatternautCore

/// A MIDI output destination (a port on connected gear / another app).
struct MIDIDestination: Identifiable, Hashable {
    let id: MIDIUniqueID
    let name: String
    let endpoint: MIDIEndpointRef
}

/// Thin CoreMIDI wrapper: enumerates destinations and sends a timed
/// ``MIDIEvent`` sequence, letting CoreMIDI schedule delivery by timestamp.
///
/// - Important: This transport can only be compile-verified here; sending must
///   be confirmed against real gear (e.g. a Tracker in `[Rec]+[Play]`).
final class MIDIOutput {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var timebase = mach_timebase_info_data_t()

    /// Holds the setup-change handler for the CoreMIDI notification block, which
    /// runs on CoreMIDI's own thread. The handler is only ever read and written
    /// on the main thread, which is what makes the unchecked conformance safe.
    private final class SetupObserver: @unchecked Sendable {
        var handler: (() -> Void)?
    }

    private let observer = SetupObserver()

    /// Called on the main queue when CoreMIDI's setup changes, so the app can
    /// pick up a Tracker that was plugged in after launch.
    var onSetupChanged: (() -> Void)? {
        get { observer.handler }
        set { observer.handler = newValue }
    }

    init?() {
        mach_timebase_info(&timebase)
        var created = MIDIClientRef()
        let observer = self.observer
        let status = MIDIClientCreateWithBlock("Patternaut" as CFString, &created) { notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            DispatchQueue.main.async { observer.handler?() }
        }
        guard status == noErr else { return nil }
        client = created
        guard MIDIOutputPortCreate(client, "Patternaut Out" as CFString, &port) == noErr else { return nil }
    }

    func destinations() -> [MIDIDestination] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { return nil }
            return MIDIDestination(id: uniqueID(of: endpoint), name: displayName(of: endpoint), endpoint: endpoint)
        }
    }

    /// Schedules `events` for delivery to `endpoint`, timed from now via `tempo`.
    /// Returns how many `MIDISend` calls returned an error status.
    @discardableResult
    func send(_ events: [MIDIEvent], tempo: Double, to endpoint: MIDIEndpointRef) -> Int {
        let start = mach_absolute_time()
        var errors = 0
        for event in events {
            let seconds = event.beat * 60.0 / max(tempo, 1)
            let timestamp = start &+ hostTicks(for: seconds)
            var list = MIDIPacketList()
            let packet = MIDIPacketListInit(&list)
            let bytes = event.bytes
            _ = MIDIPacketListAdd(&list, 1024, packet, timestamp, bytes.count, bytes)
            if MIDISend(port, endpoint, &list) != noErr { errors += 1 }
        }
        return errors
    }

    // MARK: - Private

    private func hostTicks(for seconds: Double) -> UInt64 {
        guard timebase.numer != 0 else { return 0 }
        return UInt64(seconds * 1_000_000_000.0 * Double(timebase.denom) / Double(timebase.numer))
    }

    private func uniqueID(of endpoint: MIDIEndpointRef) -> MIDIUniqueID {
        var id: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
        return id
    }

    private func displayName(of endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr,
           let name = name?.takeRetainedValue() {
            return name as String
        }
        return "MIDI \(endpoint)"
    }
}
