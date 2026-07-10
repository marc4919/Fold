import Foundation

/// Vista raíz activa de la app.
enum AppRoute: Hashable {
    case onboarding
    case selector
    case setup
    case workspace
    case memory
}

/// Selección de la sidebar del workspace.
enum SidebarSelection: Hashable {
    case home
    case change(String)
    case archive
}

/// Archivos editables de un change (modal de edición).
enum ChangeFileKey: String, CaseIterable, Identifiable {
    case proposal
    case design
    case tasks
    case deltas

    var id: String { rawValue }
}

/// Sheets globales de la app.
enum AppSheet: Identifiable, Hashable {
    case forge
    case inventory
    case config
    case fileEditor(ChangeFileKey)
    case artifactFullscreen
    case terminal
    case userSettings
    case commitDetail(String)

    var id: Self { self }
}

/// Contenido del inspector lateral (drawer) del workspace.
enum InspectorContent: Hashable {
    case history
    case memory
}
