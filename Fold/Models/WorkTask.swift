import Foundation

/// Tarea de un change (número OPSX tipo "1.1").
/// No se llama `Task` para no colisionar con Swift Concurrency.
struct WorkTask: Identifiable {
    enum Lane {
        /// Tronco secuencial: deben ejecutarse en orden.
        case trunk
        /// Abanico paralelo: pueden repartirse entre agentes.
        case fan
    }

    let id: String
    let title: String
    let group: String
    let lane: Lane
    var done = false
}
