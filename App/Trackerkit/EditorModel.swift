import Foundation
import Observation
import PatternsmithCore

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

    /// Validates and writes a project bundle to `directory`.
    func export(to directory: URL) {
        issues = device.profile.validate(pattern)
        guard device.profile.isExportable(pattern) else { return }
        do {
            let result = try ProjectBundleWriter.write(
                patterns: [pattern], projectName: pattern.metadata.name, device: device,
                tempo: Float(tempo), to: directory
            )
            lastExportPath = result.projectDirectory.path
        } catch {
            issues = [ValidationIssue(severity: .error, message: "Export failed: \(error.localizedDescription)")]
        }
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
