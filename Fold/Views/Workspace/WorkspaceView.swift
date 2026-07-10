import SwiftUI

/// Marco del proyecto: sidebar del sistema + detail (Hub o dashboard del change).
struct WorkspaceView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            ProjectSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            detail
        }
        .onChange(of: appState.sidebarSelection) { _, newValue in
            if case .change(let id) = newValue,
               appState.session == nil || appState.openedChangeID != id {
                appState.openChange(id: id)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.sidebarSelection {
        case .home:
            HubView()
                .toolbar { workspaceToolbar }
        case .archive:
            ArchiveView()
                .toolbar { workspaceToolbar }
        case .change:
            if let session = appState.session {
                DashboardView(session: session)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                appState.closeProject()
            } label: {
                Label("Proyectos", systemImage: "chevron.left")
            }
            .help(String(localized: "Cerrar proyecto y volver al selector"))
        }

        ToolbarItem {
            Button {
                appState.navigate(to: .memory)
            } label: {
                Label("Memoria", systemImage: "cylinder.split.1x2")
            }
            .tint(.foldMemory)
            .help(String(localized: "Memoria del proyecto · \(appState.activeProject?.memoryEntryCount ?? 0) contextos"))
        }

        ToolbarItem {
            AppearanceToggleButton()
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup {
            Button {
                appState.activeSheet = .inventory
            } label: {
                Label("Inventario", systemImage: "square.grid.2x2")
            }
            .help(String(localized: "Inventario · \(appState.activeProject?.inventoryPieceCount ?? 0) piezas"))

            Button {
                appState.activeSheet = .forge
            } label: {
                Label("Forja", systemImage: "hammer")
            }
            .help(String(localized: "Forja · crear piezas"))

            Button {
                appState.activeSheet = .userSettings
            } label: {
                Label("Tú", systemImage: "person.crop.circle")
            }
            .help(String(localized: "Ajustes de usuario"))
        }
    }
}

#Preview {
    let state = AppState()
    state.activeProject = SampleData.acmeAPI
    return WorkspaceView()
        .environment(state)
        .frame(width: 1280, height: 800)
}
