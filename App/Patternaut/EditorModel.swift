import Foundation
import Observation
import PatternautCore

/// Observable shell around ``PatternEditor`` plus app-level context (device,
/// tempo, base octave) and actions (generate, export). All editing logic lives
/// in the tested core; this only bridges it to SwiftUI.
/// - Note: `@unchecked Sendable` because `UndoManager` requires it of a target.
///   Every member is touched from the UI only, on the main thread.
@Observable
final class EditorModel: @unchecked Sendable {
    /// One editor per pattern, each with its own undo history, so switching
    /// patterns does not throw away what you did in the last one.
    var editors: [PatternEditor]
    /// Which pattern is on screen.
    var currentPatternIndex: Int = 0
    var device: DeviceModel
    /// The window's undo manager. Editing registers with it so ⌘Z works from the
    /// Edit menu and, just as importantly, so the document knows it has changed
    /// and will be saved.
    var undoManager: UndoManager?
    var tempo: Double { didSet { registerValueUndo(oldValue, "Change Tempo") { $0.tempo = $1 } } }
    /// Base octave for keyboard note entry.
    var baseOctave: Int = 4 { didSet { registerValueUndo(oldValue, "Change Octave") { $0.baseOctave = $1 } } }
    /// Root and scale used for the pitched parts of generated patterns.
    var key = MusicalKey() { didSet { registerValueUndo(oldValue, "Change Key") { $0.key = $1 } } }
    /// Name of the exported project: the folder on the card and the name the
    /// Tracker shows in its project browser.
    var projectName: String = "Patternaut" { didSet { registerValueUndo(oldValue, "Rename Project") { $0.projectName = $1 } } }

    /// Last validation issues from an export attempt.
    var issues: [ValidationIssue] = []
    var lastExportPath: String?
    /// What the export did beyond writing files, when that is worth knowing.
    var exportNote: String?

    /// Diagnostics log (unified logging + in-app panel).
    let diagnostics = Diagnostics()

    /// Loaded sample instruments (written as `.pti` on export). Their order is
    /// the sample-instrument slot: index 0 = instrument 0 in the pattern grid.
    var instruments: [LoadedInstrument] = [] { didSet { registerValueUndo(oldValue, "Change Instruments") { $0.instruments = $1 } } }
    var sampleError: String?

    /// A sample loaded from a WAV, ready to export as a `.pti`.
    struct LoadedInstrument: Identifiable, Sendable {
        let id = UUID()
        var name: String
        var instrument: Instrument
        /// The converted audio, kept so the document can be saved and reopened.
        var wav: Data
        var isStereo: Bool { instrument.sample.channels == 2 }
        var frames: Int { instrument.sample.length }
    }

    init(device: DeviceModel = .trackerPlus) {
        self.device = device
        self.tempo = 130
        let pattern = device.profile.makeEmptyPattern(name: "Pattern 1", tempo: 130, stepCount: 32)
        self.editors = [PatternEditor(pattern: pattern)]
    }

    /// The editor for the pattern on screen.
    var editor: PatternEditor {
        get { editors[min(max(currentPatternIndex, 0), editors.count - 1)] }
        set { editors[min(max(currentPatternIndex, 0), editors.count - 1)] = newValue }
    }

    /// True for a document nothing has been put into yet: one pattern, no notes.
    var isEmpty: Bool {
        editors.count == 1 && !editors[0].pattern.tracks.contains { track in
            track.steps.contains { $0.isActive }
        }
    }

    /// Every pattern in the document, in playlist order.
    var patterns: [Pattern] { editors.map(\.pattern) }
    var patternCount: Int { editors.count }

    /// Adds a pattern after the current one and switches to it.
    func addPattern() {
        let pattern = device.profile.makeEmptyPattern(
            name: "Pattern \(editors.count + 1)", tempo: tempo, stepCount: editor.rowCount
        )
        let index = currentPatternIndex + 1
        editors.insert(PatternEditor(pattern: pattern), at: index)
        currentPatternIndex = index
        diagnostics.log("Added pattern \(index + 1) of \(editors.count).", category: "app")
    }

    /// Duplicates the current pattern, which is how most variations start.
    func duplicatePattern() {
        var copy = editor.pattern
        copy.id = UUID()
        copy.metadata.name = "\(editor.pattern.metadata.name) copy"
        let index = currentPatternIndex + 1
        editors.insert(PatternEditor(pattern: copy), at: index)
        currentPatternIndex = index
        diagnostics.log("Duplicated pattern into slot \(index + 1).", category: "app")
    }

