import Foundation

/// Encapsula uma rodada percepção→decisão. Mantém o histórico de mensagens
/// pro provider e traduz a tool call de volta numa `AgentDecision`.
public actor Agent {
    private let provider: ModelProvider
    private let model: String
    private let system: String
    private var history: [ModelMessage] = []
    /// A cada N passos manda screenshot; nos demais, só a árvore de a11y (mais barato).
    private let imageEveryNSteps: Int
    private var step = 0

    public init(provider: ModelProvider, model: String, goal: String,
                persona: String, imageEveryNSteps: Int = 1) {
        self.provider = provider
        self.model = model
        self.system = Prompt.system(goal: goal, persona: persona)
        self.imageEveryNSteps = max(1, imageEveryNSteps)
    }

    public func decide(from observation: ScreenObservation) async throws -> (AgentDecision, ModelResponse.Usage) {
        let includeImage = step % imageEveryNSteps == 0
        history.append(Prompt.step(observation: observation, includeImage: includeImage))

        let response = try await provider.complete(
            ModelRequest(model: model, system: system, messages: history,
                         tools: ToolSchema.all, maxTokens: 1024)
        )
        history.append(ModelMessage(role: .assistant, text: response.text))
        step += 1

        return (Self.decision(from: response), response.usage)
    }

    /// Traduz a resposta do modelo (texto + tool calls) numa decisão.
    static func decision(from response: ModelResponse) -> AgentDecision {
        let reasoning = response.text ?? ""
        guard let call = response.toolCalls.first else {
            // Sem tool call: tratamos como "continue" sem ação (re-prompt no loop).
            return AgentDecision(reasoning: reasoning, action: nil, status: .continue)
        }

        if call.name == "report" {
            let json = (try? JSONSerialization.jsonObject(with: call.arguments)) as? [String: Any] ?? [:]
            let raw = json["status"] as? String ?? "gave_up"
            let status: AgentDecision.Status = raw == "succeeded" ? .succeeded
                                             : raw == "failed" ? .failed : .gaveUp
            let friction = json["friction"] as? [String] ?? []
            let summary = json["summary"] as? String ?? reasoning
            return AgentDecision(reasoning: summary, action: nil, status: status, friction: friction)
        }

        return AgentDecision(reasoning: reasoning,
                             action: ToolSchema.action(from: call),
                             status: .continue)
    }
}
