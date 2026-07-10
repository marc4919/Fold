import Foundation

/// Las piezas del workspace: leerlas (Inventario) y crearlas (Forja).
/// Todo son archivos planos en el repo — nada vive atrapado en la app.
enum PiecesService {
    // MARK: - Inventario real

    nonisolated static func inventory(at root: URL, agents: [AgentCLI]) -> [InventoryGroup] {
        var groups: [InventoryGroup] = []

        // Skills: .workspace/skills/<nombre>/SKILL.md
        var skills: [InventoryPiece] = []
        let skillsURL = root.appendingPathComponent(".workspace/skills")
        if let entries = try? FileManager.default.contentsOfDirectory(
            at: skillsURL, includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for dir in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let skillFile = dir.appendingPathComponent("SKILL.md")
                guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
                skills.append(InventoryPiece(
                    name: dir.lastPathComponent,
                    detail: firstParagraph(of: content) ?? String(localized: "skill del workspace"),
                    badges: ["activo"],
                    previewText: String(content.prefix(600))
                ))
            }
        }
        groups.append(InventoryGroup(title: String(localized: "Skills"), pieces: skills))

        // Agentes: las CLIs activas del usuario + los perfiles forjados en .workspace/agents/.
        var agentPieces = agents.filter { $0.isSelected && $0.isDetected }.map { agent in
            InventoryPiece(
                name: agent.name,
                detail: agent.versionLabel + " · " + agent.authLabel,
                badges: agent.isDefault ? ["activo", "default"] : ["activo"],
                previewText: "CLI: \(agent.name)\nBinario: \(agent.binaryPath ?? "—")\nAuth: heredada de tu sesión de terminal"
            )
        }
        let forgedAgentsURL = root.appendingPathComponent(".workspace/agents")
        if let entries = try? FileManager.default.contentsOfDirectory(at: forgedAgentsURL, includingPropertiesForKeys: nil) {
            for file in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "md" {
                let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                agentPieces.append(InventoryPiece(
                    name: file.deletingPathExtension().lastPathComponent,
                    detail: firstParagraph(of: content) ?? String(localized: "perfil de agente forjado"),
                    badges: ["perfil"],
                    previewText: String(content.prefix(600))
                ))
            }
        }
        groups.append(InventoryGroup(title: String(localized: "Agentes"), pieces: agentPieces))

        // Plantillas forjadas: openspec/templates/.
        var templates: [InventoryPiece] = []
        let templatesURL = root.appendingPathComponent("openspec/templates")
        if let entries = try? FileManager.default.contentsOfDirectory(at: templatesURL, includingPropertiesForKeys: nil) {
            for file in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "md" {
                let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                templates.append(InventoryPiece(
                    name: file.deletingPathExtension().lastPathComponent,
                    detail: firstParagraph(of: content) ?? String(localized: "plantilla de change"),
                    badges: [],
                    previewText: String(content.prefix(600))
                ))
            }
        }
        if !templates.isEmpty {
            groups.append(InventoryGroup(title: String(localized: "Plantillas"), pieces: templates))
        }

