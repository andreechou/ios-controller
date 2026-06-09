import Foundation

/// Roda uma `TestSuite`: cada cenário vira um run isolado (driver + agente +
/// ledger próprios) e o veredito é comparado com o esperado.
public struct SuiteRunner: Sendable {
    let suite: TestSuite
    let udid: String
    let registry: ProviderRegistry

    public init(suite: TestSuite, udid: String,
                registry: ProviderRegistry = ProviderRegistry()) {
        self.suite = suite; self.udid = udid; self.registry = registry
    }

    public func run(onScenarioDone: (@Sendable (ScenarioResult) -> Void)? = nil) async throws -> SuiteResult {
        let started = Date()
        var results: [ScenarioResult] = []
        let model = suite.model ?? ProviderRegistry.defaultModel(for: suite.provider)

        for scenario in suite.scenarios {
            let config = RunConfig(
                goal: scenario.goal, persona: scenario.persona,
                udid: udid, bundleId: suite.bundleId,
                provider: suite.provider, model: model,
                maxSteps: scenario.maxSteps ?? 40)

            let provider = try registry.provider(for: suite.provider)
            let agent = Agent(provider: provider, model: model,
                              goal: scenario.goal, persona: scenario.persona)
            let driver = WebDriverAgentDriver(
                config: .init(udid: udid, bundleId: suite.bundleId))
            let ledger = JSONLLedger()
            let coordinator = RunCoordinator(driver: driver, agent: agent,
                                             ledger: ledger, config: config)

            var finalState: RunState?
            for await event in await coordinator.run() {
                if case .finished(let state) = event { finalState = state }
            }
            let result = evaluate(scenario, finalState ?? RunState())
            results.append(result)
            onScenarioDone?(result)
        }

        return SuiteResult(suite: suite.name, results: results,
                           startedAt: started, finishedAt: Date())
    }

    private func evaluate(_ scenario: Scenario, _ state: RunState) -> ScenarioResult {
        let outcome = state.outcome ?? .gaveUp
        var passed = outcome == scenario.expectedOutcome
        var reason: String?

        if passed, scenario.failOnFriction, !state.friction.isEmpty {
            passed = false
            reason = "fricção detectada (\(state.friction.count))"
        } else if !passed {
            reason = "esperado \(scenario.expectedOutcome.rawValue), obtido \(outcome.rawValue)"
        }

        return ScenarioResult(
            scenario: scenario, actualOutcome: outcome, passed: passed,
            steps: state.step, tokens: state.tokensUsed,
            friction: state.friction, failureReason: reason)
    }
}
