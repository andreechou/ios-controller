import Foundation

/// `SimulatorDriver` que dirige a responder chain do simulador via WebDriverAgent.
/// `prepare` garante o sim bootado e abre a sessão WDA; `observe` lê a árvore de
/// a11y + screenshot; `perform` traduz cada `Action` num endpoint WDA.
public actor WebDriverAgentDriver: SimulatorDriver {
    public struct Config: Sendable {
        public var udid: String
        public var bundleId: String
        public var appPath: String?
        public var wdaBaseURL: URL
        public init(udid: String, bundleId: String, appPath: String? = nil,
                    wdaBaseURL: URL = URL(string: "http://127.0.0.1:8100")!) {
            self.udid = udid; self.bundleId = bundleId
            self.appPath = appPath; self.wdaBaseURL = wdaBaseURL
        }
    }

    private let config: Config
    private let simctl = Simctl()
    private let wda: WebDriverAgentClient
    private var sessionId: String?
    private var screenSize = ScreenObservation.Size(width: 0, height: 0)
    /// Cache do último snapshot: id do nó -> frame, pra resolver `tapElement`.
    private var lastFrames: [String: AccessibilitySnapshot.Node.Frame] = [:]

    public init(config: Config) {
        self.config = config
        self.wda = WebDriverAgentClient(baseURL: config.wdaBaseURL)
    }

    public func prepare() async throws {
        try simctl.boot(udid: config.udid)

        // Aguarda o WDA ficar de pé (rodar o WebDriverAgentRunner é
        // responsabilidade do scripts/start-wda.sh — ver README).
        var ready = false
        for _ in 0..<30 {
            if await wda.isReady() { ready = true; break }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard ready else {
            throw DriverError.wdaUnavailable(reason: "WDA não respondeu em \(config.wdaBaseURL). Rode scripts/start-wda.sh.")
        }

        sessionId = try await wda.createSession(bundleId: config.bundleId, appPath: config.appPath)
        let (w, h) = try await wda.windowSize(session: sessionId!)
        screenSize = .init(width: w, height: h)
    }

    public func observe() async throws -> ScreenObservation {
        guard let sid = sessionId else { throw DriverError.wdaUnavailable(reason: "sem sessão") }
        let tree = try await wda.sourceJSON(session: sid)
        let nodes = WDASource.parse(tree)
        lastFrames = Dictionary(nodes.map { ($0.id, $0.frame) }, uniquingKeysWith: { a, _ in a })
        let png = try await wda.screenshotPNG()
        return ScreenObservation(screenshotPNG: png,
                           accessibility: AccessibilitySnapshot(nodes: nodes),
                           screenSize: screenSize)
    }

    /// Só a árvore de a11y, sem screenshot — barato o bastante pra polling
    /// (detectar mudança de tela por ScreenSignature sem pagar o PNG).
    public func observeTree() async throws -> AccessibilitySnapshot {
        guard let sid = sessionId else { throw DriverError.wdaUnavailable(reason: "sem sessão") }
        let tree = try await wda.sourceJSON(session: sid)
        let nodes = WDASource.parse(tree)
        lastFrames = Dictionary(nodes.map { ($0.id, $0.frame) }, uniquingKeysWith: { a, _ in a })
        return AccessibilitySnapshot(nodes: nodes)
    }

    public func perform(_ action: Action) async throws -> ActionOutcome {
        guard let sid = sessionId else { throw DriverError.wdaUnavailable(reason: "sem sessão") }
        do {
            switch action {
            case .tap(let x, let y):
                try await wda.tap(session: sid, x: x, y: y)
            case .tapElement(let id):
                guard let f = lastFrames[id] else {
                    return ActionOutcome(ok: false, detail: "elemento \(id) não está no último snapshot")
                }
                try await wda.tap(session: sid, x: f.center.x, y: f.center.y)
            case .type(let text):
                try await wda.typeText(session: sid, text)
            case .scroll(let dir, let amount):
                try await scroll(sid, dir, amount)
            case .wait(let ms):
                try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            case .launch(let bundleId):
                try await wda.launchApp(session: sid, bundleId: bundleId)
            case .terminate(let bundleId):
                try await wda.terminateApp(session: sid, bundleId: bundleId)
            }
            return ActionOutcome(ok: true)
        } catch {
            throw DriverError.actionFailed(action, reason: "\(error)")
        }
    }

    public func teardown() async throws {
        if let sid = sessionId { await wda.deleteSession(sid) }
        sessionId = nil
    }

    /// Scroll = drag do centro pra uma borda, na direção inversa do movimento.
    private func scroll(_ sid: String, _ dir: Action.ScrollDirection, _ amount: Double) async throws {
        let cx = screenSize.width / 2, cy = screenSize.height / 2
        let (tx, ty): (Double, Double)
        switch dir {
        case .up:    (tx, ty) = (cx, cy + amount)
        case .down:  (tx, ty) = (cx, cy - amount)
        case .left:  (tx, ty) = (cx + amount, cy)
        case .right: (tx, ty) = (cx - amount, cy)
        }
        try await wda.drag(session: sid, fromX: cx, fromY: cy, toX: tx, toY: ty)
    }
}
