import Foundation

/// Change leído del disco (openspec/changes/<id>/).
struct OpenSpecChangeInfo: Identifiable, Sendable {
    let id: String
    var title: String
    var proposal: String?
    var design: String?
    var tasksText: String?
    var tasks: [WorkTask]
    var dirURL: URL
}

/// Estado del proyecto OpenSpec, leído en vivo del filesystem — nunca duplicado.
struct OpenSpecState: Sendable {
    var isInitialized: Bool
    var specPaths: [String]
    var changes: [OpenSpecChangeInfo]
    var archivedCount: Int
}

/// Lee y escribe la estructura OpenSpec del repo. El filesystem es la fuente de verdad.
enum OpenSpecService {
    nonisolated private static var fileManager: FileManager { FileManager.default }

    // MARK: - Lectura

    nonisolated static func read(at root: URL) -> OpenSpecState {
        let openspecURL = root.appendingPathComponent("openspec")
        guard fileManager.fileExists(atPath: openspecURL.path) else {
            return OpenSpecState(isInitialized: false, specPaths: [], changes: [], archivedCount: 0)
        }

        // Specs vivas
        var specPaths: [String] = []
        let specsURL = openspecURL.appendingPathComponent("specs")
        if let enumerator = fileManager.enumerator(at: specsURL, includingPropertiesForKeys: nil) {
            for case let file as URL in enumerator where file.pathExtension == "md" {
                specPaths.append(file.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }

        // Changes activos
        var changes: [OpenSpecChangeInfo] = []
        let changesURL = openspecURL.appendingPathComponent("changes")
        if let entries = try? fileManager.contentsOfDirectory(at: changesURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory, entry.lastPathComponent != "archive" else { continue }
                changes.append(readChange(at: entry))
            }
        }

        // Archive
        var archivedCount = 0
        let archiveURL = changesURL.appendingPathComponent("archive")
        if let entries = try? fileManager.contentsOfDirectory(at: archiveURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            archivedCount = entries.count
        }

        return OpenSpecState(
            isInitialized: true,
            specPaths: specPaths.sorted(),
            changes: changes,
            archivedCount: archivedCount
        )
    }

    /// Relee un change concreto desde su directorio (en el árbol principal o en un worktree).
    nonisolated static func readChange(at dirURL: URL) -> OpenSpecChangeInfo {
        let id = dirURL.lastPathComponent
        let proposal = try? String(contentsOf: dirURL.appendingPathComponent("proposal.md"), encoding: .utf8)
        let design = try? String(contentsOf: dirURL.appendingPathComponent("design.md"), encoding: .utf8)
        let tasksText = try? String(contentsOf: dirURL.appendingPathComponent("tasks.md"), encoding: .utf8)

        var title = id
        if let proposal,
           let heading = proposal.components(separatedBy: "\n").first(where: { $0.hasPrefix("# ") }) {
            title = heading.dropFirst(2).trimmingCharacters(in: .whitespaces)
        }

        return OpenSpecChangeInfo(
            id: id,
            title: title,
            proposal: proposal,
            design: design,
            tasksText: tasksText,
            tasks: parseTasks(tasksText ?? ""),
            dirURL: dirURL
        )
    }

    /// Parsea tasks.md: checkboxes "- [ ] 1.1 Título" agrupadas bajo headings "##".
    nonisolated static func parseTasks(_ text: String) -> [WorkTask] {
        var tasks: [WorkTask] = []
        var currentGroup = "Tasks"
        var fallbackIndex = 1

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                var group = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                // "1. Backend" → "Backend"
                if let dotRange = group.range(of: ". "), group.prefix(upTo: dotRange.lowerBound).allSatisfy(\.isNumber) {
                    group = String(group[dotRange.upperBound...])
                }
                currentGroup = group
                continue
            }
            let isOpen = trimmed.hasPrefix("- [ ]")
            let isDone = trimmed.lowercased().hasPrefix("- [x]")
            guard isOpen || isDone else { continue }

            var rest = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            var id = "\(fallbackIndex)"
            if let first = rest.components(separatedBy: " ").first,
               first.contains("."), first.allSatisfy({ $0.isNumber || $0 == "." }) {
                id = first
                rest = String(rest.dropFirst(first.count)).trimmingCharacters(in: .whitespaces)
            }
            fallbackIndex += 1

            tasks.append(WorkTask(
                id: id,
                title: rest,
                group: currentGroup,
                lane: tasks.count < 2 ? .trunk : .fan,
                done: isDone
            ))
        }
        return tasks
    }

    // MARK: - Escritura

    /// Crea la estructura OpenSpec del repo (los archivos del card de confirmación del Setup).
    nonisolated static func initializeStructure(at root: URL, projectName: String) throws {
        let openspec = root.appendingPathComponent("openspec")
        try fileManager.createDirectory(at: openspec.appendingPathComponent("specs"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: openspec.appendingPathComponent("changes/archive"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: root.appendingPathComponent(".workspace/memory"), withIntermediateDirectories: true)

        let agents = openspec.appendingPathComponent("AGENTS.md")
        if !fileManager.fileExists(atPath: agents.path) {
            try """
            # Instrucciones para agentes

            Este repo usa OpenSpec. Las specs vivas están en `openspec/specs/`;
            los changes activos en `openspec/changes/`. Antes de implementar,
            lee la spec afectada y el proposal del change.
            """.write(to: agents, atomically: true, encoding: .utf8)
        }

        let project = openspec.appendingPathComponent("project.md")
        if !fileManager.fileExists(atPath: project.path) {
            try """
            # \(projectName)

            Contexto del proyecto para los agentes. Completa aquí el stack,
            las convenciones y los límites que deben respetar.
            """.write(to: project, atomically: true, encoding: .utf8)
        }
    }

    /// Crea un change nuevo con sus artefactos de planning vacíos.
    nonisolated static func createChange(at root: URL, title: String) throws -> OpenSpecChangeInfo {
        let slug = slugify(title)
        var id = slug
        let changesURL = root.appendingPathComponent("openspec/changes")
        var counter = 2
        while fileManager.fileExists(atPath: changesURL.appendingPathComponent(id).path) {
            id = "\(slug)-\(counter)"
            counter += 1
        }
        let dirURL = changesURL.appendingPathComponent(id)
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        try "# \(title)\n\n## ¿Qué?\n\n## ¿Por qué?\n\n## Alcance\n"
            .write(to: dirURL.appendingPathComponent("proposal.md"), atomically: true, encoding: .utf8)
        try "# Tareas\n\n## 1. Implementación\n"
            .write(to: dirURL.appendingPathComponent("tasks.md"), atomically: true, encoding: .utf8)
        // La frase del usuario ES la intención inicial: puebla la tab Idea.
        try title.write(to: dirURL.appendingPathComponent("idea.md"), atomically: true, encoding: .utf8)

        return readChange(at: dirURL)
    }

    nonisolated static func saveFile(named name: String, content: String, in change: OpenSpecChangeInfo) throws {
        guard let safe = PathGuard.safeFilename(name) else {
            throw PathGuard.ContainmentError(path: name, root: change.dirURL.path)
        }
        let target = try PathGuard.verify(change.dirURL.appendingPathComponent(safe), within: change.dirURL)
        try content.write(to: target, atomically: true, encoding: .utf8)
    }

    /// Marca/desmarca una task en tasks.md (write-back del checkbox).
    nonisolated static func toggleTask(id: String, done: Bool, in change: OpenSpecChangeInfo) throws {
        let tasksURL = change.dirURL.appendingPathComponent("tasks.md")
        guard let content = try? String(contentsOf: tasksURL, encoding: .utf8) else { return }

        var fallbackIndex = 1
        let lines = content.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- [ ]") || trimmed.lowercased().hasPrefix("- [x]") else { return line }
            let rest = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            var lineID = "\(fallbackIndex)"
            if let first = rest.components(separatedBy: " ").first,
               first.contains("."), first.allSatisfy({ $0.isNumber || $0 == "." }) {
                lineID = first
            }
            fallbackIndex += 1
            guard lineID == id else { return line }
            // Sustituir solo el checkbox, conservando el resto de la línea.
            for marker in ["- [ ]", "- [x]", "- [X]"] {
                if let range = line.range(of: marker) {
                    return line.replacingCharacters(in: range, with: done ? "- [x]" : "- [ ]")
                }
            }
            return line
        }
        try lines.joined(separator: "\n").write(to: tasksURL, atomically: true, encoding: .utf8)
    }

    /// Deltas (cards de la tab Plan) de un change leído del disco.
    nonisolated static func deltas(for info: OpenSpecChangeInfo) -> [Delta] {
        makeDeltas(from: info)
    }

    /// Entrada del archive: un change cerrado.
    nonisolated struct ArchivedChange: Identifiable, Sendable {
        let id: String
        let title: String
        let summary: String
        let dateLabel: String
        let dirURL: URL
    }

    /// El "¿Qué?" del proposal, en una frase — describe el change de un vistazo.
    nonisolated static func proposalSummary(from proposal: String?) -> String {
        guard let proposal else { return "" }
        var inQue = false
        for line in proposal.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ¿Qué") { inQue = true; continue }
            if trimmed.hasPrefix("#") { if inQue { break }; continue }
            if inQue, !trimmed.isEmpty {
                return String(trimmed.prefix(160))
            }
        }
        // Sin sección ¿Qué?: primer párrafo cualquiera.
        for line in proposal.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                return String(trimmed.prefix(160))
            }
        }
        return ""
    }

    /// Lee los changes archivados (openspec/changes/archive/).
    nonisolated static func readArchive(at root: URL) -> [ArchivedChange] {
        let archiveURL = root.appendingPathComponent("openspec/changes/archive")
        guard let entries = try? fileManager.contentsOfDirectory(
            at: archiveURL, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return entries
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .compactMap { dir in
                let isDirectory = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory else { return nil }
                let name = dir.lastPathComponent
                // Formato "yyyy-MM-dd-<id>"
                let dateLabel = String(name.prefix(10))
                var title = String(name.dropFirst(min(11, name.count)))
                var summary = ""
                if let proposal = try? String(contentsOf: dir.appendingPathComponent("proposal.md"), encoding: .utf8) {
                    if let heading = proposal.components(separatedBy: "\n").first(where: { $0.hasPrefix("# ") }) {
                        title = String(heading.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    }
                    summary = proposalSummary(from: proposal)
                }
                return ArchivedChange(id: name, title: title, summary: summary, dateLabel: dateLabel, dirURL: dir)
            }
    }

    /// Archiva un change: lo mueve a openspec/changes/archive/ (la esencia de /opsx:archive).
    /// Devuelve el destino dentro de archive/.
    @discardableResult
    nonisolated static func archive(_ change: OpenSpecChangeInfo) throws -> URL {
        let archiveDir = change.dirURL.deletingLastPathComponent().appendingPathComponent("archive")
        try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let target = archiveDir.appendingPathComponent("\(formatter.string(from: .now))-\(change.id)")
        try fileManager.moveItem(at: change.dirURL, to: target)
        return target
    }

    nonisolated private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return collapsed.isEmpty ? "cambio" : collapsed
    }

    // MARK: - Traducción a modelo de UI

    /// Construye el `Change` de la UI desde el estado real del disco.
    nonisolated static func makeChange(from info: OpenSpecChangeInfo, agentLabel: String = "agente") -> Change {
        let doneCount = info.tasks.filter(\.done).count
        let state: ChangeState = if info.tasks.isEmpty {
            .exploring
        } else if doneCount == info.tasks.count {
            .review
        } else if doneCount > 0 {
            .implementing
        } else {
            .planned
        }

        let ideaText = info.proposal
            .flatMap { proposal in
                proposal.components(separatedBy: "\n")
                    .drop(while: { !$0.hasPrefix("## ") })
                    .dropFirst()
                    .prefix(while: { !$0.hasPrefix("#") })
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } ?? ""

        return Change(
            id: info.id,
            title: info.title,
            state: state,
            createdLabel: String(localized: "leído del repo"),
            origin: "openspec/changes/\(info.id)",
            agentLabel: agentLabel,
            tasks: info.tasks,
            deltas: makeDeltas(from: info),
            artifacts: [],
            exploreChat: [],
            ideaText: ideaText.isEmpty ? String(localized: "Describe aquí la intención del cambio, en tus palabras.") : ideaText,
            ideaContext: [],
            historyStages: [],
            closingVoices: makeVoices(title: info.title),
            closureStats: makeClosureStats(info: info),
            reviewLanes: []
        )
    }

    nonisolated private static func makeDeltas(from info: OpenSpecChangeInfo) -> [Delta] {
        var deltas: [Delta] = []
        if info.proposal != nil {
            deltas.append(Delta(kind: .md, path: "proposal.md", summary: String(localized: "qué y por qué"), fileKey: .proposal))
        }
        if info.design != nil {
            deltas.append(Delta(kind: .md, path: "design.md", summary: String(localized: "decisiones técnicas"), fileKey: .design))
        }
        if info.tasksText != nil {
            deltas.append(Delta(kind: .md, path: "tasks.md", summary: String(localized: "\(info.tasks.count) tareas"), fileKey: .tasks))
        }
        return deltas
    }

    nonisolated private static func makeVoices(title: String) -> [ClosingVoice] {
        [
            ClosingVoice(
                kind: .commit,
                icon: "G",
                title: String(localized: "Mensaje de commit"),
                audience: String(localized: "para git · técnico"),
                ruleBadge: nil,
                content: "feat: \(title)\n\n",
                primaryActionLabel: String(localized: "Copiar"),
                footnote: String(localized: "el merge usará este mensaje"),
                needsConfirmation: false
            ),
            ClosingVoice(
                kind: .ticket,
                icon: "J",
                title: String(localized: "Nota para el ticket"),
                audience: String(localized: "negocio"),
                content: String(localized: "✅ Resuelto — \(title)."),
                primaryActionLabel: String(localized: "Adjuntar al ticket →"),
                footnote: String(localized: "cierra contra la intención de origen"),
                needsConfirmation: true
            ),
            ClosingVoice(
                kind: .team,
                icon: "#",
                title: String(localized: "Resumen para el equipo"),
                audience: String(localized: "humano, breve"),
                content: String(localized: "🚀 Mergeado: \(title)."),
                primaryActionLabel: String(localized: "Enviar →"),
                footnote: String(localized: "tu firma, no la del agente"),
                needsConfirmation: true
            ),
        ]
    }

    nonisolated private static func makeClosureStats(info: OpenSpecChangeInfo) -> ClosureStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return ClosureStats(
            archivedAtLabel: formatter.string(from: .now),
            durationValue: "—",
            durationDetail: String(localized: "1 sesión"),
            tokensValue: "—",
            tokensDetail: String(localized: "según la sesión"),
            filesValue: "\(info.tasks.count)",
            filesDetail: String(localized: "tasks del change"),
            committedItems: [String(localized: "Cambios de la sesión del agente")],
            commitSHA: "—",
            commitMessage: "feat: \(info.title)",
            learnedItems: [String(localized: "El change queda archivado en el repo")],
            archivePath: "openspec/changes/archive/\(info.id)/"
        )
    }
}
