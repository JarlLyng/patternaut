import Foundation

/// The editing brain for the tracker grid: a cursor over a ``Pattern`` plus
/// navigation, per-step edits, and undo/redo. Pure value logic with no UI
/// dependency, so it is unit-tested directly; the SwiftUI layer is a thin shell.
public struct PatternEditor: Sendable {
    /// The four editable fields per step, in left-to-right grid order.
    public enum Column: Int, CaseIterable, Sendable {
        case note, instrument, fx1, fx2
    }

    public struct Cursor: Equatable, Sendable {
        public var track: Int
        public var row: Int
        public var column: Column

        public init(track: Int = 0, row: Int = 0, column: Column = .note) {
            self.track = track
            self.row = row
            self.column = column
        }
    }

    public private(set) var pattern: Pattern
    public private(set) var cursor = Cursor()

    private var undoStack: [Pattern] = []
    private var redoStack: [Pattern] = []
    public let maxUndo: Int

    public init(pattern: Pattern, maxUndo: Int = 200) {
        self.pattern = pattern
        self.maxUndo = maxUndo
    }

    // MARK: - Geometry

    public var trackCount: Int { pattern.tracks.count }
    /// Displayed row count = the longest track.
    public var rowCount: Int { pattern.tracks.map(\.length).max() ?? 0 }

    /// The step under the cursor, or `nil` if the cursor is outside data.
    public var currentStep: Step? {
        guard cursor.track < pattern.tracks.count,
              cursor.row < pattern.tracks[cursor.track].steps.count else { return nil }
        return pattern.tracks[cursor.track].steps[cursor.row]
    }

    // MARK: - Navigation

    private var columnsPerTrack: Int { Column.allCases.count }

    public mutating func moveUp() { cursor.row = max(0, cursor.row - 1) }
    public mutating func moveDown() { cursor.row = min(max(0, rowCount - 1), cursor.row + 1) }

    public mutating func moveLeft() { setLinearColumn(linearColumn - 1) }
    public mutating func moveRight() { setLinearColumn(linearColumn + 1) }

    /// Places the cursor, clamping to valid ranges.
    public mutating func setCursor(track: Int, row: Int, column: Column) {
        cursor.track = min(max(0, track), max(0, trackCount - 1))
        cursor.row = min(max(0, row), max(0, rowCount - 1))
        cursor.column = column
    }

    private var linearColumn: Int { cursor.track * columnsPerTrack + cursor.column.rawValue }

    private mutating func setLinearColumn(_ value: Int) {
        let total = trackCount * columnsPerTrack
        guard total > 0 else { return }
        let clamped = min(max(0, value), total - 1)
        cursor.track = clamped / columnsPerTrack
        cursor.column = Column(rawValue: clamped % columnsPerTrack) ?? .note
    }

    // MARK: - Edits (each records undo)

    public mutating func setNote(_ note: Note) {
        editStep { $0.note = note }
    }

    public mutating func setInstrument(_ instrument: Int?) {
        editStep { $0.instrument = instrument }
    }

    /// Sets or clears effect lane `lane` (0 = FX1, 1 = FX2), preserving slot
    /// position so it maps to the correct on-disk lane.
    public mutating func setFX(lane: Int, _ command: FXCommand?) {
        guard lane == 0 || lane == 1 else { return }
        editStep { step in
            var l0 = step.fx.count > 0 ? step.fx[0] : FXCommand(.none)
            var l1 = step.fx.count > 1 ? step.fx[1] : FXCommand(.none)
            let value = command ?? FXCommand(.none)
            if lane == 0 { l0 = value } else { l1 = value }
            step.fx = (l0.type == .none && l1.type == .none) ? [] : [l0, l1]
        }
    }

    /// The lane the cursor sits on (0 = FX1, 1 = FX2), or `nil` when the cursor
    /// is on the note or instrument column.
    public var cursorFXLane: Int? {
        switch cursor.column {
        case .fx1: return 0
        case .fx2: return 1
        case .note, .instrument: return nil
        }
    }

    /// The effect on lane `lane` of the step under the cursor, or `nil` when the
    /// lane is empty.
    public func fx(lane: Int) -> FXCommand? {
        guard let step = currentStep, step.fx.count > lane else { return nil }
        let command = step.fx[lane]
        return command.type == .none ? nil : command
    }

    /// Places `type` on lane `lane`, keeping the lane's existing value when it
    /// still fits the new effect's range and using the effect's default otherwise.
    public mutating func setFXType(lane: Int, _ type: FXType) {
        guard lane == 0 || lane == 1 else { return }
        guard type != .none else { setFX(lane: lane, nil); return }
        var command = FXCommand(type)
        if let existing = fx(lane: lane) {
            command.value = existing.value
            command.value = command.clampedValue
        }
        setFX(lane: lane, command)
    }

    /// Sets lane `lane`'s value from a number in the *displayed* range, clamped.
    /// Does nothing when the lane holds no effect yet.
    public mutating func setFXDisplayValue(lane: Int, _ displayed: Int) {
        guard var command = fx(lane: lane) else { return }
        command.setDisplayValue(displayed)
        setFX(lane: lane, command)
    }

    /// Nudges lane `lane`'s displayed value by `delta`, clamped. Does nothing
    /// when the lane holds no effect yet.
    public mutating func adjustFXValue(lane: Int, by delta: Int) {
        guard let command = fx(lane: lane) else { return }
        setFXDisplayValue(lane: lane, command.displayValue + delta)
    }

    /// Clears the step under the cursor (note, instrument, effects).
    public mutating func clearStep() {
        editStep { step in
            step.note = .empty
            step.instrument = nil
            step.fx = []
        }
    }

    /// Transposes the note under the cursor by `semitones`, clamped to `0...127`.
    public mutating func transpose(by semitones: Int) {
        editStep { step in
            guard case .pitch(let p) = step.note else { return }
            let next = min(max(Int(p) + semitones, 0), 127)
            step.note = .pitch(UInt8(next))
        }
    }

    // MARK: - Undo / redo

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(pattern)
        pattern = previous
    }

    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(pattern)
        pattern = next
    }

    /// Replaces the whole pattern (e.g. applying a mutation or generated result)
    /// as a single undoable step, keeping the cursor in range.
    public mutating func replace(with newPattern: Pattern) {
        snapshot()
        pattern = newPattern
        setCursor(track: cursor.track, row: cursor.row, column: cursor.column)
    }

    // MARK: - Private

    private mutating func editStep(_ body: (inout Step) -> Void) {
        guard cursor.track < pattern.tracks.count,
              cursor.row < pattern.tracks[cursor.track].steps.count else { return }
        snapshot()
        body(&pattern.tracks[cursor.track].steps[cursor.row])
    }

    private mutating func snapshot() {
        undoStack.append(pattern)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }
}
