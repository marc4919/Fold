import Foundation
import SwiftUI

/// Estado de un change. `Comparable` por orden de progreso: las tabs del
/// dashboard se desbloquean cuando `state >= tab.minState`.
enum ChangeState: Int, Comparable, CaseIterable {
    case exploring
    case idea
    case planned
    case implementing
    case review
    case archived

    static func < (lhs: ChangeState, rhs: ChangeState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .exploring: String(localized: "Explorando idea")
        case .idea: String(localized: "Idea aterrizada")
        case .planned: String(localized: "Listo para implementar")
        case .implementing: String(localized: "Implementando")
        case .review: String(localized: "Listo para revisar")
        case .archived: String(localized: "Archivado")
        }
    }

    var dot: StatusDot.Kind {
        switch self {
        case .exploring, .idea: .explore
        case .planned: .ready
        case .implementing: .running
        case .review: .review
        case .archived: .archived
        }
    }

    var defaultTab: DashboardTab {
        switch self {
        case .exploring: .explore
        case .idea: .idea
        case .planned: .plan
        case .implementing: .work
        case .review, .archived: .review
        }
    }
}

/// Las cinco tabs progresivas del dashboard del change.
enum DashboardTab: Int, CaseIterable, Identifiable {
    case explore
    case idea
    case plan
    case work
    case review

    var id: Int { rawValue }

    /// Estado mínimo del change para que la tab sea visible.
    var minState: ChangeState {
        switch self {
        case .explore: .exploring
        case .idea: .idea
        case .plan: .planned
        case .work: .implementing
        case .review: .review
        }
    }

    func label(state: ChangeState) -> String {
        switch self {
        case .explore: String(localized: "Explorar")
        case .idea: String(localized: "Idea")
        case .plan: String(localized: "Plan")
        case .work: String(localized: "Trabajo")
        case .review: state == .archived
            ? String(localized: "Cierre")
            : String(localized: "Revisión")
        }
    }
}

/// Mensaje del chat de exploración.
struct ExploreMessage: Identifiable {
    enum Author { case user, agent }

    let id = UUID()
    let author: Author
    var text: String
    var artifactLink: String?
    var isDecision = false
    /// El agente aún está emitiendo bloques para este mensaje.
    var isStreaming = false
}

/// Artefacto generado por el agente (HTML autocontenido, briefing…).
struct ChangeArtifact: Identifiable {
    let id = UUID()
    let name: String
    let phase: String
    let timeLabel: String
}

/// Unidad de trabajo de Fold. Todo gira en torno a un change.
struct Change: Identifiable {
    let id: String
    var title: String
    var state: ChangeState
    let createdLabel: String
    let origin: String
    let agentLabel: String
    var tasks: [WorkTask]
    var deltas: [Delta]
    var artifacts: [ChangeArtifact]
    let exploreChat: [ExploreMessage]
    var ideaText: String
    var ideaContext: [String]
    let historyStages: [HistoryStage]
    var closingVoices: [ClosingVoice]
    var closureStats: ClosureStats
    let reviewLanes: [ReviewLane]
}
