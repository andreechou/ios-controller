import Foundation

/// Um cenário de teste declarativo: objetivo + persona + o que se espera.
/// Carregável de JSON — um processo de teste é uma lista desses.
public struct Scenario: Sendable, Codable, Identifiable {
    public var id: String
    public var goal: String
    public var persona: String

    /// Veredito esperado pra o cenário passar (default: succeeded).
    public var expectedOutcome: AgentDecision.Status
    /// Se true, qualquer fricção registrada reprova o cenário.
    public var failOnFriction: Bool
    /// Override opcional de budget por cenário.
    public var maxSteps: Int?

    public init(id: String, goal: String, persona: String,
                expectedOutcome: AgentDecision.Status = .succeeded,
                failOnFriction: Bool = false, maxSteps: Int? = nil) {
        self.id = id; self.goal = goal; self.persona = persona
        self.expectedOutcome = expectedOutcome
        self.failOnFriction = failOnFriction
        self.maxSteps = maxSteps
    }
}

/// Resultado da avaliação de um cenário.
public struct ScenarioResult: Sendable, Codable {
    public var scenario: Scenario
    public var actualOutcome: AgentDecision.Status
    public var passed: Bool
    public var steps: Int
    public var tokens: Int
    public var friction: [String]
    public var failureReason: String?

    public init(scenario: Scenario, actualOutcome: AgentDecision.Status, passed: Bool,
                steps: Int, tokens: Int, friction: [String], failureReason: String?) {
        self.scenario = scenario; self.actualOutcome = actualOutcome; self.passed = passed
        self.steps = steps; self.tokens = tokens
        self.friction = friction; self.failureReason = failureReason
    }
}
