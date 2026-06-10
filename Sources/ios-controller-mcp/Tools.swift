import Foundation
import MCP
import IOSControllerCore

/// Catálogo de tools MCP expostas ao Claude Code e o dispatch de cada chamada.
/// Espelha o `ToolSchema` interno, mas no formato do swift-sdk (`Tool`/`Value`).
enum Tools {
    /// Lista anunciada no `ListTools`.
    static let list: [Tool] = [
        Tool(name: "observe",
             description: "Captura o estado atual da tela: árvore de acessibilidade (texto) + screenshot (imagem). Chame antes de decidir a próxima ação.",
             inputSchema: ["type": "object", "properties": [:]]),
        Tool(name: "tap",
             description: "Toca numa coordenada em pontos (origem no topo-esquerda). Devolve só o resultado — chame observe quando precisar ver a tela.",
             inputSchema: ["type": "object",
                           "properties": ["x": ["type": "number"], "y": ["type": "number"]],
                           "required": ["x", "y"]]),
        Tool(name: "tap_element",
             description: "Toca num elemento pelo id da árvore de a11y (visto em observe). Devolve só o resultado — chame observe quando precisar ver a tela.",
             inputSchema: ["type": "object",
                           "properties": ["id": ["type": "string"]],
                           "required": ["id"]]),
        Tool(name: "type_text",
             description: "Digita texto no campo focado. Devolve só o resultado — chame observe quando precisar ver a tela.",
             inputSchema: ["type": "object",
                           "properties": ["text": ["type": "string"]],
                           "required": ["text"]]),
        Tool(name: "scroll",
             description: "Faz scroll direcional. Devolve só o resultado — chame observe quando precisar ver a tela.",
             inputSchema: ["type": "object",
                           "properties": ["direction": ["type": "string",
                                          "enum": ["up", "down", "left", "right"]],
                                          "amount": ["type": "number"]],
                           "required": ["direction"]]),
        Tool(name: "launch",
             description: "(Re)abre um bundle id no simulador. Devolve só o resultado — chame observe quando precisar ver a tela.",
             inputSchema: ["type": "object",
                           "properties": ["bundle_id": ["type": "string"]],
                           "required": ["bundle_id"]]),
    ]

    /// Executa uma chamada e devolve o conteúdo MCP (texto e/ou imagem).
    static func handle(name: String, arguments: [String: Value]?,
                       session: DriverSession) async throws -> [Tool.Content] {
        switch name {
        case "observe":
            let obs = try await session.observe()
            return observationContent(obs)

        case "tap":
            guard let x = arguments?["x"]?.doubleValue, let y = arguments?["y"]?.doubleValue else {
                throw MCPError.invalidParams("tap requer x e y")
            }
            return try await act(.tap(x: x, y: y), session)

        case "tap_element":
            guard let id = arguments?["id"]?.stringValue else {
                throw MCPError.invalidParams("tap_element requer id")
            }
            return try await act(.tapElement(id: id), session)

        case "type_text":
            guard let text = arguments?["text"]?.stringValue else {
                throw MCPError.invalidParams("type_text requer text")
            }
            return try await act(.type(text: text), session)

        case "scroll":
            let dir = Action.ScrollDirection(rawValue: arguments?["direction"]?.stringValue ?? "down") ?? .down
            let amount = arguments?["amount"]?.doubleValue ?? 300
            return try await act(.scroll(direction: dir, amount: amount), session)

        case "launch":
            guard let bundle = arguments?["bundle_id"]?.stringValue else {
                throw MCPError.invalidParams("launch requer bundle_id")
            }
            return try await act(.launch(bundleId: bundle), session)

        default:
            throw MCPError.invalidParams("tool desconhecida: \(name)")
        }
    }

    /// Executa a ação e devolve só o resultado. Observação é explícita (tool
    /// `observe`): screenshot+a11y a cada ação inflava o contexto do cliente à toa.
    private static func act(_ action: Action, _ session: DriverSession) async throws -> [Tool.Content] {
        let outcome = try await session.perform(action)
        var text = "ação: \(action) → ok=\(outcome.ok)"
        if let detail = outcome.detail, !detail.isEmpty { text += " (\(detail))" }
        return [.text(text)]
    }

    /// Converte uma ScreenObservation em conteúdo MCP: a11y como texto, tela como imagem.
    private static func observationContent(_ obs: ScreenObservation) -> [Tool.Content] {
        let tree = obs.accessibility.promptDescription()
        return [
            .text("TELA (\(Int(obs.screenSize.width))x\(Int(obs.screenSize.height))):\n\(tree)"),
            .image(data: obs.screenshotPNG.base64EncodedString(),
                   mimeType: "image/png", metadata: nil),
        ]
    }
}
