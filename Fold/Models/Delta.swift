import Foundation

/// Card de delta en la tab Plan: archivos del change y specs afectadas.
struct Delta: Identifiable {
    enum Kind: String {
        case md = "MD"
        case mod = "MOD"
        case new = "NEW"
    }

    let id = UUID()
    let kind: Kind
    let path: String
    let summary: String
    /// Si es un archivo editable del change, abre el modal de edición.
    var fileKey: ChangeFileKey?
}

/// Contenido editable de un archivo del change (proposal.md, design.md…).
struct ChangeFileContent {
    let name: String
    let title: String
    var content: String
}
