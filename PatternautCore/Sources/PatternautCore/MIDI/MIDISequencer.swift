import Foundation

/// Which MIDI channel each track transmits on.
public enum MIDIChannelMode: Sendable, Equatable {
    /// Track index → channel (clamped to 15). Good for multi-track routing.
    case perTrack
    /// All tracks on one channel — e.g. recording one track at a time into the
    /// Tracker, which captures incoming notes into the selected track.
    case fixed(UInt8)
}

/// Converts a device-neutral ``Pattern`` into an ordered list of timed
/// ``MIDIEvent``s. Pure and deterministic — the substrate for both live MIDI
/// output (Vej A) and any future MIDI-file export.
///
/// Each track is treated monophonically: a note sounds until the next note/off
/// on that track, capped by `gate`.
public enum MIDISequencer {
    /// - Parameters:
    ///   - stepsPerBeat: grid resolution; `4` = 16th-note steps.
    ///   - gate: note length as a fraction of one step (before the next-event cap).
    ///   - defaultVelocity: `0...100` used when a step has no Volume FX.
    ///   - channelMode: see ``MIDIChannelMode``.
    public static func events(
        for pattern: Pattern,
        stepsPerBeat: Double = 4,
        gate: Double = 0.5,
        defaultVelocity: Int = 100,
        channelMode: MIDIChannelMode = .perTrack
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for (trackIndex, track) in pattern.tracks.enumerated() {
            let channel: UInt8
            switch channelMode {
            case .perTrack: channel = UInt8(min(trackIndex, 15))
            case .fixed(let c): channel = c & 0x0F
            }

            let count = min(track.length, track.steps.count)
            let patternEndBeat = Double(track.length) / stepsPerBeat
            let gateBeats = gate / stepsPerBeat

            for i in 0..<count {
                guard case .pitch(let note) = track.steps[i].note else { continue }
                let onBeat = Double(i) / stepsPerBeat
                let velocity = midiVelocity(track.steps[i].velocity ?? defaultVelocity)
                let offBeat = min(onBeat + gateBeats, nextBoundary(in: track, after: i, count: count, stepsPerBeat: stepsPerBeat, patternEndBeat: patternEndBeat))
                events.append(MIDIEvent(beat: onBeat, channel: channel, kind: .noteOn(note: note, velocity: velocity)))
                events.append(MIDIEvent(beat: offBeat, channel: channel, kind: .noteOff(note: note)))
            }
        }

        // Stable order: earlier beats first; at equal beats, note-off before
        // note-on so a boundary release never cancels the note starting there.
        return events.enumerated().sorted { a, b in
            if a.element.beat != b.element.beat { return a.element.beat < b.element.beat }
            if a.element.isNoteOff != b.element.isNoteOff { return a.element.isNoteOff }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Beat of the next note/off step on this track after `i`, or the pattern end.
    private static func nextBoundary(in track: Track, after i: Int, count: Int, stepsPerBeat: Double, patternEndBeat: Double) -> Double {
        var j = i + 1
        while j < count {
            let note = track.steps[j].note
            if case .pitch = note { return Double(j) / stepsPerBeat }
            if note == .off || note == .offCut || note == .offFade { return Double(j) / stepsPerBeat }
            j += 1
        }
        return patternEndBeat
    }

    /// Maps a `0...100` tracker velocity to MIDI `1...127` (never 0, which would
    /// read as a note-off).
    private static func midiVelocity(_ value: Int) -> UInt8 {
        let scaled = Int((Double(value) / 100.0 * 127.0).rounded())
        return UInt8(min(max(scaled, 1), 127))
    }
}
