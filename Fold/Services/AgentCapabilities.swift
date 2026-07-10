import Foundation

/// Matriz de capacidades por CLI. Una operación solo se ofrece si la CLI la
/// garantiza; si no, la UI la deshabilita y explica por qué. Sin fallback
/// genérico: una CLI desconocida no se ejecuta con permisos implícitos.
nonisolated struct AgentCapabilities: Sendable {
    /// Cómo comprobar la autenticación real (- -version no basta).
    nonisolated enum AuthCheck: Sendable {
        /// Comando cuyo exit 0 (y opcionalmente un texto) confirma sesión.
        case command(arguments: [String], successContains: String?)
        /// Ítem del llavero del sistema que existe solo con sesión iniciada.
        case keychainItem(service: String)
        /// Archivo de credenciales de la CLI.
        case credentialFile(relativeToHome: String)
        /// No hay forma fiable de comprobarlo sin gastar tokens.
        case unverifiable
    }

    let structuredOutput: Bool
    /// Puede reanudar una conversación anterior (session/thread id).
    let supportsResume: Bool
    /// Explorar garantizado de solo lectura (modo/sandbox del propio CLI).
    let guaranteedReadOnly: Bool
    /// Modo escritura soportado en headless.
    let supportsWrite: Bool
    /// El CLI aporta su propio sandbox de SO en escritura.
    let osSandbox: Bool
    let authCheck: AuthCheck
    let loginHint: String
    /// Por qué explorar está deshabilitado, si lo está.
    var readOnlyExplanation: String?

    /// La matriz es cerrada: nil para binarios desconocidos.
    static func forBinary(_ binary: String) -> AgentCapabilities? {
        switch (binary as NSString).lastPathComponent {
        case "claude":
            AgentCapabilities(
                structuredOutput: true,
                supportsResume: true,
                guaranteedReadOnly: true,   // --permission-mode plan
                supportsWrite: true,        // --permission-mode acceptEdits
                osSandbox: false,
                authCheck: .keychainItem(service: "Claude Code-credentials"),
                loginHint: String(localized: "Ejecuta `claude` en tu terminal y usa /login")
            )
        case "codex":
            AgentCapabilities(
                structuredOutput: true,
                supportsResume: true,
                guaranteedReadOnly: true,   // -s read-only (sandbox de SO)
                supportsWrite: true,        // -s workspace-write
                osSandbox: true,
                authCheck: .command(arguments: ["login", "status"], successContains: nil),
                loginHint: String(localized: "Ejecuta `codex login` en tu terminal")
            )
        case "opencode":
            AgentCapabilities(
                structuredOutput: false,
                supportsResume: true,
                guaranteedReadOnly: true,   // --agent plan (agente sin herramientas de escritura)
                supportsWrite: true,
                osSandbox: false,
                authCheck: .credentialFile(relativeToHome: ".local/share/opencode/auth.json"),
                loginHint: String(localized: "Ejecuta `opencode auth login` en tu terminal")
            )
        case "cursor-agent":
            AgentCapabilities(
                structuredOutput: false,
                supportsResume: true,
                guaranteedReadOnly: false,  // sin modo de solo lectura garantizado en headless
                supportsWrite: true,        // -f
                osSandbox: false,
                authCheck: .command(arguments: ["status"], successContains: "ogged in"),
                loginHint: String(localized: "Ejecuta `cursor-agent login` en tu terminal"),
                readOnlyExplanation: String(localized: "Cursor CLI no garantiza un modo de solo lectura en headless; Explorar está deshabilitado con este agente. Usa Claude Code, Codex u OpenCode para explorar.")
            )
        default:
            nil
        }
    }

    /// Comprueba la autenticación real de la CLI. Devuelve nil si no es verificable.
    func verifyAuthentication(binary: String) async -> Bool? {
        switch authCheck {
        case .command(let arguments, let successContains):
            let process = SupervisedProcess(config: .init(
                executable: binary,
                arguments: arguments,
                inactivityTimeout: 15,
                hardTimeout: 20
            ))
            var output = ""
            process.start()
            var result: RunResult?
            for await event in process.events {
                switch event {
                case .stdoutLine(let line): output += line + "\n"
                case .terminated(let r): result = r
                }
            }
            guard let result else { return false }
            guard result.state == .succeeded else { return false }
            if let successContains {
                return output.contains(successContains) || result.stderrTail.contains(successContains)
            }
            return true

        case .keychainItem(let service):
            let process = SupervisedProcess(config: .init(
                executable: "/usr/bin/security",
                arguments: ["find-generic-password", "-s", service],
                inactivityTimeout: 10,
                hardTimeout: 15
            ))
            process.start()
            let result = await process.waitUntilExit()
            return result.state == .succeeded

        case .credentialFile(let relative):
            let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: url), data.count > 2 else { return false }
            return true

        case .unverifiable:
            return nil
        }
    }
}
