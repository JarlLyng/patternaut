import SwiftUI
import AppKit

/// A simple log viewer sheet: monospaced entries with Copy/Clear, so a TestFlight
/// tester can capture and share what happened (MIDI sends, exports, errors).
struct DiagnosticsView: View {
    let diagnostics: Diagnostics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Diagnostics Log").font(.headline)
                Spacer()
                Button("Copy") { copyToPasteboard() }
                    .disabled(diagnostics.lines.isEmpty)
                Button("Clear") { diagnostics.clear() }
                    .disabled(diagnostics.lines.isEmpty)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(8)
            Divider()
            ScrollView {
                Text(diagnostics.lines.isEmpty ? "No entries yet." : diagnostics.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(diagnostics.lines.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .frame(width: 580, height: 420)
    }

    private func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.text, forType: .string)
    }
}
