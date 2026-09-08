import Foundation
import Observation
import PatternautCore

/// Observable shell around ``PatternEditor`` plus app-level context (device,
/// tempo, base octave) and actions (generate, export). All editing logic lives
/// in the tested core; this only bridges it to SwiftUI.
@Observable
final class EditorModel {
    var editor: PatternEditor
    var device: DeviceModel
    var tempo: Double
    /// Base octave for keyboard note entry.
    var baseOctave: Int = 4
    /// Last validation issues from an export attempt.
    var issues: [ValidationIssue] = []
    var lastExportPath: String?

    /// Diagnostics log (unified logging + in-app panel).
    let diagnostics = Diagnostics()

    /// Loaded sample instruments (written as `.pti` on export). Their order is
    /// the sample-instrument slot: index 0 = instrument 0 in the pattern grid.
    var instruments: [LoadedInstrument] = []
    var sampleError: String?

    /// A sample loaded from a WAV, ready to export as a `.pti`.
    struct LoadedInstrument: Identifiable {
        let id = UUID()
        var name: String
        var instrument: Instrument
        var isStereo: Bool { instrument.sample.channels == 2 }
        var frames: Int { instrument.sample.length }
    }

    init(device: DeviceModel = .trackerPlus) {
        self.device = device
        self.tempo = 130
        let pattern = device.profile.makeEmptyPattern(name: "Untitled", tempo: 130, stepCount: 32)
        self.editor = PatternEditor(pattern: pattern)
    }

    var pattern: Pattern { editor.pattern }

    // MARK: - Actions

    func newPattern(steps: Int = 32) {
        editor = PatternEditor(pattern: device.profile.makeEmptyPattern(name: "Untitled", tempo: tempo, stepCount: steps))
    }

    func changeDevice(_ newDevice: DeviceModel) {
        device = newDevice
        newPattern()
    }

    /// Fills the pattern with a simple euclidean starter kit for demoing.
    func generateStarter(seed: UInt64 = 1) {
        let steps = 16
        let kick = RhythmGenerator.euclidean(pulses: 4, steps: steps, note: .pitch(36), instrument: 0, velocity: 110, name: "Kick")
        let snare = RhythmGenerator.euclidean(pulses: 2, steps: steps, rotation: 4, note: .pitch(38), instrument: 1, velocity: 100, name: "Snare")
        let hat = RhythmGenerator.euclidean(pulses: 11, steps: steps, rotation: 1, note: .pitch(42), instrument: 2, velocity: 70, name: "Hat")
        let pattern = PatternGenerator.assemble(
            device: device, name: "Starter", tempo: tempo, steps: steps, seed: seed, tracks: [kick, snare, hat]
        )
        editor = PatternEditor(pattern: pattern)
    }

    var canUndo: Bool { editor.canUndo }
    var canRedo: Bool { editor.canRedo }
    func undo() { editor.undo() }
    func redo() { editor.redo() }

    // MARK: - Live MIDI (Vej A)

    private let midi = MIDIOutput()
    var midiDestinations: [MIDIDestination] = []
    var selectedDestinationID: MIDIDestination.ID?
    var midiStatus: String?
    /// MIDI channel (1...16) the Tracker is listening on for Notes In.
    var midiChannel: Int = 1

    /// Live MIDI sends the track the cursor is on. The Tracker records incoming
    /// MIDI into its currently selected track only, so this is one track at a time.
    var sendTrackIndex: Int { editor.cursor.track }
    var sendTrackName: String {
        let tracks = pattern.tracks
        guard sendTrackIndex >= 0, sendTrackIndex < tracks.count else { return "track" }
        return tracks[sendTrackIndex].name
    }

    func refreshMIDIDestinations() {
        if midi == nil { diagnostics.log("CoreMIDI unavailable (client/port not created).", level: .error, category: "midi") }
        midiDestinations = midi?.destinations() ?? []
        if selectedDestinationID == nil || !midiDestinations.contains(where: { $0.id == selectedDestinationID }) {
            selectedDestinationID = midiDestinations.first?.id
        }
        let names = midiDestinations.isEmpty ? "none" : midiDestinations.map(\.name).joined(separator: ", ")
        diagnostics.log("MIDI destinations: \(names)", category: "midi")
    }

