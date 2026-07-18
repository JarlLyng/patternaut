import Foundation

/// Generates single tracks from rhythmic models. Results are meant to be edited
/// further, not treated as finished — matching the spec's philosophy.
public enum RhythmGenerator {
    /// A track whose hits follow a Euclidean rhythm.
    public static func euclidean(
        pulses: Int,
        steps: Int,
        rotation: Int = 0,
        note: Note,
        instrument: Int?,
        velocity: Int? = nil,
        name: String,
        role: TrackRole = .universal
    ) -> Track {
        let hits = Euclidean.rhythm(pulses: pulses, steps: steps, rotation: rotation)
        let stepData = hits.map { hit -> Step in
            guard hit else { return .empty }
            var step = Step(note: note, instrument: instrument)
            if let velocity { step.velocity = velocity }
            return step
        }
        return Track(name: name, role: role, length: steps, steps: stepData)
    }

    /// A track where each step becomes a hit with probability `density`
    /// (`0...1`), decided by the seeded RNG so the result is reproducible.
    ///
    /// If `chance` is provided, the Chance FX (`C`) is written on each hit so
    /// the hardware also performs probability at playback.
    public static func probability(
        steps: Int,
        density: Double,
        note: Note,
        instrument: Int?,
        velocity: Int? = nil,
        chance: Int? = nil,
        name: String,
        role: TrackRole = .universal,
        using rng: inout SeededGenerator
    ) -> Track {
        let clampedDensity = min(max(density, 0), 1)
        let stepData = (0..<steps).map { _ -> Step in
            let roll = Double.random(in: 0..<1, using: &rng)
            guard roll < clampedDensity else { return .empty }
            var step = Step(note: note, instrument: instrument)
            if let velocity { step.velocity = velocity }
            if let chance { step.probability = chance }
            return step
        }
        return Track(name: name, role: role, length: steps, steps: stepData)
    }
}
