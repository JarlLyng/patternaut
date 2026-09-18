import SwiftUI
import PatternautCore
import UniformTypeIdentifiers

/// Lets the File menu reach the document in the front window.
struct EditorModelKey: FocusedValueKey {
    typealias Value = EditorModel
}

extension FocusedValues {
    var editorModel: EditorModel? {
        get { self[EditorModelKey.self] }
        set { self[EditorModelKey.self] = newValue }
    }
}

/// Opening a Tracker project folder is separate from opening a Patternaut
/// document, so it gets its own panel and its own wording everywhere.
enum ProjectImport {
    static func run(into model: EditorModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        // A pattern file is a fine thing to point at; the reader works out which
        // project it belongs to.
        panel.canChooseFiles = true
        panel.prompt = "Import"
        panel.message = "Choose a project on your Tracker's card, e.g. Projects/User/my song."
        if let card = mountedCardProjects() { panel.directoryURL = card }
        if panel.runModal() == .OK, let url = panel.url {
            model.importProject(at: url)
        }
    }

    /// The Projects folder of a mounted Tracker card, so the panel opens where
    /// the projects actually are.
    private static func mountedCardProjects() -> URL? {
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil)) ?? []
        for volume in volumes {
            let projects = volume.appendingPathComponent("Projects", isDirectory: true)
            let marker = volume.appendingPathComponent("trackerConfig")
            if FileManager.default.fileExists(atPath: marker.path),
               FileManager.default.fileExists(atPath: projects.path) {
                return projects
            }
        }
        return nil
    }
}