        // Workflows: el estándar OPSX (los personalizados vivirán en openspec/profiles/).
        var workflows = [InventoryPiece(
            name: "estándar-opsx",
            detail: "Explorar → Idea → Plan → Trabajo → Revisión",
            badges: ["core"],
            previewText: "Fases: Explorar → Idea → Plan → Trabajo → Revisión\nComandos opsx: explore · propose · apply · verify · archive"
        )]
        let profilesURL = root.appendingPathComponent("openspec/profiles")
        if let entries = try? FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) {
            for file in entries where file.pathExtension == "yaml" {
                let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                workflows.append(InventoryPiece(
                    name: file.deletingPathExtension().lastPathComponent,
                    detail: String(localized: "workflow personalizado"),
                    badges: [],
                    previewText: String(content.prefix(600))
                ))
            }
        }
        groups.append(InventoryGroup(title: String(localized: "Workflows"), pieces: workflows))

        // Reglas: secciones "## " de CLAUDE.md.
        var rules: [InventoryPiece] = []
        if let claude = try? String(
            contentsOf: root.appendingPathComponent("CLAUDE.md"), encoding: .utf8
        ) {
            for section in sections(of: claude) {
                rules.append(InventoryPiece(
                    name: section.title,
                    detail: firstParagraph(of: section.body) ?? String(localized: "regla del proyecto"),
                    badges: ["bloqueante"],
                    previewText: String(section.body.prefix(500))
                ))
            }
        }
        groups.append(InventoryGroup(title: String(localized: "Reglas"), pieces: rules))

        return groups
    }

    /// Piezas propias del repo (skills + reglas + workflows custom), para las stats.
    nonisolated static func pieceCount(at root: URL) -> Int {
        var count = 0
        if let skills = try? FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent(".workspace/skills").path
        ) {
            count += skills.count
        }
        if let claude = try? String(contentsOf: root.appendingPathComponent("CLAUDE.md"), encoding: .utf8) {
            count += sections(of: claude).count
        }
        if let profiles = try? FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent("openspec/profiles").path
        ) {
            count += profiles.filter { $0.hasSuffix(".yaml") }.count
        }
        return count
    }

    // MARK: - Forja real

    nonisolated static func create(
        kind: ForgePieceKind,
        name: String,
        description: String,
        at root: URL
    ) throws -> String {
        let slug = slugify(name)
        let manager = FileManager.default

        switch kind {
        case .skill:
            // Colisión de slug = pieza existente: jamás se sobrescribe en silencio.
            let unique = uniqueSlug(slug) { candidate in
                manager.fileExists(atPath: root.appendingPathComponent(".workspace/skills/\(candidate)").path)
            }
            let dir = root.appendingPathComponent(".workspace/skills/\(unique)")
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("SKILL.md")
            try """
            # \(name)

            \(description.isEmpty ? "Describe cuándo se usa esta skill y qué hace." : description)

            ## Cuándo se usa

            ## Qué hace
            -
            """.write(to: file, atomically: true, encoding: .utf8)
            return ".workspace/skills/\(unique)/SKILL.md"

        case .rule:
            let file = root.appendingPathComponent("CLAUDE.md")
            let existing = (try? String(contentsOf: file, encoding: .utf8)) ?? "# Reglas del proyecto\n"
            let body = description.isEmpty
                ? String(localized: "Describe la restricción que los agentes deben respetar siempre.")
                : description
            try (existing + "\n## \(name)\n\n\(body)\n")
                .write(to: file, atomically: true, encoding: .utf8)
            return "CLAUDE.md"

        case .template:
            let dir = root.appendingPathComponent("openspec/templates")
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            let unique = uniqueSlug(slug) { manager.fileExists(atPath: dir.appendingPathComponent("\($0).md").path) }
            let file = dir.appendingPathComponent("\(unique).md")
            try """
            # Plantilla · \(name)

            \(description)

            ## ¿Qué?

            ## ¿Por qué?

            ## Tareas
            - [ ] 1.1
            """.write(to: file, atomically: true, encoding: .utf8)
            return "openspec/templates/\(unique).md"

        case .workflow:
            let dir = root.appendingPathComponent("openspec/profiles")
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            let unique = uniqueSlug(slug) { manager.fileExists(atPath: dir.appendingPathComponent("\($0).yaml").path) }
            let file = dir.appendingPathComponent("\(unique).yaml")
            try """
            # Workflow · \(name)
            # \(description)
            phases:
              - explore
              - idea
              - plan
              - work
              - review
            """.write(to: file, atomically: true, encoding: .utf8)
            return "openspec/profiles/\(unique).yaml"

        case .agent:
            let dir = root.appendingPathComponent(".workspace/agents")
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            let unique = uniqueSlug(slug) { manager.fileExists(atPath: dir.appendingPathComponent("\($0).md").path) }
            let file = dir.appendingPathComponent("\(unique).md")
            try """
            # Agente · \(name)

            \(description)

            cli:
            rol: implementador
            puede-tocar:
            aislamiento: worktree
            """.write(to: file, atomically: true, encoding: .utf8)
            return ".workspace/agents/\(unique).md"

        case .schema:
            throw ForgeError.advancedNotAvailable
        }
    }

    /// Sufijo incremental hasta encontrar un slug libre (mismo patrón que los changes).
    nonisolated private static func uniqueSlug(_ slug: String, exists: (String) -> Bool) -> String {
        guard exists(slug) else { return slug }
        var counter = 2
        while exists("\(slug)-\(counter)") { counter += 1 }
        return "\(slug)-\(counter)"
    }

    nonisolated enum ForgeError: LocalizedError {
        case advancedNotAvailable

        var errorDescription: String? {
            switch self {
            case .advancedNotAvailable:
                String(localized: "Los esquemas personalizados llegarán con la integración ACP.")
            }
        }
    }

    // MARK: - Helpers

    nonisolated private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return collapsed.isEmpty ? "pieza" : collapsed
    }

    nonisolated private static func firstParagraph(of markdown: String) -> String? {
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            return String(trimmed.prefix(90))
        }
        return nil
    }

    nonisolated private static func sections(of markdown: String) -> [(title: String, body: String)] {
        var result: [(String, String)] = []
        var currentTitle: String?
        var buffer: [String] = []
        func flush() {
            if let currentTitle {
                result.append((currentTitle, buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            buffer = []
        }
        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                flush()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if currentTitle != nil {
                buffer.append(line)
            }
        }
        flush()
        return result
    }
}
