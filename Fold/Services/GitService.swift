import Foundation

/// Operaciones git por shell-out: worktrees de aislamiento, commits y merge.
/// El usuario nunca ve la palabra "worktree" en la UI principal.
enum GitService {
    /// ¿Es un repo git con al menos un commit? (sin HEAD no hay worktrees posibles)
    nonisolated static func hasHead(at root: URL) async -> Bool {
        await ShellRunner.run("git rev-parse --verify HEAD >/dev/null 2>&1 && echo yes", cwd: root)
            .trimmedOutput == "yes"
    }

    /// Resultado del aislamiento: éxito con la ruta, o el motivo REAL del fallo.
    nonisolated enum WorktreeSetup: Sendable {
        case success(URL)
        case failure(String)
    }

    /// Prepara el aislamiento de un change: commitea los artefactos de planning
    /// y crea (o recupera) un worktree dedicado con rama propia.
    /// Cada causa de fallo tiene su mensaje real — nunca se atribuye todo a
    /// "repo sin commits" ni se resetea una rama residual con -B.
    nonisolated static func setupWorktree(root: URL, changeID: String) async -> WorktreeSetup {
        let isRepo = await ShellRunner.run("git rev-parse --is-inside-work-tree 2>/dev/null", cwd: root)
        guard isRepo.trimmedOutput == "true" else {
            return .failure(String(localized: "La carpeta no es un repositorio git — inicialízalo (git init) para poder aislar el trabajo."))
        }
        guard await hasHead(at: root) else {
            return .failure(String(localized: "El repo no tiene ningún commit todavía: crea un commit inicial para poder aislar el trabajo."))
        }

        // Los artefactos de planning forman parte del registro: se commitean
        // (solo el directorio del change, nunca add -A).
        _ = await ShellRunner.run(
            "git add openspec/changes/\(ShellRunner.quote(changeID)) && git commit -q -m \(ShellRunner.quote("opsx: plan de \(changeID)")) 2>/dev/null",
            cwd: root
        )

        let worktreePath = ".workspace/worktrees/\(changeID)"
        let worktreeURL = root.appendingPathComponent(worktreePath)
        let branch = "fold/\(changeID)"

        // Recuperación tras reinicio: worktree ya registrado y presente → se reutiliza.
        let registered = await ShellRunner.run("git worktree list --porcelain", cwd: root)
        if registered.stdout.contains("worktree \(worktreeURL.path)"),
           FileManager.default.fileExists(atPath: worktreeURL.path) {
            return .success(worktreeURL)
        }
        // Registro huérfano (directorio borrado a mano) → limpiar el registro.
        _ = await ShellRunner.run("git worktree prune", cwd: root)

        // Directorio residual sin registro: se aparta (nunca se borra — podría
        // contener trabajo de una sesión interrumpida).
        if FileManager.default.fileExists(atPath: worktreeURL.path) {
            let stamp = Int(Date.now.timeIntervalSince1970)
            let recovered = root.appendingPathComponent(".workspace/worktrees/\(changeID)-recuperado-\(stamp)")
            do {
                try FileManager.default.moveItem(at: worktreeURL, to: recovered)
            } catch {
                return .failure(String(localized: "Hay un directorio residual en \(worktreePath) que no se pudo apartar: \(error.localizedDescription)"))
            }
        }

        // La rama residual se REUTILIZA (conserva sus commits); solo se crea si no existe.
        let branchExists = await ShellRunner.run(
            "git rev-parse --verify -q refs/heads/\(ShellRunner.quote(branch)) >/dev/null 2>&1 && echo yes",
            cwd: root
        ).trimmedOutput == "yes"

        let addCommand = branchExists
            ? "git worktree add \(ShellRunner.quote(worktreePath)) \(ShellRunner.quote(branch)) 2>&1"
            : "git worktree add -b \(ShellRunner.quote(branch)) \(ShellRunner.quote(worktreePath)) 2>&1"
        let result = await ShellRunner.run(addCommand, cwd: root)
        guard result.ok else {
            let detail = result.trimmedOutput.isEmpty ? result.stderr : result.trimmedOutput
            return .failure(String(localized: "git worktree add falló: \(detail)"))
        }
        return .success(worktreeURL)
    }

