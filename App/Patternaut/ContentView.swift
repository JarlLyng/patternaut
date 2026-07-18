import SwiftUI
import PatternautCore
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = EditorModel()
    @FocusState private var gridFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            PatternGridView(model: model)
                .focusable()
                .focused($gridFocused)
                .focusEffectDisabled()
                .onKeyPress { handle($0) }
            if !model.issues.isEmpty {
                Divider()
                issueBar
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .onAppear { gridFocused = true }
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
                Text("Tempo")
                TextField("", value: $model.tempo, format: .number)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 4) {
                Text("Oct")
                Stepper(value: $model.baseOctave, in: 0...8) { Text("\(model.baseOctave)") }
                    .fixedSize()
            }

            Button("Generate") { model.generateStarter() }
            Button("Undo") { model.undo() }.disabled(!model.canUndo).keyboardShortcut("z")
            Button("Redo") { model.redo() }.disabled(!model.canRedo).keyboardShortcut("z", modifiers: [.command, .shift])
            Spacer()
            Button("Export…") { exportBundle() }
        }
        .padding(8)
    }

    private var issueBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let path = model.lastExportPath {
                Label("Exported to \(path)", systemImage: "checkmark.circle")
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
        case .deleteForward, .delete: model.editor.clearStep(); return .handled
        default: break
        }

        if let ch = press.characters.first {
            switch ch {
            case "+", "=": model.editor.transpose(by: 1); return .handled
            case "-", "_": model.editor.transpose(by: -1); return .handled
            case "]": model.editor.transpose(by: 12); return .handled
            case "[": model.editor.transpose(by: -12); return .handled
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
}
