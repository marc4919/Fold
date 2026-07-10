import SwiftUI
import AppKit

/// Dashboard del change: cinco tabs progresivas sobre un change vivo.
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ChangeSession

    @State private var selectedEditor: EditorOption = {
        let storedID = UserDefaults.standard.string(forKey: "defaultEditorID")
        return SampleData.editors.first(where: { $0.id == storedID }) ?? SampleData.editors[0]
    }()
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDiscardConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 32)
                .padding(.top, 20)

            PillTabBar(tabs: tabs, selection: tabSelection)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .animation(.smooth(duration: 0.3), value: session.visibleTabs.count)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar { dashboardToolbar }
        .inspector(isPresented: inspectorBinding) {
            Group {
                switch appState.inspector {
                case .history:
                    HistoryDrawer(session: session)
                case .memory:
                    MemoryDrawer()
                case nil:
                    EmptyView()
                }
            }
            .inspectorColumnWidth(min: 360, ideal: 480, max: 560)
        }
        .alert("Editar título", isPresented: $showRename) {
            TextField("Título del change", text: $renameText)
            Button("Guardar") {
                // El título persiste en el heading de proposal.md, no solo en memoria.
                session.renameChange(to: renameText)
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog(
            "¿Descartar este change?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Descartar change", role: .destructive) {
                appState.discardActiveChange()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán el worktree, la rama y el directorio del change. Las specs vivas no se tocan.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(appState.activeProject?.name ?? String(localized: "proyecto")) › Changes › \(session.change.id)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(session.change.title)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .italic()

                HStack(spacing: 7) {
                    StatusDot(kind: session.state.dot, pulses: session.state == .implementing)
                    Text(session.state.label)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(session.state.dot.color.opacity(0.12), in: .capsule)

                Spacer()

                Text("\(session.change.id) · \(session.change.createdLabel)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Tabs

    private var tabs: [PillTab] {
        session.visibleTabs.map { tab in
            PillTab(
                id: "\(tab.rawValue)",
                label: tab.label(state: session.state),
                number: tab.rawValue + 1,
                isCompleted: session.isCompleted(tab),
                isLive: tab == .work && session.state == .implementing
            )
        }
    }

    private var tabSelection: Binding<String> {
        Binding(
            get: { "\(session.activeTab.rawValue)" },
            set: { id in
                if let raw = Int(id), let tab = DashboardTab(rawValue: raw) {
                    session.select(tab: tab)
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch session.activeTab {
        case .explore:
            ExploreTabView(session: session)
                .transition(.opacity)
        case .idea:
            IdeaTabView(session: session)
                .transition(.opacity)
        case .plan:
            PlanTabView(session: session)
                .transition(.opacity)
        case .work:
            WorkTabView(session: session)
                .transition(.opacity)
        case .review:
            if session.state == .archived {
                ClosureView(session: session)
                    .transition(.opacity)
            } else {
                ReviewTabView(session: session)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var dashboardToolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                appState.toggleInspector(.memory)
            } label: {
                Label("Memoria", systemImage: "cylinder.split.1x2")
            }
            .tint(.foldMemory)
            .help(String(localized: "Memoria del proyecto · acceso rápido"))
        }

        ToolbarItem {
            AppearanceToggleButton()
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Menu {
                ForEach(switchableAgents) { agent in
                    Button {
                        session.setAgent(binaryPath: agent.binaryPath)
                        appState.toasts.show(String(localized: "Agente de la sesión: \(agent.name)"))
                    } label: {
                        if isCurrentAgent(agent) {
                            Label(agent.versionLabel, systemImage: "checkmark")
                        } else {
                            Text(agent.versionLabel)
                        }
                    }
                }
                if switchableAgents.isEmpty {
                    Text("Sin agentes activos — actívalos en Configuración")
                }
            } label: {
                Label(currentAgentName, systemImage: "cpu")
            }
            .help(String(localized: "Agente que ejecuta esta sesión"))
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Toggle(isOn: frugalBinding) {
                Label("Ahorro de tokens", systemImage: "leaf")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(String(localized: "Modo ahorro: el agente trabaja al grano, sin artefactos visuales"))
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Menu {
                ForEach(SampleData.editors) { editor in
                    Button {
                        selectedEditor = editor
                        UserDefaults.standard.set(editor.id, forKey: "defaultEditorID")
                        appState.toasts.show(String(localized: "Editor por defecto: \(editor.name)"))
                    } label: {
                        if editor.id == selectedEditor.id {
                            Label(editor.name, systemImage: "checkmark")
                        } else {
                            Text(editor.isAvailable ? editor.name : "\(editor.name) · no instalado")
                        }
                    }
                    .disabled(!editor.isAvailable)
                }
            } label: {
                Label(selectedEditor.name, systemImage: "chevron.left.forwardslash.chevron.right")
            } primaryAction: {
                openInEditor(selectedEditor)
            }
            .help(String(localized: "Abrir en editor"))
        }

        ToolbarItem {
            Button {
                appState.toggleInspector(.history)
            } label: {
                Label("Historia", systemImage: "clock.arrow.circlepath")
            }
            .help(String(localized: "Timeline del change"))
        }

        ToolbarItem {
            Menu {
                Button("Mostrar en Finder") {
                    showInFinder()
                }
                Button("Copiar comando de reproducción") {
                    copyReproCommand()
                }
                Divider()
                Button("Editar título") {
                    renameText = session.change.title
                    showRename = true
                }
                Divider()
                Button("Descartar change", role: .destructive) {
                    showDiscardConfirm = true
                }
            } label: {
                Label("Más", systemImage: "ellipsis")
            }
        }
    }

    // MARK: - Agentes y acciones reales

    /// Los agentes activos del popup de configuración, pulsables desde aquí.
    private var switchableAgents: [AgentCLI] {
        let agents = appState.detectedAgents.isEmpty ? SampleData.clis : appState.detectedAgents
        return agents.filter { $0.isSelected && $0.isDetected }
    }

    private func isCurrentAgent(_ agent: AgentCLI) -> Bool {
        agent.binaryPath != nil && agent.binaryPath == session.agentBinary
    }

    private var currentAgentName: String {
        if let binary = session.agentBinary {
            return switchableAgents.first(where: { $0.binaryPath == binary })?.name
                ?? (binary as NSString).lastPathComponent
        }
        return switchableAgents.first?.name ?? String(localized: "Agente")
    }

    /// Directorio que abren el editor y Finder: el change real, o el proyecto.
    private var targetDirectory: URL? {
        session.realInfo?.dirURL ?? appState.projectURL
    }

    private func openInEditor(_ editor: EditorOption) {
        guard let url = targetDirectory else {
            appState.toasts.show(String(localized: "(demo) Abriendo el worktree en \(editor.name)…"))
            return
        }
        Task {
            let result = await ShellRunner.run(
                "open -a \(ShellRunner.quote(editor.appName)) \(ShellRunner.quote(url.path))"
            )
            appState.toasts.show(result.ok
                ? String(localized: "Abriendo \(url.lastPathComponent) en \(editor.name)…")
                : String(localized: "No se pudo abrir \(editor.name) — ¿está instalado?"))
        }
    }

    private func showInFinder() {
        guard let url = targetDirectory else {
            appState.toasts.show(String(localized: "(demo) Mostrando el worktree en Finder…"))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyReproCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("openspec show \(session.change.id)", forType: .string)
        appState.toasts.show(String(localized: "Comando copiado al portapapeles"))
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { appState.inspector != nil },
            set: { if !$0 { appState.inspector = nil } }
        )
    }

    private var frugalBinding: Binding<Bool> {
        Binding(
            get: { appState.frugalMode },
            set: { newValue in
                appState.frugalMode = newValue
                session.isFrugal = newValue
            }
        )
    }
}

/// Placeholder de tabs aún no construidas.
struct TabPlaceholder: View {
    let name: String

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.title2.weight(.semibold))
            Text("En construcción")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
