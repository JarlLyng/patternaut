import Foundation
import Testing
@testable import PatternautCore

@Suite("Model")
struct ModelTests {
    @Test("Note raw values round-trip")
    func noteRawValues() {
        #expect(Note.empty.rawValue == -1)
        #expect(Note.offFade.rawValue == -2)
        #expect(Note.offCut.rawValue == -3)
        #expect(Note.off.rawValue == -4)
        #expect(Note.pitch(60).rawValue == 60)

        #expect(Note(rawValue: -1) == .empty)
        #expect(Note(rawValue: 60) == .pitch(60))
        #expect(Note(rawValue: 128) == nil)
        #expect(Note(rawValue: -5) == nil)
    }

    @Test("Note scientific name uses MIDI 60 = C4")
    func noteName() {
        #expect(Note.pitch(60).scientificName == "C4")
        #expect(Note.pitch(61).scientificName == "C#4")
        #expect(Note.empty.scientificName == nil)
    }

    @Test("Semantic step accessors read and write FX lanes")
    func stepAccessors() {
        var step = Step(note: .pitch(48), instrument: 0)
        step.velocity = 90
        step.probability = 75

        #expect(step.fx.count == 2)
        #expect(step.fxValue(.volume) == 90)
        #expect(step.fxValue(.chance) == 75)

        step.velocity = nil
        #expect(step.fx.count == 1)
        #expect(step.velocity == nil)
    }

    @Test("Instrument kind is derived from index ranges")
    func instrumentKinds() {
        #expect(InstrumentKind(index: 0) == .sample)
        #expect(InstrumentKind(index: 47) == .sample)
        #expect(InstrumentKind(index: 48) == .midi)
        #expect(InstrumentKind(index: 63) == .midi)
        #expect(InstrumentKind(index: 64) == .synth)
        #expect(InstrumentKind(index: 66) == .synth)
        #expect(InstrumentKind(index: 67) == nil)
    }

    @Test("Pattern JSON round-trips exactly")
    func jsonRoundTrip() throws {
        // Integer epoch seconds so ISO-8601 encoding is lossless.
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        var pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "Test", tempo: 128, meter: .sevenEight, stepCount: 16)
        pattern.metadata.createdAt = created
        pattern.metadata.modifiedAt = created
        pattern.metadata.tags = ["jungle", "7/8"]
        pattern.tracks[0].steps[0] = Step(
            id: pattern.tracks[0].steps[0].id,
            note: .pitch(60),
            instrument: 1,
            fx: [FXCommand(type: .chance, value: 80)]
        )

        let data = try pattern.jsonData()
        let decoded = try Pattern.decoded(from: data)
        #expect(decoded == pattern)
    }
}
