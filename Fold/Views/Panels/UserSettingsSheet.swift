import SwiftUI

/// Ajustes de usuario: el perfil del onboarding, editable, más un contexto
/// libre de preferencias que los agentes reciben en cada prompt.
struct UserSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var roles: Set<String> = []
    @State private var preferences = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ajustes de usuario")
                        .font(.title3.weight(.semibold))
                    Text("Quién eres y cómo te gusta trabajar. Los agentes lo leen en cada sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: String(localized: "Tu nombre"))
                TextField("Tu nombre", text: $name)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(10)
                    .background(.background.secondary, in: .rect(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: String(localized: "Tu rol — combina los que quieras"))
                GlassEffectContainer {
                    FlowChips(items: UserProfile.roleOptions) { role in
                        SelectableChip(label: role, isSelected: roles.contains(role)) {
                            if roles.contains(role) {
                                roles.remove(role)
                            } else {
                                roles.insert(role)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(
                    title: String(localized: "Preferencias y contexto"),
                    pills: [String(localized: "los agentes lo leen")]
                )
                TextEditor(text: $preferences)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
                    .background(.background.secondary, in: .rect(cornerRadius: 8))
                Text("P. ej. «Prefiero async/await, tests primero, respuestas breves en español».")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.glass)
                Button("Guardar") {
                    appState.profile.name = name.trimmingCharacters(in: .whitespaces)
                    appState.profile.roles = roles
                    appState.profile.preferences = preferences.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.saveProfile()
                    appState.toasts.show(String(localized: "Perfil guardado"))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            name = appState.profile.name
            roles = appState.profile.roles
            preferences = appState.profile.preferences
        }
    }
}
