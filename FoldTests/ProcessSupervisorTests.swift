import XCTest
@testable import Fold

final class ProcessSupervisorTests: XCTestCase {
    private func collect(_ process: SupervisedProcess) async -> (lines: [String], terminals: [RunResult]) {
        var lines: [String] = []
        var terminals: [RunResult] = []
        for await event in process.events {
            switch event {
            case .stdoutLine(let line): lines.append(line)
            case .terminated(let result): terminals.append(result)
            }
        }
        return (lines, terminals)
    }

    func testSuccessEmitsSingleTerminalEvent() async {
        let process = SupervisedProcess(config: .init(
            executable: "/bin/sh",
            arguments: ["-c", "echo uno; echo dos"],
            inactivityTimeout: 10, hardTimeout: 20
        ))
        process.start()
        let (lines, terminals) = await collect(process)
        XCTAssertEqual(lines, ["uno", "dos"])
        XCTAssertEqual(terminals.count, 1, "exactamente un evento terminal")
        XCTAssertEqual(terminals.first?.state, .succeeded)
    }

    func testNonZeroExitIsFailureNotSuccess() async {
        let process = SupervisedProcess(config: .init(
            executable: "/bin/sh",
            arguments: ["-c", "echo err >&2; exit 3"],
            inactivityTimeout: 10, hardTimeout: 20
        ))
        process.start()
        let (_, terminals) = await collect(process)
        XCTAssertEqual(terminals.count, 1)
        XCTAssertEqual(terminals.first?.state, .failed(exitCode: 3))
        XCTAssertTrue(terminals.first?.stderrTail.contains("err") ?? false)
    }

    func testSpawnFailureIsTerminalFailure() async {
        let process = SupervisedProcess(config: .init(
            executable: "/no/existe/binario",
            arguments: [],
            inactivityTimeout: 5, hardTimeout: 10
        ))
        process.start()
        let (_, terminals) = await collect(process)
        XCTAssertEqual(terminals.count, 1)
        if case .failed = terminals.first?.state {} else {
            XCTFail("un spawn fallido debe terminar en .failed")
        }
    }

    func testCancelKillsProcessAndDescendants() async {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("fold-sup-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: marker) }

        let process = SupervisedProcess(config: .init(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 300 & echo $! > \(marker.path); echo listo; wait"],
            inactivityTimeout: 60, hardTimeout: 120
        ))
        process.start()

        // Espera a que el descendiente exista.
        var childPID: Int32 = 0
        for _ in 0..<100 {
            if let text = try? String(contentsOf: marker, encoding: .utf8),
               let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                childPID = pid
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(childPID, 0)

        await process.cancel()
        let result = await process.waitUntilExit()
        XCTAssertEqual(result.state, .cancelled)

        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertNotEqual(kill(childPID, 0), 0, "el descendiente debe morir con el grupo")
    }

    func testInactivityTimeoutFires() async {
        let process = SupervisedProcess(config: .init(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 60"],
            inactivityTimeout: 3, hardTimeout: 60
        ))
        process.start()
        let result = await process.waitUntilExit()
        XCTAssertEqual(result.state, .timedOut)
    }
}
