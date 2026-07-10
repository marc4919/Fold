import SwiftUI

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
        .frame(width: 480, height: 380)
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
        }
        .formStyle(.grouped)
        .padding()
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
