import Foundation
import Testing
@testable import PatternautCore

/// Pattern files saved on Tracker CE firmware (format version 6), where each
/// step carries a Volume and a Micro-move byte after its effects.
@Suite("Tracker CE pattern import")
struct TrackerCEImportTests {
    /// A step's extra version 6 bytes; `-1` is empty, as on the device.
    struct Extra {
        var volume: Int8 = -1
        var microMove: Int8 = -1
    }

    /// Turns a version 5 file into the version 6 file CE would save: the same
    /// steps with two bytes after each, version 6 in the header, and the new size.
    static func version6(from v5: Data, extras: [Int: [Int: Extra]] = [:]) -> Data {
        let bytes = [UInt8](v5)
        let base = 28, stepsPerTrack = 128, oldStep = 6
        let trackCount = (bytes.count - base - 4) / (1 + stepsPerTrack * oldStep)
        var out = Array(bytes[0..<base])
        var cursor = base
        for track in 0..<trackCount {
            out.append(bytes[cursor]); cursor += 1
            for step in 0..<stepsPerTrack {
                out.append(contentsOf: bytes[cursor..<cursor + oldStep]); cursor += oldStep
                let extra = extras[track]?[step] ?? Extra()
                out.append(UInt8(bitPattern: extra.volume))
                out.append(UInt8(bitPattern: extra.microMove))
            }
        }
        out.append(contentsOf: bytes[cursor..<cursor + 4])
        for i in 8..<12 { out[i] = 6 }
        let size = UInt16(out.count)
        out[12] = UInt8(size & 0xFF); out[13] = UInt8(size >> 8)
        return Data(out)
    }

    func pattern(tracks: Int) -> Pattern {
        let beat = BeatGenerator.beat(device: .trackerPlus, name: "CE", steps: 16, seed: 21)
        return Pattern(metadata: beat.metadata, device: .trackerPlus, tracks: Array(beat.tracks.prefix(tracks)))
    }

    @Test("Version 6 files of each track count have the sizes CE expects")
    func sizes() throws {
        // k8/k12/k16TracksPatternSize in tracker-ce core/include/patternFileValidation.h.
        for (tracks, size) in [(8, 8232), (12, 12332), (16, 16432)] {
            let data = Self.version6(from: MTPExporter.export(pattern(tracks: tracks)))
            #expect(data.count == size)
            let document = try MTPImporter.parse(data)
            #expect(document.tracks.count == tracks)
            #expect(document.layoutVersion == 6)
        }
    }

    @Test("A version 6 file without step values reads the same as its version 5 original")
    func sameContent() throws {
        let v5 = MTPExporter.export(pattern(tracks: 16))
        let old = try MTPImporter.parse(v5)
        let new = try MTPImporter.parse(Self.version6(from: v5))
        #expect(new.droppedStepValues == 0)
        for (a, b) in zip(old.tracks, new.tracks) {
            #expect(a.length == b.length)
            #expect(a.steps.map(\.note) == b.steps.map(\.note))
            #expect(a.steps.map(\.instrument) == b.steps.map(\.instrument))
            #expect(a.steps.map(\.fx) == b.steps.map(\.fx))
        }
    }

    @Test("Step Volume and Micro-move go into free effect lanes")
    func placesValues() throws {
        var source = DeviceProfile.trackerPlus.makeEmptyPattern(name: "P", stepCount: 16)
        source.tracks[0].steps[0] = Step(note: .pitch(60), instrument: 0)
        source.tracks[0].steps[1] = Step(note: .pitch(60), instrument: 0,
                                         fx: [FXCommand(type: .chance, value: 50)])
        source.tracks[0].steps[2] = Step(note: .pitch(60), instrument: 0,
                                         fx: [FXCommand(type: .volume, value: 20)])
        source.tracks[0].steps[3] = Step(note: .pitch(60), instrument: 0,
                                         fx: [FXCommand(type: .chance, value: 50), FXCommand(type: .roll, value: 2)])
        let extras: [Int: [Int: Extra]] = [0: [
            0: Extra(volume: 80, microMove: 25),   // both lanes free
            1: Extra(volume: 80, microMove: 25),   // one lane free: Volume fits, Micro-move does not
            2: Extra(volume: 80),                  // a Volume effect overrides it on the device
            3: Extra(microMove: 10),               // no lane free
        ]]
        let document = try MTPImporter.parse(Self.version6(from: MTPExporter.export(source), extras: extras))
        let steps = document.tracks[0].steps

        #expect(steps[0].fx.contains(FXCommand(type: .volume, value: 80)))
        #expect(steps[0].fx.contains(FXCommand(type: .microMove, value: 25)))

        #expect(steps[1].fx.contains(FXCommand(type: .chance, value: 50)))
        #expect(steps[1].fx.contains(FXCommand(type: .volume, value: 80)))
        #expect(!steps[1].fx.contains { $0.type == .microMove })

        #expect(steps[2].fx.filter { $0.type == .volume } == [FXCommand(type: .volume, value: 20)])

        #expect(!steps[3].fx.contains { $0.type == .microMove })

        // Step 1's Micro-move and step 3's.
        #expect(document.droppedStepValues == 2)
    }

    @Test("A version 6 file is written back as version 5")
    func writesVersion5() throws {
        var source = DeviceProfile.trackerPlus.makeEmptyPattern(name: "P", stepCount: 16)
        source.tracks[0].steps[0] = Step(note: .pitch(60), instrument: 0)
        let v6 = Self.version6(from: MTPExporter.export(source), extras: [0: [0: Extra(volume: 64)]])
        let written = try MTPImporter.parse(v6).data()

        #expect(written.count == 12336)
        let again = try MTPImporter.parse(written)
        #expect(again.layoutVersion == 5)
        #expect(again.options.fileStructureVersion == [5, 5, 5, 5])
        #expect(again.options.size == 12336)
        #expect(again.tracks[0].steps[0].fx.contains(FXCommand(type: .volume, value: 64)))
    }

    @Test("Importing a project saved on CE reads it and reports values with no room")
    func projectImport() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patternaut-ce-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var source = DeviceProfile.trackerPlus.makeEmptyPattern(name: "CE", stepCount: 16)
        source.tracks[0].steps[0] = Step(note: .pitch(60), instrument: 0,
                                         fx: [FXCommand(type: .chance, value: 50), FXCommand(type: .roll, value: 2)])
        let written = try ProjectBundleWriter.write(patterns: [source], projectName: "Saved On CE",
                                                    device: .trackerPlus, tempo: 120, to: root)
        let file = written.patternFiles[0]
        try Self.version6(from: Data(contentsOf: file), extras: [0: [0: Extra(volume: 90)]]).write(to: file)

        let result = try ProjectBundleReader.read(at: root.appendingPathComponent("Saved On CE"))
        #expect(result.patterns.count == 1)
        #expect(result.patterns[0].tracks[0].steps[0].note == .pitch(60))
        #expect(result.warnings.contains { $0.contains("Tracker CE") && $0.contains("1 step") })
    }
}
