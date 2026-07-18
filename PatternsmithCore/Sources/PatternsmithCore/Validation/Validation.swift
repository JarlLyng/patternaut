import Foundation

/// A problem found while validating a pattern against a device profile.
public struct ValidationIssue: Sendable, Equatable {
    public enum Severity: Sendable, Equatable {
        /// Export can proceed but data may be altered or ignored.
        case warning
        /// Export must not proceed until resolved.
        case error
    }

    public let severity: Severity
    public let message: String
    public let trackIndex: Int?
    public let stepIndex: Int?

    public init(severity: Severity, message: String, trackIndex: Int? = nil, stepIndex: Int? = nil) {
        self.severity = severity
        self.message = message
        self.trackIndex = trackIndex
        self.stepIndex = stepIndex
    }
}

public extension DeviceProfile {
    /// Validates a pattern against this profile. Returns every issue found;
    /// an empty result means the pattern is safe to export.
    ///
    /// Supports the "validate before export" and non-destructive principles:
    /// it only reports, never mutates.
    func validate(_ pattern: Pattern) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if pattern.tracks.count > trackCount {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Pattern has \(pattern.tracks.count) tracks; \(displayName) supports \(trackCount)."
            ))
        } else if pattern.tracks.count < trackCount {
            // The device parser infers track count from file size, so a hardware
            // `.mtp` must carry the full set. Fewer tracks won't load correctly.
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Pattern has \(pattern.tracks.count) of \(trackCount) tracks; hardware export needs the full set (pad with empty tracks)."
            ))
        }

        for (trackIndex, track) in pattern.tracks.enumerated() {
            if !stepRange.contains(track.length) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Track length \(track.length) is out of range \(stepRange.lowerBound)–\(stepRange.upperBound).",
                    trackIndex: trackIndex
                ))
            }

            if track.steps.count != track.length {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Track has \(track.steps.count) steps but length \(track.length); extra/missing steps will be clipped or padded on export.",
                    trackIndex: trackIndex
                ))
            }

            let role = role(forTrack: trackIndex)

            for (stepIndex, step) in track.steps.enumerated() {
                if step.fx.count > maxFXPerStep {
                    issues.append(ValidationIssue(
                        severity: .error,
                        message: "Step has \(step.fx.count) effects; max is \(maxFXPerStep).",
                        trackIndex: trackIndex,
                        stepIndex: stepIndex
                    ))
                }

                for command in step.fx {
                    if !supportedFX.contains(command.type) {
                        issues.append(ValidationIssue(
                            severity: .error,
                            message: "Effect \"\(command.type.descriptor.name)\" is not supported by \(displayName).",
                            trackIndex: trackIndex,
                            stepIndex: stepIndex
                        ))
                    } else if !command.isInRange {
                        let d = command.type.descriptor
                        issues.append(ValidationIssue(
                            severity: .warning,
                            message: "Effect \"\(d.name)\" value \(command.value) is outside \(d.min)–\(d.max) and will be clamped.",
                            trackIndex: trackIndex,
                            stepIndex: stepIndex
                        ))
                    }
                }

                if let instrument = step.instrument {
                    guard let kind = InstrumentKind(index: instrument) else {
                        issues.append(ValidationIssue(
                            severity: .error,
                            message: "Instrument index \(instrument) is out of range \(TrackerFormat.instrumentRange.lowerBound)–\(TrackerFormat.instrumentRange.upperBound).",
                            trackIndex: trackIndex,
                            stepIndex: stepIndex
                        ))
                        continue
                    }
                    if kind == .sample && role == .midiSynth {
                        issues.append(ValidationIssue(
                            severity: .error,
                            message: "Track is MIDI/synth only and cannot play a sample instrument.",
                            trackIndex: trackIndex,
                            stepIndex: stepIndex
                        ))
                    }
                    if kind == .sample && instrument >= instrumentCount {
                        issues.append(ValidationIssue(
                            severity: .error,
                            message: "Sample instrument \(instrument) exceeds the \(instrumentCount)-instrument limit.",
                            trackIndex: trackIndex,
                            stepIndex: stepIndex
                        ))
                    }
                }
            }
        }

        return issues
    }

    /// Convenience: true when the pattern has no blocking errors.
    func isExportable(_ pattern: Pattern) -> Bool {
        !validate(pattern).contains { $0.severity == .error }
    }
}
