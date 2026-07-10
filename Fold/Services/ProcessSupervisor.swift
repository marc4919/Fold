import Foundation
import Darwin

/// Estado de una ejecución supervisada. Exactamente un estado terminal por ejecución.
nonisolated enum RunState: Sendable, Equatable {
    case idle
    case starting
    case running
    case stopping
    case succeeded
    case failed(exitCode: Int32)
    case cancelled
    case timedOut

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .timedOut: true
        default: false
        }
    }
}

/// Resultado terminal único de una ejecución.
nonisolated struct RunResult: Sendable {
    let state: RunState
    let stderrTail: String
}

/// Evento emitido por el supervisor.
nonisolated enum SupervisedEvent: Sendable {
    case stdoutLine(String)
    case terminated(RunResult)
}

/// Supervisor de procesos: ejecuta binario + argumentos directamente (sin shell),
/// en un grupo de procesos propio para poder terminar también a los descendientes.
/// Buffers acotados, timeout por inactividad reiniciado con cada señal de vida,
/// y exactamente un evento terminal por ejecución.
nonisolated final class SupervisedProcess: @unchecked Sendable {
    nonisolated struct Config: Sendable {
        var executable: String
        var arguments: [String]
        var cwd: URL?
        var environment: [String: String]
        /// Sin actividad (stdout/stderr) durante este tiempo → timedOut.
        var inactivityTimeout: TimeInterval
        /// Tope absoluto de la ejecución, actividad aparte.
        var hardTimeout: TimeInterval

        init(
            executable: String,
            arguments: [String],
            cwd: URL? = nil,
            environment: [String: String] = ProcessEnvironment.resolved(),
            inactivityTimeout: TimeInterval = 180,
            hardTimeout: TimeInterval = 1800
        ) {
            self.executable = executable
            self.arguments = arguments
            self.cwd = cwd
            self.environment = environment
            self.inactivityTimeout = inactivityTimeout
            self.hardTimeout = hardTimeout
        }
    }

    // Límites de memoria: nada de retener salidas sin tope.
    private static let maxLineBytes = 32_768
    private static let maxPendingBytes = 1_048_576
    private static let maxStderrBytes = 65_536

    private let config: Config
    private let lock = NSLock()
    private var state: RunState = .idle
    private var pid: pid_t = -1
    private var pendingStdout = Data()
    private var stderrTail = Data()
    private var lastActivity = Date.now
    private var terminalSent = false
    private var timeoutFired = false
    private var continuation: AsyncStream<SupervisedEvent>.Continuation?

    let events: AsyncStream<SupervisedEvent>

    init(config: Config) {
        self.config = config
        var captured: AsyncStream<SupervisedEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
    }

    var currentState: RunState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    /// Lanza el proceso. Falla cerrado: cualquier error de arranque produce
    /// el evento terminal .failed sin dejar nada corriendo.
    func start() {
        lock.lock()
        guard state == .idle else { lock.unlock(); return }
        state = .starting
        lock.unlock()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_addopen(&fileActions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe.fileHandleForWriting.fileDescriptor, 1)
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe.fileHandleForWriting.fileDescriptor, 2)
        if let cwd = config.cwd {
            posix_spawn_file_actions_addchdir_np(&fileActions, cwd.path)
        }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Grupo de procesos propio (pgid = pid del hijo): killpg alcanza a los descendientes.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)

        // PWD debe contar la verdad: hay CLIs (p. ej. opencode) que detectan la
        // raíz del proyecto por $PWD y no por el cwd real. Un PWD heredado de
        // quien lanzó la app apuntaría al repo equivocado.
        var environment = config.environment
        if let cwd = config.cwd {
            environment["PWD"] = cwd.path
        } else {
            environment.removeValue(forKey: "PWD")
        }
        environment.removeValue(forKey: "OLDPWD")

        let argv: [UnsafeMutablePointer<CChar>?] =
            ([config.executable] + config.arguments).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] =
            environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var childPID: pid_t = 0
        let spawnResult = posix_spawn(&childPID, config.executable, &fileActions, &attributes, argv, envp)

        // El padre no usa los extremos de escritura.
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()

        guard spawnResult == 0 else {
            let message = String(cString: strerror(spawnResult))
            sendTerminal(.failed(exitCode: -1), stderrOverride: "No se pudo lanzar \(config.executable): \(message)")
            return
        }

        lock.lock()
        pid = childPID
        state = .running
        lastActivity = .now
        lock.unlock()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.touch()
            for line in self.bufferStdout(data) {
                self.continuation?.yield(.stdoutLine(line))
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.touch()
            self.appendStderr(data)
        }

        scheduleWatchdogs()

        // waitpid en hilo propio: única fuente del evento terminal en el camino normal.
        Thread.detachNewThread { [weak self] in
            var status: Int32 = 0
            while waitpid(childPID, &status, 0) == -1 && errno == EINTR { continue }
            guard let self else { return }

            // Drena lo que quede en los pipes antes de cerrar.
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            if let rest = try? stdoutPipe.fileHandleForReading.readToEnd(), !rest.isEmpty {
                for line in self.bufferStdout(rest, flush: true) {
                    self.continuation?.yield(.stdoutLine(line))
                }
            } else {
                for line in self.bufferStdout(Data(), flush: true) {
                    self.continuation?.yield(.stdoutLine(line))
                }
            }
            if let rest = try? stderrPipe.fileHandleForReading.readToEnd(), !rest.isEmpty {
                self.appendStderr(rest)
            }

            self.lock.lock()
            let wasCancelled = self.state == .stopping
            let didTimeOut = self.timeoutFired
            self.lock.unlock()

            let finalState: RunState
            if didTimeOut {
                finalState = .timedOut
            } else if wasCancelled {
                finalState = .cancelled
            } else if WIFEXITED(status) && WEXITSTATUS(status) == 0 {
                finalState = .succeeded
            } else if WIFEXITED(status) {
                finalState = .failed(exitCode: WEXITSTATUS(status))
            } else {
                // Terminado por señal externa (no nuestra): fallo, no éxito.
                finalState = .failed(exitCode: -WTERMSIG(status))
            }
            self.sendTerminal(finalState)
        }
    }

    /// Cancelación estructurada: SIGTERM al grupo, gracia, SIGKILL, y espera
    /// a que waitpid confirme la muerte antes de devolver el control.
    func cancel() async {
        lock.lock()
        guard state == .running || state == .starting else { lock.unlock(); return }
        state = .stopping
        let group = pid
        lock.unlock()

        guard group > 0 else { return }
        killpg(group, SIGTERM)

        // Gracia de 3 s; si el grupo sigue vivo, SIGKILL.
        for _ in 0..<30 {
            if currentState.isTerminal { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        killpg(group, SIGKILL)
        for _ in 0..<50 {
            if currentState.isTerminal { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Espera el resultado terminal consumiendo (y descartando) los eventos restantes.
    func waitUntilExit() async -> RunResult {
        for await event in events {
            if case .terminated(let result) = event { return result }
        }
        return RunResult(state: currentState, stderrTail: stderrText())
    }

    // MARK: - Internos

    private func touch() {
        lock.lock()
        lastActivity = .now
        lock.unlock()
    }

    private func scheduleWatchdogs() {
        let start = Date.now
        Thread.detachNewThread { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 2)
                guard let self else { return }
                self.lock.lock()
                let running = self.state == .running
                let idle = Date.now.timeIntervalSince(self.lastActivity)
                let total = Date.now.timeIntervalSince(start)
                let group = self.pid
                let inactivity = self.config.inactivityTimeout
                let hard = self.config.hardTimeout
                self.lock.unlock()

                guard running else { return }
                if idle > inactivity || total > hard {
                    self.lock.lock()
                    self.timeoutFired = true
                    self.lock.unlock()
                    if group > 0 {
                        killpg(group, SIGTERM)
                        Thread.sleep(forTimeInterval: 3)
                        if !self.currentState.isTerminal { killpg(group, SIGKILL) }
                    }
                    return
                }
            }
        }
    }

    private func bufferStdout(_ data: Data, flush: Bool = false) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pendingStdout.append(data)
        // Tope del buffer pendiente: una "línea" interminable no debe crecer sin límite.
        if pendingStdout.count > Self.maxPendingBytes {
            pendingStdout = pendingStdout.suffix(Self.maxLineBytes)
        }
        var lines: [String] = []
        while let newline = pendingStdout.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = pendingStdout.prefix(upTo: newline).prefix(Self.maxLineBytes)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
            pendingStdout.removeSubrange(...newline)
        }
        if flush, !pendingStdout.isEmpty {
            let lineData = pendingStdout.prefix(Self.maxLineBytes)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
            pendingStdout.removeAll()
        }
        return lines
    }

    private func appendStderr(_ data: Data) {
        lock.lock()
        stderrTail.append(data)
        if stderrTail.count > Self.maxStderrBytes {
            stderrTail = stderrTail.suffix(Self.maxStderrBytes / 2)
        }
        lock.unlock()
    }

    func stderrText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: stderrTail, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Emite el único evento terminal permitido y cierra el stream.
    private func sendTerminal(_ finalState: RunState, stderrOverride: String? = nil) {
        lock.lock()
        guard !terminalSent else { lock.unlock(); return }
        terminalSent = true
        state = finalState
        lock.unlock()

        continuation?.yield(.terminated(RunResult(
            state: finalState,
            stderrTail: stderrOverride ?? stderrText()
        )))
        continuation?.finish()
        continuation = nil
    }
}