struct ContentView: View {
    @Bindable var model: EditorModel
    @Environment(\.undoManager) private var undoManager
    @FocusState private var gridFocused: Bool
    @State private var showingLog = false
    @State private var showingShortcuts = false
    /// Dismissed once for this window: someone who wants to type their own
    /// pattern should not have to argue with a panel about it.
    @State private var dismissedEmptyState = false

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            patternBar
            Divider()
            HSplitView {
                VStack(spacing: 0) {
                    PatternGridView(model: model)
                        .focusable()
                        .focused($gridFocused)
                        .focusEffectDisabled()
                        .onKeyPress { handle($0) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay { if model.isEmpty && !dismissedEmptyState { emptyState } }
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
        .focusedSceneValue(\.editorModel, model)
        .onAppear {
            gridFocused = true
            model.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, new in model.undoManager = new }
        .sheet(isPresented: $showingLog) {
            DiagnosticsView(diagnostics: model.diagnostics)
        }
        .sheet(isPresented: $showingShortcuts) {
            ShortcutsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showingShortcuts = true
        }
    }

    /// Shown over an untouched grid. The two ways to put something in a
    /// document are not obvious from an empty tracker grid, and one of them is
    /// easily confused with File > Open.
    private var emptyState: some View {
        VStack(spacing: Design.Space.lg) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Start blank and write the pattern yourself")
            }
            Text("Nothing here yet")
                .font(.title2)
            Text("Make a beat to start from, or bring in patterns you already have on your Tracker's SD card.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack(spacing: 10) {
                Button("Generate a Beat") { model.generate() }
                    .buttonStyle(.borderedProminent)
                Button("Import from Tracker…") { ProjectImport.run(into: model) }
                Button("Start Blank") { dismiss() }
            }
            Text("Import takes a project folder from the card, the one containing project.mt.\nFile > Open is for documents you saved here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Design.Space.xl)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.md))
        .padding()
    }

    /// Puts the panel away and hands the keyboard back to the grid.
    private func dismiss() {
        dismissedEmptyState = true
        gridFocused = true
    }

    /// The patterns in this document, and the one being edited. A Tracker
    /// project holds many; this is how you move between them.
    private var patternBar: some View {
        HStack(spacing: 8) {
            Picker("Pattern", selection: $model.currentPatternIndex) {
                ForEach(Array(model.patterns.enumerated()), id: \.offset) { index, pattern in
                    Text(String(format: "%02d  %@", index + 1, pattern.metadata.name)).tag(index)
                }
            }
            .labelsHidden()
            .fixedSize()

            TextField("Pattern name", text: $model.patternName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .help("Shown in the Tracker's pattern list.")

            Button {
                model.addPattern()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add an empty pattern after this one")

            Button {
                model.duplicatePattern()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .help("Duplicate this pattern, e.g. to mutate the copy")

            Button {
                model.removeCurrentPattern()
            } label: {
                Image(systemName: "minus")
            }
            .disabled(model.patternCount < 2)
            .help("Remove this pattern")

            Text(model.patternCount == 1 ? "1 pattern" : "\(model.patternCount) patterns")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Patterns are exported in this order and played in that order on the device")

            Divider().frame(height: 18)

            Button("Generate") { model.generate() }
                .help("Make a new beat in this pattern. Every press is a different one, and Undo brings back what you had.")
            generateSettings
            Menu("Mutate") {
                ForEach(MutationStrength.allCases, id: \.self) { strength in
                    Button(strength.rawValue.capitalized) { model.mutate(strength) }
                }
            }
            .fixedSize()
            .help("Vary this pattern, gently or not")
            fxMenu

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .lineLimit(1)
    }

    private var showsStatusBar: Bool {
        !model.issues.isEmpty || model.lastExportPath != nil || model.importStatus != nil
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

    /// The project: what is being made and for which machine. These settings
    /// belong to the whole document, so they sit apart from the per-pattern row
    /// below and from the buttons that move work to and from the card.
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
                Text("Project").fixedSize()
                TextField("Name", text: $model.projectName)
                    .frame(width: 130)
                    .textFieldStyle(.roundedBorder)
                    .help("The folder written to the card, and the name the Tracker shows.")
            }

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
                    .help("Which octave the note keys play in")
            }

            Spacer()

            Button("Import…") { ProjectImport.run(into: model) }
                .help("Import a Tracker project folder from an SD card. Its patterns replace what is in this document. This is not the same as File > Open, which opens Patternaut's own documents.")
            Button("Export…") { exportBundle() }
                .help("Write this document to a card as a Tracker project")
            Button("Log") { showingLog = true }
                .help("What the app has been doing, ready to copy")
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
            if let status = model.importStatus {
                Label(status, systemImage: "square.and.arrow.down")
                    .foregroundStyle(.secondary)
            }
            if let path = model.lastExportPath {
                Label("Exported to \(path)\(model.exportNote.map { " (\($0))" } ?? "")",
                      systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
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
            if model.editor.cursorFXLane != nil {
                model.clearCursorFX()
            } else {
                model.edit("Clear Step") { model.editor.clearStep() }
            }
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

    /// Asks before writing into a project that is already there. Overwriting a
    /// project on a card is not something to do silently.
    private func confirmOverwrite(of url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        let alert = NSAlert()
        alert.messageText = "\"\(url.lastPathComponent)\" already exists"
        alert.informativeText = "Its patterns will be replaced by this document's "
            + "\(model.patternCount), and pattern files left over from a longer version will be "
            + "removed.\n\nThe project's own instruments, mixer, delay and reverb are kept."
        alert.addButton(withTitle: "Replace Patterns")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func exportBundle() {
        // A save panel rather than a folder picker, so the project gets its name
        // here: the name becomes the folder on the card and what the Tracker shows.
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldLabel = "Project:"
        panel.nameFieldStringValue = model.exportProjectName
        panel.prompt = "Export"
        panel.message = "Name the project and choose where to put it, e.g. your SD card's Projects/User folder."
        if panel.runModal() == .OK, let url = panel.url, confirmOverwrite(of: url) {
            model.export(to: url.deletingLastPathComponent(), named: url.lastPathComponent)
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
