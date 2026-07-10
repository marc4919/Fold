import Foundation

/// Archivo tocado por la sesión, mostrado en la tab Revisión.
struct ReviewFile: Identifiable {
    enum Kind: String {
        case new = "NEW"
        case mod = "MOD"
    }

    let id = UUID()
    let kind: Kind
    let path: String
    let added: Int
    let removed: Int
}

/// Lane colapsable de la tab Revisión (Specs / Código / Artefactos).
struct ReviewLane: Identifiable {
    enum Content {
        case files([ReviewFile])
        case artifacts([ChangeArtifact])
    }

    let id = UUID()
    let iconLetter: String
    let title: String
    let countLabel: String
    let content: Content
    var note: String?
}
