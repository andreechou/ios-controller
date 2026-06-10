import SwiftUI
import IOSControllerCore

/// Estado observável da UI. Dispara um run e consome o AsyncStream de eventos.
@MainActor
@Observable
final class AppState {
    struct StepRow: Identifiable {
        let id = UUID()
        let index: Int
        let reasoning: String
        let action: String?
        let ok: Bool?
        var imagePath: String? = nil
    }

    var phase: RunState.Phase = .idle
    var steps: [StepRow] = []
    var friction: [String] = []
    var outcome: AgentDecision.Status?
    /// Último frame do simulador (PNG), atualizado pelo preview ao vivo.
    var screenshot: Data?
    var isRunning: Bool { phase == .preparing || phase == .running }

    // Saúde do cockpit: WDA no ar? qual sim? qual bundle na sessão externa?
    var wdaUp: Bool?
    var simName: String?
    var sessionBundle: String?
    var wdaStarting = false

    /// Diretório do projeto — cwd do terminal e raiz do start-wda.sh.
    /// Override: defaults write md.chou.ioscontroller.app projectDir <path>.
    static var projectDir: String {
        UserDefaults.standard.string(forKey: "projectDir")
            ?? ProcessInfo.processInfo.environment["IOSCTL_PROJECT_DIR"]
            ?? NSHomeDirectory() + "/Projects/ios-controller"
    }

    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?

    /// Vigia o WDA (:8100) a cada 3s e o nome do sim bootado a cada ~30s.
    func startStatusPolls() {
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                let up = await Self.probeWDA()
                let name = tick % 10 == 0 ? await Self.bootedSimName() : nil
                guard let self, !Task.isCancelled else { break }
                self.wdaUp = up
                if up { self.wdaStarting = false }
                if let name { self.simName = name }
                tick += 1
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    /// Sobe o WDA via scripts/start-wda.sh (fire-and-forget; o poll vira o ●).
    func startWDA() {
        guard !wdaStarting else { return }
        wdaStarting = true
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "cd \(Self.projectDir) && exec ./scripts/start-wda.sh >/tmp/wda-start.log 2>&1"]
        do { try p.run() } catch {
            wdaStarting = false
            friction.append("start-wda falhou: \(error.localizedDescription)")
        }
    }

    nonisolated private static func probeWDA() async -> Bool {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:8100/status")!)
        req.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    /// Nome do primeiro simulador bootado ("iPhone 17"). Parse do simctl.
    nonisolated private static func bootedSimName() async -> String? {
        await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["simctl", "list", "devices", "booted"]
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            for line in out.split(separator: "\n") where line.contains("(Booted)") {
                if let parenIdx = line.firstIndex(of: "(") {
                    return line[..<parenIdx].trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }.value
    }

    /// Espelha o simulador no pane: tira screenshot via simctl em loop (~1.5 fps).
    /// Independe do WDA — funciona ocioso e durante um run.
    func startPreview(udid: String) {
        guard !udid.isEmpty else { return }
        stopPreview()
        previewTask = Task { [weak self] in
            var lastHash: Int?
            while !Task.isCancelled {
                let data = await Task.detached { try? Simctl().screenshotPNG(udid: udid) }.value
                guard let self, !Task.isCancelled else { break }
                // Tela parada → frame idêntico → não republica (evita re-render à toa).
                if let data, data.hashValue != lastHash {
                    lastHash = data.hashValue
                    self.screenshot = data
                }
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
        }
    }

    func stopPreview() { previewTask?.cancel(); previewTask = nil }

    @ObservationIgnored private var feedTask: Task<Void, Never>?

    /// Espelha no feed os passos de QUALQUER driver externo (wda.sh / curl / MCP)
    /// que escreva em ~/.ios-controller/feed.jsonl — uma linha JSON por ação. Começa no fim
    /// do arquivo (só passos novos); detecta truncamento (nova sessão) e reseta.
    func startFeedTail() {
        feedTask?.cancel()
        let path = NSHomeDirectory() + "/.ios-controller/feed.jsonl"
        feedTask = Task { [weak self] in
            var offset: UInt64 = Self.fileSize(path)
            while !Task.isCancelled {
                let (lines, newOffset) = Self.tail(path, from: offset)
                offset = newOffset
                guard let self, !Task.isCancelled else { break }
                for line in lines {
                    guard let data = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }
                    let text = obj["text"] as? String ?? ""
                    let kind = obj["kind"] as? String
                    if kind == "session" {
                        // "▶ session <bundle>" abre, "■ close" fecha.
                        self.sessionBundle = text.hasPrefix("▶ session ")
                            ? String(text.dropFirst("▶ session ".count)) : nil
                    }
                    if kind == "friction" {
                        self.friction.append(text)
                    } else if !text.isEmpty {
                        self.steps.append(.init(index: self.steps.count, reasoning: text,
                                                action: nil, ok: obj["ok"] as? Bool,
                                                imagePath: obj["img"] as? String))
                    }
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    nonisolated private static func fileSize(_ path: String) -> UInt64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    /// Lê linhas novas a partir de `offset`. Retorna (linhas, novo offset).
    nonisolated private static func tail(_ path: String, from offset: UInt64) -> ([String], UInt64) {
        guard let h = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return ([], offset) }
        defer { try? h.close() }
        let end = (try? h.seekToEnd()) ?? 0
        if end < offset { return ([], end) }   // truncado/recriado → reseta
        try? h.seek(toOffset: offset)
        let data = (try? h.readToEnd()) ?? Data()
        let lines = (String(data: data, encoding: .utf8) ?? "")
            .split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return (lines, end)
    }

    func start(config: RunConfig, apiKey: String = "") {
        steps = []; friction = []; outcome = nil
        startPreview(udid: config.udid)
        Task {
            do {
                // Key da UI (Keychain) tem prioridade; vazia → cai pro ambiente.
                var env = ProcessInfo.processInfo.environment
                if !apiKey.isEmpty { env[ProviderRegistry.envVar(for: config.provider)] = apiKey }
                let registry = ProviderRegistry(env: env)
                let provider = try registry.provider(for: config.provider)
                let agent = Agent(provider: provider, model: config.model,
                                  goal: config.goal, persona: config.persona,
                                  imageEveryNSteps: config.imageEveryNSteps)
                let driver = WebDriverAgentDriver(
                    config: .init(udid: config.udid, bundleId: config.bundleId, appPath: config.appPath))
                let ledger = JSONLLedger()
                let coordinator = RunCoordinator(driver: driver, agent: agent,
                                                 ledger: ledger, config: config)

                for await event in await coordinator.run() {
                    apply(event)
                }
            } catch {
                phase = .finished
                friction.append("Setup error: \(error)")
            }
        }
    }

    private func apply(_ event: RunCoordinator.Event) {
        switch event {
        case .phaseChanged(let p):
            phase = p
        case .step(let index, let decision, let outcome):
            steps.append(.init(index: index, reasoning: decision.reasoning,
                               action: decision.action.map(String.init(describing:)),
                               ok: outcome?.ok))
        case .finished(let state):
            phase = .finished
            outcome = state.outcome
            friction = state.friction
        }
    }
}
