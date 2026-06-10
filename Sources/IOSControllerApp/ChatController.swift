import Foundation
import IOSControllerCore
import Observation

/// Chat interativo que dirige o simulador: cada mensagem sua vira instrução;
/// o modelo (via API) responde chamando tools (tap/type/scroll…) que executam
/// no WDA. Ações espelham no feed (painel Steps) como qualquer outro driver.
/// Limitação herdada do core: sem role de tool-result nos providers — ação e
/// resultado entram na história como texto (mesma técnica do loop interno).
@MainActor
@Observable
final class ChatController {
    struct Message: Identifiable {
        enum Role { case user, assistant, action, error }
        let id = UUID()
        let role: Role
        let text: String
    }

    let providerID: ProviderID
    var messages: [Message] = []
    var busy = false

    @ObservationIgnored private var history: [ModelMessage] = []
    @ObservationIgnored private var driver: WebDriverAgentDriver?

    private static let maxActionsPerTurn = 20
    private static let systemPrompt = """
    Você dirige um app iOS no Simulator em nome do usuário, via tools (tap, \
    tap_element, type_text, scroll, wait). A cada turno você recebe a árvore \
    de acessibilidade da tela atual ("TELA ATUAL"). Use tap_element com o id \
    da árvore sempre que possível; coordenadas são pontos. Quando terminar a \
    instrução do usuário (ou não der mais pra avançar), responda em texto \
    explicando o que fez e o que observou. Seja conciso.
    """

    init(provider: ProviderID) {
        self.providerID = provider
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return }
        Task { await run(trimmed) }
    }

    private func run(_ text: String) async {
        busy = true
        defer { busy = false }

        messages.append(.init(role: .user, text: text))
        history.append(.init(role: .user, text: text))

        do {
            let provider = try makeProvider()
            let driver = try await ensureDriver()
            var actions = 0

            while actions <= Self.maxActionsPerTurn {
                let obs = try await driver.observe()
                let screen = "TELA ATUAL:\n" + obs.accessibility.promptDescription()
                let request = ModelRequest(
                    model: ProviderRegistry.defaultModel(for: providerID),
                    system: Self.systemPrompt,
                    messages: history + [.init(role: .user, text: screen)],
                    tools: ToolSchema.all)
                let response = try await provider.complete(request)

                if let call = response.toolCalls.first, call.name != "report",
                   let action = ToolSchema.action(from: call) {
                    let outcome = try await driver.perform(action)
                    let line = "\(action)"
                    messages.append(.init(role: .action, text: "\(line) → ok=\(outcome.ok)"))
                    FeedWriter.append(text: line, ok: outcome.ok)
                    history.append(.init(role: .assistant, text: "[ação] \(line)"))
                    history.append(.init(role: .user,
                                         text: "[resultado] ok=\(outcome.ok) \(outcome.detail ?? "")"))
                    actions += 1
                    continue
                }

                let reply = response.text ?? "(sem resposta)"
                messages.append(.init(role: .assistant, text: reply))
                history.append(.init(role: .assistant, text: reply))
                break
            }
        } catch {
            messages.append(.init(role: .error, text: "\(error)"))
        }
    }

    /// Key da UI (Keychain) tem prioridade; vazia → cai pro ambiente.
    private func makeProvider() throws -> ModelProvider {
        var env = ProcessInfo.processInfo.environment
        let key = Keychain.load(account: providerID.rawValue)
        if !key.isEmpty { env[ProviderRegistry.envVar(for: providerID)] = key }
        return try ProviderRegistry(env: env).provider(for: providerID)
    }

    private func ensureDriver() async throws -> WebDriverAgentDriver {
        if let driver { return driver }
        let udid = UserDefaults.standard.string(forKey: "defaultUDID") ?? "booted"
        let bundle = UserDefaults.standard.string(forKey: "defaultBundleId") ?? ""
        let d = WebDriverAgentDriver(config: .init(udid: udid, bundleId: bundle))
        try await d.prepare()
        driver = d
        return d
    }
}

/// Espelha ações do chat API no feed.jsonl — mesmo arquivo que wda.sh/MCP usam,
/// então o painel Steps mostra tudo de todos os drivers.
enum FeedWriter {
    private static let url = URL(fileURLWithPath: NSHomeDirectory() + "/.ios-controller/feed.jsonl")
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    static func append(text: String, ok: Bool) {
        let obj: [String: Any] = ["ts": formatter.string(from: Date()), "text": text, "ok": ok]
        guard var line = try? JSONSerialization.data(withJSONObject: obj) else { return }
        line.append(0x0A)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: line)
        }
    }
}
