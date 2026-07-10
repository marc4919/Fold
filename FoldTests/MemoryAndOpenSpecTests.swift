import XCTest
@testable import Fold

final class MemoryAndOpenSpecTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fold-mem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".workspace/memory/attachments"),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Memoria: traversal de adjuntos

    func testDeleteDoesNotFollowTraversalInAttachmentReference() throws {
        // Víctima FUERA de la memoria.
        let victim = root.appendingPathComponent("victima.txt")
        try "importante".write(to: victim, atomically: true, encoding: .utf8)

        // Entrada maliciosa que referencia attachments/../../victima.txt
        let entry = root.appendingPathComponent(".workspace/memory/mala.md")
        try "kind: spec\n\n# Mala\n\nAdjunto: `attachments/../../victima.txt`\n"
            .write(to: entry, atomically: true, encoding: .utf8)

        let entries = MemoryService.read(at: root)
        let mala = try XCTUnwrap(entries.first { $0.title == "Mala" })
        try MemoryService.delete(entry: mala, at: root)

        XCTAssertTrue(FileManager.default.fileExists(atPath: victim.path),
                      "el traversal no debe borrar nada fuera de attachments/")
        XCTAssertFalse(FileManager.default.fileExists(atPath: entry.path))
    }

    func testDeleteRemovesLegitimateAttachment() throws {
        let attachment = root.appendingPathComponent(".workspace/memory/attachments/doc.pdf")
        try Data("pdf".utf8).write(to: attachment)
        let entry = root.appendingPathComponent(".workspace/memory/doc.md")
        try "kind: spec\n\n# Doc\n\nAdjunto: `attachments/doc.pdf`\n"
            .write(to: entry, atomically: true, encoding: .utf8)

        let entries = MemoryService.read(at: root)
        let doc = try XCTUnwrap(entries.first { $0.title == "Doc" })
        try MemoryService.delete(entry: doc, at: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachment.path))
    }

    func testAddAndRenameKeepSlugAndHeadingInSync() throws {
        try MemoryService.add(title: "Decisión de Diseño", body: "cuerpo", kind: .decision, at: root)
        var entries = MemoryService.read(at: root)
        XCTAssertTrue(entries.contains { $0.source.hasSuffix("decision-de-diseno.md") })

        let entry = try XCTUnwrap(entries.first { $0.title == "Decisión de Diseño" })
        try MemoryService.rename(entry: entry, to: "Regla nueva", at: root)
        entries = MemoryService.read(at: root)
        let renamed = try XCTUnwrap(entries.first { $0.title == "Regla nueva" })
        XCTAssertTrue(renamed.source.hasSuffix("regla-nueva.md"))
    }

    func testAddDeduplicatesSlugCollisions() throws {
        try MemoryService.add(title: "Regla", body: "a", kind: .convention, at: root)
        try MemoryService.add(title: "Regla", body: "b", kind: .convention, at: root)
        let files = try FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent(".workspace/memory").path
        ).filter { $0.hasSuffix(".md") }
        XCTAssertEqual(files.sorted(), ["regla-2.md", "regla.md"])
    }

    // MARK: - OpenSpec

    func testCreateChangeDeduplicatesSlug() throws {
        try OpenSpecService.initializeStructure(at: root, projectName: "test")
        let first = try OpenSpecService.createChange(at: root, title: "Mi cambio")
        let second = try OpenSpecService.createChange(at: root, title: "Mi cambio")
        XCTAssertEqual(first.id, "mi-cambio")
        XCTAssertEqual(second.id, "mi-cambio-2")
    }

    func testParseTasksFromMarkdown() throws {
        try OpenSpecService.initializeStructure(at: root, projectName: "test")
        let info = try OpenSpecService.createChange(at: root, title: "Tareas")
        try """
        # Tareas

        ## 1. Grupo
        - [ ] 1.1 Primera
        - [x] 1.2 Segunda hecha
        - [ ] 1.3 Tercera
        """.write(to: info.dirURL.appendingPathComponent("tasks.md"), atomically: true, encoding: .utf8)

        let fresh = OpenSpecService.readChange(at: info.dirURL)
        XCTAssertEqual(fresh.tasks.count, 3)
        XCTAssertEqual(fresh.tasks.filter(\.done).count, 1)
        XCTAssertEqual(fresh.tasks.first?.id, "1.1")
    }

    func testToggleTaskWritesBack() throws {
        try OpenSpecService.initializeStructure(at: root, projectName: "test")
        let info = try OpenSpecService.createChange(at: root, title: "Toggle")
        try "# Tareas\n\n- [ ] 1.1 Única\n"
            .write(to: info.dirURL.appendingPathComponent("tasks.md"), atomically: true, encoding: .utf8)

        let loaded = OpenSpecService.readChange(at: info.dirURL)
        try OpenSpecService.toggleTask(id: "1.1", done: true, in: loaded)
        let content = try String(contentsOf: info.dirURL.appendingPathComponent("tasks.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("- [x] 1.1"))
    }

    func testSaveFileRejectsTraversalName() throws {
        try OpenSpecService.initializeStructure(at: root, projectName: "test")
        let info = try OpenSpecService.createChange(at: root, title: "Seguro")
        XCTAssertThrowsError(
            try OpenSpecService.saveFile(named: "../../fuera.md", content: "x", in: info)
        )
    }

    func testProposalSummaryExtractsQueSection() {
        let proposal = """
        # Título

        ## ¿Qué?

        Añade un modo oscuro configurable.

        ## ¿Por qué?
        Porque sí.
        """
        XCTAssertEqual(
            OpenSpecService.proposalSummary(from: proposal),
            "Añade un modo oscuro configurable."
        )
    }
}
