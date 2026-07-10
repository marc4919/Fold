import SwiftUI

/// Etapa del drawer de historia (Explorar, Idea, Plan, Trabajo, Revisión).
struct HistoryStage: Identifiable {
    let id = UUID()
    let name: String
    let durationLabel: String
    let events: [HistoryEvent]
}

/// Evento individual del timeline del change.
struct HistoryEvent: Identifiable {
    enum Actor {
        case human
        case agent
        case system

        var label: String {
            switch self {
            case .human: String(localized: "tú")
            case .agent: String(localized: "agente")
            case .system: String(localized: "sistema")
            }
        }

        var tint: Color {
            switch self {
            case .human: .foldAction
            case .agent: .foldInfo
            case .system: .gray
            }
        }
    }

    let id = UUID()
    let actor: Actor
    let timeLabel: String
    let text: String
    var detail: String?
}
