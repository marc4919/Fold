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

    nonisolated static func run(_ command: String, cwd: URL? = nil) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.environment = cleanEnvironment()
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

                process.waitUntilExit()
                group.wait()

                continuation.resume(returning: ShellResult(
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? "",
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
