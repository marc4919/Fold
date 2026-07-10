import Foundation

/// Contrato de eventos interno canónico de Fold.
/// Cada agente (headless hoy, ACP mañana) se traduce a estos eventos —
/// la UI nunca conoce el formato nativo de cada CLI.
enum AgentEvent: Sendable {
    case started(sessionID: String)
    case thought(String)
    case message(String)
    case toolUse(name: String, detail: String)
    case fileChanged(path: String, created: Bool)
    case raw(String)
    case usage(outputTokens: Int)
    case finished(success: Bool, result: String?)
}

/// Modo de la sesión: explorar no puede tocar archivos; trabajar sí.
/// Los permisos son una propiedad del sistema (flags/sandbox del CLI),
/// no una súplica en el prompt.
nonisolated enum AgentMode: Sendable, Equatable {
    case explore
    case work
}

/// Asa de una ejecución en curso: permite detener el proceso del agente
/// (y sus descendientes) y ESPERAR a que muera, no solo dispararlo.
nonisolated final class AgentRunHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var process: SupervisedProcess?

    func attach(_ supervised: SupervisedProcess) {
        lock.lock()
        process = supervised
        lock.unlock()
    }

    /// Cancelación estructurada: vuelve cuando el proceso ha terminado de verdad.
    func stopAndWait() async {
        lock.lock()
        let supervised = process
        lock.unlock()
        await supervised?.cancel()
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let process else { return false }
        return !process.currentState.isTerminal
    }
}

/// Lanza el binario del agente en modo headless con salida estructurada
/// (nunca scrapea el TUI) y traduce su stream al contrato canónico.
/// Hereda la autenticación de la sesión CLI existente del usuario.
/// Ejecuta binario + argumentos directamente vía ProcessSupervisor: sin shell,
/// con grupo de procesos propio, buffers acotados y timeout por inactividad.
enum AgentRunner {
    private enum Parser: Sendable {
        case claudeJSON
        case codexJSON
        case plainText
    }

