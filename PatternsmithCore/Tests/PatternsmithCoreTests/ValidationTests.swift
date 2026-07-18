import Testing
@testable import PatternsmithCore

@Suite("Validation")
struct ValidationTests {
    @Test("A fresh empty pattern is exportable")
    func emptyIsClean() {
        let pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "Clean")
        #expect(DeviceProfile.trackerPlus.validate(pattern).isEmpty)
        #expect(DeviceProfile.trackerPlus.isExportable(pattern))
    }

    @Test("Sample instrument on a MIDI/synth track is an error")
    func sampleOnMidiTrack() {
        var pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "X", stepCount: 4)
        // Track index 8 is MIDI/synth only; instrument 0 is a sample.
        pattern.tracks[8].steps[0].instrument = 0
        let issues = DeviceProfile.trackerPlus.validate(pattern)
        #expect(issues.contains { $0.severity == .error && $0.trackIndex == 8 })
        #expect(!DeviceProfile.trackerPlus.isExportable(pattern))
    }

    @Test("More than two effects on a step is an error")
    func tooManyFX() {
        var pattern = DeviceProfile.trackerMini.makeEmptyPattern(name: "X", stepCount: 4)
        pattern.tracks[0].steps[0].fx = [
            FXCommand(type: .chance, value: 50),
            FXCommand(type: .roll, value: 2),
            FXCommand(type: .swing, value: 60),
        ]
        let issues = DeviceProfile.trackerMini.validate(pattern)
        #expect(issues.contains { $0.severity == .error && $0.stepIndex == 0 })
    }

    @Test("Out-of-range effect value is a clamping warning, not an error")
    func outOfRangeValue() {
        var pattern = DeviceProfile.trackerMini.makeEmptyPattern(name: "X", stepCount: 4)
        pattern.tracks[0].steps[0].fx = [FXCommand(type: .chance, value: 200)]
        let issues = DeviceProfile.trackerMini.validate(pattern)
        #expect(issues.contains { $0.severity == .warning })
        #expect(DeviceProfile.trackerMini.isExportable(pattern))
    }

    @Test("Out-of-range instrument index is an error")
    func badInstrument() {
        var pattern = DeviceProfile.trackerMini.makeEmptyPattern(name: "X", stepCount: 4)
        pattern.tracks[0].steps[0].instrument = 99
        let issues = DeviceProfile.trackerMini.validate(pattern)
        #expect(issues.contains { $0.severity == .error })
    }
}
