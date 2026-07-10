import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Group {
            switch appState.route {
            case .onboarding:
                OnboardingView()
            case .selector:
                ProjectSelectorView()
            case .setup:
                ProjectSetupView()
            case .workspace:
                WorkspaceView()
            case .memory:
                MemoryFullscreenView()
            }
        }
        .transition(.opacity)
        .preferredColorScheme(appState.appearance.colorScheme)
        .sheet(item: $appState.activeSheet) { sheet in
            sheetContent(sheet)
                .environment(appState)
        }
        .overlay(alignment: .bottom) {
            ToastOverlay(center: appState.toasts)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .fileEditor(let key):
            FileEditorSheet(fileKey: key)
        case .artifactFullscreen:
            ArtifactFullscreenSheet()
        case .forge:
            ForgeSheet()
        case .inventory:
            InventorySheet()
        case .config:
            ConfigSheet()
        case .terminal:
            TerminalSheet()
        case .userSettings:
            UserSettingsSheet()
        case .commitDetail(let sha):
            CommitSheet(sha: sha)
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
