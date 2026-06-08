import Foundation
import MCP
import ScoutCore

// scout-mcp — servidor MCP (stdio) que expõe o iOS Simulator como tools.
// O Claude Code conecta como cliente, chama `observe`/`tap`/`type_text`/... e
// recebe de volta a árvore de a11y (texto) + screenshot (imagem) pra "ver" a tela.
//
// Config via env: SCOUT_UDID, SCOUT_BUNDLE_ID, SCOUT_APP_PATH (opcional).

let session = DriverSession()

let server = Server(
    name: "scout",
    version: "0.1.0",
    capabilities: .init(tools: .init(listChanged: false))
)

// Anuncia as tools disponíveis.
await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: Tools.list)
}

// Executa uma chamada de tool.
await server.withMethodHandler(CallTool.self) { params in
    do {
        let content = try await Tools.handle(
            name: params.name, arguments: params.arguments, session: session)
        return CallTool.Result(content: content, isError: false)
    } catch {
        return CallTool.Result(content: [.text("erro: \(error)")], isError: true)
    }
}

let transport = StdioTransport()
try await server.start(transport: transport)

// Mantém o processo vivo enquanto o transport lê stdin.
// (Se a versão do SDK expuser `waitUntilCompleted()`, prefira-o aqui.)
try await Task.sleep(nanoseconds: .max)
