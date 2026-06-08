import Foundation

/// Provider Anthropic (formato Messages). Tool use + blocos de imagem base64.
public struct AnthropicProvider: ModelProvider {
    public let id: ProviderID = .anthropic
    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String) { self.apiKey = apiKey }

    public func complete(_ request: ModelRequest) async throws -> ModelResponse {
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens,
            "system": request.system,
            "messages": request.messages.map(Self.encodeMessage),
            "tools": request.tools.map { [
                "name": $0.name, "description": $0.description, "input_schema": $0.inputSchema
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
        var content: [[String: Any]] = []
        if let img = m.imagePNG {
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/png",
                                       "data": img.base64EncodedString()]])
        }
        if let t = m.text { content.append(["type": "text", "text": t]) }
        return ["role": m.role.rawValue, "content": content]
    }

    static func parse(_ data: Data) throws -> ModelResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw ProviderError.decoding("conteúdo ausente")
        }
        var text: String?
        var calls: [ToolCall] = []
        for block in content {
            switch block["type"] as? String {
            case "text": text = (text ?? "") + (block["text"] as? String ?? "")
            case "tool_use":
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                let args = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
                calls.append(ToolCall(name: name, arguments: args))
            default: break
            }
        }
        let u = json["usage"] as? [String: Any]
        return ModelResponse(text: text, toolCalls: calls,
                             usage: .init(inputTokens: u?["input_tokens"] as? Int ?? 0,
                                          outputTokens: u?["output_tokens"] as? Int ?? 0))
    }
}
