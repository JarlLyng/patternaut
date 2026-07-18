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
        } catch let error as WavFile.WavError {
            sampleError = "\(url.lastPathComponent): not a supported WAV (\(error)). Use 16-bit PCM."
        } catch {
            sampleError = "Couldn't load \(url.lastPathComponent)."
        }
    }

    func removeInstrument(_ id: LoadedInstrument.ID) {
        instruments.removeAll { $0.id == id }
    }

    /// Validates and writes a project bundle (patterns + loaded instruments) to
    /// `directory`.
    func export(to directory: URL) {
        issues = device.profile.validate(pattern)
        guard device.profile.isExportable(pattern) else { return }
        do {
            let result = try ProjectBundleWriter.write(
                patterns: [pattern], projectName: pattern.metadata.name, device: device,
                tempo: Float(tempo), instruments: namedInstruments(), to: directory
            )
            lastExportPath = result.projectDirectory.path
        } catch {
            issues = [ValidationIssue(severity: .error, message: "Export failed: \(error.localizedDescription)")]
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
