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
/// Los permisos son una propiedad del sistema, no una súplica en el prompt.
nonisolated enum AgentMode: Sendable, Equatable {
    case explore
    case work
}

/// Lanza el binario del agente en modo headless con salida estructurada
/// (nunca scrapea el TUI) y traduce su stream al contrato canónico.
/// Hereda la autenticación de la sesión CLI existente del usuario.
enum AgentRunner {
    private enum Parser: Sendable {
        case claudeJSON
        case codexJSON
        case plainText
    }

    /// Ejecuta un prompt contra el agente y devuelve el stream de eventos canónicos.
    /// `resumeID` continúa la conversación anterior cuando el CLI lo soporta.
    /// `timeout` mata el proceso si el CLI se cuelga (sin señales durante ese tiempo).
    nonisolated static func stream(
        prompt: String,
        binary: String,
        cwd: URL?,
        mode: AgentMode = .explore,
        resumeID: String? = nil,
        timeout: TimeInterval = 600
    ) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")

            let quoted = ShellRunner.quote(prompt)
            let invocation = headlessCommand(
                binary: binary, quotedPrompt: quoted, mode: mode, resumeID: resumeID
            )
            let parser = invocation.parser
            process.arguments = ["-lc", invocation.command]
            process.environment = ShellRunner.cleanEnvironment()
            process.standardInput = FileHandle.nullDevice
            if let cwd { process.currentDirectoryURL = cwd }

            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err

            let state = StreamState()

            out.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in state.appendStdout(data) {
                    let events: [AgentEvent] = switch parser {
                    case .claudeJSON: parseClaudeLine(line)
                    case .codexJSON: parseCodexLine(line)
                    case .plainText: cleanRawLine(line).map { [.raw($0)] } ?? []
                    }
                    for event in events {
                        state.markEmitted()
                        continuation.yield(event)
                    }
                }
            }

            err.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                state.appendStderr(data)
            }

            // Watchdog: si el proceso sigue vivo pasado el timeout, se termina.
            let watchdog = DispatchWorkItem {
                if process.isRunning {
                    state.markTimedOut()
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

            process.terminationHandler = { proc in
                watchdog.cancel()
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                if state.didTimeOut {
                    continuation.yield(.finished(
                        success: false,
                        result: String(localized: "El agente no respondió en \(Int(timeout / 60)) min y se detuvo la sesión.")
                    ))
                    continuation.finish()
                    return
                }
                // Si el agente no produjo nada útil, el error (stderr) es la respuesta.
                if !state.hasEmitted, let stderrText = state.stderrText() {
                    continuation.yield(.message(stderrText))
                }
                continuation.yield(.finished(success: proc.terminationStatus == 0, result: nil))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                watchdog.cancel()
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
            } catch {
                watchdog.cancel()
                continuation.yield(.finished(success: false, result: error.localizedDescription))
                continuation.finish()
            }
        }
    }

    /// Una pregunta puntual al agente: devuelve solo el texto de respuesta.
    nonisolated static func ask(
        prompt: String,
        binary: String,
        cwd: URL?,
        mode: AgentMode = .explore,
        resumeID: String? = nil,
        timeout: TimeInterval = 300
    ) async -> String {
        var reply = ""
        for await event in stream(prompt: prompt, binary: binary, cwd: cwd, mode: mode, resumeID: resumeID, timeout: timeout) {
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

    // MARK: - Comandos headless por agente

    /// Modo headless de cada CLI soportada, con su parser de salida,
    /// permisos por modo y reanudación de sesión.
    nonisolated private static func headlessCommand(
        binary: String,
        quotedPrompt: String,
        mode: AgentMode,
        resumeID: String?
    ) -> (command: String, parser: Parser) {
        let name = (binary as NSString).lastPathComponent
        let quotedBinary = ShellRunner.quote(binary)
        switch name {
        case "claude":
            // Fold hereda la sesión del CLI, nunca gestiona API keys
            // (el entorno ya llega saneado de variables ANTHROPIC_*/CLAUDE*).
            var flags = "--output-format stream-json --verbose"
            flags += mode == .work ? " --permission-mode acceptEdits" : " --permission-mode plan"
            if let resumeID { flags += " --resume \(ShellRunner.quote(resumeID))" }
            return ("\(quotedBinary) -p \(quotedPrompt) \(flags)", .claudeJSON)

        case "codex":
            let sandbox = mode == .work ? "workspace-write" : "read-only"
            if let resumeID {
                // El subcomando resume no acepta -s: el sandbox va por config (-c).
                let flags = "--json --skip-git-repo-check -c \(ShellRunner.quote("sandbox_mode=\"\(sandbox)\""))"
                return ("\(quotedBinary) exec resume \(flags) \(ShellRunner.quote(resumeID)) \(quotedPrompt)", .codexJSON)
            }
            return ("\(quotedBinary) exec --json --skip-git-repo-check -s \(sandbox) \(quotedPrompt)", .codexJSON)

        case "cursor-agent":
            var flags = "--output-format text"
            if mode == .work { flags += " -f" }
            if let resumeID { flags += " --resume \(ShellRunner.quote(resumeID))" }
            return ("\(quotedBinary) -p \(quotedPrompt) \(flags)", .plainText)

        case "opencode":
            var flags = ""
            if let resumeID { flags = "-s \(ShellRunner.quote(resumeID)) " }
            return ("\(quotedBinary) run \(flags)\(quotedPrompt)", .plainText)

        default:
            return ("\(quotedBinary) \(quotedPrompt)", .plainText)
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

    nonisolated private static func parseClaudeLine(_ line: String) -> [AgentEvent] {
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

    nonisolated private static func parseCodexLine(_ line: String) -> [AgentEvent] {
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
            return [.message(message)]

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

/// Estado compartido del stream: buffer de líneas, stderr y si ya se emitió algo.
nonisolated private final class StreamState: @unchecked Sendable {
    private var pendingStdout = Data()
    private var stderrData = Data()
    private var emitted = false
    private let lock = NSLock()

    private var timedOut = false

    var hasEmitted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return emitted
    }

    func markEmitted() {
        lock.lock()
        emitted = true
        lock.unlock()
    }

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func appendStdout(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pendingStdout.append(data)
        var lines: [String] = []
        while let newlineIndex = pendingStdout.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = pendingStdout.prefix(upTo: newlineIndex)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
            pendingStdout.removeSubrange(...newlineIndex)
        }
        return lines
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderrData.append(data)
        lock.unlock()
    }

    /// El stderr filtrado (sin trazas de log), si contiene algo legible.
    func stderrText() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = String(data: stderrData, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("ERROR rmcp") && !$0.hasPrefix("20") }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(600))
    }
}
