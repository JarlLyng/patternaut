import Foundation

/// How strongly a mutation departs from the original. Subtle/moderate/strong
/// keep the pattern's identity; chaotic deliberately breaks it.
public enum MutationStrength: String, Sendable, CaseIterable {
    case subtle, moderate, strong, chaotic
}

/// Deterministic, non-destructive pattern mutation: produces related variants of
/// a pattern by adding/removing hits, jittering velocity, nudging pitch, and (at
/// higher strengths) larger changes. Same pattern + strength + seed → same
/// result, so variants are reproducible.
public enum Mutation {
    /// A single mutated variant. Records lineage (`parentID`, bumped `version`,
    /// `seed`) so versions can be compared and traced.
    public static func mutate(_ pattern: Pattern, strength: MutationStrength, seed: UInt64) -> Pattern {
        var rng = SeededGenerator(seed: seed)
        var result = pattern
        result.id = UUID()
        result.tracks = pattern.tracks.map { mutateTrack($0, strength: strength, rng: &rng) }
        result.metadata.parentID = pattern.id
        result.metadata.version = pattern.metadata.version + 1
        result.metadata.seed = seed
        return result
    }

    /// `count` variants from consecutive seeds, for browsing alternatives.
    public static func mutations(_ pattern: Pattern, strength: MutationStrength, count: Int, seed: UInt64) -> [Pattern] {
        (0..<max(0, count)).map { mutate(pattern, strength: strength, seed: seed &+ UInt64($0)) }
    }

    // MARK: - Per-track

    private struct Params {
        let change: Double     // chance a step is touched at all
        let removeBias: Double // of touched active steps, share that get removed
        let pitchBias: Double  // share (after remove) that get pitch-nudged
        let addBias: Double    // chance a touched empty step gains a hit
        let velJitter: Int
        let pitchRange: Int
    }

    private static func params(_ strength: MutationStrength) -> Params {
        switch strength {
        case .subtle:   return Params(change: 0.08, removeBias: 0.35, pitchBias: 0.00, addBias: 0.15, velJitter: 6, pitchRange: 0)
        case .moderate: return Params(change: 0.18, removeBias: 0.40, pitchBias: 0.00, addBias: 0.30, velJitter: 12, pitchRange: 0)
        case .strong:   return Params(change: 0.35, removeBias: 0.45, pitchBias: 0.20, addBias: 0.45, velJitter: 20, pitchRange: 2)
        case .chaotic:  return Params(change: 0.65, removeBias: 0.45, pitchBias: 0.35, addBias: 0.60, velJitter: 40, pitchRange: 12)
        }
    }

    private static func mutateTrack(_ track: Track, strength: MutationStrength, rng: inout SeededGenerator) -> Track {
        let p = params(strength)
        var result = track
        let (signatureNote, signatureInstrument) = signature(of: track)
        let count = min(track.length, track.steps.count)

        for i in 0..<count {
            guard Double.random(in: 0..<1, using: &rng) < p.change else { continue }
            let action = Double.random(in: 0..<1, using: &rng)

            if result.steps[i].isActive {
                if action < p.removeBias {
                    result.steps[i] = .empty
                } else if p.pitchRange > 0, action < p.removeBias + p.pitchBias, case .pitch(let n) = result.steps[i].note {
                    let delta = Int.random(in: -p.pitchRange...p.pitchRange, using: &rng)
                    result.steps[i].note = .pitch(UInt8(min(max(Int(n) + delta, 0), 127)))
                } else {
                    let base = result.steps[i].velocity ?? 100
                    let delta = Int.random(in: -p.velJitter...p.velJitter, using: &rng)
                    result.steps[i].velocity = min(max(base + delta, 0), 100)
                }
            } else if let note = signatureNote, action < p.addBias {
                var step = Step(note: note, instrument: signatureInstrument)
                step.velocity = 90
                result.steps[i] = step
            }
        }
        return result
    }

    /// The most frequent (note, instrument) among a track's active steps, used
    /// to add musically-consistent hits. `nil` if the track has no active steps.
    private static func signature(of track: Track) -> (Note?, Int?) {
        var tally: [Int: (note: Note, instrument: Int?, count: Int)] = [:]
        for step in track.steps where step.isActive {
            let key = step.note.rawValue &* 1000 &+ ((step.instrument ?? 999) + 1)
            let existing = tally[key]?.count ?? 0
            tally[key] = (step.note, step.instrument, existing + 1)
        }
        guard let best = tally.values.max(by: { $0.count < $1.count }) else { return (nil, nil) }
        return (best.note, best.instrument)
    }
}