/// Entorno de los procesos hijos: saneado (sin ANTHROPIC_*/CLAUDE*) y con el PATH
/// real de login del usuario, resuelto una sola vez al arrancar.
nonisolated enum ProcessEnvironment {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var loginPATH: String?

    /// Se llama una vez al arrancar la app (junto a la detección de agentes).
    static func captureLoginPATH() async {
        let result = await ShellRunner.run("echo $PATH")
        let path = result.trimmedOutput
        guard !path.isEmpty else { return }
        lock.lock()
        loginPATH = path
        lock.unlock()
    }

    static func resolved() -> [String: String] {
        var environment = ShellRunner.cleanEnvironment()
        lock.lock()
        let captured = loginPATH
        lock.unlock()
        if let captured {
            environment["PATH"] = captured
        } else {
            // Fallback razonable si aún no se capturó el PATH de login.
            let current = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            environment["PATH"] = current + ":/opt/homebrew/bin:/usr/local/bin:" + NSHomeDirectory() + "/.local/bin"
        }
        return environment
    }
}

// posix_spawn no exporta estas macros a Swift: equivalentes de <sys/wait.h>.
nonisolated private func WIFEXITED(_ status: Int32) -> Bool { (status & 0x7f) == 0 }
nonisolated private func WEXITSTATUS(_ status: Int32) -> Int32 { (status >> 8) & 0xff }
nonisolated private func WTERMSIG(_ status: Int32) -> Int32 { status & 0x7f }
