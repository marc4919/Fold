import SwiftUI

/// Estrategia de ejecución: veredicto de paralelización con visual tronco/abanico.
struct ExecStrategyView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("¿Vale la pena dividir esto entre varios agentes?")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Button("ejemplo: paralelizable") {
                        withAnimation(.smooth(duration: 0.25)) { session.execVerdict = .parallel }
                    }
                    Button("ejemplo: no conviene") {
                        withAnimation(.smooth(duration: 0.25)) { session.execVerdict = .serial }
                    }
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            verdictBadge

            if session.execVerdict == .parallel {
                Text("1.1 y 1.2 son el tronco: tocan config y el endpoint del que todo depende. 1.3, 2.1 y 2.2 no comparten archivos — pueden ir en paralelo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    execGroup(
                        icon: "arrow.down",
                        title: String(localized: "tronco secuencial"),
                        tint: .foldInfo,
                        tasks: session.change.tasks.filter { $0.lane == .trunk }
                    )
                    execGroup(
                        icon: "arrow.triangle.branch",
                        title: String(localized: "abanico paralelo · 3 agentes"),
                        tint: .foldAction,
                        tasks: session.change.tasks.filter { $0.lane == .fan }
                    )
                }

                HStack(spacing: 10) {
                    Button("Lanzar en paralelo (3 agentes)") {
                        session.workMode = .agents
                        appState.toasts.show(String(localized: "Ejecución en paralelo seleccionada"))
                    }
                    .buttonStyle(.glassProminent)

                    Button("Mantener un solo agente") {
                        session.workMode = .stream
                        appState.toasts.show(String(localized: "Ejecución con un solo agente"))
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Text("~2.4× más rápido · 3 worktrees aislados")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Las cinco tasks tocan los mismos archivos de auth: dividirlas crearía conflictos de merge sin ganar tiempo. Mejor un solo agente, en orden.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                execGroup(
                    icon: "arrow.down",
                    title: String(localized: "secuencial · 1 agente"),
                    tint: .foldInfo,
                    tasks: session.change.tasks
                )
            }
        }
        .foldCard(padding: 18)
        .foldCardBorder()
    }

    private var verdictBadge: some View {
        let isParallel = session.execVerdict == .parallel
        return HStack(spacing: 6) {
            Image(systemName: isParallel ? "arrow.triangle.branch" : "arrow.down")
                .font(.caption.weight(.semibold))
            Text(isParallel
                 ? String(localized: "recomendado: 3 agentes en paralelo")
                 : String(localized: "recomendado: un solo agente"))
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isParallel ? Color.foldAction : Color.foldInfo).opacity(0.14), in: .capsule)
        .foregroundStyle(isParallel ? Color.foldAction : Color.foldInfo)
    }

    private func execGroup(icon: String, title: String, tint: Color, tasks: [WorkTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(tasks) { task in
                    HStack(spacing: 8) {
                        Text(task.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(tint)
                        Text(LocalizedStringKey(task.title))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.06), in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
