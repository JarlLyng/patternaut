import Testing
@testable import PatternautCore

@Suite("Validation")
struct ValidationTests {
    @Test("A fresh empty pattern is exportable")
    func emptyIsClean() {
        let pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "Clean")
        #expect(DeviceProfile.trackerPlus.validate(pattern).isEmpty)
        #expect(DeviceProfile.trackerPlus.isExportable(pattern))
    }

    @Test("A sample instrument on a MIDI-named track is allowed")
    func sampleOnMidiTrack() {
        // Tracks 9-16 carry MIDI names, but Polyend's own demo projects play
        // sample instruments on them, so this is not an error.
        var pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "X", stepCount: 4)
        pattern.tracks[8].steps[0].note = .pitch(60)
        pattern.tracks[8].steps[0].instrument = 0
        #expect(DeviceProfile.trackerPlus.validate(pattern).isEmpty)
        #expect(DeviceProfile.trackerPlus.isExportable(pattern))
    }

    @Test("An instrument on a step that plays nothing is not checked")
    func instrumentWithoutNote() {
        // Every empty step in a file stores instrument 0; those are not hits.
        var pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "X", stepCount: 4)
        pattern.tracks[0].steps[0].instrument = 999
        #expect(DeviceProfile.trackerPlus.validate(pattern).isEmpty)

        // The same instrument on a step that does play is still an error.
        pattern.tracks[0].steps[0].note = .pitch(60)
        #expect(DeviceProfile.trackerPlus.validate(pattern).contains { $0.severity == .error })
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
        pattern.tracks[0].steps[0].note = .pitch(60)
        pattern.tracks[0].steps[0].instrument = 99
        let issues = DeviceProfile.trackerMini.validate(pattern)
        #expect(issues.contains { $0.severity == .error })
    }
}
