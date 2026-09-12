import Testing
@testable import PatternautCore

@Suite("Beat generator")
struct BeatGeneratorTests {
    /// Musical content of a pattern, ignoring the per-step identity (`Step.id`
    /// is a fresh UUID every time, so raw equality says nothing here).
    func signature(_ pattern: Pattern) -> String {
        pattern.tracks.map { track in
            "\(track.name):\(track.length):" + track.steps.map { step in
                "\(step.note)|\(step.instrument.map(String.init) ?? "-")|" +
                step.fx.map { "\($0.type.rawValue)=\($0.value)" }.joined(separator: ",")
            }.joined(separator: ";")
        }.joined(separator: "\n")
    }

    @Test("The same seed always gives the same beat")
    func deterministic() {
        let a = BeatGenerator.beat(device: .trackerPlus, seed: 4242)
        let b = BeatGenerator.beat(device: .trackerPlus, seed: 4242)
        #expect(signature(a) == signature(b))
        #expect(a.metadata.seed == 4242)
    }

    @Test("Different seeds give genuinely different beats")
    func variety() {
        // The point of the feature is surprise, so near-duplicates are a bug.
        let beats = (1...40).map { BeatGenerator.beat(device: .trackerPlus, seed: UInt64($0)) }
        #expect(Set(beats.map(signature)).count == beats.count)

        // The optional parts should actually vary across seeds, not always appear.
        let filledTrackCounts = Set(beats.map { pattern in
            pattern.tracks.filter { track in track.steps.contains { $0.isActive } }.count
        })
        #expect(filledTrackCounts.count > 1)
    }

    @Test("Every generated beat is exportable on both devices")
    func exportable() {
        for device in DeviceModel.allCases {
            for seed in UInt64(1)...30 {
                let pattern = BeatGenerator.beat(device: device, seed: seed)
                let issues = device.profile.validate(pattern)
                #expect(issues.filter { $0.severity == .error }.isEmpty,
                        "seed \(seed) on \(device): \(issues.map(\.message))")
                #expect(pattern.tracks.count == device.profile.trackCount)
            }
        }
    }

    @Test("No step exceeds the device's two FX lanes")
    func fxBudget() {
        for seed in UInt64(1)...30 {
            let pattern = BeatGenerator.beat(device: .trackerPlus, seed: seed)
            for track in pattern.tracks {
                #expect(track.steps.allSatisfy { $0.fx.count <= TrackerFormat.maxFXPerStep })
            }
        }
    }

    @Test("Beats have notes, and the length is honoured and clamped")
    func shape() {
        let pattern = BeatGenerator.beat(device: .trackerPlus, steps: 32, seed: 7)
        #expect(pattern.tracks.allSatisfy { $0.length == 32 })
        #expect(pattern.tracks.contains { $0.steps.contains { $0.isActive } })

        let clamped = BeatGenerator.beat(device: .trackerPlus, steps: 9999, seed: 7)
        #expect(clamped.tracks[0].length == TrackerFormat.maxSteps)
    }

    /// The hits a device would actually play: position, note, instrument and FX
    /// of the active steps inside each track's length. Names, padding beyond the
    /// track length and the `nil`-instrument-to-0 asymmetry are all file-format
    /// facts, not musical ones, so they stay out of the comparison.
    func hits(_ pattern: Pattern) -> [String] {
        pattern.tracks.enumerated().flatMap { trackIndex, track in
            track.steps.prefix(track.length).enumerated().compactMap { row, step -> String? in
                guard step.isActive else { return nil }
                let fx = step.fx.filter { $0.type != .none }
                    .map { "\($0.type.rawValue)=\($0.value)" }.joined(separator: ",")
                return "\(trackIndex).\(row):\(step.note)|\(step.instrument ?? 0)|\(fx)"
            }
        }
    }

    @Test("A generated beat survives the round trip to disk")
    func roundTrip() throws {
        let pattern = BeatGenerator.beat(device: .trackerPlus, seed: 99)
        let document = try MTPImporter.parse(MTPExporter.export(pattern))
        let reloaded = document.makePattern(device: .trackerPlus, name: pattern.metadata.name)
        #expect(reloaded.tracks.map(\.length) == pattern.tracks.map(\.length))
        #expect(!hits(pattern).isEmpty)
        #expect(hits(reloaded) == hits(pattern))
    }
}
