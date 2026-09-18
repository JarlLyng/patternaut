import SwiftUI
import PatternautCore

/// Sidebar listing loaded sample instruments. Each becomes a `.pti` on export;
/// its position is the sample-instrument slot (I00, I01, …) referenced by the
/// instrument column in the grid.
struct InstrumentsPanel: View {
    @Bindable var model: EditorModel
    let onAdd: () -> Void
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Instruments").font(.headline)
                Spacer()
                Button(action: onAdd) { Image(systemName: "plus") }
                    .help("Load WAV samples, or drop them here")
            }

            if model.instruments.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(model.instruments.enumerated()), id: \.element.id) { index, instrument in
                        row(index: index, instrument: instrument)
                    }
                }
                .listStyle(.inset)
            }

            if let error = model.sampleError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(isDropTarget ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(4)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let wavs = urls.filter { $0.pathExtension.lowercased() == "wav" }
            guard !wavs.isEmpty else {
                model.sampleError = "Only WAV files can become instruments."
                return false
            }
            for url in wavs { model.loadSample(from: url) }
            return true
        } isTargeted: { isDropTarget = $0 }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No samples")
                .foregroundStyle(.secondary)
            Text("Drop WAVs here, or use +, to build .pti instruments.\n24-bit and other sample rates are converted.\nThe order here is the instrument number in the grid:\nthe first is 00, the next 01.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(index: Int, instrument: EditorModel.LoadedInstrument) -> some View {
        HStack(spacing: 8) {
            Text(String(format: "I%02d", index))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                TextField("name", text: nameBinding(for: instrument))
                    .textFieldStyle(.plain)
                Text("\(instrument.isStereo ? "Stereo" : "Mono") · \(instrument.frames) frames")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                model.removeInstrument(instrument.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    private func nameBinding(for instrument: EditorModel.LoadedInstrument) -> Binding<String> {
        Binding(
            get: { instrument.name },
            set: { newValue in
                if let i = model.instruments.firstIndex(where: { $0.id == instrument.id }) {
                    model.instruments[i].name = newValue
                }
            }
        )
    }
}
