import Foundation

/// Archivo tocado por la sesión, mostrado en la tab Revisión.
struct ReviewFile: Identifiable {
    enum Kind: String {
        case new = "NEW"
        case mod = "MOD"
        case del = "DEL"
        case ren = "REN"
        case bin = "BIN"
        case conflict = "CONF"
    }

    let id = UUID()
    let kind: Kind
    let path: String
    let added: Int
    let removed: Int
    /// Ruta original si el archivo fue renombrado.
    var originalPath: String?
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
