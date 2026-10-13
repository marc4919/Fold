import Foundation

/// La memoria del proyecto vive en archivos del repo (.workspace/memory/), no en la app.
enum MemoryService {
    nonisolated static func read(at root: URL) -> [MemoryEntry] {
        let memoryURL = root.appendingPathComponent(".workspace/memory")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: memoryURL, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd · HH:mm"

        return files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { file in
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now

                let lines = content.components(separatedBy: "\n")
                let title = lines.first(where: { $0.hasPrefix("# ") })
                    .map { String($0.dropFirst(2)) }
                    ?? file.deletingPathExtension().lastPathComponent

                let body = lines
                    .filter { !$0.hasPrefix("#") && !$0.hasPrefix("kind:") }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return MemoryEntry(
                    title: title,
                    kind: parseKind(content: content, filename: file.lastPathComponent),
                    body: String(body.prefix(280)),
                    source: ".workspace/memory/\(file.lastPathComponent)",
                    dateLabel: formatter.string(from: modified),
                    linkLabel: String(localized: "abrir →")
                )
            }
    }

    nonisolated private static func parseKind(content: String, filename: String) -> MemoryEntry.Kind {
        let haystack = (content.components(separatedBy: "\n").first(where: { $0.hasPrefix("kind:") }) ?? filename)
            .lowercased()
        if haystack.contains("decision") || haystack.contains("decisión") { return .decision }
        if haystack.contains("lesson") || haystack.contains("lección") || haystack.contains("leccion") { return .lesson }
        if haystack.contains("convention") || haystack.contains("convención") || haystack.contains("convencion") || haystack.contains("regla") { return .convention }
        return .spec
    }

    /// Adjunta archivos a la memoria: los .md se copian directos; el resto va a
    /// attachments/ con una entrada markdown que los referencia.
    nonisolated static func attach(fileURLs: [URL], at root: URL) throws -> Int {
        let memoryURL = root.appendingPathComponent(".workspace/memory")
        try FileManager.default.createDirectory(at: memoryURL, withIntermediateDirectories: true)

        var attached = 0
        for file in fileURLs {
            // El nombre viene del panel de archivos, pero se valida igualmente.
            guard let name = PathGuard.safeFilename(file.lastPathComponent) else { continue }
            if file.pathExtension.lowercased() == "md" {
                let destination = uniqueURL(try PathGuard.verify(
                    memoryURL.appendingPathComponent(name), within: memoryURL))
                try FileManager.default.copyItem(at: file, to: destination)
            } else {
                let attachmentsURL = memoryURL.appendingPathComponent("attachments")
                try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
                let destination = uniqueURL(try PathGuard.verify(
                    attachmentsURL.appendingPathComponent(name), within: attachmentsURL))
                try FileManager.default.copyItem(at: file, to: destination)

                let stubName = file.deletingPathExtension().lastPathComponent
                let stub = uniqueURL(memoryURL.appendingPathComponent("\(stubName).md"))
                try """
                kind: spec

                # \(file.lastPathComponent)

                Archivo adjunto a la memoria del proyecto: `attachments/\(destination.lastPathComponent)`
                """.write(to: stub, atomically: true, encoding: .utf8)
            }
            attached += 1
        }
        return attached
    }

    nonisolated private static func uniqueURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension()
        let ext = url.pathExtension
        var counter = 2
        var candidate = base.appendingPathExtension("\(counter).\(ext)")
        while FileManager.default.fileExists(atPath: candidate.path) {
            counter += 1
            candidate = base.appendingPathExtension("\(counter).\(ext)")
        }
        return candidate
    }

    /// Renombra una entrada: el archivo pasa a <slug>.md y el heading se actualiza.
    nonisolated static func rename(entry: MemoryEntry, to newName: String, at root: URL) throws {
        let memoryURL = root.appendingPathComponent(".workspace/memory")
        let fileURL = try PathGuard.verify(root.appendingPathComponent(entry.source), within: memoryURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        var content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        // Actualiza (o inserta) el heading para que título y archivo cuenten lo mismo.
        var lines = content.components(separatedBy: "\n")
        if let headingIndex = lines.firstIndex(where: { $0.hasPrefix("# ") }) {
            lines[headingIndex] = "# \(newName)"
        } else {
            lines.insert("# \(newName)", at: 0)
        }
        content = lines.joined(separator: "\n")

        let slug = slugify(newName)
        var destination = fileURL.deletingLastPathComponent().appendingPathComponent("\(slug).md")
        if destination.path != fileURL.path, FileManager.default.fileExists(atPath: destination.path) {
            var counter = 2
            repeat {
                destination = fileURL.deletingLastPathComponent().appendingPathComponent("\(slug)-\(counter).md")
                counter += 1
            } while FileManager.default.fileExists(atPath: destination.path)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        if destination.path != fileURL.path {
            try FileManager.default.moveItem(at: fileURL, to: destination)
        }
    }

    /// Elimina una entrada; si referencia un adjunto en attachments/, lo elimina también.
    /// El nombre del adjunto sale del CONTENIDO del archivo (no confiable): se valida
    /// como nombre simple y se verifica su contención antes de tocar nada.
    nonisolated static func delete(entry: MemoryEntry, at root: URL) throws {
        let memoryURL = root.appendingPathComponent(".workspace/memory")
        let fileURL = try PathGuard.verify(root.appendingPathComponent(entry.source), within: memoryURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        // Adjunto referenciado como `attachments/<archivo>` en el cuerpo.
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            let attachmentsURL = memoryURL.appendingPathComponent("attachments")
            for line in content.components(separatedBy: "\n") {
                guard let range = line.range(of: "attachments/") else { continue }
                let tail = line[range.lowerBound...]
                let raw = String(tail.dropFirst("attachments/".count)
                    .prefix(while: { $0 != "`" && $0 != " " && $0 != ")" }))
                guard let name = PathGuard.safeFilename(raw),
                      let attachment = try? PathGuard.verify(
                          attachmentsURL.appendingPathComponent(name), within: attachmentsURL
                      ) else { continue }
                try? FileManager.default.removeItem(at: attachment)
            }
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    nonisolated private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return collapsed.isEmpty ? "entrada" : collapsed
    }

    /// Añade una entrada como archivo markdown plano, versionable con git.
    /// Devuelve el archivo creado.
    @discardableResult
    nonisolated static func add(title: String, body: String, kind: MemoryEntry.Kind, at root: URL) throws -> URL {
        let memoryURL = root.appendingPathComponent(".workspace/memory")
        try FileManager.default.createDirectory(at: memoryURL, withIntermediateDirectories: true)

        var slug = title.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { partial, character in partial.append(character) }
        slug = slug.components(separatedBy: "-").filter { !$0.isEmpty }.joined(separator: "-")
        if slug.isEmpty { slug = "entrada" }

        var fileURL = memoryURL.appendingPathComponent("\(slug).md")
        var counter = 2
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = memoryURL.appendingPathComponent("\(slug)-\(counter).md")
            counter += 1
        }

        try "kind: \(kind.rawValue)\n\n# \(title)\n\n\(body)\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
