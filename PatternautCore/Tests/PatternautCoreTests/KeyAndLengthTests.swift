import Testing
@testable import PatternautCore

@Suite("Key and length")
struct KeyAndLengthTests {
    @Test("Scale pitches start on the root at or above the floor")
    func pitchesFromFloor() {
        let key = MusicalKey(root: 2, scale: .minor) // D minor
        let pitches = key.pitches(from: 24, count: 7)
        #expect(pitches.first == 26) // D1, the first D at or above C1
        #expect(pitches == [26, 28, 29, 31, 33, 34, 36])

        // Asking from exactly the root keeps it.
        #expect(MusicalKey(root: 0, scale: .major).pitches(from: 24, count: 3) == [24, 26, 28])
    }

    @Test("Pitches continue into the next octave")
    func pitchesAcrossOctaves() {
        let key = MusicalKey(root: 0, scale: .minorPentatonic)
        let pitches = key.pitches(from: 36, count: 7)
        #expect(pitches == [36, 39, 41, 43, 46, 48, 51])
    }

    @Test("Snapping moves out-of-key notes to the nearest scale tone")
    func snapping() {
        let cMinor = MusicalKey(root: 0, scale: .minor) // C D Eb F G Ab Bb
        #expect(cMinor.snap(60) == 60) // C stays
        #expect(cMinor.snap(61) == 60) // C# down to C
        #expect(cMinor.snap(64) == 63) // E down to Eb
        #expect(cMinor.snap(0) >= 0)
        #expect(cMinor.snap(127) <= 127)
    }

    @Test("Generated bass stays in the key, and drums are left alone")
    func generatedBassInKey() {
        let key = MusicalKey(root: 7, scale: .minorPentatonic) // G minor pentatonic
        var checkedABass = false
        for seed in UInt64(1)...40 {
            let pattern = BeatGenerator.beat(device: .trackerPlus, key: key, seed: seed)
            guard let bass = pattern.tracks.first(where: { $0.name == "Bass" }) else { continue }
            checkedABass = true
            for step in bass.steps where step.isActive {
                guard case .pitch(let pitch) = step.note else { continue }
                let pitchClass = ((Int(pitch) % 12) - key.root + 12) % 12
                #expect(key.scale.intervals.contains(pitchClass), "seed \(seed): \(pitch) is out of key")
            }
            // Drum tracks keep their sample-trigger pitches whatever the key is.
            let kick = pattern.tracks[0].steps.first { $0.isActive }
            #expect(kick?.note == .pitch(36))
        }
        #expect(checkedABass)
    }

    @Test("The same seed in a different key gives the same rhythm")
    func keyDoesNotDisturbRhythm() {
        let a = BeatGenerator.beat(device: .trackerPlus, key: MusicalKey(root: 0, scale: .minor), seed: 5)
        let b = BeatGenerator.beat(device: .trackerPlus, key: MusicalKey(root: 5, scale: .lydian), seed: 5)
        let rhythm = { (pattern: Pattern) in pattern.tracks.map { $0.steps.map(\.isActive) } }
        #expect(rhythm(a) == rhythm(b))
    }

    @Test("Lengthening pads with empty steps and shortening drops them")
    func changingLength() {
        var editor = PatternEditor(pattern: BeatGenerator.beat(device: .trackerPlus, steps: 16, seed: 3))
        let originalHits = editor.pattern.tracks[0].steps.filter(\.isActive).count

        editor.setLength(32)
        #expect(editor.rowCount == 32)
        #expect(editor.pattern.tracks.allSatisfy { $0.length == 32 && $0.steps.count == 32 })
        #expect(editor.pattern.tracks[0].steps.filter(\.isActive).count == originalHits)
        #expect(editor.pattern.tracks[0].steps[16...].allSatisfy { $0 == .empty || !$0.isActive })

        editor.setLength(8)
        #expect(editor.rowCount == 8)
        #expect(editor.pattern.tracks.allSatisfy { $0.steps.count == 8 })

        // Undo walks back through both changes.
        editor.undo()
        #expect(editor.rowCount == 32)
        editor.undo()
        #expect(editor.rowCount == 16)
    }

    @Test("Length is clamped to what the device accepts")
    func lengthClamping() {
        var editor = PatternEditor(pattern: BeatGenerator.beat(device: .trackerMini, steps: 16, seed: 3))
        editor.setLength(9999)
        #expect(editor.rowCount == TrackerFormat.maxSteps)
        editor.setLength(0)
        #expect(editor.rowCount == TrackerFormat.minSteps)
    }

    @Test("A resized pattern is still exportable and reloads at its new length")
    func resizedExport() throws {
        var editor = PatternEditor(pattern: BeatGenerator.beat(device: .trackerPlus, steps: 16, seed: 11))
        editor.setLength(64)
        #expect(DeviceProfile.trackerPlus.validate(editor.pattern).filter { $0.severity == .error }.isEmpty)
        let reloaded = try MTPImporter.parse(MTPExporter.export(editor.pattern))
        #expect(reloaded.tracks.allSatisfy { $0.length == 64 })
    }
}
