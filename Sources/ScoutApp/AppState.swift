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
    /// Último frame do simulador (PNG), atualizado pelo preview ao vivo.
    var screenshot: Data?
    var isRunning: Bool { phase == .preparing || phase == .running }

    @ObservationIgnored private var previewTask: Task<Void, Never>?

    /// Espelha o simulador no pane: tira screenshot via simctl em loop (~1.5 fps).
    /// Independe do WDA — funciona ocioso e durante um run.
    func startPreview(udid: String) {
        guard !udid.isEmpty else { return }
        stopPreview()
        previewTask = Task { [weak self] in
            while !Task.isCancelled {
                let data = await Task.detached { try? Simctl().screenshotPNG(udid: udid) }.value
                guard let self, !Task.isCancelled else { break }
                if let data { self.screenshot = data }
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
        }
    }

    func stopPreview() { previewTask?.cancel(); previewTask = nil }

    func start(config: RunConfig, apiKey: String = "") {
        steps = []; friction = []; outcome = nil
        startPreview(udid: config.udid)
        Task {
            do {
                // Key da UI (Keychain) tem prioridade; vazia → cai pro ambiente.
                var env = ProcessInfo.processInfo.environment
                if !apiKey.isEmpty { env[ProviderRegistry.envVar(for: config.provider)] = apiKey }
                let registry = ProviderRegistry(env: env)
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
