import SwiftUI

/// Drawer de memoria: acceso rápido a las últimas entradas, sin salir del dashboard.
struct MemoryDrawer: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatusDot(kind: .running, pulses: true)
                    Text("Memoria")
                        .font(.headline)
                    Text("\(appState.memoryEntries.count)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.foldMemory)
                    Spacer()
                }

                Text("Lo que el proyecto sabe. Los agentes lo leen en cada sesión.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(appState.memoryEntries.suffix(4).reversed()) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.title)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(entry.kind.label)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(entry.kind.tint.opacity(0.14), in: .capsule)
                                    .foregroundStyle(entry.kind.tint)
                            }
                            Text(LocalizedStringKey(entry.body))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: .rect(cornerRadius: 10))
                    }
                }

                Button {
                    appState.inspector = nil
                    appState.navigate(to: .memory)
                } label: {
                    HStack {
                        Text("Abrir memoria a pantalla completa")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(.foldMemory)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}
