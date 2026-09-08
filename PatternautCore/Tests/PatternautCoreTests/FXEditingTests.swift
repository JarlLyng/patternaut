import Testing
@testable import PatternautCore

@Suite("FX editing")
struct FXEditingTests {
    func editor() -> PatternEditor {
        var e = PatternEditor(pattern: DeviceProfile.trackerPlus.makeEmptyPattern(name: "P", stepCount: 16))
        e.setCursor(track: 0, row: 0, column: .fx1)
        return e
    }

    @Test("Symbols map to the effects the device shows, case-sensitively")
    func symbolMap() {
        #expect(FXKeyMap.fx(for: "L") == .lowPass)
        #expect(FXKeyMap.fx(for: "l") == .finetuneLFO)
        #expect(FXKeyMap.fx(for: "P") == .panning)
        #expect(FXKeyMap.fx(for: "-") == nil) // None is not placeable
        #expect(FXKeyMap.fx(for: "x") == .breakPattern) // duplicate symbol, lower index wins
        #expect(FXKeyMap.fx(for: "§") == nil)
        // Every placeable effect is reachable from the menu.
        #expect(FXKeyMap.menuOrder.count == FXType.allCases.count - 1)
        #expect(!FXKeyMap.menuOrder.contains(.none))
    }

    @Test("Cursor lane reflects the column")
    func cursorLane() {
        var e = editor()
        #expect(e.cursorFXLane == 0)
        e.setCursor(track: 0, row: 0, column: .fx2)
        #expect(e.cursorFXLane == 1)
        e.setCursor(track: 0, row: 0, column: .note)
        #expect(e.cursorFXLane == nil)
    }

    @Test("Placing an effect uses its default, and typing sets the value")
    func placeAndType() {
        var e = editor()
        e.setFXType(lane: 0, .lowPass)
        #expect(e.fx(lane: 0)?.type == .lowPass)
        #expect(e.fx(lane: 0)?.value == FXType.lowPass.descriptor.default)

        e.setFXDisplayValue(lane: 0, 40)
        #expect(e.fx(lane: 0)?.value == 40)

        // Out of range clamps rather than writing something the device rejects.
        e.setFXDisplayValue(lane: 0, 500)
        #expect(e.fx(lane: 0)?.value == 100)
    }

    @Test("Scaled effects read and write in the range the device displays")
    func scaledValues() {
        var e = editor()
        e.setFXType(lane: 0, .panning)
        e.setFXDisplayValue(lane: 0, -50)
        #expect(e.fx(lane: 0)?.value == 0)          // stored 0...100
        #expect(e.fx(lane: 0)?.displayValue == -50)

        e.setFXDisplayValue(lane: 0, 0)
        #expect(e.fx(lane: 0)?.value == 50)         // centre
        e.setFXDisplayValue(lane: 0, 50)
        #expect(e.fx(lane: 0)?.value == 100)

        e.setFXType(lane: 0, .tempo)
        e.setFXDisplayValue(lane: 0, 400)
        #expect(e.fx(lane: 0)?.value == 200)        // stored 4...200, shown 8...400
        #expect(e.fx(lane: 0)?.displayValue == 400)

        e.setFXType(lane: 0, .slice)
        e.setFXDisplayValue(lane: 0, 1)
        #expect(e.fx(lane: 0)?.value == 0)          // stored 0...47, shown 1...48
    }

    @Test("Changing type keeps a value that still fits, clamps one that doesn't")
    func typeChangeKeepsValue() {
        var e = editor()
        e.setFXType(lane: 0, .lowPass)
        e.setFXDisplayValue(lane: 0, 90)
        e.setFXType(lane: 0, .highPass)
        #expect(e.fx(lane: 0)?.value == 90)         // both 0...100

        e.setFXType(lane: 0, .roll)                 // 0...47
        #expect(e.fx(lane: 0)?.value == 47)
    }

    @Test("Nudging moves in displayed units and stops at the ends")
    func nudge() {
        var e = editor()
        e.setFXType(lane: 0, .panning)
        e.setFXDisplayValue(lane: 0, 0)
        e.adjustFXValue(lane: 0, by: 5)
        #expect(e.fx(lane: 0)?.displayValue == 5)
        e.adjustFXValue(lane: 0, by: -100)
        #expect(e.fx(lane: 0)?.displayValue == -50)

        // Nothing to nudge on an empty lane.
        e.setFX(lane: 0, nil)
        e.adjustFXValue(lane: 0, by: 5)
        #expect(e.fx(lane: 0) == nil)
    }

    @Test("Lanes stay independent and map to the right slot")
    func laneIndependence() {
        var e = editor()
        e.setFXType(lane: 1, .reverbSend)
        e.setFXDisplayValue(lane: 1, 30)
        #expect(e.fx(lane: 0) == nil)
        #expect(e.fx(lane: 1)?.type == .reverbSend)

        e.setFXType(lane: 0, .delaySend)
        #expect(e.currentStep?.fx.count == 2)
        #expect(e.currentStep?.fx[0].type == .delaySend)
        #expect(e.currentStep?.fx[1].type == .reverbSend)

        // Clearing both lanes empties the step's fx entirely.
        e.setFX(lane: 0, nil)
        e.setFX(lane: 1, nil)
        #expect(e.currentStep?.fx.isEmpty == true)
    }

    @Test("FX edits are undoable")
    func undo() {
        var e = editor()
        e.setFXType(lane: 0, .overdrive)
        e.setFXDisplayValue(lane: 0, 70)
        e.undo()
        #expect(e.fx(lane: 0)?.value == FXType.overdrive.descriptor.default)
        e.undo()
        #expect(e.fx(lane: 0) == nil)
        e.redo()
        #expect(e.fx(lane: 0)?.type == .overdrive)
    }

    @Test("An FX-only step survives the round trip to disk")
    func exportRoundTrip() throws {
        var e = editor()
        e.setFXType(lane: 0, .lowPass)
        e.setFXDisplayValue(lane: 0, 40)
        e.setFXType(lane: 1, .panning)
        e.setFXDisplayValue(lane: 1, -25)
        e.setCursor(track: 0, row: 0, column: .note)
        e.setNote(.pitch(60))

        let data = MTPExporter.export(e.pattern)
        let reloaded = try MTPImporter.parse(data)
        let step = reloaded.tracks[0].steps[0]
        #expect(step.fx.count == 2)
        #expect(step.fx[0] == FXCommand(type: .lowPass, value: 40))
        #expect(step.fx[1].type == .panning)
        #expect(step.fx[1].displayValue == -25)
    }
}
