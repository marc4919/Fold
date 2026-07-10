import XCTest
@testable import Fold

final class ChangeStateMachineTests: XCTestCase {
    func testForwardOneStepAllowed() {
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .exploring, to: .idea))
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .idea, to: .planned))
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .planned, to: .implementing))
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .implementing, to: .review))
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .review, to: .archived))
    }

    func testIterateFromReviewAllowed() {
        XCTAssertTrue(ChangeStateMachine.canTransition(from: .review, to: .implementing))
    }

    func testSkippingStatesRejected() {
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .exploring, to: .planned))
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .exploring, to: .archived))
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .idea, to: .implementing))
    }

    func testBackwardsRejected() {
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .planned, to: .exploring))
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .archived, to: .review))
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .implementing, to: .planned))
    }

    func testSameStateRejected() {
        XCTAssertFalse(ChangeStateMachine.canTransition(from: .review, to: .review))
    }

    func testDemoAllowsForwardJumps() {
        XCTAssertTrue(ChangeStateMachine.canTransitionInDemo(from: .exploring, to: .review))
        XCTAssertTrue(ChangeStateMachine.canTransitionInDemo(from: .review, to: .implementing))
        XCTAssertFalse(ChangeStateMachine.canTransitionInDemo(from: .review, to: .exploring))
    }
}
