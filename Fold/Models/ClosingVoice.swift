import Foundation

/// Una de las tres voces del panel de cierre: el mismo cambio
/// contado a tres audiencias distintas.
struct ClosingVoice: Identifiable {
    enum Kind {
        case commit
        case ticket
        case team
    }

    let id = UUID()
    let kind: Kind
    let icon: String
    let title: String
    let audience: String
    var ruleBadge: String?
    var content: String
    let primaryActionLabel: String
    let footnote: String
    /// Adjuntar/enviar requiere confirmación explícita del usuario.
    let needsConfirmation: Bool
}

/// Stats del cierre post-merge.
struct ClosureStats {
    let archivedAtLabel: String
    let durationValue: String
    let durationDetail: String
    let tokensValue: String
    let tokensDetail: String
    let filesValue: String
    let filesDetail: String
    let committedItems: [String]
    let commitSHA: String
    let commitMessage: String
    let learnedItems: [String]
    let archivePath: String
}
