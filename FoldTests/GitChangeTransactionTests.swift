import XCTest
@testable import Fold

/// Integración git con repos temporales reales: la transacción del change
/// de punta a punta, incluidos los casos que protegen el trabajo del usuario.
final class GitChangeTransactionTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fold-tx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func git(_ command: String, in dir: URL? = nil) async -> ShellResult {
        await ShellRunner.run("git \(command)", cwd: dir ?? root)
    }

    private func makeRepo() async throws {
        _ = await git("init -q -b main")
        _ = await git("config user.email test@fold && git config user.name Fold")
        try "base".write(to: root.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
        let changeDir = root.appendingPathComponent("openspec/changes/mi-change")
        try FileManager.default.createDirectory(at: changeDir, withIntermediateDirectories: true)
        try "# Mi change".write(to: changeDir.appendingPathComponent("proposal.md"), atomically: true, encoding: .utf8)
        _ = await git("add -A && git commit -qm inicial")
    }

    // MARK: - Estado (porcelain v2)

    func testStatusDetectsKindsAndPreStaged() async throws {
        try await makeRepo()
        try "mod".write(to: root.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
        try "nuevo".write(to: root.appendingPathComponent("nuevo.txt"), atomically: true, encoding: .utf8)
        try "staged".write(to: root.appendingPathComponent("staged.txt"), atomically: true, encoding: .utf8)
        _ = await git("add staged.txt")

        let entries = await GitChangeTransaction.status(at: root)
        let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
        XCTAssertEqual(byPath["base.txt"]?.kind, .modified)
        XCTAssertEqual(byPath["nuevo.txt"]?.kind, .untracked)
        XCTAssertEqual(byPath["staged.txt"]?.kind, .added)
        XCTAssertEqual(byPath["staged.txt"]?.hasStagedChanges, true)
        XCTAssertEqual(byPath["base.txt"]?.hasStagedChanges, false)
    }

    func testStatusHandlesFilenamesWithSpaces() async throws {
        try await makeRepo()
        try "x".write(to: root.appendingPathComponent("con espacios y ñ.txt"), atomically: true, encoding: .utf8)
        let entries = await GitChangeTransaction.status(at: root)
        XCTAssertTrue(entries.contains { $0.path == "con espacios y ñ.txt" })
    }

    // MARK: - begin

    func testBeginCapturesBaseAndPreStaged() async throws {
        try await makeRepo()
        try "user".write(to: root.appendingPathComponent("usuario.txt"), atomically: true, encoding: .utf8)
        _ = await git("add usuario.txt")

        let record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change", worktreePath: nil, workBranch: nil
        )
        XCTAssertEqual(record.baseBranch, "main")
        XCTAssertFalse(record.baseSHA.isEmpty)
        XCTAssertTrue(record.preStagedPaths.contains("usuario.txt"))

        // El registro sobrevive (reinicio): load lo devuelve igual.
        let loaded = GitChangeTransaction.load(root: root, changeID: "mi-change")
        XCTAssertEqual(loaded?.baseBranch, "main")
    }

    // MARK: - Commit del manifiesto (modo directo)

    func testCommitExcludesUserPreStagedAndUsesFullMessage() async throws {
        try await makeRepo()
        try "user".write(to: root.appendingPathComponent("usuario.txt"), atomically: true, encoding: .utf8)
        _ = await git("add usuario.txt")

        var record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change", worktreePath: nil, workBranch: nil
        )
        try "agente".write(to: root.appendingPathComponent("agente.txt"), atomically: true, encoding: .utf8)
        try "mod".write(to: root.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
        record.approvedPaths = ["agente.txt", "base.txt"]
        GitChangeTransaction.save(record, root: root)

        let message = "feat: cambio\n\nCuerpo multilínea\nque debe usarse entero"
        let result = await GitChangeTransaction.commitAndMerge(root: root, record: record, message: message)
        XCTAssertTrue(result.ok, result.detail)

        let body = await git("show --format=%B -s HEAD")
        XCTAssertTrue(body.stdout.contains("Cuerpo multilínea"), "el mensaje editado debe usarse íntegro")

        let files = await git("show --name-only --format= HEAD")
        XCTAssertTrue(files.stdout.contains("agente.txt"))
        XCTAssertFalse(files.stdout.contains("usuario.txt"), "lo pre-staged del usuario no entra en el commit")

        // usuario.txt sigue staged, intacto.
        let status = await GitChangeTransaction.status(at: root)
        XCTAssertTrue(status.contains { $0.path == "usuario.txt" && $0.hasStagedChanges })
    }

    func testMergeBlockedWhenBranchChanged() async throws {
        try await makeRepo()
        var record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change", worktreePath: nil, workBranch: nil
        )
        record.approvedPaths = []
        _ = await git("checkout -qb otra-rama")

        let result = await GitChangeTransaction.commitAndMerge(root: root, record: record, message: "x")
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.detail.contains("otra-rama"))
    }

    func testCommitWithoutManifestBlocked() async throws {
        try await makeRepo()
        let record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change", worktreePath: nil, workBranch: nil
        )
        let result = await GitChangeTransaction.commitAndMerge(root: root, record: record, message: "x")
        XCTAssertFalse(result.ok, "sin manifiesto de revisión no hay commit")
    }

    // MARK: - Worktree completo

    func testWorktreeFlowMergeArchiveCleanTree() async throws {
        try await makeRepo()

        let setup = await GitService.setupWorktree(root: root, changeID: "mi-change")
        guard case .success(let worktree) = setup else {
            return XCTFail("setupWorktree falló")
        }
        var record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change",
            worktreePath: ".workspace/worktrees/mi-change", workBranch: "fold/mi-change"
        )

        try "impl".write(to: worktree.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        record.approvedPaths = ["feature.txt"]
        GitChangeTransaction.save(record, root: root)

        let merge = await GitChangeTransaction.commitAndMerge(root: root, record: record, message: "feat: feature")
        XCTAssertTrue(merge.ok, merge.detail)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("feature.txt").path))

        // Archive simulado (mueve el change) + memoria + finalize.
        let archiveDir = root.appendingPathComponent("openspec/changes/archive")
        try FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
            at: root.appendingPathComponent("openspec/changes/mi-change"),
            to: archiveDir.appendingPathComponent("2026-01-01-mi-change")
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".workspace/memory"), withIntermediateDirectories: true
        )
        try "# decisión".write(
            to: root.appendingPathComponent(".workspace/memory/mi-change.md"),
            atomically: true, encoding: .utf8
        )

        let merged = GitChangeTransaction.load(root: root, changeID: "mi-change")!
        let finalize = await GitChangeTransaction.finalizeArchive(root: root, record: merged)
        XCTAssertTrue(finalize.ok, finalize.detail)

        // Árbol limpio (el registro de la transacción también desapareció).
        let status = await git("status --porcelain")
        XCTAssertEqual(status.trimmedOutput, "", "el repo debe quedar limpio tras el cierre")
        XCTAssertNil(GitChangeTransaction.load(root: root, changeID: "mi-change"))

        // Rama y worktree limpiados.
        let branches = await git("branch --list 'fold/*'")
        XCTAssertEqual(branches.trimmedOutput, "")
    }

    func testConflictIsRecoverable() async throws {
        try await makeRepo()
        let setup = await GitService.setupWorktree(root: root, changeID: "mi-change")
        guard case .success(let worktree) = setup else { return XCTFail() }
        var record = await GitChangeTransaction.begin(
            root: root, changeID: "mi-change",
            worktreePath: ".workspace/worktrees/mi-change", workBranch: "fold/mi-change"
        )

        // Divergencia: ambos tocan base.txt.
        try "version worktree".write(to: worktree.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
        record.approvedPaths = ["base.txt"]
        GitChangeTransaction.save(record, root: root)
        try "version main".write(to: root.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
        _ = await git("commit -qam 'cambio main'")

        let result = await GitChangeTransaction.commitAndMerge(root: root, record: record, message: "feat: x")
        XCTAssertFalse(result.ok)

        // Recuperable: sin merge a medias, worktree y rama conservados.
        let mergeHead = await git("rev-parse -q --verify MERGE_HEAD")
        XCTAssertNotEqual(mergeHead.exitCode, 0, "no debe quedar un merge a medias")
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktree.path))
        let branch = await git("rev-parse --verify -q refs/heads/fold/mi-change")
        XCTAssertEqual(branch.exitCode, 0, "la rama del change se conserva")
    }

    // MARK: - setupWorktree honesto

    func testSetupWorktreeFailsWithReasonOutsideRepo() async {
        let setup = await GitService.setupWorktree(root: root, changeID: "x")
        guard case .failure(let reason) = setup else {
            return XCTFail("debería fallar fuera de un repo")
        }
        XCTAssertTrue(reason.contains("repositorio"))
    }

    func testSetupWorktreeFailsWithReasonWithoutCommits() async throws {
        _ = await git("init -q -b main")
        let setup = await GitService.setupWorktree(root: root, changeID: "x")
        guard case .failure(let reason) = setup else {
            return XCTFail("debería fallar sin commits")
        }
        XCTAssertTrue(reason.contains("commit"))
    }

    func testSetupWorktreePlanCommitExcludesUserPreStaged() async throws {
        try await makeRepo()
        // El usuario tenía algo staged ANTES de que Fold commitee el plan.
        try "trabajo del usuario".write(to: root.appendingPathComponent("usuario.txt"), atomically: true, encoding: .utf8)
        _ = await git("add usuario.txt")

        let setup = await GitService.setupWorktree(root: root, changeID: "mi-change")
        guard case .success = setup else { return XCTFail("setupWorktree falló") }

        // El commit del plan NO puede llevarse usuario.txt.
        let planCommit = await git("log --format=%H -n 1 --grep 'opsx: plan'")
        if !planCommit.trimmedOutput.isEmpty {
            let files = await git("show --name-only --format= \(planCommit.trimmedOutput)")
            XCTAssertFalse(files.stdout.contains("usuario.txt"),
                           "el commit del plan se tragó lo pre-staged del usuario")
        }
        // Y usuario.txt sigue staged, esperando al usuario.
        let status = await GitChangeTransaction.status(at: root)
        XCTAssertTrue(status.contains { $0.path == "usuario.txt" && $0.hasStagedChanges })
    }

    func testSetupWorktreeReusesResidualBranchWithoutReset() async throws {
        try await makeRepo()
        // Rama residual con un commit propio.
        _ = await git("branch fold/mi-change")
        _ = await git("worktree add -q .workspace/worktrees/tmp fold/mi-change")
        let tmp = root.appendingPathComponent(".workspace/worktrees/tmp")
        try "trabajo previo".write(to: tmp.appendingPathComponent("previo.txt"), atomically: true, encoding: .utf8)
        _ = await git("add previo.txt && git commit -qm previo", in: tmp)
        let residualSHA = await git("rev-parse refs/heads/fold/mi-change")
        _ = await git("worktree remove --force .workspace/worktrees/tmp")

        let setup = await GitService.setupWorktree(root: root, changeID: "mi-change")
        guard case .success = setup else { return XCTFail("debería recuperar la rama residual") }
        let after = await git("rev-parse refs/heads/fold/mi-change")
        XCTAssertEqual(after.trimmedOutput, residualSHA.trimmedOutput,
                       "la rama residual conserva sus commits (sin -B)")
    }
}