    /// Removes the current pattern. A document always keeps at least one.
    func removeCurrentPattern() {
        guard editors.count > 1 else { return }
        let removed = editor.pattern.metadata.name
        editors.remove(at: currentPatternIndex)
        currentPatternIndex = min(currentPatternIndex, editors.count - 1)
        diagnostics.log("Removed pattern \"\(removed)\"; \(editors.count) left.", category: "app")
    }

    /// The current pattern's name, which is what the device shows in its
    /// pattern list (stored in `patternsMetadata`).
    var patternName: String {
        get { editor.pattern.metadata.name }
        set { edit("Rename Pattern") { editor.renamePattern(newValue) } }
    }

    #if DEBUG
    /// Puts the app into a fixed state for App Store captures, driven by launch
    /// arguments so a screenshot is repeatable rather than a matter of clicking
    /// in the right order. See the hub's DESIGN.md. Debug builds only.
    func applyScreenshotArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-screenshots") else { return }
        guard let index = arguments.firstIndex(of: "-cursor"), index + 1 < arguments.count else { return }
        // "track,row,column" with column one of note/instrument/fx1/fx2.
        let parts = arguments[index + 1].split(separator: ",")
        guard parts.count == 3, let track = Int(parts[0]), let row = Int(parts[1]) else { return }
        let column: PatternEditor.Column
        switch parts[2] {
        case "instrument": column = .instrument
        case "fx1": column = .fx1
        case "fx2": column = .fx2
        default: column = .note
        }
        editor.setCursor(track: track, row: row, column: column)
    }
    #endif

    /// Restores a saved document.
    convenience init(file: ProjectFile) {
        self.init(device: file.device)
        tempo = file.tempo
        baseOctave = file.baseOctave
        key = file.key
        projectName = file.projectName
        if !file.patterns.isEmpty {
            editors = file.patterns.map { PatternEditor(pattern: $0) }
            currentPatternIndex = 0
        }
        for sample in file.instruments {
            guard let instrument = try? Instrument.new(wav: sample.wav, filename: String(sample.name.prefix(31))) else {
                diagnostics.log("Could not restore sample \"\(sample.name)\".", level: .error, category: "samples")
                continue
            }
            instruments.append(LoadedInstrument(name: sample.name, instrument: instrument, wav: sample.wav))
        }
        diagnostics.log("Opened \"\(file.projectName)\": \(file.patterns.count) pattern(s), \(instruments.count) instrument(s).", category: "app")
    }

    /// The document as it should be written to disk.
    var projectFile: ProjectFile {
        ProjectFile(
            projectName: projectName,
            device: device,
            tempo: tempo,
            baseOctave: baseOctave,
            key: key,
            patterns: patterns,
            instruments: instruments.map { .init(name: $0.name, wav: $0.wav) }
        )
    }

    var pattern: Pattern { editor.pattern }

    // MARK: - Undo bridging

    /// Runs an edit and tells the undo manager how to take it back. The editor
    /// keeps its own history; this makes the window's Undo drive that history.
    func edit(_ name: String, _ change: () -> Void) {
        change()
        registerEditorUndo(name)
    }

    private func registerEditorUndo(_ name: String) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            model.editor.undo()
            model.registerEditorRedo(name)
        }
        undoManager.setActionName(name)
    }

    private func registerEditorRedo(_ name: String) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            model.editor.redo()
            model.registerEditorUndo(name)
        }
        undoManager.setActionName(name)
    }

    /// Undo for a plain value: put the old one back. Restoring fires the same
    /// `didSet`, which registers the opposite move, so redo works too.
    private func registerValueUndo<Value: Sendable>(_ oldValue: Value, _ name: String,
                                                    _ apply: @escaping @Sendable (EditorModel, Value) -> Void) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in apply(model, oldValue) }
        undoManager.setActionName(name)
    }

    // MARK: - Actions

    func newPattern(steps: Int = 32) {
        editors = [PatternEditor(pattern: device.profile.makeEmptyPattern(name: "Pattern 1", tempo: tempo, stepCount: steps))]
        currentPatternIndex = 0
    }

    func changeDevice(_ newDevice: DeviceModel) {
        device = newDevice
        newPattern()
    }

    /// What the pattern on screen came from: its generator seed, plus how many
    /// mutations have been applied on top. A mutation keeps the original seed,
    /// so this stays truthful after mutating.
    var lineage: String? {
        let metadata = editor.pattern.metadata
        guard let seed = metadata.seed else { return nil }
        let mutations = max(0, metadata.version - 1)
        guard mutations > 0 else { return "Seed \(seed)" }
        return "Seed \(seed), mutated \(mutations == 1 ? "once" : "\(mutations) times")"
    }

    /// Generates a fresh beat. Each press rolls a new seed, so you get something
    /// different every time; the seed is kept with the pattern, so any beat can
    /// be made again. Undoable, so a generate never loses your work.
    func generate(seed: UInt64? = nil) {
        let used = seed ?? UInt64.random(in: 1...UInt64(UInt32.max))
        let pattern = BeatGenerator.beat(
            device: device, name: "Generated", tempo: tempo, steps: length, key: key, seed: used
        )
        edit("Generate") { editor.replace(with: pattern) }
        diagnostics.log("Generated a beat from seed \(used), \(length) steps, \(key.displayName).", category: "app")
    }

    /// Pattern length in steps. Setting it resizes the pattern on screen, in one
    /// undoable step, and is what the next generate uses.
    var length: Int {
        get { max(editor.rowCount, TrackerFormat.minSteps) }
        set {
            guard newValue != editor.rowCount else { return }
            edit("Change Length") { editor.setLength(newValue) }
            diagnostics.log("Pattern length set to \(editor.rowCount) steps.", category: "app")
        }
    }

    /// The step counts offered in the UI. Any length works on the device, these
    /// are just the ones people actually reach for.
    static let lengthChoices = [8, 16, 24, 32, 48, 64, 96, 128]

    /// Renames a track (undoable). Names travel to the device in `project.mt`.
    func renameTrack(_ name: String, at index: Int) {
        edit("Rename Track") { editor.renameTrack(name, at: index) }
    }


    private var mutationCounter: UInt64 = 0

    /// Applies a mutation of the current pattern in place (undoable). Each call
    /// uses a fresh seed so repeated mutations explore different variants.
    func mutate(_ strength: MutationStrength) {
        mutationCounter &+= 1
        let mutated = Mutation.mutate(editor.pattern, strength: strength, seed: mutationCounter)
        edit("Mutate") { editor.replace(with: mutated) }
    }

    // MARK: - Import

    /// Loads a Tracker project folder from an SD card into this document,
    /// replacing what is here. Patterns, their names, the track names and the
    /// tempo all come across; `.pti` audio does not, since the format is
    /// written but not yet read.
    func importProject(at url: URL) {
        do {
            let result = try ProjectBundleReader.read(at: url, device: device)
            let restored = result.patterns.map { PatternEditor(pattern: $0) }
            edit("Import Project") {
                editors = restored
                currentPatternIndex = 0
            }
            projectName = result.projectName
            tempo = result.tempo
            issues = []

            // Instruments arrive in slot order, so index 0 here is instrument 00
            // in the grid, the same as the device.
            instruments = result.instruments.map { imported in
                let audio = imported.instrument.sample
                return LoadedInstrument(
                    name: imported.name,
                    instrument: imported.instrument,
                    wav: WavFile.make(pcm: imported.instrument.pcm, channels: audio.channels)
                )
            }

            let extras = result.warnings.isEmpty ? "" : " " + result.warnings.joined(separator: " ")
            importStatus = "Imported \(result.patterns.count) pattern(s) and \(instruments.count) instrument(s) from \"\(result.projectName)\".\(extras)"
            diagnostics.log("Imported \"\(result.projectName)\": \(result.patterns.count) patterns at \(Int(result.tempo)) BPM, \(instruments.count) instruments.\(extras)", category: "export")
        } catch {
            importStatus = error.localizedDescription
            diagnostics.log("Import failed: \(error.localizedDescription)", level: .error, category: "export")
        }
    }

    /// Last import outcome, shown under the grid.
    var importStatus: String?

    // MARK: - Samples / instruments

    /// Loads a WAV as a sample instrument, converting bit depth and sample rate
    /// to what the Tracker plays. Reports a friendly error instead of throwing.
    func loadSample(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let source = try WavFile.info(data)
            let name = url.deletingPathExtension().lastPathComponent
            let instrument = try Instrument.new(wav: data, filename: String(name.prefix(31)))
            // Keep the converted audio as a canonical WAV so the document can
            // be saved and reopened without the original file.
            let (pcm, audio) = try WavFile.pcm16(data)
            instruments.append(LoadedInstrument(
                name: name, instrument: instrument,
                wav: WavFile.make(pcm: pcm, channels: audio.channels, sampleRate: audio.sampleRate)
            ))
            sampleError = nil

            var changes: [String] = []
            if source.bitsPerSample != 16 || source.isFloat {
                changes.append("\(source.bitsPerSample)-bit\(source.isFloat ? " float" : "") to 16-bit")
            }
            if source.sampleRate != WavFile.trackerSampleRate {
                changes.append("\(source.sampleRate) Hz to \(WavFile.trackerSampleRate) Hz")
            }
            let note = changes.isEmpty ? "" : ", converted \(changes.joined(separator: " and "))"
            diagnostics.log("Loaded sample \"\(name)\" (\(instrument.sample.channels == 2 ? "stereo" : "mono"), \(instrument.sample.length) frames\(note)).", category: "samples")
        } catch let error as WavFile.WavError {
            sampleError = message(for: error, file: url.lastPathComponent)
            diagnostics.log("Sample load failed: \(url.lastPathComponent) — \(error).", level: .error, category: "samples")
        } catch {
            sampleError = "Couldn't load \(url.lastPathComponent)."
            diagnostics.log("Sample load failed: \(url.lastPathComponent) — \(error.localizedDescription)", level: .error, category: "samples")
        }
    }

    private func message(for error: WavFile.WavError, file: String) -> String {
        switch error {
        case .notRIFF: return "\(file): not a WAV file."
        case .noFormatChunk, .noDataChunk: return "\(file): the WAV is missing audio data."
        case .unsupportedFormat(let bits, let isFloat):
            return "\(file): \(bits)-bit\(isFloat ? " float" : "") WAV isn't supported. 16, 24 or 32-bit works."
        }
    }

    func removeInstrument(_ id: LoadedInstrument.ID) {
        instruments.removeAll { $0.id == id }
    }

    /// Validates and writes a project bundle (patterns + loaded instruments) to
    /// `directory`, under `name` if given.
    func export(to directory: URL, named name: String? = nil) {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectName = name
        }
        issues = patterns.flatMap { device.profile.validate($0) }
        let errorCount = issues.filter { $0.severity == .error }.count
        guard patterns.allSatisfy({ device.profile.isExportable($0) }) else {
            diagnostics.log("Export blocked: \(errorCount) validation error(s).", level: .error, category: "export")
            return
        }
        do {
            let result = try ProjectBundleWriter.write(
                patterns: patterns, projectName: exportProjectName, device: device,
                tempo: Float(tempo), instruments: namedInstruments(), to: directory
            )
            lastExportPath = result.projectDirectory.path
            var notes: [String] = []
            if result.keptExistingSettings {
                notes.append("kept the project's own instruments and mixer")
            }
            if !result.removedFiles.isEmpty {
                notes.append("removed \(result.removedFiles.count) leftover pattern file(s)")
            }
            exportNote = notes.isEmpty ? nil : notes.joined(separator: ", ")
            diagnostics.log("Exported \"\(exportProjectName)\" (\(patterns.count) patterns, \(instruments.count) instruments) to \(result.projectDirectory.path). \(exportNote ?? "")", category: "export")
        } catch {
            issues = [ValidationIssue(severity: .error, message: "Export failed: \(error.localizedDescription)")]
            diagnostics.log("Export failed: \(error.localizedDescription)", level: .error, category: "export")
        }
    }

    /// The project name, cleaned up and never empty, as written to the card.
    var exportProjectName: String {
        let cleaned = sanitizedFileName(projectName)
        return cleaned == "instrument" ? "Patternaut" : cleaned
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

    // MARK: - FX entry

    /// Digits typed so far in the FX column, and the cell they belong to. Typing
    /// `4` then `0` means 40, the way a tracker's value field behaves; moving the
    /// cursor starts over.
    private var fxDigits = ""
    private var fxDigitsCell: PatternEditor.Cursor?
    /// The same idea for the instrument column: instruments run past 9, so a
    /// single digit cannot reach them.
    private var instrumentDigits = ""
    private var instrumentDigitsCell: PatternEditor.Cursor?

    /// A one-line description of the cell under the cursor, shown under the grid
    /// so the single-letter FX symbols are never a guessing game.
    var cursorHint: String? {
        guard let lane = editor.cursorFXLane else { return nil }
        let laneName = lane == 0 ? "FX1" : "FX2"
        guard let command = editor.fx(lane: lane) else {
            return "\(laneName): empty. Type an effect symbol (L low-pass, P panning, s delay send…) or pick from the FX menu."
        }
        let d = command.type.descriptor
        let range = command.displayRange
        return "\(laneName): \(d.name) (\(d.symbol)) \(command.displayValue), range \(range.min) to \(range.max). Type digits to set it, + and - to nudge by one, [ and ] by ten."
    }

    /// Places `type` on the lane under the cursor. Used by the FX menu.
    func setCursorFX(_ type: FXType) {
        guard let lane = editor.cursorFXLane else { return }
        resetFXDigits()
        edit("Set Effect") { editor.setFXType(lane: lane, type) }
    }

    /// Clears the lane under the cursor.
    func clearCursorFX() {
        guard let lane = editor.cursorFXLane else { return }
        resetFXDigits()
        edit("Clear Effect") { editor.setFX(lane: lane, nil) }
    }

    /// Nudges the value under the cursor: the FX value in an FX column, the note
    /// elsewhere. Returns `true` if it handled the key.
    func nudge(by delta: Int) -> Bool {
        if let lane = editor.cursorFXLane {
            guard editor.fx(lane: lane) != nil else { return false }
            resetFXDigits()
            edit("Change Effect Value") { editor.adjustFXValue(lane: lane, by: delta) }
            return true
        }
        edit("Transpose") { editor.transpose(by: delta) }
        return true
    }

    /// True when the cursor sits on an FX lane that already holds an effect.
    var hasCursorFX: Bool {
        guard let lane = editor.cursorFXLane else { return false }
        return editor.fx(lane: lane) != nil
    }

    var cursorFXType: FXType? {
        guard let lane = editor.cursorFXLane else { return nil }
        return editor.fx(lane: lane)?.type
    }

    private func resetFXDigits() {
        fxDigits = ""
        fxDigitsCell = nil
    }

    /// Handles a keystroke in an FX column: an effect symbol places that effect,
    /// a digit types into the value.
    private func handleFXKey(_ character: Character, lane: Int) -> Bool {
        if let digit = character.wholeNumberValue, (0...9).contains(digit), character.isASCII {
            guard editor.fx(lane: lane) != nil else { return false }
            if fxDigitsCell != editor.cursor { fxDigits = ""; fxDigitsCell = editor.cursor }
            // Three digits is the widest displayed range (Slide Up/Down, 0...255).
            if fxDigits.count >= 3 { fxDigits = "" }
            fxDigits.append(character)
            if let value = Int(fxDigits) {
                edit("Set Effect Value") { editor.setFXDisplayValue(lane: lane, value) }
            }
            return true
        }
        if let type = FXKeyMap.fx(for: character) {
            resetFXDigits()
            edit("Set Effect") { editor.setFXType(lane: lane, type) }
            return true
        }
        return false
    }

    // MARK: - Key handling

    /// Applies a key to the editor. Returns `true` if handled.
    func handleKey(_ character: Character, shift: Bool) -> Bool {
        switch editor.cursor.column {
        case .note:
            if let note = NoteKeyMap.note(for: character, baseOctave: baseOctave) {
                edit("Set Note") { editor.setNote(note) }
                editor.moveDown()
                return true
            }
        case .instrument:
            if let digit = character.wholeNumberValue, (0...9).contains(digit), character.isASCII {
                if instrumentDigitsCell != editor.cursor {
                    instrumentDigits = ""
                    instrumentDigitsCell = editor.cursor
                }
                // Two digits is enough for every slot: 0-47 samples, 48-63 MIDI,
                // 64-66 synth.
                if instrumentDigits.count >= 2 { instrumentDigits = "" }
                instrumentDigits.append(character)
                let value = min(Int(instrumentDigits) ?? digit, TrackerFormat.instrumentRange.upperBound)
                edit("Set Instrument") { editor.setInstrument(value) }
                return true
            }
        case .fx1:
            return handleFXKey(character, lane: 0)
        case .fx2:
            return handleFXKey(character, lane: 1)
        }
        return false
    }
}
