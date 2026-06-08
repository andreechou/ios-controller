import Foundation

/// Abstração sobre os 4 providers. Anthropic usa o formato Messages; OpenAI,
/// DeepSeek e OpenRouter são todos OpenAI-compatible (mesmo cliente, base URL
/// diferente). Por isso só existem duas implementações concretas.
public protocol ModelProvider: Sendable {
    var id: ProviderID { get }
    func complete(_ request: ModelRequest) async throws -> ModelResponse
}

public enum ProviderID: String, Sendable, Codable, CaseIterable {
    case anthropic, openai, deepseek, openrouter
}

public struct ModelRequest: Sendable {
    public var model: String
    public var system: String
    public var messages: [ModelMessage]
    public var tools: [ToolSpec]
    public var maxTokens: Int

    public init(model: String, system: String, messages: [ModelMessage],
                tools: [ToolSpec], maxTokens: Int = 1024) {
        self.model = model; self.system = system; self.messages = messages
        self.tools = tools; self.maxTokens = maxTokens
    }
}

public struct ModelMessage: Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public var role: Role
    public var text: String?
    public var imagePNG: Data?      // screenshot opcional (multimodal)

    public init(role: Role, text: String? = nil, imagePNG: Data? = nil) {
        self.role = role; self.text = text; self.imagePNG = imagePNG
    }
}

public struct ModelResponse: Sendable {
    public var text: String?
    public var toolCalls: [ToolCall]
    public var usage: Usage

    public struct Usage: Sendable { public var inputTokens: Int; public var outputTokens: Int }
    public init(text: String?, toolCalls: [ToolCall], usage: Usage) {
        self.text = text; self.toolCalls = toolCalls; self.usage = usage
    }
}

public struct ToolCall: Sendable { public var name: String; public var arguments: Data }

public enum ProviderError: Error, Sendable {
    case missingAPIKey(ProviderID)
    case httpStatus(Int, body: String)
    case decoding(String)
}
