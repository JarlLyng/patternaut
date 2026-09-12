import Foundation

/// Generates a whole starting beat from a seed: a kick, snare and hat, usually
/// some percussion and a bass line, with groove and probability applied.
///
/// Every choice comes from the seeded RNG, so a seed always gives back the same
/// beat, and a new seed gives a genuinely different one. The output is a
/// starting point to edit, not a finished track.
public enum BeatGenerator {
    /// Drum voices, in the order they are placed on tracks.
    private struct Voice {
        let name: String
        let note: Note
        let instrument: Int
    }

    /// Builds a beat for `device` from `seed`.
    ///
    /// - Parameters:
    ///   - steps: Pattern length. Clamped to the device's range.
    ///   - seed: Everything below is derived from this, including which optional
    ///     parts appear.
    public static func beat(
        device: DeviceModel,
        name: String = "Generated",
        tempo: Double = 130,
        steps: Int = 16,
        seed: UInt64
    ) -> Pattern {
        var rng = SeededGenerator(seed: seed)
        let profile = device.profile
        let length = min(max(steps, profile.stepRange.lowerBound), profile.stepRange.upperBound)
        // Euclidean parameters are written for 16 steps; scale them with length.
        let scale = max(1, length / 16)

        var tracks: [Track] = []

        // Kick: sparse and usually on the downbeat.
        let kickPulses = Int.random(in: 3...6, using: &rng) * scale
        var kick = RhythmGenerator.euclidean(
            pulses: kickPulses, steps: length,
            rotation: Bool.random(using: &rng) ? 0 : Int.random(in: 0...2, using: &rng),
            note: .pitch(36), instrument: 0, velocity: Int.random(in: 100...115, using: &rng),
            name: "Kick"
        )

        // Snare: fewer hits, rotated off the downbeat so it answers the kick.
        let snarePulses = Int.random(in: 2...4, using: &rng) * scale
        var snare = RhythmGenerator.euclidean(
            pulses: snarePulses, steps: length,
            rotation: [4, 4, 8, 6].randomElement(using: &rng)! * scale,
            note: .pitch(38), instrument: 1, velocity: Int.random(in: 90...105, using: &rng),
            name: "Snare"
        )

        // Hat: the busy one, and the one that carries the swing.
        let hatPulses = Int.random(in: 6...13, using: &rng) * scale
        var hat = RhythmGenerator.euclidean(
            pulses: hatPulses, steps: length,
            rotation: Int.random(in: 0...3, using: &rng),
            note: .pitch(42), instrument: 2, velocity: Int.random(in: 55...80, using: &rng),
            name: "Hat"
        )

        // Groove. Swing lands on the hat, humanising on all three, and the two
        // together stay inside the device's two-FX-per-step limit.
        let swingAmount = [0, 0, 8, 12, 18, 25].randomElement(using: &rng)!
        if swingAmount > 0 { hat = Groove.swing(hat, amount: swingAmount) }
        let velocityJitter = Int.random(in: 4...14, using: &rng)
        kick = Groove.humanize(kick, velocity: velocityJitter, using: &rng)
        snare = Groove.humanize(snare, velocity: velocityJitter, using: &rng)
        hat = Groove.humanize(hat, velocity: velocityJitter, using: &rng)

        tracks.append(contentsOf: [kick, snare, hat])

        // Percussion, two thirds of the time: probability-based, and the Chance
        // FX goes on the steps so the hardware keeps surprising you on playback.
        if Int.random(in: 0...2, using: &rng) > 0 {
            let perc = RhythmGenerator.probability(
                steps: length,
                density: Double.random(in: 0.15...0.4, using: &rng),
                note: .pitch(39), instrument: 3,
                velocity: Int.random(in: 60...90, using: &rng),
                chance: [40, 50, 60, 75].randomElement(using: &rng)!,
                name: "Perc",
                using: &rng
            )
            tracks.append(perc)
        }

        // Bass, half the time: the same euclidean idea, with the root moving.
        if Bool.random(using: &rng) {
            let root = [33, 35, 36, 38, 40].randomElement(using: &rng)!
            let bassPulses = Int.random(in: 3...5, using: &rng) * scale
            var bass = RhythmGenerator.euclidean(
                pulses: bassPulses, steps: length,
                rotation: Int.random(in: 0...3, using: &rng),
                note: .pitch(UInt8(root)), instrument: 4,
                velocity: Int.random(in: 85...105, using: &rng),
                name: "Bass"
            )
            // Move some notes off the root so the line has shape.
            let intervals = [0, 0, 0, 7, 12, -5]
            for index in bass.steps.indices where bass.steps[index].isActive {
                let interval = intervals.randomElement(using: &rng)!
                if interval != 0, case .pitch(let pitch) = bass.steps[index].note {
                    let moved = min(max(Int(pitch) + interval, 0), 127)
                    bass.steps[index].note = .pitch(UInt8(moved))
                }
            }
            tracks.append(bass)
        }

        tracks = tracks.map { trimFX($0, to: profile.maxFXPerStep) }

        return PatternGenerator.assemble(
            device: device, name: name, tempo: tempo, steps: length, seed: seed, tracks: tracks
        )
    }

    /// Keeps a step inside the device's FX-lane budget, dropping the least
    /// important effects first (chance and volume carry more than micro-timing).
    private static func trimFX(_ track: Track, to limit: Int) -> Track {
        var result = track
        let priority: [FXType] = [.chance, .volume, .microMove]
        for index in result.steps.indices where result.steps[index].fx.count > limit {
            let fx = result.steps[index].fx
            let ordered = priority.compactMap { type in fx.first(where: { $0.type == type }) }
                + fx.filter { !priority.contains($0.type) }
            result.steps[index].fx = Array(ordered.prefix(limit))
        }
        return result
    }
}