    /// Sends the cursor's track as live MIDI to the selected destination, e.g.
    /// into a Tracker armed with `[Rec]+[Play]`. One track at a time, because the
    /// Tracker records incoming MIDI into its selected track only.
    func sendLive() {
        guard let midi else {
            midiStatus = "MIDI unavailable."
            diagnostics.log("Send aborted: CoreMIDI unavailable.", level: .error, category: "midi")
            return
        }
        guard let id = selectedDestinationID, let dest = midiDestinations.first(where: { $0.id == id }) else {
            midiStatus = "Choose a MIDI destination first."
            diagnostics.log("Send aborted: no destination selected.", level: .warning, category: "midi")
            return
        }
        let channel = UInt8(min(max(midiChannel, 1), 16) - 1)
        let index = sendTrackIndex
        let name = sendTrackName
        let events = MIDISequencer.events(forTrack: index, in: pattern, channel: channel)
        guard !events.isEmpty else {
            midiStatus = "\(name) has no notes to send."
            diagnostics.log("Send skipped: track \(index + 1) \"\(name)\" has no notes.", level: .warning, category: "midi")
            return
        }
        let errors = midi.send(events, tempo: tempo, to: dest.endpoint)
        midiStatus = "Sent \(name), \(events.count) events, on channel \(midiChannel) to \(dest.name)."
        diagnostics.log("Sent track \(index + 1) \"\(name)\", \(events.count) events, channel \(midiChannel), to \"\(dest.name)\" at \(Int(tempo)) BPM\(errors > 0 ? "; \(errors) send errors" : "").",
                        level: errors > 0 ? .error : .info, category: "midi")
    }

    private var mutationCounter: UInt64 = 0

    /// Applies a mutation of the current pattern in place (undoable). Each call
    /// uses a fresh seed so repeated mutations explore different variants.
    func mutate(_ strength: MutationStrength) {
        mutationCounter &+= 1
        let mutated = Mutation.mutate(editor.pattern, strength: strength, seed: mutationCounter)
        editor.replace(with: mutated)
    }

    // MARK: - Samples / instruments

    /// Loads a 16-bit PCM WAV as a sample instrument. Reports a friendly error
    /// on unsupported files instead of throwing.
    func loadSample(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let info = try WavFile.info(data)
            guard info.bitsPerSample == 16 else {
                sampleError = "\(url.lastPathComponent): needs a 16-bit WAV (got \(info.bitsPerSample)-bit)."
                return
            }
            let name = url.deletingPathExtension().lastPathComponent
            let instrument = try Instrument.new(wav: data, filename: String(name.prefix(31)))
            instruments.append(LoadedInstrument(name: name, instrument: instrument))
            sampleError = nil
            diagnostics.log("Loaded sample \"\(name)\" (\(instrument.sample.channels == 2 ? "stereo" : "mono"), \(instrument.sample.length) frames).", category: "samples")
        } catch let error as WavFile.WavError {
            sampleError = "\(url.lastPathComponent): not a supported WAV (\(error)). Use 16-bit PCM."
            diagnostics.log("Sample load failed: \(url.lastPathComponent) — \(error).", level: .error, category: "samples")
        } catch {
            sampleError = "Couldn't load \(url.lastPathComponent)."
            diagnostics.log("Sample load failed: \(url.lastPathComponent) — \(error.localizedDescription)", level: .error, category: "samples")
        }
    }

    func removeInstrument(_ id: LoadedInstrument.ID) {
        instruments.removeAll { $0.id == id }
    }

    /// Validates and writes a project bundle (patterns + loaded instruments) to
    /// `directory`.
    func export(to directory: URL) {
        issues = device.profile.validate(pattern)
        let errorCount = issues.filter { $0.severity == .error }.count
        guard device.profile.isExportable(pattern) else {
            diagnostics.log("Export blocked: \(errorCount) validation error(s).", level: .error, category: "export")
            return
        }
        do {
            let result = try ProjectBundleWriter.write(
                patterns: [pattern], projectName: pattern.metadata.name, device: device,
                tempo: Float(tempo), instruments: namedInstruments(), to: directory
            )
            lastExportPath = result.projectDirectory.path
            diagnostics.log("Exported \"\(pattern.metadata.name)\" (\(instruments.count) instruments) to \(result.projectDirectory.path).", category: "export")
        } catch {
            issues = [ValidationIssue(severity: .error, message: "Export failed: \(error.localizedDescription)")]
            diagnostics.log("Export failed: \(error.localizedDescription)", level: .error, category: "export")
        }
    }

    /// Maps loaded instruments to unique, filesystem-safe `.pti` names.
    private func namedInstruments() -> [ProjectBundleWriter.NamedInstrument] {
        var used = Set<String>()
        return instruments.map { loaded in
            let base = sanitizedFileName(loaded.name)
            var name = base
            var suffix = 1
            while used.contains(name) { name = "\(base)-\(suffix)"; suffix += 1 }
            used.insert(name)
            return ProjectBundleWriter.NamedInstrument(name: name, instrument: loaded.instrument)
        }
    }

    private func sanitizedFileName(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "instrument" : String(cleaned.prefix(40))
    }

    // MARK: - Key handling

    /// Applies a key to the editor. Returns `true` if handled.
    func handleKey(_ character: Character, shift: Bool) -> Bool {
        switch editor.cursor.column {
        case .note:
            if let note = NoteKeyMap.note(for: character, baseOctave: baseOctave) {
                editor.setNote(note)
                editor.moveDown()
                return true
            }
        case .instrument:
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                editor.setInstrument(digit)
                return true
            }
        case .fx1, .fx2:
            break
        }
        return false
    }
}
