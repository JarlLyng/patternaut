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
