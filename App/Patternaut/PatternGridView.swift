import SwiftUI
import PatternautCore

/// The tracker grid: row numbers down the left, one column group per track, the
/// cursor cell highlighted. Keyboard-first — see `.onKeyPress` handling in
/// ``ContentView``.
struct PatternGridView: View {
    @Bindable var model: EditorModel

    private let columns = PatternEditor.Column.allCases

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                headerRow
                ForEach(0..<max(model.editor.rowCount, 0), id: \.self) { row in
                    gridRow(row)
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding(8)
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("")
                .frame(width: 34)
            ForEach(Array(model.pattern.tracks.enumerated()), id: \.offset) { index, track in
                TextField("", text: Binding(
                    get: { track.name },
                    set: { model.renameTrack($0, at: index) }
                ))
                .textFieldStyle(.plain)
                .lineLimit(1)
                .frame(width: cellGroupWidth, alignment: .leading)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .help("Track name. It is written into the project, so the Tracker shows it. Up to \(Track.nameLimit(forTrack: index)) characters.")
            }
        }
        .padding(.bottom, 4)
    }

    private func gridRow(_ row: Int) -> some View {
        GridRow {
            Text(String(format: "%02d", row))
                .foregroundStyle(row % 4 == 0 ? .primary : .secondary)
                .frame(width: 34, alignment: .trailing)
                .padding(.trailing, 4)

            ForEach(Array(model.pattern.tracks.enumerated()), id: \.offset) { trackIndex, track in
                trackCells(trackIndex: trackIndex, track: track, row: row)
            }
        }
        .background(row % 4 == 0 ? Color.secondary.opacity(0.06) : Color.clear)
    }

    private func trackCells(trackIndex: Int, track: Track, row: Int) -> some View {
        let step = row < track.steps.count ? track.steps[row] : nil
        return HStack(spacing: 6) {
            ForEach(columns, id: \.self) { column in
                cell(text: text(step: step, column: column),
                     isCursor: isCursor(track: trackIndex, row: row, column: column),
                     active: step?.isActive ?? false)
            }
        }
        .frame(width: cellGroupWidth, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func cell(text: String, isCursor: Bool, active: Bool) -> some View {
        Text(text)
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(isCursor ? Color.accentColor.opacity(0.35) : Color.clear)
            .overlay(isCursor ? RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1) : nil)
    }

    private func text(step: Step?, column: PatternEditor.Column) -> String {
        switch column {
        case .note: return StepFormatting.note(step?.note ?? .empty)
        case .instrument: return StepFormatting.instrument(step?.instrument)
        case .fx1: return StepFormatting.fxLane(step, lane: 0)
        case .fx2: return StepFormatting.fxLane(step, lane: 1)
        }
    }

    private func isCursor(track: Int, row: Int, column: PatternEditor.Column) -> Bool {
        let c = model.editor.cursor
        return c.track == track && c.row == row && c.column == column
    }

    private var cellGroupWidth: CGFloat { 150 }
}
