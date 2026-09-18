import Foundation
import Testing
@testable import PatternautCore

@Suite("Pattern editor")
struct PatternEditorTests {
    func makeEditor() -> PatternEditor {
        let pattern = DeviceProfile.trackerPlus.makeEmptyPattern(name: "E", stepCount: 8)
        return PatternEditor(pattern: pattern)
    }

    @Test("Starts at track 0, row 0, note column")
    func initialCursor() {
        let e = makeEditor()
        #expect(e.cursor == PatternEditor.Cursor(track: 0, row: 0, column: .note))
        #expect(e.trackCount == 16)
        #expect(e.rowCount == 8)
    }

    @Test("Horizontal navigation walks fields then tracks and clamps")
    func horizontal() {
        var e = makeEditor()
        e.moveRight() // note → instrument
        #expect(e.cursor.column == .instrument)
        e.moveRight(); e.moveRight() // fx1 → fx2
        #expect(e.cursor.column == .fx2)
        e.moveRight() // wraps to next track, note
        #expect(e.cursor.track == 1)
        #expect(e.cursor.column == .note)
        e.moveLeft() // back to track 0, fx2
        #expect(e.cursor == PatternEditor.Cursor(track: 0, row: 0, column: .fx2))

        // Clamp at the far left.
        e.setCursor(track: 0, row: 0, column: .note)
        e.moveLeft()
        #expect(e.cursor == PatternEditor.Cursor(track: 0, row: 0, column: .note))
    }

    @Test("Vertical navigation clamps to row range")
    func vertical() {
        var e = makeEditor()
        e.moveUp()
        #expect(e.cursor.row == 0)
        for _ in 0..<20 { e.moveDown() }
        #expect(e.cursor.row == 7) // rowCount - 1
    }

    @Test("Editing sets values and records undo/redo")
    func editUndoRedo() {
        var e = makeEditor()
        #expect(e.canUndo == false)

        e.setNote(.pitch(60))
        e.setInstrument(3)
        #expect(e.currentStep?.note == .pitch(60))
        #expect(e.currentStep?.instrument == 3)
        #expect(e.canUndo)

        e.undo() // undoes instrument
        #expect(e.currentStep?.instrument == nil)
        #expect(e.currentStep?.note == .pitch(60))
        #expect(e.canRedo)

        e.redo()
        #expect(e.currentStep?.instrument == 3)
    }

    @Test("Clear resets the step; transpose clamps to 0...127")
    func clearAndTranspose() {
        var e = makeEditor()
        e.setNote(.pitch(120))
        e.transpose(by: 24) // 120 + 24 = 144 → clamp 127
        #expect(e.currentStep?.note == .pitch(127))

        e.transpose(by: -200)
        #expect(e.currentStep?.note == .pitch(0))

        e.clearStep()
        #expect(e.currentStep?.note == .empty)
        #expect(e.currentStep?.instrument == nil)
        #expect(e.currentStep?.fx.isEmpty == true)
    }

    @Test("Setting only FX2 keeps lane position")
    func fxLanePosition() {
        var e = makeEditor()
        e.setFX(lane: 1, FXCommand(type: .roll, value: 2))
        #expect(e.currentStep?.fx.count == 2)
        #expect(e.currentStep?.fx[0].type == FXType.none) // FX1 empty
        #expect(e.currentStep?.fx[1].type == .roll)       // FX2 set

        e.setFX(lane: 1, nil) // clearing both lanes collapses to empty
        #expect(e.currentStep?.fx.isEmpty == true)
    }

    @Test("Replace swaps the whole pattern and is undoable")
    func replacePattern() {
        var e = makeEditor()
        e.setNote(.pitch(60)) // original edit on track 0/row 0
        let replacement = DeviceProfile.trackerPlus.makeEmptyPattern(name: "R", stepCount: 8)

        e.replace(with: replacement)
        #expect(e.currentStep?.note == .empty) // replacement's step 0 is empty
        #expect(e.canUndo)

        e.undo()
        #expect(e.currentStep?.note == .pitch(60)) // back to pre-replace pattern
    }

    @Test("Note key map follows the tracker layout")
    func noteKeyMap() {
        #expect(NoteKeyMap.semitoneOffset(for: "z") == 0)
        #expect(NoteKeyMap.semitoneOffset(for: "s") == 1)
        #expect(NoteKeyMap.semitoneOffset(for: "q") == 12)
        #expect(NoteKeyMap.semitoneOffset(for: "1") == nil)

        // Base octave 4 → C4 = MIDI 60.
        #expect(NoteKeyMap.note(for: "z", baseOctave: 4) == .pitch(60))
        #expect(NoteKeyMap.note(for: "q", baseOctave: 4) == .pitch(72))
    }

    @Test("Renaming a track is undoable and fits the device's name fields")
    func renameTrack() {
        var editor = PatternEditor(pattern: DeviceProfile.trackerPlus.makeEmptyPattern(name: "P", stepCount: 16))
        editor.renameTrack("Kick", at: 0)
        #expect(editor.pattern.tracks[0].name == "Kick")
        editor.undo()
        #expect(editor.pattern.tracks[0].name != "Kick")

        // A sample track gets 21 bytes in project.mt, a MIDI track 8, and one
        // byte of each is left for the terminator.
        editor.renameTrack(String(repeating: "a", count: 40), at: 0)
        #expect(editor.pattern.tracks[0].name.count == 20)
        editor.renameTrack(String(repeating: "b", count: 40), at: 9)
        #expect(editor.pattern.tracks[9].name.count == 7)

        // Out of range does nothing, and renaming to the same name is not an edit.
        editor.renameTrack("X", at: 99)
        let before = editor.canUndo
        editor.renameTrack(editor.pattern.tracks[0].name, at: 0)
        #expect(editor.canUndo == before)
    }

    @Test("A renamed track reaches project.mt")
    func renamedTrackExports() throws {
        var editor = PatternEditor(pattern: DeviceProfile.trackerPlus.makeEmptyPattern(name: "P", stepCount: 16))
        editor.renameTrack("Rimshot", at: 2)
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patternaut-rename-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try ProjectBundleWriter.write(
            patterns: [editor.pattern], projectName: "Named", device: .trackerPlus, to: root
        )
        let project = try MTProjectImporter.parse(Data(contentsOf: result.projectFile))
        #expect(project.trackNames[2] == "Rimshot")
    }
}
