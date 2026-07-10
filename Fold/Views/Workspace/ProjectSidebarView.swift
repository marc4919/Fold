import SwiftUI

/// Sidebar del workspace: proyecto, inicio, changes activos y archive.
struct ProjectSidebarView: View {
    @Environment(AppState.self) private var appState

    @State private var showNewChange = false
    @State private var newChangeTitle = ""

    var body: some View {
        @Bindable var appState = appState
        let project = appState.activeProject ?? SampleData.acmeAPI

        List(selection: selectionBinding) {
            Section {
                projectHead(project)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 10, trailing: 8))
            }

            Section {
                Label("Inicio", systemImage: "house")
                    .tag(SidebarSelection.home)
            }

            Section {
                ForEach(project.activeChanges) { change in
                    HStack(spacing: 9) {
                        StatusDot(kind: change.dot, pulses: change.dot == .running)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(change.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(change.id)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .tag(SidebarSelection.change(change.id))
                }
            } header: {
                HStack {
                    Text("Changes activos · \(project.activeChanges.count)")
                    Spacer()
                    Button {
                        if appState.isRealProject {
                            showNewChange = true
                        } else {
                            appState.openChange(id: SampleData.addAppleLogin.id, initialState: .exploring)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(String(localized: "Nuevo change"))
                }
            }

            Section {
                HStack(spacing: 9) {
                    Image(systemName: "archivebox")
                        .foregroundStyle(.secondary)
                    Text("Archive")
                    Spacer()
                    Text("\(project.archivedCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .tag(SidebarSelection.archive)
            }
        }
        .listStyle(.sidebar)
        .alert("¿Qué quieres cambiar, en una frase?", isPresented: $showNewChange) {
            TextField("p. ej. «Login con Apple en la app iOS»", text: $newChangeTitle)
            Button("Crear change") {
                let title = newChangeTitle.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return }
                appState.createRealChange(title: title, initialState: .exploring)
                newChangeTitle = ""
            }
            Button("Cancelar", role: .cancel) { newChangeTitle = "" }
        }
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        @Bindable var appState = appState
        return Binding(
            get: { appState.sidebarSelection },
            set: { appState.sidebarSelection = $0 ?? .home }
        )
    }

    private func projectHead(_ project: Project) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                Text(project.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                appState.activeSheet = .config
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Configuración del proyecto"))
        }
    }
}
