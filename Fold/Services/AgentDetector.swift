import Foundation

/// Detecta las CLIs de agentes instaladas y autenticadas en la máquina.
/// Fold nunca gestiona API keys: hereda las sesiones existentes del usuario.
enum AgentDetector {
    nonisolated private struct Candidate: Sendable {
        let id: String
        let name: String
        let abbreviation: String
        let binary: String
        var fallbackPaths: [String] = []
    }

    nonisolated private static let candidates: [Candidate] = [
        Candidate(id: "claude-code", name: "Claude Code", abbreviation: "CC", binary: "claude"),
        Candidate(id: "codex", name: "Codex CLI", abbreviation: "CX", binary: "codex",
                  fallbackPaths: ["/Applications/Codex.app/Contents/Resources/codex"]),
        Candidate(id: "cursor", name: "Cursor CLI", abbreviation: "CR", binary: "cursor-agent"),
        Candidate(id: "opencode", name: "OpenCode", abbreviation: "OC", binary: "opencode"),
    ]

    nonisolated static func detect() async -> [AgentCLI] {
        let results = await withTaskGroup(of: (Int, AgentCLI).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    (index, await detectOne(candidate))
                }
            }
            var collected: [(Int, AgentCLI)] = []
            for await item in group {
                collected.append(item)
            }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // El primer agente detectado queda seleccionado y como default.
        var agents = results
        var defaultAssigned = false
        for index in agents.indices where agents[index].isDetected {
            agents[index].isSelected = true
            if !defaultAssigned {
                agents[index].isDefault = true
                defaultAssigned = true
            }
        }
        return agents
    }

    private nonisolated static func detectOne(_ candidate: Candidate) async -> AgentCLI {
        var binaryPath: String?

        let which = await ShellRunner.run("command -v \(candidate.binary)")
        if which.ok, !which.trimmedOutput.isEmpty {
            binaryPath = which.trimmedOutput.components(separatedBy: "\n").first
        } else {
            // CLIs que no viven en el PATH (p. ej. el codex embebido en Codex.app).
            binaryPath = candidate.fallbackPaths.first {
                FileManager.default.isExecutableFile(atPath: $0)
            }
        }

        guard let binaryPath else {
            return AgentCLI(
                id: candidate.id, name: candidate.name,
                abbreviation: candidate.abbreviation, version: nil, isDetected: false
            )
        }

        var version: String?
        let versionResult = await ShellRunner.run("\(ShellRunner.quote(binaryPath)) --version 2>/dev/null | head -1")
        if versionResult.ok {
            let raw = versionResult.trimmedOutput
            if !raw.isEmpty {
                // "2.1.4 (Claude Code)" → "v2.1.4"
                let token = raw.components(separatedBy: " ").first(where: { $0.first?.isNumber == true }) ?? raw
                version = token.hasPrefix("v") ? token : "v\(token)"
            }
        }

        // Autenticación real: --version no basta. nil = no verificable.
        let isAuthenticated = await AgentCapabilities.forBinary(binaryPath)?
            .verifyAuthentication(binary: binaryPath)

        return AgentCLI(
            id: candidate.id, name: candidate.name,
            abbreviation: candidate.abbreviation, version: version,
            isDetected: true, binaryPath: binaryPath,
            isAuthenticated: isAuthenticated
        )
    }
}
