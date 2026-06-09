import Foundation

/// Um único provider OpenAI-compatible cobre OpenAI, DeepSeek e OpenRouter —
/// só muda a base URL e a key. Tool use via `tools`/`tool_calls`, imagem via
/// `image_url` com data URI.
public struct OpenAICompatibleProvider: ModelProvider {
    public let id: ProviderID
    private let apiKey: String
    private let endpoint: URL

    public init(id: ProviderID, apiKey: String, baseURL: URL) {
        self.id = id
        self.apiKey = apiKey
        self.endpoint = baseURL.appendingPathComponent("chat/completions")
    }

    /// Fábricas pros três compatíveis.
    public static func openai(_ key: String) -> Self {
        .init(id: .openai, apiKey: key, baseURL: URL(string: "https://api.openai.com/v1")!)
    }
    public static func deepseek(_ key: String) -> Self {
        .init(id: .deepseek, apiKey: key, baseURL: URL(string: "https://api.deepseek.com/v1")!)
    }
    public static func openrouter(_ key: String) -> Self {
        .init(id: .openrouter, apiKey: key, baseURL: URL(string: "https://openrouter.ai/api/v1")!)
    }

    public func complete(_ request: ModelRequest) async throws -> ModelResponse {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: Any]] = [["role": "system", "content": request.system]]
        messages += request.messages.map(Self.encodeMessage)

        let body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens,
            "messages": messages,
            "tools": request.tools.map { [
                "type": "function",
                "function": ["name": $0.name, "description": $0.description, "parameters": $0.inputSchema]
            ] },
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProviderError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1,
                                           body: String(data: data, encoding: .utf8) ?? "")
        }
        return try Self.parse(data)
    }

    static func encodeMessage(_ m: ModelMessage) -> [String: Any] {
        if let img = m.imagePNG {
            var parts: [[String: Any]] = [[
                "type": "image_url",
                "image_url": ["url": "data:image/png;base64,\(img.base64EncodedString())"]
            ]]
            if let t = m.text { parts.append(["type": "text", "text": t]) }
            return ["role": m.role.rawValue, "content": parts]
        }
        return ["role": m.role.rawValue, "content": m.text ?? ""]
    }

    static func parse(_ data: Data) throws -> ModelResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw ProviderError.decoding("choices ausente")
        }
        let text = message["content"] as? String
        var calls: [ToolCall] = []
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in toolCalls {
                guard let fn = tc["function"] as? [String: Any] else { continue }
                let name = fn["name"] as? String ?? ""
                let argString = fn["arguments"] as? String ?? "{}"
                calls.append(ToolCall(name: name, arguments: Data(argString.utf8)))
            }
        }
        let u = json["usage"] as? [String: Any]
        return ModelResponse(text: text, toolCalls: calls,
                             usage: .init(inputTokens: u?["prompt_tokens"] as? Int ?? 0,
                                          outputTokens: u?["completion_tokens"] as? Int ?? 0))
    }
}
