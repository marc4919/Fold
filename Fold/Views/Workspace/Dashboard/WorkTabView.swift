import SwiftUI

/// Tab Trabajo: stream único o orquestación de agentes.
struct WorkTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolbar
            WorkStreamView(session: session)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private var toolbar: some View {
        HStack {
            // El badge de ahorro solo aparece cuando el modo está activo de verdad.
            if appState.frugalMode {
                Label("modo ahorro · stream en texto plano", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.5), in: .capsule)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.activeSheet = .terminal
            } label: {
                Label("terminal", systemImage: "apple.terminal")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "Terminal embebida en el proyecto"))
        }
    }
}
