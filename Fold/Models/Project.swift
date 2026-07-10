import Foundation

/// Referencia compacta a un change para listas (sidebar, selector).
struct ChangeRef: Identifiable {
    let id: String
    let title: String
    let dot: StatusDot.Kind
}

/// Proyecto abierto en Fold.
struct Project: Identifiable {
    let id: String
    let name: String
    let path: String
    let relativeTimeLabel: String
    let statusSummary: String
    let activeChanges: [ChangeRef]
    let archivedCount: Int
    let memoryEntryCount: Int
    let inventoryPieceCount: Int
}

/// Estadísticas globales del selector.
struct GlobalStats {
    let openProjects: Int
    let detectedAgents: Int
    let totalArchives: Int
}
