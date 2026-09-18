import Testing
@testable import PatternautCore

@Suite("Mutation")
struct MutationTests {
    /// A source pattern with real content across a few tracks.
    func source() -> Pattern {
        let kick = RhythmGenerator.euclidean(pulses: 4, steps: 16, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let snare = RhythmGenerator.euclidean(pulses: 3, steps: 16, rotation: 4, note: .pitch(38), instrument: 1, velocity: 100, name: "Snare")
        let hat = RhythmGenerator.euclidean(pulses: 11, steps: 16, rotation: 1, note: .pitch(42), instrument: 2, velocity: 70, name: "Hat")
        return PatternGenerator.assemble(device: .trackerPlus, name: "Src", steps: 16, seed: 1, tracks: [kick, snare, hat])
    }

    /// Content projection ignoring ids/timestamps.
    func project(_ p: Pattern) -> [[String]] {
        p.tracks.map { track in
            track.steps.prefix(track.length).map { step in
                let fx = step.fx.map { "\($0.type.rawValue)=\($0.value)" }.joined(separator: ",")
                return "\(step.note.rawValue):\(step.instrument.map(String.init) ?? "-"):\(fx)"
            }
        }
    }

    func activeDiffs(_ a: Pattern, _ b: Pattern) -> Int {
        var diffs = 0
        for (ta, tb) in zip(a.tracks, b.tracks) {
            let n = min(ta.length, ta.steps.count, tb.steps.count)
            for i in 0..<n where ta.steps[i] != tb.steps[i] { diffs += 1 }
        }
        return diffs
    }

    @Test("Same seed reproduces identical content; different seed differs")
    func deterministic() {
        let p = source()
        #expect(project(Mutation.mutate(p, strength: .moderate, seed: 7)) == project(Mutation.mutate(p, strength: .moderate, seed: 7)))
        #expect(project(Mutation.mutate(p, strength: .moderate, seed: 7)) != project(Mutation.mutate(p, strength: .moderate, seed: 8)))
    }

    @Test("Records lineage: parent, bumped version, seed")
    func lineage() {
        let p = source()
        let m = Mutation.mutate(p, strength: .subtle, seed: 3)
        #expect(m.metadata.parentID == p.id)
        #expect(m.metadata.version == p.metadata.version + 1)
        #expect(m.metadata.mutationSeed == 3)
        #expect(m.id != p.id)
    }

    @Test("Structure (track count and lengths) is preserved")
    func structurePreserved() {
        let p = source()
        for strength in MutationStrength.allCases {
            let m = Mutation.mutate(p, strength: strength, seed: 5)
            #expect(m.tracks.count == p.tracks.count)
            #expect(zip(m.tracks, p.tracks).allSatisfy { $0.length == $1.length })
        }
    }

    @Test("Stronger settings change more (summed over many seeds)")
    func strengthMonotonic() {
        let p = source()
        func totalDiffs(_ strength: MutationStrength) -> Int {
            (0..<24).reduce(0) { sum, seed in sum + activeDiffs(p, Mutation.mutate(p, strength: strength, seed: UInt64(seed))) }
        }
        let subtle = totalDiffs(.subtle)
        let moderate = totalDiffs(.moderate)
        let chaotic = totalDiffs(.chaotic)
        #expect(subtle < moderate)
        #expect(moderate < chaotic)
        #expect(subtle > 0)
    }

    @Test("Subtle keeps most of the pattern intact")
    func subtleKeepsIdentity() {
        let p = source()
        let m = Mutation.mutate(p, strength: .subtle, seed: 2)
        let totalActiveRegion = p.tracks.reduce(0) { $0 + min($1.length, $1.steps.count) }
        // Fewer than 20% of steps change under a subtle mutation.
        #expect(activeDiffs(p, m) < totalActiveRegion / 5)
    }

    @Test("Batch returns N reproducible variants")
    func batch() {
        let p = source()
        let a = Mutation.mutations(p, strength: .strong, count: 5, seed: 100)
        let b = Mutation.mutations(p, strength: .strong, count: 5, seed: 100)
        #expect(a.count == 5)
        #expect(a.map(project) == b.map(project))
    }

    @Test("Mutating an empty pattern stays empty and does not crash")
    func emptyPattern() {
        let p = DeviceProfile.trackerMini.makeEmptyPattern(name: "E", stepCount: 16)
        for strength in MutationStrength.allCases {
            let m = Mutation.mutate(p, strength: strength, seed: 9)
            #expect(m.tracks.allSatisfy { track in track.steps.allSatisfy { !$0.isActive } })
        }
    }
}
