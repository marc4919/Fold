import SwiftUI

/// Centro de operaciones del proyecto: Hacer · Cola de atención · Ramas en curso.
struct HubView: View {
    @Environment(AppState.self) private var appState

    @State private var activeTab = "do"
    @State private var demoDecisions: [QueueDecision] = []
    @State private var decisionsLoaded = false

    /// Decisiones reales derivadas del estado de los changes en disco.
    private var realDecisions: [QueueDecision] {
        guard let state = appState.openSpecState else { return [] }
        return state.changes.compactMap { info in
            let done = info.tasks.filter(\.done).count
            if !info.tasks.isEmpty, done == info.tasks.count {
                return QueueDecision(
                    id: "ready-\(info.id)",
                    kindLabel: String(localized: "Listo para revisar"),
                    scopeLabel: info.id,
                    authorityLabel: String(localized: "decisión humana"),
                    title: String(localized: "«\(info.title)» tiene todas las tasks completadas"),
                    body: String(localized: "La sesión terminó su trabajo (\(done)/\(info.tasks.count) tasks). Revisa el diff y decide si mergear o iterar."),
                    consequenceTitle: "",
                    consequences: [],
                    actions: [.init(label: String(localized: "Abrir change"), role: .primary, toastMessage: "")],
                    changeID: info.id
                )
            }
            if !info.tasks.isEmpty, done == 0, (info.proposal?.count ?? 0) > 60 {
                return QueueDecision(
                    id: "plan-\(info.id)",
                    kindLabel: String(localized: "Plan listo · necesita tu OK"),
                    scopeLabel: info.id,
                    authorityLabel: String(localized: "decisión humana"),
                    title: String(localized: "Plan de \(info.tasks.count) tasks para «\(info.title)»"),
                    body: String(localized: "El plan está generado y ninguna task ha empezado. Revisa proposal, design y tasks, y lanza la implementación."),
                    consequenceTitle: "",
                    consequences: [],
                    actions: [.init(label: String(localized: "Abrir change"), role: .primary, toastMessage: "")],
                    changeID: info.id
                )
            }
            return nil
        }
    }

    private var displayedDecisions: [QueueDecision] {
        appState.isRealProject ? realDecisions : demoDecisions
    }

    var body: some View {
        let project = appState.activeProject ?? SampleData.acmeAPI

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header(project)

                PillTabBar(tabs: tabs, selection: $activeTab)

                switch activeTab {
                case "queue":
                    HubQueuePane(decisions: displayedDecisions) { decision, action in
                        resolve(decision, action: action)
                    }
                    .transition(.opacity)
                case "lanes":
                    HubLanesPane()
                        .transition(.opacity)
                default:
                    HubDoPane()
                        .transition(.opacity)
                }
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.25), value: activeTab)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .task {
            if !decisionsLoaded {
                decisionsLoaded = true
                demoDecisions = appState.isRealProject ? [] : SampleData.queueDecisions
            }
        }
    }

    private func resolve(_ decision: QueueDecision, action: QueueDecision.Action) {
        if let changeID = decision.changeID {
            appState.openChange(id: changeID)
            return
        }
        appState.toasts.show(action.toastMessage)
        withAnimation(.smooth(duration: 0.35)) {
            demoDecisions.removeAll { $0.id == decision.id }
        }
    }

    private var laneCount: Int {
        appState.isRealProject
            ? (appState.openSpecState?.changes.count ?? 0)
            : SampleData.workLanes.count
    }

    private var tabs: [PillTab] {
        [
            PillTab(id: "do", label: String(localized: "Hacer")),
            PillTab(id: "queue", label: String(localized: "Cola de atención"),
                    badge: displayedDecisions.isEmpty ? nil : displayedDecisions.count, badgeTint: .foldDanger),
            PillTab(id: "lanes", label: String(localized: "Ramas en curso"),
                    badge: laneCount),
        ]
    }

    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(project.name) · \(project.path)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            (Text("¿Qué quieres ")
             + Text("hacer").italic().foregroundStyle(Color.foldAction)
             + Text("?"))
                .font(.system(size: 34, weight: .semibold, design: .serif))

            Text("Explorar → Idea → Plan → Trabajo → Revisión")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let state = AppState()
    state.activeProject = SampleData.acmeAPI
    return HubView()
        .environment(state)
        .frame(width: 1100, height: 800)
}
