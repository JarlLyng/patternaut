import SwiftUI

@main
struct PatternautApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // macOS shows document apps an open panel at launch. The Info.plist key
        // for that is read as a user default, not from the bundle, so it has to
        // be set here to have any effect.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

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

/// Makes sure launching lands in a blank document rather than a file picker,
/// whatever the system default happens to be.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A document asked for at launch (double-clicked, or passed on the
        // command line) is opened after this runs, so checking immediately would
        // add an empty window beside it. Look again once that has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard NSDocumentController.shared.documents.isEmpty else { return }
            NSDocumentController.shared.newDocument(nil)
        }
    }
}
