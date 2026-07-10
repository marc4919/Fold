import SwiftUI

/// Decisión pendiente en la cola de atención del Hub.
struct QueueDecision: Identifiable {
    struct Action: Identifiable {
        enum Role {
            case primary
            case secondary
            case ghost
            case destructive
            case postpone
        }

        let id = UUID()
        let label: String
        let role: Role
        let toastMessage: String
    }

    let id: String
    let kindLabel: String
    let scopeLabel: String
    let authorityLabel: String
    let title: String
    let body: String
    let consequenceTitle: String
    let consequences: [String]
    let actions: [Action]
    /// Change real al que pertenece la decisión (las acciones lo abren).
    var changeID: String?
}

/// Carril de "Ramas en curso" del Hub.
struct WorkLane: Identifiable {
    enum Status {
        case conflict
        case needsRevision
        case readyToMerge

        var label: String {
            switch self {
            case .conflict: String(localized: "conflicto")
            case .needsRevision: String(localized: "necesita revisión")
            case .readyToMerge: String(localized: "listo para mergear")
            }
        }

        var tint: Color {
            switch self {
            case .conflict: .foldDanger
            case .needsRevision: .foldReview
            case .readyToMerge: .foldSuccess
            }
        }
    }

    let id = UUID()
    let status: Status
    let name: String
    let taskInfo: String
    let agentInfo: String
    let actions: [String]
}
