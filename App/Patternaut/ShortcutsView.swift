import SwiftUI
import PatternautCore

/// What the keyboard does. The editor is keyboard-first, and none of it is
/// visible otherwise, so this is the difference between the grid feeling like a
/// tracker and feeling like a locked door.
struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Shortcut: Identifiable {
        let id = UUID()
        let keys: String
        let what: String
    }

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let note: String?
        let shortcuts: [Shortcut]
    }

    private var sections: [Section] {
        [
            Section(title: "Moving around", note: nil, shortcuts: [
                .init(keys: "↑ ↓", what: "Previous or next step"),
                .init(keys: "← →", what: "Move between columns and tracks"),
                .init(keys: "⌦", what: "Clear the step, or just the effect lane you are in"),
            ]),
            Section(title: "Notes", note: "The two keyboard rows are an octave each, as in any tracker. Oct in the toolbar sets which octave.", shortcuts: [
                .init(keys: "Z S X D C V G B H N J M", what: "Lower octave, C upwards"),
                .init(keys: "Q 2 W 3 E R 5 T 6 Y 7 U", what: "The octave above"),
                .init(keys: "+ −", what: "Transpose the note by a semitone"),
                .init(keys: "[ ]", what: "Transpose by an octave"),
            ]),
            Section(title: "Instrument column", note: "Numbers match the list in the instruments panel.", shortcuts: [
                .init(keys: "0…9", what: "Type an instrument number, two digits for 10 and up"),
                .init(keys: "⌦", what: "Clear the step"),
            ]),
            Section(title: "Effect lanes", note: "Type an effect's own symbol, the one the Tracker shows. The line under the grid names whatever is under the cursor.", shortcuts: [
                .init(keys: "L P s t", what: "Low-pass, panning, delay send, reverb send"),
                .init(keys: "C R V q", what: "Chance, roll, volume, gate length"),
                .init(keys: "0…9", what: "Type the value"),
                .init(keys: "+ −", what: "Nudge the value by one"),
                .init(keys: "[ ]", what: "Nudge by ten"),
                .init(keys: "⌦", what: "Clear this lane"),
            ]),
            Section(title: "Document", note: nil, shortcuts: [
                .init(keys: "⌘Z  ⇧⌘Z", what: "Undo and redo, named in the Edit menu"),
                .init(keys: "⌘S  ⌘O", what: "Save and open a Patternaut document"),
                .init(keys: "⇧⌘I", what: "Import a Tracker project from a card"),
            ]),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard")
                    .font(.title2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                            if let note = section.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 2)
                            }
                            ForEach(section.shortcuts) { shortcut in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(shortcut.keys)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 210, alignment: .leading)
                                    Text(shortcut.what)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    Text("Every effect the device has is in the FX menu, with its symbol, name and range.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
        }
        .frame(width: 560, height: 560)
    }
}
