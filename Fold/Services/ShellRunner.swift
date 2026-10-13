import Foundation

nonisolated struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var ok: Bool { exitCode == 0 }
    var trimmedOutput: String { stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Ejecuta comandos en una zsh de login para heredar el PATH y el entorno del usuario
/// (la misma fontanería de auth que usan sus CLIs en la terminal).
enum ShellRunner {
    /// Entorno saneado: sin variables ANTHROPIC_*/CLAUDE* heredadas de quien
    /// lanzó la app (p. ej. otro agente). El CLI debe usar su propia sesión.
    nonisolated static func cleanEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in environment.keys where key.hasPrefix("ANTHROPIC_") || key.hasPrefix("CLAUDE") {
            environment.removeValue(forKey: key)
        }
        return environment
    }

    /// Entorno de los comandos propios de Fold (git, wc…), no de los agentes:
    /// pathspecs SIEMPRE literales — un archivo llamado `*` o `:(top)x` no puede
    /// ampliar un `git add`/`git commit` — y git nunca pide credenciales por TTY.
    nonisolated static func commandEnvironment() -> [String: String] {
        var environment = cleanEnvironment()
        environment["GIT_LITERAL_PATHSPECS"] = "1"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        return environment
    }

    /// `timeout` corta el comando (y su grupo) si no termina: un hook de git o un
    /// prompt de GPG no pueden colgar la app.
    nonisolated static func run(_ command: String, cwd: URL? = nil, timeout: TimeInterval = 120) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.environment = commandEnvironment()
                process.standardInput = FileHandle.nullDevice
                if let cwd { process.currentDirectoryURL = cwd }

                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ShellResult(
                        stdout: "", stderr: error.localizedDescription, exitCode: -1
                    ))
                    return
                }

                // Ambos pipes se drenan en paralelo: leer uno hasta EOF mientras el otro
                // se llena es el deadlock clásico de Process.
                let group = DispatchGroup()
                var outData = Data()
                var errData = Data()

                group.enter()
                DispatchQueue.global().async {
                    outData = out.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    errData = err.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                let timedOut = TimeoutFlag()
                let watchdog = DispatchWorkItem { [process] in
                    guard process.isRunning else { return }
                    timedOut.set()
                    kill(process.processIdentifier, SIGKILL)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

                process.waitUntilExit()
                watchdog.cancel()
                // Un nieto que herede los pipes no debe bloquear la lectura para siempre.
                _ = group.wait(timeout: .now() + 5)

                var stderr = String(data: errData, encoding: .utf8) ?? ""
                if timedOut.isSet {
                    stderr += String(localized: "\nEl comando superó \(Int(timeout)) s y se detuvo.")
                }
                continuation.resume(returning: ShellResult(
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: stderr,
                    exitCode: process.terminationStatus
                ))
            }
        }
    }

    /// Escapa un argumento para zsh con comillas simples.
    nonisolated static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

nonisolated private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
