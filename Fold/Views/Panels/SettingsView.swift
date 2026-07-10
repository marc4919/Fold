import SwiftUI
import AppKit

/// Ajustes nativos de la app (⌘,): perfil del usuario y preferencias generales.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            profileTab
                .tabItem { Label("Tú", systemImage: "person.crop.circle") }
        }
        .frame(width: 480, height: 400)
    }

    private var generalTab: some View {
        Form {
            Picker("Apariencia", selection: appearanceBinding) {
                Text("Sistema").tag(AppearanceMode.system)
                Text("Claro").tag(AppearanceMode.light)
                Text("Oscuro").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)

            Picker("Aislamiento de sesiones", selection: isolationBinding) {
                Text("Worktree dedicado (recomendado)").tag("worktree")
                Text("Directo sobre el working tree").tag("direct")
            }

            LabeledContent("Agentes detectados") {
                Text(appState.detectedAgents.filter(\.isDetected).map(\.name).joined(separator: " · "))
                    .foregroundStyle(.secondary)
            }

            Section("Diagnóstico") {
                LabeledContent("Exportar diagnóstico") {
                    Button("Guardar informe…") { exportDiagnostics() }
                }
                Text("Versiones y estados de la app, redactado: sin credenciales ni contenido de tus repos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Informe local y redactado para reportar fallos de la beta.
    private func exportDiagnostics() {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let agents = appState.detectedAgents.map {
            "- \($0.name): \($0.isDetected ? ($0.version ?? "sin versión") : "no instalado") · \($0.authLabel)"
        }.joined(separator: "\n")
        let project = appState.isRealProject
            ? "proyecto abierto: sí · changes activos: \(appState.openSpecState?.changes.count ?? 0) · archivados: \(appState.openSpecState?.archivedCount ?? 0) · memoria: \(appState.realMemory.count)"
            : "proyecto abierto: no (o demo)"

        let report = """
        # Diagnóstico Fold
        Fold \(version) (\(build)) · \(os)
        Aislamiento: \(appState.isolationMode) · Frugal: \(appState.frugalMode)

        ## Agentes
        \(agents)

        ## Estado
        \(project)
        """

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "fold-diagnostico.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var profileTab: some View {
        @Bindable var appState = appState
        return Form {
            TextField("Tu nombre", text: $appState.profile.name)

            LabeledContent("Tu rol") {
                FlowChips(items: UserProfile.roleOptions) { role in
                    SelectableChip(
                        label: role,
                        isSelected: appState.profile.roles.contains(role)
                    ) {
                        if appState.profile.roles.contains(role) {
                            appState.profile.roles.remove(role)
                        } else {
                            appState.profile.roles.insert(role)
                        }
                        appState.saveProfile()
                    }
                }
            }

            Section("Preferencias y contexto — los agentes lo leen en cada sesión") {
                TextEditor(text: $appState.profile.preferences)
                    .font(.callout)
                    .frame(minHeight: 90)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: appState.profile.name) { appState.saveProfile() }
        .onChange(of: appState.profile.preferences) { appState.saveProfile() }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { appState.appearance },
            set: { appState.setAppearance($0) }
        )
    }

    private var isolationBinding: Binding<String> {
        Binding(
            get: { appState.isolationMode },
            set: { appState.setIsolation($0) }
        )
    }
}
