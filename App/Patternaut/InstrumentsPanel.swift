import SwiftUI
import PatternautCore

/// Sidebar listing loaded sample instruments. Each becomes a `.pti` on export;
/// its position is the sample-instrument slot (I00, I01, …) referenced by the
/// instrument column in the grid.
struct InstrumentsPanel: View {
    @Bindable var model: EditorModel
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Instruments").font(.headline)
                Spacer()
                Button(action: onAdd) { Image(systemName: "plus") }
                    .help("Load 16-bit WAV samples")
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
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No samples")
                .foregroundStyle(.secondary)
            Text("Load 16-bit WAVs to build .pti instruments.\nExported into the project's Instruments folder;\nassign them to slots on the Tracker.")
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