    /// Cierra el change: commit en el worktree, merge a la rama original y limpieza.
    /// Si el commit falla habiendo cambios pendientes, aborta con detalle.
    nonisolated static func mergeWorktree(
        root: URL,
        changeID: String,
        worktree: URL,
        message: String
    ) async -> (ok: Bool, detail: String) {
        let branch = "fold/\(changeID)"

        let commit = await ShellRunner.run(
            "git add -A && git commit -q -m \(ShellRunner.quote(message)) 2>&1",
            cwd: worktree
        )
        if !commit.ok {
            // Sin cambios que commitear es legítimo; cualquier otro fallo, no.
            let pending = await ShellRunner.run("git status --porcelain 2>/dev/null", cwd: worktree)
            if !pending.trimmedOutput.isEmpty {
                return (false, String(localized: "El commit en el worktree falló: \(commit.stderr.isEmpty ? commit.stdout : commit.stderr)"))
            }
        }

        let merge = await ShellRunner.run(
            "git merge --no-ff \(ShellRunner.quote(branch)) -m \(ShellRunner.quote("merge: \(changeID)")) 2>&1",
            cwd: root
        )
        guard merge.ok else {
            _ = await ShellRunner.run("git merge --abort 2>/dev/null", cwd: root)
            return (false, merge.stdout + merge.stderr)
        }

        let cleanup = await ShellRunner.run(
            "git worktree remove \(ShellRunner.quote(worktree.path)) --force 2>&1; git branch -D \(ShellRunner.quote(branch)) 2>&1",
            cwd: root
        )
        _ = cleanup // la limpieza fallida no invalida el merge; queda en el log de git
        return (true, merge.trimmedOutput)
    }

    /// Descarta el aislamiento de un change: elimina worktree y rama sin mergear.
    nonisolated static func discardWorktree(root: URL, changeID: String) async {
        let branch = "fold/\(changeID)"
        let worktreePath = ".workspace/worktrees/\(changeID)"
        _ = await ShellRunner.run(
            "git worktree remove \(ShellRunner.quote(worktreePath)) --force 2>/dev/null; git branch -D \(ShellRunner.quote(branch)) 2>/dev/null",
            cwd: root
        )
    }

    /// Commit directo (modo sin aislamiento).
    nonisolated static func commitAll(at root: URL, message: String) async -> Bool {
        let result = await ShellRunner.run(
            "git add -A && git commit -q -m \(ShellRunner.quote(message)) 2>&1",
            cwd: root
        )
        return result.ok
    }

    /// SHA corto del último commit.
    nonisolated static func headSHA(at root: URL) async -> String? {
        let result = await ShellRunner.run("git rev-parse --short HEAD 2>/dev/null", cwd: root)
        let sha = result.trimmedOutput
        return sha.isEmpty ? nil : sha
    }

    /// Cambios pendientes del directorio, con el tipo correcto por archivo:
    /// M/renombrado → mod; añadido/untracked → new. Números desde numstat.
    nonisolated static func pendingChanges(at dir: URL) async -> [ReviewFile] {
        // Estados por archivo (staged + unstaged + untracked, ARCHIVO a archivo:
        // sin -uall los directorios nuevos salen como "openspec/" a secas).
        let porcelain = await ShellRunner.run("git status --porcelain -uall 2>/dev/null", cwd: dir)

        // Números de líneas para los tracked.
        var stats: [String: (added: Int, removed: Int)] = [:]
        let numstat = await ShellRunner.run("git diff --numstat HEAD 2>/dev/null", cwd: dir)
        for line in numstat.stdout.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }
            stats[parts[2]] = (Int(parts[0]) ?? 0, Int(parts[1]) ?? 0)
        }

        var files: [ReviewFile] = []
        for line in porcelain.stdout.components(separatedBy: "\n") where line.count > 3 {
            let statusCode = String(line.prefix(2))
            var path = String(line.dropFirst(3))
            // Renombrados: "R  viejo -> nuevo"
            if let arrow = path.range(of: " -> ") {
                path = String(path[arrow.upperBound...])
            }
            if path.hasPrefix("\"") { path = String(path.dropFirst().dropLast()) }

            let isNew = statusCode.contains("?") || statusCode.contains("A")
            var added = stats[path]?.added ?? 0
            var removed = stats[path]?.removed ?? 0
            if isNew, added == 0 {
                let lineCount = await ShellRunner.run(
                    "wc -l < \(ShellRunner.quote(path)) 2>/dev/null", cwd: dir
                )
                added = Int(lineCount.trimmedOutput) ?? 0
                removed = 0
            }
            files.append(ReviewFile(
                kind: isNew ? .new : .mod,
                path: path,
                added: added,
                removed: removed
            ))
        }
        return files
    }
}
