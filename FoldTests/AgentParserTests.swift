import XCTest
@testable import Fold

final class AgentParserTests: XCTestCase {
    // MARK: - Claude stream-json

    func testClaudeInitEmitsSessionID() {
        let line = #"{"type":"system","subtype":"init","session_id":"abc-123"}"#
        let events = AgentRunner.parseClaudeLine(line)
        guard case .started(let id)? = events.first else {
            return XCTFail("esperaba .started")
        }
        XCTAssertEqual(id, "abc-123")
    }

    func testClaudeAssistantTextAndToolUse() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"hola"},{"type":"tool_use","name":"Bash","input":{"command":"ls -la"}}]}}"#
        let events = AgentRunner.parseClaudeLine(line)
        XCTAssertEqual(events.count, 2)
        guard case .message(let text) = events[0] else { return XCTFail("esperaba .message") }
        XCTAssertEqual(text, "hola")
        guard case .toolUse(let name, let detail) = events[1] else { return XCTFail("esperaba .toolUse") }
        XCTAssertEqual(name, "Bash")
        XCTAssertEqual(detail, "ls -la")
    }

    func testClaudeFileWriteBecomesFileChanged() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/tmp/x.swift"}}]}}"#
        let events = AgentRunner.parseClaudeLine(line)
        guard case .fileChanged(let path, let created)? = events.first else {
            return XCTFail("esperaba .fileChanged")
        }
        XCTAssertEqual(path, "/tmp/x.swift")
        XCTAssertTrue(created)
    }

    func testClaudeResultFailureIsNotSuccess() {
        let line = #"{"type":"result","subtype":"error_during_execution","result":"boom"}"#
        let events = AgentRunner.parseClaudeLine(line)
        guard case .finished(let success, let result)? = events.last else {
            return XCTFail("esperaba .finished")
        }
        XCTAssertFalse(success)
        XCTAssertEqual(result, "boom")
    }

    func testClaudeUsageParsed() {
        let line = #"{"type":"result","subtype":"success","usage":{"output_tokens":1234}}"#
        let events = AgentRunner.parseClaudeLine(line)
        guard case .usage(let tokens)? = events.first else { return XCTFail("esperaba .usage") }
        XCTAssertEqual(tokens, 1234)
    }

    func testGarbageLinesProduceNothing() {
        XCTAssertTrue(AgentRunner.parseClaudeLine("no es json").isEmpty)
        XCTAssertTrue(AgentRunner.parseCodexLine("{malformed").isEmpty)
        XCTAssertTrue(AgentRunner.parseClaudeLine("{}").isEmpty)
    }

    // MARK: - Codex JSONL

    func testCodexThreadStarted() {
        let line = #"{"type":"thread.started","thread_id":"th_9"}"#
        let events = AgentRunner.parseCodexLine(line)
        guard case .started(let id)? = events.first else { return XCTFail("esperaba .started") }
        XCTAssertEqual(id, "th_9")
    }

    func testCodexAgentMessage() {
        let line = #"{"type":"item.completed","item":{"type":"agent_message","text":"listo"}}"#
        let events = AgentRunner.parseCodexLine(line)
        guard case .message(let text)? = events.first else { return XCTFail("esperaba .message") }
        XCTAssertEqual(text, "listo")
    }

    func testCodexFileChanges() {
        let line = #"{"type":"item.completed","item":{"type":"file_change","changes":[{"path":"a.swift","kind":"add"},{"path":"b.swift","kind":"modify"}]}}"#
        let events = AgentRunner.parseCodexLine(line)
        XCTAssertEqual(events.count, 2)
        guard case .fileChanged(_, let created) = events[0] else { return XCTFail() }
        XCTAssertTrue(created)
        guard case .fileChanged(_, let modified) = events[1] else { return XCTFail() }
        XCTAssertFalse(modified)
    }

    func testCodexTurnFailedEmitsFailure() {
        let line = #"{"type":"turn.failed","error":{"message":"sin cuota"}}"#
        let events = AgentRunner.parseCodexLine(line)
        guard case .finished(let success, let result)? = events.last else {
            return XCTFail("esperaba .finished")
        }
        XCTAssertFalse(success)
        XCTAssertEqual(result, "sin cuota")
    }

    /// Explorar con OpenCode: el agente inyectado niega todo salvo lectura.
    func testOpenCodeExploreConfigIsDenyAll() throws {
        let data = try XCTUnwrap(AgentRunner.openCodeExploreConfig.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let agent = try XCTUnwrap((json["agent"] as? [String: Any])?[AgentRunner.openCodeExploreAgent] as? [String: Any])
        let permission = try XCTUnwrap(agent["permission"] as? [String: Any])
        XCTAssertEqual(permission["*"] as? String, "deny")
        for tool in ["bash", "edit", "write", "patch", "webfetch", "task"] {
            XCTAssertNil(permission[tool], "\(tool) no debe reabrirse tras el deny-all")
        }
    }
}
