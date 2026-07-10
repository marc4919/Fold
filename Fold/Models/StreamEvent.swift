import SwiftUI

/// Evento del stream en vivo de la tab Trabajo.
struct StreamEvent: Identifiable {
    enum Kind {
        case thought
        case fileCreated
        case fileModified
        case message
        case tool(name: String)

        var metaLabel: String {
            switch self {
            case .thought: String(localized: "pensando")
            case .fileCreated: String(localized: "archivo creado")
            case .fileModified: String(localized: "archivo modificado")
            case .message: String(localized: "mensaje del agente")
            case .tool(let name): String(localized: "tool · \(name)")
            }
        }

        var icon: String {
            switch self {
            case .thought: "ellipsis"
            case .fileCreated: "plus"
            case .fileModified: "pencil"
            case .message: "text.bubble"
            case .tool: "wrench.and.screwdriver"
            }
        }

        var tint: Color {
            switch self {
            case .thought: .gray
            case .fileCreated: .foldSuccess
            case .fileModified: .foldReview
            case .message: .foldInfo
            case .tool: .foldMemory
            }
        }
    }

    struct FileRow {
        let path: String
        let added: Int
        let removed: Int
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let timeLabel: String
    var fileRow: FileRow?
    /// Línea que añade a la terminal embebida al emitirse.
    var terminalLine: String?
}
