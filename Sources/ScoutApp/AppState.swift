import SwiftUI
import ScoutCore

/// Estado observável da UI. Dispara um run e consome o AsyncStream de eventos.
@MainActor
@Observable
final class AppState {
    struct StepRow: Identifiable {
        let id = UUID()
        let index: Int
        let reasoning: String
        let action: String?
        let ok: Bool?
    }

    var phase: RunState.Phase = .idle
    var steps: [StepRow] = []
    var friction: [String] = []
    var outcome: AgentDecision.Status?
    var isRunning: Bool { phase == .preparing || phase == .running }

    func start(config: RunConfig) {
        steps = []; friction = []; outcome = nil
        Task {
            do {
                let registry = ProviderRegistry()
                let provider = try registry.provider(for: config.provider)
                let agent = Agent(provider: provider, model: config.model,
                                  goal: config.goal, persona: config.persona,
                                  imageEveryNSteps: config.imageEveryNSteps)
                let driver = WebDriverAgentDriver(
                    config: .init(udid: config.udid, bundleId: config.bundleId, appPath: config.appPath))
                let ledger = JSONLLedger()
                let coordinator = RunCoordinator(driver: driver, agent: agent,
                                                 ledger: ledger, config: config)

                for await event in await coordinator.run() {
                    apply(event)
                }
            } catch {
                phase = .finished
                friction.append("erro de setup: \(error)")
            }
        }
    }

    private func apply(_ event: RunCoordinator.Event) {
        switch event {
        case .phaseChanged(let p):
            phase = p
        case .step(let index, let decision, let outcome):
            steps.append(.init(index: index, reasoning: decision.reasoning,
                               action: decision.action.map(String.init(describing:)),
                               ok: outcome?.ok))
        case .finished(let state):
            phase = .finished
            outcome = state.outcome
            friction = state.friction
        }
    }
}
