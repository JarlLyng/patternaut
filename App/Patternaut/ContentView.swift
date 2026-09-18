import SwiftUI
import PatternautCore
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = EditorModel()
    @FocusState private var gridFocused: Bool
    @State private var showingLog = false

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            HSplitView {
                VStack(spacing: 0) {
                    PatternGridView(model: model)
                        .focusable()
                        .focused($gridFocused)
                        .focusEffectDisabled()
                        .onKeyPress { handle($0) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if showsStatusBar {
                        Divider()
                        issueBar
                    }
                }
                InstrumentsPanel(model: model, onAdd: loadSamples)
                    .frame(minWidth: 240, idealWidth: 260, maxWidth: 380)
            }
        }
        .frame(minWidth: 900, minHeight: 480)
        .onAppear {
            gridFocused = true
            model.startMIDIWatch()
        }
        .sheet(isPresented: $showingLog) {
            DiagnosticsView(diagnostics: model.diagnostics)
        }
    }

    private var showsStatusBar: Bool {
        !model.issues.isEmpty || model.lastExportPath != nil || model.midiStatus != nil
            || model.cursorHint != nil || model.lineage != nil
    }

    /// Length and key: what Generate builds, and what the pattern on screen is
    /// resized to. Kept in one menu so the toolbar stays readable.
    private var generateSettings: some View {
        Menu("\(model.length) steps, \(model.key.displayName)") {
            Picker("Length", selection: Binding(get: { model.length }, set: { model.length = $0 })) {
                ForEach(EditorModel.lengthChoices, id: \.self) { Text("\($0) steps").tag($0) }
            }
            Picker("Key", selection: $model.key.root) {
                ForEach(Array(MusicalKey.noteNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(index)
                }
            }
            Picker("Scale", selection: $model.key.scale) {
                ForEach(Scale.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }
        .fixedSize()
        .help("Pattern length, and the key the pitched parts are generated in. Changing the length resizes the pattern you have now.")
    }

    /// Every effect the device supports, applied to the lane under the cursor.
    private var fxMenu: some View {
        Menu("FX") {
            if model.hasCursorFX {
                Button("Clear lane") { model.clearCursorFX() }
                Divider()
            }
            ForEach(FXKeyMap.menuOrder, id: \.self) { type in
                Button(FXKeyMap.label(for: type)) { model.setCursorFX(type) }
            }
        }
        .fixedSize()
        .disabled(model.editor.cursorFXLane == nil)
        .help("Place an effect on the FX lane under the cursor. Move the cursor to an FX column first.")
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Device", selection: Binding(
                get: { model.device },
                set: { model.changeDevice($0) }
            )) {
                ForEach(DeviceModel.allCases) { Text($0.displayName).tag($0) }
            }
            .fixedSize()

            HStack(spacing: 4) {
                Text("Tempo").fixedSize()
                TextField("", value: $model.tempo, format: .number)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 4) {
                Text("Oct").fixedSize()
                Stepper(value: $model.baseOctave, in: 0...8) { Text("\(model.baseOctave)") }
                    .fixedSize()
            }

            Button("Generate") { model.generate() }
                .help("Make a new beat. Every press is a different one, and Undo brings back what you had.")
            generateSettings
            Menu("Mutate") {
                ForEach(MutationStrength.allCases, id: \.self) { strength in
                    Button(strength.rawValue.capitalized) { model.mutate(strength) }
                }
            }
            .fixedSize()
            fxMenu
            Button("Undo") { model.undo() }.disabled(!model.canUndo).keyboardShortcut("z")
            Button("Redo") { model.redo() }.disabled(!model.canRedo).keyboardShortcut("z", modifiers: [.command, .shift])
            Spacer()
            if !model.midiDestinations.isEmpty {
                Picker("MIDI", selection: $model.selectedDestinationID) {
                    ForEach(model.midiDestinations) { Text($0.name).tag(Optional($0.id)) }
                }
                .labelsHidden()
                .fixedSize()
                HStack(spacing: 4) {
                    Text("Ch").fixedSize()
                    Stepper(value: $model.midiChannel, in: 1...16) { Text("\(model.midiChannel)") }
                        .fixedSize()
                }
                Button("Send \(model.sendTrackName)") { model.sendLive() }
                    .help("Send the track your cursor is on as live MIDI. The Tracker records into its selected track, so send one track at a time.")
            }
            Button("Export…") { exportBundle() }
            Button("Log") { showingLog = true }
        }
        .padding(8)
        .lineLimit(1)
    }

    private var issueBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let lineage = model.lineage {
                Label(lineage, systemImage: "dice")
                    .foregroundStyle(.secondary)
            }
            if let hint = model.cursorHint {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
            if let path = model.lastExportPath {
                Label("Exported to \(path)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            if let status = model.midiStatus {
                Label(status, systemImage: "pianokeys")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(model.issues.enumerated()), id: \.offset) { _, issue in
                Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                    .foregroundStyle(issue.severity == .error ? .red : .orange)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    // MARK: Key handling

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow: model.editor.moveUp(); return .handled
        case .downArrow: model.editor.moveDown(); return .handled
        case .leftArrow: model.editor.moveLeft(); return .handled
        case .rightArrow: model.editor.moveRight(); return .handled
        case .deleteForward, .delete:
            // In an FX column, delete clears just that lane, not the whole step.
            if model.editor.cursorFXLane != nil { model.clearCursorFX() } else { model.editor.clearStep() }
            return .handled
        default: break
        }

        if let ch = press.characters.first {
            let onFX = model.editor.cursorFXLane != nil
            switch ch {
            case "+", "=": if model.nudge(by: 1) { return .handled }
            case "-", "_": if model.nudge(by: -1) { return .handled }
            case "]": if model.nudge(by: onFX ? 10 : 12) { return .handled }
            case "[": if model.nudge(by: onFX ? -10 : -12) { return .handled }
            default:
                if model.handleKey(ch, shift: press.modifiers.contains(.shift)) { return .handled }
            }
        }
        return .ignored
    }

    // MARK: Export

    private func exportBundle() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Export Here"
        panel.message = "Choose a folder (e.g. your SD card's Projects directory)"
        if panel.runModal() == .OK, let url = panel.url {
            model.export(to: url)
        }
    }

    private func loadSamples() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.wav]
        panel.prompt = "Load"
        panel.message = "Choose WAV samples. 24-bit and other sample rates are converted for you."
        if panel.runModal() == .OK {
            for url in panel.urls { model.loadSample(from: url) }
        }
    }
}
