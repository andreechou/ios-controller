import Foundation

/// Descrição de uma tool exposta ao modelo (JSON Schema do input).
/// `@unchecked Sendable`: `inputSchema` é um JSON Schema constante e imutável —
/// só é lido e re-serializado pros providers, nunca mutado após a init.
public struct ToolSpec: @unchecked Sendable {
    public var name: String
    public var description: String
    public var inputSchema: [String: Any]

    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name; self.description = description; self.inputSchema = inputSchema
    }
}

/// Catálogo de tools que o agente pode chamar. Cada tool corresponde a um case
/// de `Action` (ou ao encerramento do run via `report`).
public enum ToolSchema {
    public static let all: [ToolSpec] = [
        ToolSpec(name: "tap", description: "Toca numa coordenada em pontos.",
                 inputSchema: ["type": "object",
                               "properties": ["x": ["type": "number"], "y": ["type": "number"]],
                               "required": ["x", "y"]]),
        ToolSpec(name: "tap_element", description: "Toca num elemento pelo id da árvore de a11y.",
                 inputSchema: ["type": "object",
                               "properties": ["id": ["type": "string"]],
                               "required": ["id"]]),
        ToolSpec(name: "type_text", description: "Digita texto no campo focado.",
                 inputSchema: ["type": "object",
                               "properties": ["text": ["type": "string"]],
                               "required": ["text"]]),
        ToolSpec(name: "scroll", description: "Faz scroll direcional.",
                 inputSchema: ["type": "object",
                               "properties": ["direction": ["type": "string",
                                               "enum": ["up", "down", "left", "right"]],
                                              "amount": ["type": "number"]],
                               "required": ["direction"]]),
        ToolSpec(name: "wait", description: "Espera N milissegundos.",
                 inputSchema: ["type": "object",
                               "properties": ["ms": ["type": "integer"]],
                               "required": ["ms"]]),
        // Encerra o run com veredito + notas de fricção pro ledger.
        ToolSpec(name: "report", description: "Encerra o teste com um veredito e notas de fricção de UX.",
                 inputSchema: ["type": "object",
                               "properties": ["status": ["type": "string",
                                               "enum": ["succeeded", "failed", "gave_up"]],
                                              "summary": ["type": "string"],
                                              "friction": ["type": "array", "items": ["type": "string"]]],
                               "required": ["status", "summary"]]),
    ]

    /// Converte uma tool call do modelo em uma `Action` (ou nil se for `report`).
    public static func action(from call: ToolCall) -> Action? {
        let json = (try? JSONSerialization.jsonObject(with: call.arguments)) as? [String: Any] ?? [:]
        switch call.name {
        case "tap":
            guard let x = json["x"] as? Double, let y = json["y"] as? Double else { return nil }
            return .tap(x: x, y: y)
        case "tap_element":
            guard let id = json["id"] as? String else { return nil }
            return .tapElement(id: id)
        case "type_text":
            guard let t = json["text"] as? String else { return nil }
            return .type(text: t)
        case "scroll":
            let dir = Action.ScrollDirection(rawValue: json["direction"] as? String ?? "down") ?? .down
            return .scroll(direction: dir, amount: json["amount"] as? Double ?? 300)
        case "wait":
            return .wait(ms: json["ms"] as? Int ?? 500)
        default:
            return nil // "report" — tratado pelo Agent
        }
    }
}
