import Foundation

/// Resolve um `ProviderID` no provider concreto, lendo keys do ambiente.
/// Os 4 são cidadãos de primeira classe — nenhum é cortado.
public struct ProviderRegistry: Sendable {
    private let env: [String: String]

    public init(env: [String: String] = ProcessInfo.processInfo.environment) {
        self.env = env
    }

    public func provider(for id: ProviderID) throws -> ModelProvider {
        switch id {
        case .anthropic:
            return AnthropicProvider(apiKey: try key("ANTHROPIC_API_KEY", id))
        case .openai:
            return OpenAICompatibleProvider.openai(try key("OPENAI_API_KEY", id))
        case .deepseek:
            return OpenAICompatibleProvider.deepseek(try key("DEEPSEEK_API_KEY", id))
        case .openrouter:
            return OpenAICompatibleProvider.openrouter(try key("OPENROUTER_API_KEY", id))
        }
    }

    private func key(_ name: String, _ id: ProviderID) throws -> String {
        guard let v = env[name], !v.isEmpty else { throw ProviderError.missingAPIKey(id) }
        return v
    }

    /// Modelos default por provider — ajuste à vontade.
    public static func defaultModel(for id: ProviderID) -> String {
        switch id {
        case .anthropic:  return "claude-sonnet-4-20250514"
        case .openai:     return "gpt-4o"
        case .deepseek:   return "deepseek-chat"
        case .openrouter: return "anthropic/claude-sonnet-4"
        }
    }
}