    /// Ejecuta un prompt contra el agente y devuelve el stream de eventos canónicos.
    /// `resumeID` continúa la conversación anterior cuando el CLI lo soporta.
    /// `timeout` es de INACTIVIDAD: se reinicia con cada señal de vida del proceso.
    /// Emite exactamente un `.finished` por ejecución.
    nonisolated static func stream(
        prompt: String,
        binary: String,
        cwd: URL?,
        mode: AgentMode = .explore,
        resumeID: String? = nil,
        timeout: TimeInterval = 600,
        handle: AgentRunHandle? = nil
    ) -> AsyncStream<AgentEvent> {
        // Fail closed: sin capacidades conocidas no hay ejecución con permisos implícitos.
        guard let capabilities = AgentCapabilities.forBinary(binary) else {
            return refusalStream(String(localized: "CLI no soportada: \((binary as NSString).lastPathComponent). Fold solo ejecuta agentes con capacidades conocidas."))
        }
        if mode == .explore, !capabilities.guaranteedReadOnly {
            return refusalStream(capabilities.readOnlyExplanation
                ?? String(localized: "Este agente no garantiza un modo de solo lectura."))
        }
        guard let invocation = headlessInvocation(
            binary: binary, prompt: prompt, mode: mode, resumeID: resumeID
        ) else {
            return refusalStream(String(localized: "CLI no soportada: \((binary as NSString).lastPathComponent)."))
        }

        let process = SupervisedProcess(config: .init(
            executable: binary,
            arguments: invocation.arguments,
            cwd: cwd,
            inactivityTimeout: timeout,
            hardTimeout: max(timeout * 4, 3600)
        ))
        handle?.attach(process)
        let parser = invocation.parser

        return AsyncStream { continuation in
            // El .finished del parser (p. ej. "result" de claude) se retiene hasta
            // conocer el estado terminal real del proceso: un solo .finished, veraz.
            let box = FinishedBox()

            let pump = Task.detached {
                for await event in process.events {
                    switch event {
                    case .stdoutLine(let line):
                        let events: [AgentEvent] = switch parser {
                        case .claudeJSON: parseClaudeLine(line)
                        case .codexJSON: parseCodexLine(line)
                        case .plainText: cleanRawLine(line).map { [.raw($0)] } ?? []
                        }
                        for event in events {
                            if case .finished(let success, let result) = event {
                                box.store(success: success, result: result)
                            } else {
                                box.markEmitted()
                                continuation.yield(event)
                            }
                        }

                    case .terminated(let result):
                        switch result.state {
                        case .succeeded:
                            let stored = box.stored
                            continuation.yield(.finished(
                                success: stored?.success ?? true,
                                result: stored?.result
                            ))
                        case .timedOut:
                            continuation.yield(.finished(
                                success: false,
                                result: String(localized: "El agente no dio señales de vida durante \(Int(timeout / 60)) min y se detuvo la sesión.")
                            ))
                        case .cancelled:
                            continuation.yield(.finished(
                                success: false,
                                result: String(localized: "Sesión cancelada.")
                            ))
                        case .failed(let code):
                            // Si no llegó nada útil, el stderr es la explicación.
                            if !box.emitted, !result.stderrTail.isEmpty {
                                continuation.yield(.message(String(result.stderrTail.prefix(600))))
                            }
                            continuation.yield(.finished(
                                success: false,
                                result: box.stored?.result
                                    ?? String(localized: "El agente terminó con código \(code).")
                            ))
                        default:
                            continuation.yield(.finished(success: false, result: nil))
                        }
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                pump.cancel()
                Task.detached { await process.cancel() }
            }

            process.start()
        }
    }

    /// Una pregunta puntual al agente: devuelve solo el texto de respuesta.
    nonisolated static func ask(
        prompt: String,
        binary: String,
        cwd: URL?,
        mode: AgentMode = .explore,
        resumeID: String? = nil,
        timeout: TimeInterval = 300,
        handle: AgentRunHandle? = nil
    ) async -> String {
        var reply = ""
        for await event in stream(prompt: prompt, binary: binary, cwd: cwd, mode: mode, resumeID: resumeID, timeout: timeout, handle: handle) {
            switch event {
            case .message(let text):
                reply += (reply.isEmpty ? "" : "\n") + text
            case .raw(let line):
                reply += (reply.isEmpty ? "" : "\n") + line
            case .finished(let success, let result):
                if !success, reply.isEmpty {
                    reply = result ?? String(localized: "El agente no respondió. Comprueba que su CLI funciona en tu terminal.")
                }
            default:
                break
            }
        }
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stream que rechaza la operación con una explicación: fail closed, sin proceso.
    nonisolated private static func refusalStream(_ reason: String) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            continuation.yield(.finished(success: false, result: reason))
            continuation.finish()
        }
    }

    // MARK: - Invocación headless por agente (argv directo, sin shell)

    nonisolated private static func headlessInvocation(
        binary: String,
        prompt: String,
        mode: AgentMode,
        resumeID: String?
    ) -> (arguments: [String], parser: Parser)? {
        switch (binary as NSString).lastPathComponent {
        case "claude":
            // Fold hereda la sesión del CLI, nunca gestiona API keys
            // (el entorno ya llega saneado de variables ANTHROPIC_*/CLAUDE*).
            var args = ["-p", prompt, "--output-format", "stream-json", "--verbose"]
            args += ["--permission-mode", mode == .work ? "acceptEdits" : "plan"]
            if let resumeID { args += ["--resume", resumeID] }
            return (args, .claudeJSON)

        case "codex":
            let sandbox = mode == .work ? "workspace-write" : "read-only"
            if let resumeID {
                // El subcomando resume no acepta -s: el sandbox va por config (-c).
                return (["exec", "resume", "--json", "--skip-git-repo-check",
                         "-c", "sandbox_mode=\"\(sandbox)\"", resumeID, prompt], .codexJSON)
            }
            return (["exec", "--json", "--skip-git-repo-check", "-s", sandbox, prompt], .codexJSON)

        case "cursor-agent":
            // Solo modo work: explorar se rechaza antes (sin read-only garantizado).
            var args = ["-p", prompt, "--output-format", "text"]
            if mode == .work { args.append("-f") }
            if let resumeID { args += ["--resume", resumeID] }
            return (args, .plainText)

        case "opencode":
            // Explorar usa el agente integrado "plan": sin herramientas de escritura.
            var args = ["run"]
            if mode == .explore { args += ["--agent", "plan"] }
            if let resumeID { args += ["-s", resumeID] }
            args.append(prompt)
            return (args, .plainText)

        default:
            return nil
        }
    }

    /// Limpia escapes ANSI y ruido de banner de la salida en texto plano.
    nonisolated private static func cleanRawLine(_ line: String) -> String? {
        var clean = line.replacingOccurrences(
            of: "\u{1B}\\[[0-9;?]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        clean = clean.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, !clean.hasPrefix(">") else { return nil }
        return clean
    }

    // MARK: - Traducción del stream-json de Claude Code

    nonisolated static func parseClaudeLine(_ line: String) -> [AgentEvent] {
        guard let json = decodeJSON(line), let type = json["type"] as? String else { return [] }

        switch type {
        case "system":
            if json["subtype"] as? String == "init", let session = json["session_id"] as? String {
                return [.started(sessionID: session)]
            }
            return []

        case "assistant":
            guard let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { return [] }
            var events: [AgentEvent] = []
            for block in content {
                switch block["type"] as? String {
                case "thinking":
                    if let text = block["thinking"] as? String, !text.isEmpty {
                        events.append(.thought(text))
                    }
                case "text":
                    if let text = block["text"] as? String, !text.isEmpty {
                        events.append(.message(text))
                    }
                case "tool_use":
                    let name = block["name"] as? String ?? "tool"
                    let input = block["input"] as? [String: Any] ?? [:]
                    if let path = input["file_path"] as? String {
                        events.append(.fileChanged(path: path, created: name == "Write"))
                    } else {
                        let detail = (input["command"] as? String)
                            ?? (input["pattern"] as? String)
                            ?? (input["query"] as? String)
                            ?? (input["description"] as? String)
                            ?? ""
                        events.append(.toolUse(name: name, detail: detail))
                    }
                default:
                    break
                }
            }
            return events

        case "result":
            var events: [AgentEvent] = []
            if let usage = json["usage"] as? [String: Any],
               let output = usage["output_tokens"] as? Int {
                events.append(.usage(outputTokens: output))
            }
            let success = (json["subtype"] as? String) == "success"
            events.append(.finished(success: success, result: json["result"] as? String))
            return events

        default:
            return []
        }
    }

    // MARK: - Traducción del JSONL de Codex (exec --json)

    nonisolated static func parseCodexLine(_ line: String) -> [AgentEvent] {
        guard let json = decodeJSON(line), let type = json["type"] as? String else { return [] }

        switch type {
        case "thread.started":
            if let thread = json["thread_id"] as? String {
                return [.started(sessionID: thread)]
            }
            return []

        case "item.completed", "item.started":
            guard type == "item.completed",
                  let item = json["item"] as? [String: Any] else { return [] }
            switch item["type"] as? String {
            case "agent_message":
                if let text = item["text"] as? String, !text.isEmpty {
                    return [.message(text)]
                }
            case "reasoning":
                if let text = item["text"] as? String, !text.isEmpty {
                    return [.thought(text)]
                }
            case "command_execution":
                let command = (item["command"] as? String) ?? ""
                return [.toolUse(name: "shell", detail: command)]
            case "file_change":
                if let changes = item["changes"] as? [[String: Any]] {
                    return changes.compactMap { change in
                        guard let path = change["path"] as? String else { return nil }
                        return .fileChanged(path: path, created: (change["kind"] as? String) == "add")
                    }
                }
            case "mcp_tool_call", "web_search", "todo_list":
                return [.toolUse(name: item["type"] as? String ?? "tool", detail: "")]
            default:
                break
            }
            return []

        case "turn.completed":
            var events: [AgentEvent] = []
            if let usage = json["usage"] as? [String: Any],
               let output = usage["output_tokens"] as? Int {
                events.append(.usage(outputTokens: output))
            }
            return events

        case "turn.failed", "error":
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? json["message"] as? String
                ?? String(localized: "El agente terminó con un error.")
            return [.message(message), .finished(success: false, result: message)]

        default:
            return []
        }
    }

    nonisolated private static func decodeJSON(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

/// El .finished del parser se retiene hasta el estado terminal real del proceso.
nonisolated private final class FinishedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _stored: (success: Bool, result: String?)?
    private var _emitted = false

    var stored: (success: Bool, result: String?)? {
        lock.lock(); defer { lock.unlock() }
        return _stored
    }

    var emitted: Bool {
        lock.lock(); defer { lock.unlock() }
        return _emitted
    }

    func store(success: Bool, result: String?) {
        lock.lock()
        // El primer resultado con texto gana; un fallo posterior no se pisa por un éxito.
        if _stored == nil || (_stored?.success == true && !success) {
            _stored = (success, result)
        }
        lock.unlock()
    }

    func markEmitted() {
        lock.lock(); _emitted = true; lock.unlock()
    }
}
