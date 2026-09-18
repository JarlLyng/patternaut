import SwiftUI

@main
struct PatternautApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { PatternautDocument() }) { file in
            ContentView(model: file.document.model)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Link("Patternaut Website", destination: URL(string: "https://patternaut.iamjarl.com")!)
            }
        }
    }
}
