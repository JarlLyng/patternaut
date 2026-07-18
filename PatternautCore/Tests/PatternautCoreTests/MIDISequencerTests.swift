import Testing
@testable import PatternautCore

@Suite("MIDI sequencer")
struct MIDISequencerTests {
    /// A one-track pattern with the given steps (length = steps.count).
    func oneTrack(_ steps: [Step], length: Int? = nil) -> Pattern {
        let track = Track(name: "T", length: length ?? steps.count, steps: steps)
        return Pattern(metadata: PatternMetadata(name: "P"), device: .trackerPlus, tracks: [track])
    }

    @Test("Notes become on/off pairs at the right beats")
    func basicTiming() {
        var s0 = Step(note: .pitch(60), instrument: 0); s0.velocity = 100
        let steps = [s0, .empty, .empty, .empty, Step(note: .pitch(62), instrument: 0)]
        let events = MIDISequencer.events(for: oneTrack(steps), stepsPerBeat: 4, gate: 0.5)

        // step 0 → beat 0, step 4 → beat 1.0
        #expect(events.count == 4)
        #expect(events[0] == MIDIEvent(beat: 0, channel: 0, kind: .noteOn(note: 60, velocity: 127)))
        #expect(events[1] == MIDIEvent(beat: 0.125, channel: 0, kind: .noteOff(note: 60))) // gate 0.5 * (1/4)
        #expect(events[2].beat == 1.0)
        #expect(events[2] == MIDIEvent(beat: 1.0, channel: 0, kind: .noteOn(note: 62, velocity: 127)))
    }

    @Test("Velocity maps 0...100 to MIDI 1...127")
    func velocity() {
        var s = Step(note: .pitch(60), instrument: 0); s.velocity = 50
        let events = MIDISequencer.events(for: oneTrack([s]), stepsPerBeat: 4)
        #expect(events.first == MIDIEvent(beat: 0, channel: 0, kind: .noteOn(note: 60, velocity: 64)))
    }

    @Test("A note is cut short by the next note (boundary beats gate)")
    func boundaryClampsGate() {
        // Long gate (2 steps) but a note follows one step later → off at the next note.
        let steps = [Step(note: .pitch(60), instrument: 0), Step(note: .pitch(62), instrument: 0)]
        let events = MIDISequencer.events(for: oneTrack(steps), stepsPerBeat: 4, gate: 2.0)
        // note 60: on@0, off clamped to step 1 (beat 0.25), not 0 + 2*0.25 = 0.5
        let off60 = events.first { $0.kind == .noteOff(note: 60) }
        #expect(off60?.beat == 0.25)
    }

    @Test("An off step releases the sounding note")
    func offStep() {
        let steps = [Step(note: .pitch(60), instrument: 0), .empty, Step(note: .off), .empty]
        let events = MIDISequencer.events(for: oneTrack(steps), stepsPerBeat: 4, gate: 4.0)
        // gate would ring 1 beat, but the off at step 2 (beat 0.5) cuts it.
        let off60 = events.first { $0.kind == .noteOff(note: 60) }
        #expect(off60?.beat == 0.5)
    }

    @Test("At equal beats, note-off is ordered before note-on")
    func orderingAtEqualBeat() {
        // Two adjacent notes: off of the first shares the second's beat.
        let steps = [Step(note: .pitch(60), instrument: 0), Step(note: .pitch(62), instrument: 0)]
        let events = MIDISequencer.events(for: oneTrack(steps), stepsPerBeat: 4, gate: 1.0)
        let atQuarter = events.filter { $0.beat == 0.25 }
        #expect(atQuarter.count == 2)
        #expect(atQuarter[0].isNoteOff) // off(60) before on(62)
        #expect(atQuarter[1] == MIDIEvent(beat: 0.25, channel: 0, kind: .noteOn(note: 62, velocity: 127)))
    }

    @Test("Channel mode: per-track vs fixed")
    func channels() {
        let kick = RhythmGenerator.euclidean(pulses: 1, steps: 4, note: .pitch(36), instrument: 0, name: "K")
        let snare = RhythmGenerator.euclidean(pulses: 1, steps: 4, note: .pitch(38), instrument: 1, name: "S")
        let pattern = Pattern(metadata: PatternMetadata(name: "P"), device: .trackerPlus, tracks: [kick, snare])

        let perTrack = MIDISequencer.events(for: pattern, channelMode: .perTrack)
        #expect(perTrack.contains { $0.channel == 0 } && perTrack.contains { $0.channel == 1 })

        let fixed = MIDISequencer.events(for: pattern, channelMode: .fixed(9))
        #expect(fixed.allSatisfy { $0.channel == 9 })
    }

    @Test("Empty pattern yields no events; bytes are correct")
    func emptyAndBytes() {
        let empty = DeviceProfile.trackerMini.makeEmptyPattern(name: "E", stepCount: 16)
        #expect(MIDISequencer.events(for: empty).isEmpty)

        #expect(MIDIEvent(beat: 0, channel: 2, kind: .noteOn(note: 60, velocity: 100)).bytes == [0x92, 60, 100])
        #expect(MIDIEvent(beat: 0, channel: 2, kind: .noteOff(note: 60)).bytes == [0x82, 60, 0])
    }
}
