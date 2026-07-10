import Foundation

/// CLI de agente soportada (Claude Code, Codex, Cursor, OpenCode).
struct AgentCLI: Identifiable {
    let id: String
    let name: String
    let abbreviation: String
    let version: String?
    let isDetected: Bool
    var isSelected = false
    var isDefault = false
    /// Ruta real del binario en la máquina (detección real).
    var binaryPath: String?

    var versionLabel: String {
        if let version { "\(name) \(version)" } else { name }
    }
}

/// Resultado del onboarding, editable después en Ajustes de usuario.
struct UserProfile {
    var name = ""
    var roles: Set<String> = []
    var clis: [AgentCLI] = []
    /// Contexto libre sobre preferencias que los agentes reciben en cada prompt.
    var preferences = ""

    static let roleOptions: [String] = [
        String(localized: "Backend"),
        String(localized: "Frontend"),
        String(localized: "Fullstack"),
        String(localized: "Mobile"),
        String(localized: "Infra / DevOps"),
        String(localized: "Data / ML"),
        String(localized: "Diseño / Producto"),
    ]
}
