import Foundation

/// Transiciones válidas del ciclo de vida de un change. La state machine es
/// pura y testeable: la sesión le pregunta antes de moverse y las transiciones
/// imposibles se rechazan en vez de dejar la UI en un estado mentiroso.
enum ChangeStateMachine {
    /// Un change avanza de fase en fase; el único retroceso permitido es
    /// Revisión → Trabajo (iterar con feedback).
    nonisolated static func canTransition(from current: ChangeState, to target: ChangeState) -> Bool {
        if target == current { return false }
        // Avance de exactamente una fase.
        if target.rawValue == current.rawValue + 1 { return true }
        // Iterar: de la revisión se vuelve a implementar.
        if current == .review, target == .implementing { return true }
        // La demo permite saltar hacia delante (entrar en un estado avanzado).
        return false
    }

    /// Variante para la demo: los saltos hacia delante están permitidos
    /// (abrir el change de ejemplo directamente en review, p. ej.).
    nonisolated static func canTransitionInDemo(from current: ChangeState, to target: ChangeState) -> Bool {
        target != current && (target > current || (current == .review && target == .implementing))
    }
}
