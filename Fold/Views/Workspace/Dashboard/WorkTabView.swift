import SwiftUI

/// Tab Trabajo: stream único o orquestación de agentes.
struct WorkTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolbar

            Group {
                if appState.frugalMode || session.isReal || session.workMode == .stream {
                    WorkStreamView(session: session)
                        .transition(.opacity)
                } else {
                    OrchestrationView(session: session)
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.25), value: session.workMode)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private var toolbar: some View {
        HStack {
            if !appState.frugalMode, !session.isReal {
                Picker("Modo", selection: $session.workMode) {
                    Label("Stream único", systemImage: "list.bullet.rectangle")
                        .tag(WorkMode.stream)
                    Label("Orquestación de agentes · 3", systemImage: "arrow.triangle.branch")
                        .tag(WorkMode.agents)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            } else {
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
