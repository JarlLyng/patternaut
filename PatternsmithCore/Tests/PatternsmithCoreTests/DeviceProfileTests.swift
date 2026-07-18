import Testing
@testable import PatternsmithCore

@Suite("Device profiles")
struct DeviceProfileTests {
    @Test("Both modern profiles use the 16-track format")
    func trackCounts() {
        #expect(DeviceProfile.trackerMini.trackCount == 16)
        #expect(DeviceProfile.trackerPlus.trackCount == 16)
        #expect(TrackerFormat.TrackGeneration.miniPlus.trackCount == 16)
        #expect(TrackerFormat.TrackGeneration.og.trackCount == 12)
        #expect(TrackerFormat.TrackGeneration.old.trackCount == 8)
    }

    @Test("Track roles split 8 universal + 8 MIDI/synth")
    func trackRoles() {
        let plus = DeviceProfile.trackerPlus
        #expect(plus.trackRoles.count == 16)
        #expect(plus.role(forTrack: 0) == .universal)
        #expect(plus.role(forTrack: 7) == .universal)
        #expect(plus.role(forTrack: 8) == .midiSynth)
        #expect(plus.role(forTrack: 15) == .midiSynth)
    }

    @Test("Default track names mirror the format layout")
    func trackNames() {
        let names = DeviceProfile.trackerPlus.defaultTrackNames
        #expect(names.first == "Track 1")
        #expect(names[7] == "Track 8")
        #expect(names[8] == "Midi 9")
        #expect(names.last == "Midi 16")
    }

    @Test("Empty pattern is sized correctly")
    func emptyPattern() {
        let pattern = DeviceProfile.trackerMini.makeEmptyPattern(name: "New", stepCount: 64)
        #expect(pattern.tracks.count == 16)
        #expect(pattern.tracks.allSatisfy { $0.length == 64 })
        #expect(pattern.tracks.allSatisfy { $0.steps.count == 64 })
        #expect(pattern.device == .trackerMini)
    }

    @Test("Step count is clamped to the valid range")
    func stepClamping() {
        let tooLong = DeviceProfile.trackerPlus.makeEmptyPattern(name: "X", stepCount: 999)
        #expect(tooLong.tracks[0].length == 128)
    }
}
