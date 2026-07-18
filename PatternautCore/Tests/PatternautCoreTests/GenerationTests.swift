import Testing
@testable import PatternautCore

@Suite("Generation")
struct GenerationTests {
    // MARK: Seeded RNG

    @Test("Seeded RNG is deterministic and seed-sensitive")
    func seededDeterminism() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        var c = SeededGenerator(seed: 43)

        let seqA = (0..<8).map { _ in a.next() }
        let seqB = (0..<8).map { _ in b.next() }
        let seqC = (0..<8).map { _ in c.next() }

        #expect(seqA == seqB)
        #expect(seqA != seqC)
    }

    // MARK: Euclidean track

    @Test("Euclidean track places notes on hits only")
    func euclideanTrack() {
        let track = RhythmGenerator.euclidean(
            pulses: 4, steps: 16, note: .pitch(36), instrument: 0, velocity: 100, name: "Kick"
        )
        #expect(track.length == 16)
        #expect(track.steps.count == 16)
        #expect(track.steps.filter { $0.isActive }.count == 4)
        // First hit carries note + velocity.
        #expect(track.steps[0].note == .pitch(36))
        #expect(track.steps[0].velocity == 100)
        #expect(track.steps[1].isActive == false)
    }

    // MARK: Probability

    @Test("Probability generator is reproducible for a seed")
    func probabilityReproducible() {
        func gen(_ seed: UInt64) -> [Bool] {
            var rng = SeededGenerator(seed: seed)
            let track = RhythmGenerator.probability(
                steps: 32, density: 0.5, note: .pitch(38), instrument: 1, name: "Snare", using: &rng
            )
            return track.steps.map { $0.isActive }
        }
        #expect(gen(7) == gen(7))
        #expect(gen(7) != gen(8))
    }

    @Test("Density 0 and 1 are empty and full")
    func densityExtremes() {
        var rng = SeededGenerator(seed: 1)
        let none = RhythmGenerator.probability(steps: 16, density: 0, note: .pitch(38), instrument: 1, name: "S", using: &rng)
        let all = RhythmGenerator.probability(steps: 16, density: 1, note: .pitch(38), instrument: 1, name: "S", using: &rng)
        #expect(none.steps.allSatisfy { !$0.isActive })
        #expect(all.steps.allSatisfy { $0.isActive })
    }

    @Test("Probability can attach the Chance FX for runtime probability")
    func chanceFX() {
        var rng = SeededGenerator(seed: 3)
        let track = RhythmGenerator.probability(
            steps: 16, density: 1, note: .pitch(38), instrument: 1, chance: 70, name: "S", using: &rng
        )
        #expect(track.steps.allSatisfy { $0.probability == 70 })
    }

    // MARK: Groove

    @Test("Swing nudges off-beat hits only")
    func swing() {
        // Every step active so we can see which get nudged.
        let track = RhythmGenerator.euclidean(pulses: 8, steps: 8, note: .pitch(42), instrument: 2, name: "Hat")
        let swung = Groove.swing(track, amount: 20, every: 2)
        #expect(swung.steps[0].microtiming == nil) // on-beat
        #expect(swung.steps[1].microtiming == 20)  // off-beat
        #expect(swung.steps[2].microtiming == nil)
        #expect(swung.steps[3].microtiming == 20)
    }

    @Test("Humanize is bounded and reproducible")
    func humanize() {
        let track = RhythmGenerator.euclidean(pulses: 8, steps: 8, note: .pitch(42), instrument: 2, velocity: 80, name: "Hat")
        func run() -> [Int?] {
            var rng = SeededGenerator(seed: 99)
            let h = Groove.humanize(track, timing: 10, velocity: 15, using: &rng)
            return h.steps.map { $0.velocity }
        }
        let first = run()
        #expect(first == run()) // reproducible
        // Velocity stays within base +/- range and clamped to 0...100.
        for v in first.compactMap({ $0 }) {
            #expect(v >= 65 && v <= 95)
        }
    }

    // MARK: Transforms

    @Test("Rotate wraps; full rotation is identity; reverse flips")
    func transforms() {
        let track = RhythmGenerator.euclidean(pulses: 3, steps: 8, note: .pitch(36), instrument: 0, name: "K")
        let active = { (t: Track) in t.steps.map { $0.isActive } }

        let rotated = Transform.rotate(track, by: 1)
        #expect(active(rotated) == [false, false, true, false, false, true, false, true])
        #expect(active(Transform.rotate(track, by: 8)) == active(track))

        let reversed = Transform.reverse(track)
        #expect(active(reversed) == active(track).reversed())
    }

    // MARK: Assembly + end-to-end

    @Test("Assembled pattern is device-sized, seeded, and export-valid")
    func assembleAndExport() {
        let kick = RhythmGenerator.euclidean(pulses: 4, steps: 16, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let hat = RhythmGenerator.euclidean(pulses: 11, steps: 16, rotation: 2, note: .pitch(42), instrument: 1, velocity: 70, name: "Hat")

        let pattern = PatternGenerator.assemble(
            device: .trackerPlus, name: "Breakbeat", tempo: 160, meter: .fourFour,
            steps: 16, seed: 12345, tracks: [kick, hat]
        )

        #expect(pattern.tracks.count == 16)
        #expect(pattern.metadata.seed == 12345)
        #expect(pattern.tracks[0].name == "Kick")
        #expect(pattern.tracks[2].name == "Track 3") // filled empty

        // The generated pattern validates and exports cleanly.
        #expect(DeviceProfile.trackerPlus.isExportable(pattern))
        let data = MTPExporter.export(pattern)
        #expect(data.count == 12336)
    }
}
