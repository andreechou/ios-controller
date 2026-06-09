import Foundation

/// Resolve um `ProviderID` no provider concreto, lendo keys do ambiente.
/// Os 4 são cidadãos de primeira classe — nenhum é cortado.
public struct ProviderRegistry: Sendable {
    private let env: [String: String]

    public init(env: [String: String] = ProcessInfo.processInfo.environment) {
        self.env = env
    }

    public func provider(for id: ProviderID) throws -> ModelProvider {
        let k = try key(for: id)
        switch id {
        case .anthropic:  return AnthropicProvider(apiKey: k)
        case .openai:     return OpenAICompatibleProvider.openai(k)
        case .deepseek:   return OpenAICompatibleProvider.deepseek(k)
        case .openrouter: return OpenAICompatibleProvider.openrouter(k)
        }
    }

    /// Nome da variável de ambiente que guarda a key de cada provider.
    public static func envVar(for id: ProviderID) -> String {
        switch id {
        case .anthropic:  return "ANTHROPIC_API_KEY"
        case .openai:     return "OPENAI_API_KEY"
        case .deepseek:   return "DEEPSEEK_API_KEY"
        case .openrouter: return "OPENROUTER_API_KEY"
        }
    }

    private func key(for id: ProviderID) throws -> String {
        guard let v = env[Self.envVar(for: id)], !v.isEmpty else {
            throw ProviderError.missingAPIKey(id)
        }
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
