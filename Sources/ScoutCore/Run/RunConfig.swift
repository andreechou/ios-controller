import Foundation

public struct RunConfig: Sendable {
    public var goal: String
    public var persona: String
    public var udid: String
    public var bundleId: String
    public var appPath: String?
    public var provider: ProviderID
    public var model: String

    // Budgets — encerram o run mesmo se o agente não chamar `report`.
    public var maxSteps: Int
    public var maxTokens: Int
    public var imageEveryNSteps: Int

    public init(goal: String, persona: String, udid: String, bundleId: String,
                appPath: String? = nil, provider: ProviderID, model: String,
                maxSteps: Int = 40, maxTokens: Int = 200_000, imageEveryNSteps: Int = 1) {
        self.goal = goal; self.persona = persona; self.udid = udid
        self.bundleId = bundleId; self.appPath = appPath
        self.provider = provider; self.model = model
        self.maxSteps = maxSteps; self.maxTokens = maxTokens
        self.imageEveryNSteps = imageEveryNSteps
    }
}

public struct RunState: Sendable {
    public enum Phase: String, Sendable { case idle, preparing, running, finished }
    public var phase: Phase = .idle
    public var step = 0
    public var tokensUsed = 0
    public var outcome: AgentDecision.Status?
    public var friction: [String] = []
    public init() {}
}
