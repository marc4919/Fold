import Foundation

/// Check secuencial de la pantalla de Setup.
struct SetupCheck: Identifiable {
    enum State {
        case pending
        case running
        case waitingConfirmation
        case done
    }

    let id: Int
    let name: String
    let pendingDetail: String
    let runningDetail: String
    let doneDetail: String
    var state: State = .pending

    var detail: String {
        switch state {
        case .pending: pendingDetail
        case .running: runningDetail
        case .waitingConfirmation: runningDetail
        case .done: doneDetail
        }
    }

    var actionLabel: String {
        switch state {
        case .pending: String(localized: "en cola")
        case .running: String(localized: "analizando")
        case .waitingConfirmation: String(localized: "esperando")
        case .done: String(localized: "listo")
        }
    }
}
