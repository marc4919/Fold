import Foundation

/// Registro persistente de la transacción git de un change: qué rama y SHA eran
/// la base, dónde vive el worktree, qué archivos revisó el usuario y en qué
/// estado quedó. Sobrevive a reinicios (.workspace/transactions/<id>.json).
nonisolated struct ChangeTransactionRecord: Codable, Sendable {
    var changeID: String
    var baseBranch: String
    var baseSHA: String
    /// Rama de trabajo (nil en modo directo).
    var workBranch: String?
    /// Ruta del worktree relativa al root (nil en modo directo).
    var worktreePath: String?
    /// "open" → trabajando · "merged" → merge hecho, falta archivar.
    var state: String
    /// Manifiesto EXACTO que el usuario vio en Revisión; el commit usa esto.
    var approvedPaths: [String]?
    /// Staged por el usuario ANTES de empezar (modo directo): nunca se tocan.
    var preStagedPaths: [String]
    var createdAt: Date
}

/// La transacción git de un change: única fuente de verdad del cierre.
/// Revisión y commit operan sobre el mismo manifiesto; el staging es explícito
/// (nunca add -A); el merge verifica la rama base; y nada se limpia hasta
/// confirmar que merge + archive + memoria quedaron consistentes.
enum GitChangeTransaction {
    // MARK: - Estado de archivos (porcelain v2, NUL-safe)

    nonisolated struct FileStatus: Sendable {
        enum Kind: Sendable { case modified, added, deleted, renamed, untracked, conflicted }
        let path: String
        let originalPath: String?
        let kind: Kind
        /// Había cambios staged (columna X) para este path.
        let hasStagedChanges: Bool
    }

    /// Estado del árbol con `git status --porcelain=v2 -z`: nombres NUL-safe
    /// (espacios, comillas, unicode), renames y untracked archivo a archivo.
    nonisolated static func status(at dir: URL) async -> [FileStatus] {
        let result = await ShellRunner.run(
            "git status --porcelain=v2 -z -uall 2>/dev/null | tr '\\0' '\\n'", cwd: dir
        )
        // tr traduce NUL→\n para transportarlo como texto; los nombres con \n
        // reales son patológicos y quedan fuera del soporte de la beta.
        var entries: [FileStatus] = []
        var tokens = result.stdout.components(separatedBy: "\n").makeIterator()
        while let token = tokens.next() {
            guard !token.isEmpty else { continue }
            let type = token.prefix(1)
            switch type {
            case "1":
                // 1 XY sub mH mI mW hH hI <path>
                let parts = token.split(separator: " ", maxSplits: 8).map(String.init)
                guard parts.count >= 9 else { continue }
                let xy = parts[1]
                entries.append(FileStatus(
                    path: parts[8],
                    originalPath: nil,
                    kind: kindFor(xy: xy),
                    hasStagedChanges: xy.first != "."
                ))
            case "2":
                // 2 XY sub mH mI mW hH hI Xscore <newPath> NUL <origPath>
                let parts = token.split(separator: " ", maxSplits: 9).map(String.init)
                guard parts.count >= 10 else { continue }
                let xy = parts[1]
                let origPath = tokens.next()
                entries.append(FileStatus(
                    path: parts[9],
                    originalPath: origPath,
                    kind: .renamed,
                    hasStagedChanges: xy.first != "."
                ))
            case "u":
                let parts = token.split(separator: " ", maxSplits: 10).map(String.init)
                guard let path = parts.last else { continue }
                entries.append(FileStatus(path: path, originalPath: nil, kind: .conflicted, hasStagedChanges: true))
            case "?":
                entries.append(FileStatus(
                    path: String(token.dropFirst(2)),
                    originalPath: nil, kind: .untracked, hasStagedChanges: false
                ))
            default:
                continue
            }
        }
        return entries
    }

    nonisolated private static func kindFor(xy: String) -> FileStatus.Kind {
        if xy.contains("A") { return .added }
        if xy.contains("D") { return .deleted }
        if xy.contains("R") { return .renamed }
        return .modified
    }

