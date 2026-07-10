import SwiftUI

/// Configuración del proyecto: agentes, aislamiento, OpenSpec y conectores.
struct ConfigSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var tab = "agents"
    @State private var clis = SampleData.clis
    @State private var telemetry = UserDefaults.standard.bool(forKey: "telemetryEnabled")
    @State private var mcpServers: [String: Bool] = {
        if let stored = UserDefaults.standard.dictionary(forKey: "mcpServers") as? [String: Bool] {
            return stored
        }
        return ["GitHub": true, "Postgres MCP": true, "Filesystem (sandbox)": true, "Linear": false]
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configuración del proyecto")
                        .font(.title3.weight(.semibold))
                    Text(appState.activeProject?.name ?? "acme-api")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Picker("Sección", selection: $tab) {
                Text("Agentes").tag("agents")
                Text("Aislamiento").tag("isolation")
                Text("OpenSpec").tag("openspec")
                Text("Conectores").tag("connectors")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 420)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                Group {
                    switch tab {
                    case "isolation": isolationPane
                    case "openspec": openspecPane
                    case "connectors": connectorsPane
                    default: agentsPane
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 520, idealHeight: 560)
        .onAppear {
            if !appState.detectedAgents.isEmpty {
                clis = appState.detectedAgents
            }
        }
    }

    // MARK: - Agentes

    private var agentsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elige qué agentes orquestan tu proyecto. Fold hereda la autenticación de tus sesiones CLI — nunca gestiona API keys.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach($clis) { $cli in
                    HStack(spacing: 12) {
                        Text(cli.abbreviation)
                            .font(.caption.weight(.bold).monospaced())
                            .frame(width: 32, height: 32)
                            .background(
                                cli.isSelected ? Color.foldAction.opacity(0.16) : Color.gray.opacity(0.1),
                                in: .rect(cornerRadius: 8)
                            )
                            .foregroundStyle(cli.isSelected ? Color.foldAction : .secondary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(cli.name)
                                .font(.body.weight(.medium))
                            Text(cli.isDetected ? cli.versionLabel : String(localized: "no instalado"))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if cli.isSelected {
                            if cli.isDefault {
                                Text("default")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.foldAction.opacity(0.16), in: .capsule)
                                    .foregroundStyle(Color.foldAction)
                            } else {
                                Button("hacer default") { makeDefault(cli.id) }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        StatusDot(kind: cli.isSelected ? .success : .archived, size: 7)

                        Toggle("", isOn: toggleBinding($cli))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.small)
                            .disabled(!cli.isDetected)
                    }
                    .padding(12)
                    .background(.background.secondary, in: .rect(cornerRadius: 10))
                    .opacity(cli.isDetected ? 1 : 0.5)
                }
            }
        }
    }

    private func toggleBinding(_ cli: Binding<AgentCLI>) -> Binding<Bool> {
        Binding(
            get: { cli.wrappedValue.isSelected },
            set: { newValue in
                cli.wrappedValue.isSelected = newValue
                if !newValue, cli.wrappedValue.isDefault {
                    cli.wrappedValue.isDefault = false
                    if let first = clis.firstIndex(where: { $0.isSelected }) {
                        clis[first].isDefault = true
                    }
                } else if newValue, !clis.contains(where: { $0.isDefault }) {
                    cli.wrappedValue.isDefault = true
                }
                syncToAppState()
            }
        )
    }

    private func makeDefault(_ id: String) {
        for index in clis.indices {
            clis[index].isDefault = clis[index].id == id
        }
        syncToAppState()
    }

    /// La configuración de agentes es global: se propaga al estado de la app y persiste.
    private func syncToAppState() {
        if !appState.detectedAgents.isEmpty {
            appState.detectedAgents = clis
            appState.saveDefaultAgent()
        }
    }

    // MARK: - Aislamiento

    private var isolationPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dónde trabajan los agentes cuando implementan un change.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Aislamiento", selection: isolationBinding) {
                Text("Worktree dedicado · cada change en su propia copia del repo (recomendado)").tag("worktree")
                Text("Directo · el agente trabaja sobre tu working tree").tag("direct")
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text("Con worktree dedicado, los artefactos del plan se commitean y la sesión vive en su copia aislada; al mergear converge con tu rama. Requiere un repo git con al menos un commit.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var isolationBinding: Binding<String> {
        Binding(
            get: { appState.isolationMode },
            set: { appState.setIsolation($0) }
        )
    }

    // MARK: - OpenSpec

    private var openspecPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let state = appState.openSpecState, appState.isRealProject {
                infoRow(label: "Estado", value: state.isInitialized ? "inicializado" : "sin inicializar")
                infoRow(label: "Profile activo", value: "estándar")
                infoRow(label: "Specs", value: "\(state.specPaths.count)")
                infoRow(label: "Changes", value: "\(state.changes.count) activos · \(state.archivedCount) archivados")
                infoRow(label: "Slash commands", value: "explore · propose · apply · verify · archive")
            } else {
                infoRow(label: "Estado", value: "inicializado")
                infoRow(label: "Versión OPSX", value: "0.9.2")
                infoRow(label: "Profile activo", value: "estándar")
                infoRow(label: "Specs", value: "5")
                infoRow(label: "Changes", value: "3 activos · 14 archivados")
                infoRow(label: "Slash commands", value: "explore · propose · apply · verify · archive")
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospaced())
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    // MARK: - Conectores

    private var connectorsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Los conectores se conectan aquí, no se forjan. El login lo haces tú, nunca el agente.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(mcpServers.keys.sorted(), id: \.self) { server in
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                        Text(server)
                            .font(.callout)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { mcpServers[server] ?? false },
                            set: {
                                mcpServers[server] = $0
                                UserDefaults.standard.set(mcpServers, forKey: "mcpServers")
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(.background.secondary, in: .rect(cornerRadius: 10))
                }
            }

            Text("La preferencia se guarda; la conexión real de MCP a los agentes llegará con la integración ACP.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Toggle("Telemetría anónima (reservado — Fold no envía nada todavía)", isOn: Binding(
                get: { telemetry },
                set: {
                    telemetry = $0
                    UserDefaults.standard.set($0, forKey: "telemetryEnabled")
                }
            ))
            .toggleStyle(.switch)
            .padding(.top, 6)
        }
    }
}
