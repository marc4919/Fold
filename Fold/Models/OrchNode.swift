import Foundation
import CoreGraphics

/// Nodo del diagrama de orquestación: tronco secuencial → abanico paralelo → convergencia.
struct OrchNode: Identifiable {
    enum Column {
        case trunk
        case fan
        case merge
    }

    enum Status {
        case pending
        case running
        case done
    }

    let id: String
    let agentLabel: String
    let taskLabel: String
    let column: Column
    var status: Status
    /// Posición fija en el lienzo 820×330 (como el SVG del prototipo).
    let position: CGPoint
}
