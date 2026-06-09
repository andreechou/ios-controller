import XCTest
@testable import IOSControllerCore

final class AgentDecisionTests: XCTestCase {
    func testReportToolEndsRun() throws {
        let args = try JSONSerialization.data(withJSONObject: [
            "status": "succeeded", "summary": "objetivo atingido",
            "friction": ["botão 'Avançar' com label ambígua"]
        ])
        let response = ModelResponse(
            text: "Cheguei na tela final.",
            toolCalls: [ToolCall(name: "report", arguments: args)],
            usage: .init(inputTokens: 10, outputTokens: 5))

        let decision = Agent.decision(from: response)
        XCTAssertEqual(decision.status, .succeeded)
        XCTAssertNil(decision.action)
        XCTAssertEqual(decision.friction.count, 1)
    }

    func testTapToolBecomesAction() throws {
        let args = try JSONSerialization.data(withJSONObject: ["x": 100.0, "y": 220.0])
        let response = ModelResponse(
            text: "Tocando no botão.",
            toolCalls: [ToolCall(name: "tap", arguments: args)],
            usage: .init(inputTokens: 8, outputTokens: 4))

        let decision = Agent.decision(from: response)
        XCTAssertEqual(decision.status, .continue)
        XCTAssertEqual(decision.action, .tap(x: 100, y: 220))
    }
}
