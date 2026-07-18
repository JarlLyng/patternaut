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
}
