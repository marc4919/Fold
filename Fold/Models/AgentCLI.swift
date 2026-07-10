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
    /// Autenticación real comprobada (llavero/credenciales/comando de estado).
    /// nil = no verificable sin gastar tokens.
    var isAuthenticated: Bool?

    var versionLabel: String {
        if let version { "\(name) \(version)" } else { name }
    }

    var capabilities: AgentCapabilities? {
        binaryPath.flatMap { AgentCapabilities.forBinary($0) }
    }

    /// Etiqueta honesta del estado de sesión para la UI.
    var authLabel: String {
        switch isAuthenticated {
        case .some(true): String(localized: "sesión activa")
        case .some(false): String(localized: "sin sesión — requiere login")
        case .none: String(localized: "sesión sin verificar")
        }
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
