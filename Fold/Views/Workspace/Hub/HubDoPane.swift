import SwiftUI

/// Tab "Hacer": las dos tarjetas grandes de arranque + memoria + changes en curso.
struct HubDoPane: View {
    @Environment(AppState.self) private var appState

    @State private var showNewChange = false
    @State private var newChangeTitle = ""
    @State private var newChangeState: ChangeState = .exploring

    var body: some View {
        let project = appState.activeProject ?? SampleData.acmeAPI

        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 14) {
                StartCard(
                    iconLetter: "E",
                    tint: .foldInfo,
                    title: String(localized: "Explorar idea"),
                    description: String(localized: "El agente investiga el código contigo, te hace preguntas y genera briefings comparando approaches. No implementa nada hasta que aterrices la idea."),
                    command: "/opsx:explore"
                ) {
                    openChange(initialState: .exploring)
                }

                StartCard(
                    iconLetter: "P",
                    tint: .foldAction,
                    title: String(localized: "Proponer cambio"),
                    description: String(localized: "El agente crea el change completo: proposal, tasks y deltas en un paso. Para cuando ya sabes qué quieres hacer."),
                    command: "/opsx:propose"
                ) {
                    // Aterriza directamente en Idea con la frase como intención.
                    openChange(initialState: .idea)
                }
            }

            memoryCard(project)

            inProgress(project)
        }
        .alert("¿Qué quieres cambiar, en una frase?", isPresented: $showNewChange) {
            TextField("p. ej. «Login con Apple en la app iOS»", text: $newChangeTitle)
            Button("Crear change") {
                let title = newChangeTitle.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return }
                appState.createRealChange(title: title, initialState: newChangeState)
                newChangeTitle = ""
            }
            Button("Cancelar", role: .cancel) { newChangeTitle = "" }
        } message: {
            Text("Se creará openspec/changes/ con los artefactos de planning. Tu intención, en tus palabras.")
        }
    }

    private func openChange(initialState: ChangeState) {
        if appState.isRealProject {
            newChangeState = initialState
            showNewChange = true
        } else {
            appState.openChange(id: SampleData.addAppleLogin.id, initialState: initialState)
        }
    }

    private func memoryCard(_ project: Project) -> some View {
        Button {
            appState.navigate(to: .memory)
        } label: {
            HStack(spacing: 16) {
                StatusDot(kind: .running, pulses: true)
                    .tint(.foldMemory)
                Text("\(project.memoryEntryCount)")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.foldMemory)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memoria del proyecto")
                        .font(.headline)
                    Text("Specs, convenciones, decisiones y lecciones. Vive en el repo, los agentes la leen en cada sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.foldMemory.opacity(0.08), in: .rect(cornerRadius: FoldMetrics.cardRadius))
            .foldCardBorder(.foldMemory)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func inProgress(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: String(localized: "En curso"))

            VStack(spacing: 6) {
                ForEach(project.activeChanges) { change in
                    Button {
                        appState.openChange(id: change.id)
                    } label: {
                        HStack(spacing: 12) {
                            StatusDot(kind: change.dot, pulses: change.dot == .running)
                            Text(change.title)
                                .font(.body.weight(.medium))
                            Text(change.id)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(13)
                        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Tarjeta grande de arranque (Explorar / Proponer).
private struct StartCard: View {
    let iconLetter: String
    let tint: Color
    let title: String
    let description: String
    let command: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Text(iconLetter)
                    .font(.title3.weight(.bold).monospaced())
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.16), in: .rect(cornerRadius: 10))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(command)
                        .font(.caption.monospaced())
                        .foregroundStyle(tint)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background(.background.secondary, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(hovering ? 0.5 : 0.15), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.01 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.18), value: hovering)
    }
}
