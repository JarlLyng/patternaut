import SwiftUI

@main
struct PatternautApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { PatternautDocument() }) { file in
            ContentView(model: file.document.model)
        }
        .commands {
            CommandGroup(after: .importExport) {
                ImportProjectButton()
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
                Divider()
                Link("Patternaut Website", destination: URL(string: "https://patternaut.iamjarl.com")!)
            }
        }
    }
}

/// In the File menu, so importing a Tracker project is as findable as opening a
/// document. The two are easy to confuse, so they are named differently: Open
/// takes a Patternaut document, Import takes a folder off the card.
private struct ImportProjectButton: View {
    @FocusedValue(\.editorModel) private var model

    var body: some View {
        Button("Import Tracker Project…") {
            if let model { ProjectImport.run(into: model) }
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
        .disabled(model == nil)
    }
}

extension Notification.Name {
    /// Posted by the Help menu; the front window shows the sheet.
    static let showKeyboardShortcuts = Notification.Name("PatternautShowKeyboardShortcuts")
}