    /// Archivos para la Revisión con números de líneas (numstat) y kinds reales.
    nonisolated static func reviewFiles(at dir: URL) async -> [ReviewFile] {
        let entries = await status(at: dir)

        var stats: [String: (added: Int, removed: Int, binary: Bool)] = [:]
        let numstat = await ShellRunner.run("git diff --numstat HEAD 2>/dev/null", cwd: dir)
        for line in numstat.stdout.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }
            // Binarios: numstat reporta "-\t-\tpath".
            let binary = parts[0] == "-"
            stats[parts[2]] = (Int(parts[0]) ?? 0, Int(parts[1]) ?? 0, binary)
        }

        var files: [ReviewFile] = []
        for entry in entries {
            let stat = stats[entry.path]
            var added = stat?.added ?? 0
            var removed = stat?.removed ?? 0
            let kind: ReviewFile.Kind
            switch entry.kind {
            case .untracked, .added:
                kind = stat?.binary == true ? .bin : .new
                if added == 0, entry.kind == .untracked {
                    let count = await ShellRunner.run(
                        "wc -l < \(ShellRunner.quote(entry.path)) 2>/dev/null", cwd: dir
                    )
                    added = Int(count.trimmedOutput) ?? 0
                    removed = 0
                }
            case .deleted: kind = .del
            case .renamed: kind = .ren
            case .conflicted: kind = .conflict
            case .modified: kind = stat?.binary == true ? .bin : .mod
            }
            files.append(ReviewFile(
                kind: kind, path: entry.path, added: added, removed: removed,
                originalPath: entry.originalPath
            ))
        }
        return files
    }

    // MARK: - Persistencia del registro

    nonisolated private static func recordURL(root: URL, changeID: String) -> URL {
        root.appendingPathComponent(".workspace/transactions/\(changeID).json")
    }

    /// El registro vive en el repo y NO es de confianza (puede venir clonado):
    /// solo se acepta si su rama y su worktree son exactamente los que Fold
    /// crea para ese change. Así un JSON manipulado no puede dirigir
    /// `git branch -D` ni `git worktree remove` a otra rama o ruta.
    nonisolated static func load(root: URL, changeID: String) -> ChangeTransactionRecord? {
        guard let data = try? Data(contentsOf: recordURL(root: root, changeID: changeID)),
              let record = try? JSONDecoder().decode(ChangeTransactionRecord.self, from: data),
              isTrusted(record, root: root, changeID: changeID) else { return nil }
        return record
    }

    nonisolated static func isTrusted(_ record: ChangeTransactionRecord, root: URL, changeID: String) -> Bool {
        guard record.changeID == changeID, PathGuard.safeFilename(changeID) == changeID else { return false }
        if let branch = record.workBranch, branch != "fold/\(changeID)" { return false }
        if let path = record.worktreePath {
            guard path == ".workspace/worktrees/\(changeID)",
                  PathGuard.isContained(root.appendingPathComponent(path),
                                        within: root.appendingPathComponent(".workspace/worktrees"))
            else { return false }
        }
        // Rama y worktree van juntos o no van.
        return (record.workBranch == nil) == (record.worktreePath == nil)
    }

    nonisolated static func save(_ record: ChangeTransactionRecord, root: URL) {
        let url = recordURL(root: root, changeID: record.changeID)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: url)
        }
    }

    nonisolated static func remove(root: URL, changeID: String) {
        try? FileManager.default.removeItem(at: recordURL(root: root, changeID: changeID))
    }

    /// Abre (o recupera) la transacción del change: rama base, SHA base y
    /// staged previos del usuario quedan registrados antes de tocar nada.
    nonisolated static func begin(
        root: URL,
        changeID: String,
        worktreePath: String?,
        workBranch: String?
    ) async -> ChangeTransactionRecord {
        if var existing = load(root: root, changeID: changeID) {
            // Reinicio: el registro manda; solo se refresca la ruta si cambió.
            existing.worktreePath = worktreePath ?? existing.worktreePath
            existing.workBranch = workBranch ?? existing.workBranch
            save(existing, root: root)
            return existing
        }
        let branch = await ShellRunner.run("git symbolic-ref --short -q HEAD 2>/dev/null", cwd: root)
        let sha = await ShellRunner.run("git rev-parse HEAD 2>/dev/null", cwd: root)
        let preStaged = await status(at: root)
            .filter(\.hasStagedChanges)
            .map(\.path)
        let record = ChangeTransactionRecord(
            changeID: changeID,
            baseBranch: branch.trimmedOutput.isEmpty ? "HEAD" : branch.trimmedOutput,
            baseSHA: sha.trimmedOutput,
            workBranch: workBranch,
            worktreePath: worktreePath,
            state: "open",
            approvedPaths: nil,
            preStagedPaths: preStaged,
            createdAt: .now
        )
        save(record, root: root)
        return record
    }

    // MARK: - Cierre

    /// Commit del manifiesto aprobado + merge a la rama base.
    /// - El commit incluye EXACTAMENTE `approvedPaths` (staging explícito por
    ///   pathspec — jamás add -A). Lo staged previamente por el usuario no entra.
    /// - El merge se bloquea si la rama actual del root ya no es la rama base.
    /// - Un conflicto aborta el merge y deja todo recuperable.
    /// - El worktree y la rama NO se tocan aquí: eso llega tras archivar.
    nonisolated static func commitAndMerge(
        root: URL,
        record: ChangeTransactionRecord,
        message: String
    ) async -> (ok: Bool, detail: String) {
        guard let approved = record.approvedPaths else {
            return (false, String(localized: "No hay manifiesto de revisión: revisa los archivos antes de mergear."))
        }

        // La rama base debe seguir siendo la actual: si cambiaste de rama,
        // el cierre se detiene en vez de mergear donde no toca.
        let current = await ShellRunner.run("git symbolic-ref --short -q HEAD 2>/dev/null", cwd: root)
        guard current.trimmedOutput == record.baseBranch else {
            return (false, String(localized: "La rama actual (\(current.trimmedOutput)) ya no es la rama base del change (\(record.baseBranch)). Vuelve a \(record.baseBranch) o descarta el change."))
        }

        let workDir: URL
        if let worktreePath = record.worktreePath {
            workDir = root.appendingPathComponent(worktreePath)
            guard FileManager.default.fileExists(atPath: workDir.path) else {
                return (false, String(localized: "El worktree del change ya no existe (\(worktreePath))."))
            }
        } else {
            workDir = root
        }

        // Staging explícito, solo el manifiesto (en modo directo, además,
        // se excluye lo que el usuario tenía staged de antes).
        let excluded = Set(record.worktreePath == nil ? record.preStagedPaths : [])
        let paths = approved.filter { !excluded.contains($0) }
        if !paths.isEmpty {
            let specs = paths.map { ShellRunner.quote($0) }.joined(separator: " ")
            let add = await ShellRunner.run("git add -- \(specs) 2>&1", cwd: workDir)
            guard add.ok else {
                return (false, String(localized: "No se pudieron preparar los archivos aprobados: \(add.stderr.isEmpty ? add.stdout : add.stderr)"))
            }
            // El commit fija el pathspec: aunque hubiera más cosas en el índice,
            // SOLO entran los paths aprobados. El mensaje editado se usa entero.
            let commit = await ShellRunner.run(
                "git commit -q -m \(ShellRunner.quote(message)) -- \(specs) 2>&1",
                cwd: workDir
            )
            if !commit.ok {
                let pending = await status(at: workDir)
                let stillPending = pending.contains { paths.contains($0.path) }
                if stillPending {
                    return (false, String(localized: "El commit falló: \(commit.stdout.isEmpty ? commit.stderr : commit.stdout)"))
                }
                // Sin cambios que commitear en el manifiesto: legítimo (p. ej. re-cierre).
            }
        }

        // Modo directo: el commit ya está en la rama base — no hay merge.
        guard let workBranch = record.workBranch, record.worktreePath != nil else {
            var merged = record
            merged.state = "merged"
            save(merged, root: root)
            return (true, "")
        }

        let merge = await ShellRunner.run(
            "git merge --no-ff \(ShellRunner.quote(workBranch)) -m \(ShellRunner.quote("merge: \(record.changeID)")) 2>&1",
            cwd: root
        )
        guard merge.ok else {
            // Conflicto: estado recuperable — se aborta y se explica.
            _ = await ShellRunner.run("git merge --abort 2>/dev/null", cwd: root)
            return (false, String(localized: "El merge tiene conflictos con \(record.baseBranch): \(merge.trimmedOutput). El worktree y la rama \(workBranch) se conservan intactos."))
        }

        var merged = record
        merged.state = "merged"
        save(merged, root: root)
        return (true, merge.trimmedOutput)
    }

    /// Tras archivar el change y actualizar la memoria: los deja versionados
    /// en un commit propio y SOLO entonces limpia worktree, rama y registro.
    /// `paths` son las rutas exactas del cierre (relativas al root): el
    /// directorio original del change, su destino en archive/ y la entrada de
    /// memoria creada. Nada más entra — ni otros changes ni otras memorias.
    /// Devuelve además si el árbol quedó limpio.
    nonisolated static func finalizeArchive(
        root: URL,
        record: ChangeTransactionRecord,
        paths: [String]
    ) async -> (ok: Bool, detail: String) {
        // Solo rutas dentro del root; una ruta que ni existe ni está en el
        // índice haría fallar el pathspec entero, así que se descarta.
        var specs: [String] = []
        for path in paths {
            guard PathGuard.isContained(root.appendingPathComponent(path), within: root),
                  root.appendingPathComponent(path).standardizedFileURL != root.standardizedFileURL
            else { continue }
            let onDisk = FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
            let inIndex = await ShellRunner.run("git ls-files -- \(ShellRunner.quote(path))", cwd: root)
                .trimmedOutput.isEmpty == false
            if onDisk || inIndex { specs.append(ShellRunner.quote(path)) }
        }

        if !specs.isEmpty {
            let joined = specs.joined(separator: " ")
            let add = await ShellRunner.run("git add -- \(joined) 2>&1", cwd: root)
            guard add.ok else {
                return (false, String(localized: "No se pudo preparar el archivo: \(add.trimmedOutput)"))
            }
            let commit = await ShellRunner.run(
                "git commit -q -m \(ShellRunner.quote("opsx: archive \(record.changeID)")) -- \(joined) 2>&1",
                cwd: root
            )
            if !commit.ok {
                let pending = await status(at: root)
                let archivePending = pending.contains { entry in
                    paths.contains { entry.path == $0 || entry.path.hasPrefix($0 + "/") }
                }
                if archivePending {
                    return (false, String(localized: "El commit del archivo falló: \(commit.stdout.isEmpty ? commit.stderr : commit.stdout)"))
                }
            }
        }

        // Limpieza: solo ahora que merge + archive + memoria están confirmados.
        if let worktreePath = record.worktreePath {
            _ = await ShellRunner.run(
                "git worktree remove \(ShellRunner.quote(worktreePath)) --force 2>&1",
                cwd: root
            )
        }
        if let workBranch = record.workBranch {
            _ = await ShellRunner.run("git branch -D \(ShellRunner.quote(workBranch)) 2>&1", cwd: root)
        }
        remove(root: root, changeID: record.changeID)

        let final = await ShellRunner.run("git status --porcelain 2>/dev/null", cwd: root)
        let clean = final.trimmedOutput.isEmpty
        return (true, clean ? "" : String(localized: "Quedan cambios sin versionar ajenos al change: \(final.trimmedOutput.components(separatedBy: "\n").count) archivo(s)"))
    }
}
