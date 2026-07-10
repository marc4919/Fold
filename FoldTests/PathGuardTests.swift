import XCTest
@testable import Fold

final class PathGuardTests: XCTestCase {
    var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pathguard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("root/attachments"), withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("outside"), withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    func testRejectsDotDotTraversal() {
        let attachments = base.appendingPathComponent("root/attachments")
        let evil = attachments.appendingPathComponent("../../outside/victima.txt")
        XCTAssertNil(try? PathGuard.verify(evil, within: attachments))
    }

    func testRejectsEscapingSymlink() throws {
        let attachments = base.appendingPathComponent("root/attachments")
        let victim = base.appendingPathComponent("outside/victima.txt")
        try "secreto".write(to: victim, atomically: true, encoding: .utf8)
        let link = attachments.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: victim)
        XCTAssertNil(try? PathGuard.verify(link, within: attachments))
    }

    func testAcceptsLegitimateFile() throws {
        let attachments = base.appendingPathComponent("root/attachments")
        let ok = attachments.appendingPathComponent("normal.txt")
        try "hola".write(to: ok, atomically: true, encoding: .utf8)
        XCTAssertNotNil(try? PathGuard.verify(ok, within: attachments))
    }

    func testAcceptsNotYetExistingFileInsideRoot() {
        let root = base.appendingPathComponent("root")
        let newFile = root.appendingPathComponent("nueva/entrada.md")
        XCTAssertNotNil(try? PathGuard.verify(newFile, within: root))
    }

    func testRejectsNotYetExistingFileOutsideRoot() {
        let root = base.appendingPathComponent("root")
        let newFile = base.appendingPathComponent("outside/nueva.md")
        XCTAssertNil(try? PathGuard.verify(newFile, within: root))
    }

    func testSafeFilename() {
        XCTAssertNil(PathGuard.safeFilename("../x"))
        XCTAssertNil(PathGuard.safeFilename("a/b"))
        XCTAssertNil(PathGuard.safeFilename(".."))
        XCTAssertNil(PathGuard.safeFilename(""))
        XCTAssertNil(PathGuard.safeFilename("  "))
        XCTAssertEqual(PathGuard.safeFilename("informe.pdf"), "informe.pdf")
        XCTAssertEqual(PathGuard.safeFilename(" con espacios.md "), "con espacios.md")
    }
}
