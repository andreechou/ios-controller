import Foundation

/// O coração: orquestra driver + agente + ledger num loop até sucesso, falha
/// ou esgotamento de budget. Emite eventos pra UI consumir (app ou CLI).
public actor RunCoordinator {
    public enum Event: Sendable {
        case phaseChanged(RunState.Phase)
        case step(index: Int, decision: AgentDecision, outcome: ActionOutcome?)
        case finished(RunState)
    }

    private let driver: SimulatorDriver
    private let agent: Agent
    private let ledger: Ledger
    private let config: RunConfig
    private var state = RunState()

    public init(driver: SimulatorDriver, agent: Agent, ledger: Ledger, config: RunConfig) {
        self.driver = driver
        self.agent = agent
        self.ledger = ledger
        self.config = config
    }

    /// Executa o run e entrega eventos via stream pra UI/CLI renderizar ao vivo.
    public func run() -> AsyncStream<Event> {
        AsyncStream(Event.self) { continuation in
            Task {
                do {
                    try await self.loop { _ = continuation.yield($0) }
                } catch {
                    await self.ledger.append(.error("\(error)"))
                }
                continuation.yield(.finished(self.state))
                continuation.finish()
            }
        }
    }

    private func loop(emit: @Sendable (Event) -> Void) async throws {
        state.phase = .preparing
        emit(.phaseChanged(.preparing))
        await ledger.append(.runStarted(goal: config.goal, persona: config.persona,
                                         provider: config.provider, model: config.model))
        try await driver.prepare()

        state.phase = .running
        emit(.phaseChanged(.running))

        while state.step < config.maxSteps && state.tokensUsed < config.maxTokens {
            let observation = try await driver.observe()
            let (decision, usage) = try await agent.decide(from: observation)

            state.tokensUsed += usage.inputTokens + usage.outputTokens
            state.friction.append(contentsOf: decision.friction)

            await ledger.append(.decision(step: state.step, decision: decision,
                                           tokens: usage.inputTokens + usage.outputTokens))

            // Encerramento decidido pelo agente.
            guard decision.status == .continue else {
                state.outcome = decision.status
                emit(.step(index: state.step, decision: decision, outcome: nil))
                break
            }

            var outcome: ActionOutcome?
            if let action = decision.action {
                outcome = try await driver.perform(action)
                await ledger.append(.action(step: state.step, action: action, outcome: outcome!))
            }
            emit(.step(index: state.step, decision: decision, outcome: outcome))
            state.step += 1
        }

        // Esgotou budget sem report explícito.
        if state.outcome == nil { state.outcome = .gaveUp }

        try await driver.teardown()
        state.phase = .finished
        await ledger.append(.runFinished(outcome: state.outcome!, steps: state.step,
                                          tokens: state.tokensUsed, friction: state.friction))
        emit(.phaseChanged(.finished))
    }
}
