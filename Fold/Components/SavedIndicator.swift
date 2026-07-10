import SwiftUI

/// Indicador de autosave: "guardando…" → "✓ guardado".
struct SavedIndicator: View {
    enum Phase {
        case idle
        case saving
        case saved
    }

    let phase: Phase

    var body: some View {
        Group {
            switch phase {
            case .idle:
                EmptyView()
            case .saving:
                Text("guardando…")
                    .foregroundStyle(.tertiary)
            case .saved:
                Label("guardado", systemImage: "checkmark")
                    .foregroundStyle(Color.foldSuccess)
            }
        }
        .font(.caption)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }
}
