import SwiftUI
import IOSControllerCore

/// Estado do mapa de navegação. Dois modos:
/// - **manual** (Mapear): lança o app no root; cada clique em "Capturar tela"
///   registra a tela atual — você dirige o Simulator na mão.
/// - **auto** (Mapear automático): AuditCrawler (BFS determinístico) navega
///   sozinho e a árvore cresce via streaming.
/// PNGs ficam em ~/.ios-controller/atlas/<bundle>-<ts>/.
@MainActor
@Observable
final class AtlasController {
    enum Mode { case manual, auto }

    struct Node: Identifiable {
        let signature: String
        let depth: Int
        let edge: String?            // ação que trouxe até aqui; nil = launch
        let parentSignature: String?
        let image: NSImage?
        let imagePath: String
        let issueCount: Int
        let elementCount: Int
        var id: String { signature }
    }

    private(set) var nodes: [Node] = []
    private(set) var running = false
    private(set) var mode: Mode = .auto
    private(set) var status: String?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var manualDriver: WebDriverAgentDriver?
    @ObservationIgnored private var lastSignature: String?
    @ObservationIgnored private var depthBySignature: [String: Int] = [:]
    @ObservationIgnored private var sigByPath: [String: String] = [:]
    @ObservationIgnored private var runDir: URL?

    var maxDepthSeen: Int { nodes.map(\.depth).max() ?? 0 }

    func nodes(at depth: Int) -> [Node] {
        // Irmãos do mesmo pai ficam juntos na coluna.
        nodes.filter { $0.depth == depth }
            .sorted { ($0.parentSignature ?? "", $0.signature)
                    < ($1.parentSignature ?? "", $1.signature) }
    }

    // MARK: - Modo manual (semiautomático): você navega, ele captura

    /// Abre a sessão WDA (lança o app no root), captura a primeira tela e fica
    /// de olho: assinatura mudou (= seu toque navegou) → espera a tela assentar
    /// → captura sozinho. Voltar pra tela já mapeada só reancora, sem duplicar.
    func startManual(udid: String, bundleId: String) {
        guard !running, !bundleId.isEmpty else { return }
        reset(.manual, bundleId: bundleId)
        let driver = WebDriverAgentDriver(config: .init(udid: udid, bundleId: bundleId))
        manualDriver = driver
        task = Task {
            do {
                try await driver.prepare()
                try? await Task.sleep(for: .milliseconds(800))   // launch assenta
                await captureCurrentScreen()
            } catch {
                status = "Falhou: \(error.localizedDescription)"
                manualDriver = nil
                running = false
                return
            }
            // Watcher semiautomático: polling leve (árvore sem screenshot).
            while !Task.isCancelled, let driver = manualDriver {
                try? await Task.sleep(for: .milliseconds(900))
                guard let tree = try? await driver.observeTree() else { continue }
                let sig = ScreenSignature.of(tree)
                guard sig != lastSignature else { continue }
                if depthBySignature[sig] != nil {
                    lastSignature = sig   // backhistory: reancora em silêncio
                } else {
                    try? await Task.sleep(for: .milliseconds(700))   // página carregando
                    await captureCurrentScreen()
                }
            }
        }
    }

    /// Registra a tela atual do Simulator no mapa (dedupe por assinatura).
    func captureCurrentScreen() async {
        guard let driver = manualDriver else { return }
        do {
            let obs = try await driver.observe()
            let sig = ScreenSignature.of(obs.accessibility)
            guard depthBySignature[sig] == nil else {
                lastSignature = sig   // reancora: próxima captura pendura aqui
                status = "tela já está no mapa"
                return
            }
            appendManual(obs, signature: sig, parent: lastSignature)
            lastSignature = sig
            status = nil
        } catch {
            status = "Captura falhou: \(error.localizedDescription)"
        }
    }

    // MARK: - Modo auto: crawl BFS

    func startAuto(udid: String, bundleId: String, maxScreens: Int, maxDepth: Int) {
        guard !running, !bundleId.isEmpty else { return }
        reset(.auto, bundleId: bundleId)
        let driver = WebDriverAgentDriver(config: .init(udid: udid, bundleId: bundleId))
        let crawler = AuditCrawler(driver: driver, bundleId: bundleId,
                                   maxScreens: maxScreens, maxDepth: maxDepth)
        task = Task {
            do {
                let result = try await crawler.crawl { screen in
                    Task { @MainActor in self.append(screen) }
                }
                status = "\(result.screens.count) telas · \(result.totalIssues) issues de a11y"
                    + (result.truncated ? " · parcial" : "")
            } catch {
                status = "Falhou: \(error.localizedDescription)"
            }
            running = false
        }
    }

    /// Para o modo ativo. No manual a sessão fica órfã de propósito —
    /// teardown fecharia o app na sua frente no Simulator.
    func stop() {
        task?.cancel()
        switch mode {
        case .manual:
            manualDriver = nil
            status = "\(nodes.count) telas mapeadas"
            running = false
        case .auto:
            if running { status = "Parando…" }
        }
    }

    // MARK: - Internos

    private func reset(_ newMode: Mode, bundleId: String) {
        nodes = []
        sigByPath = [:]
        depthBySignature = [:]
        lastSignature = nil
        status = nil
        mode = newMode
        running = true
        let dir = URL(fileURLWithPath:
            NSHomeDirectory() + "/.ios-controller/atlas/\(bundleId)-\(Self.stamp())")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runDir = dir
    }

    private func append(_ screen: AuditScreen) {
        guard let runDir else { return }
        let file = runDir.appending(path: String(format: "%03d.png", nodes.count))
        try? screen.screenshotPNG.write(to: file)

        let key = Self.key(screen.path)
        sigByPath[key] = screen.signature
        depthBySignature[screen.signature] = screen.path.count
        let parent = screen.path.isEmpty
            ? nil : sigByPath[Self.key(Array(screen.path.dropLast()))]

        nodes.append(.init(
            signature: screen.signature,
            depth: screen.path.count,
            edge: screen.path.last.map { "tap \($0.describe)" },
            parentSignature: parent,
            image: NSImage(data: screen.screenshotPNG),
            imagePath: file.path,
            issueCount: screen.issues.count,
            elementCount: screen.nodeCount))
    }

    private func appendManual(_ obs: ScreenObservation, signature: String, parent: String?) {
        guard let runDir else { return }
        let file = runDir.appending(path: String(format: "%03d.png", nodes.count))
        try? obs.screenshotPNG.write(to: file)

        let depth = parent.flatMap { depthBySignature[$0].map { $0 + 1 } } ?? 0
        depthBySignature[signature] = depth

        nodes.append(.init(
            signature: signature,
            depth: depth,
            edge: parent == nil ? nil : "manual",
            parentSignature: parent,
            image: NSImage(data: obs.screenshotPNG),
            imagePath: file.path,
            issueCount: A11yChecks.run(on: obs.accessibility).count,
            elementCount: obs.accessibility.nodes.count))
    }

    nonisolated private static func key(_ path: [TapTarget]) -> String {
        path.map { "\($0.role)|\($0.label)|\($0.occurrence)" }.joined(separator: "→")
    }

    nonisolated private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

/// Janela Atlas: treeline de navegação do app — colunas por profundidade,
/// cada tela com screenshot, ação de chegada e issues de a11y.
struct AtlasView: View {
    @Environment(AtlasController.self) private var atlas
    @Environment(AppState.self) private var state
    @AppStorage("defaultUDID") private var udid = "booted"
    @AppStorage("defaultBundleId") private var bundleId = ""
    @AppStorage("atlasMaxScreens") private var maxScreens = 30
    @AppStorage("atlasMaxDepth") private var maxDepth = 3
    @State private var crawlStatus: CrawlControl.Status?

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let status = crawlStatus {
                crawlBar(status)
                Divider()
            }
            if atlas.nodes.isEmpty {
                emptyState
            } else {
                map
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .task {
            // Heartbeat do crawl (deste app OU de fora, ex: CLI) via
            // ~/.ios-controller/crawl/status.json.
            while !Task.isCancelled {
                crawlStatus = CrawlControl.current()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: - Barra de controles

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Bundle ID", text: $bundleId)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Picker("Profundidade", selection: $maxDepth) {
                ForEach(1..<6) { d in Text("\(d)").tag(d) }
            }
            .fixedSize()
            Picker("Telas", selection: $maxScreens) {
                ForEach([10, 20, 30, 60, 100], id: \.self) { n in Text("\(n)").tag(n) }
            }
            .fixedSize()

            Spacer()

            if atlas.running, atlas.mode == .manual {
                Button("Capturar tela", systemImage: "camera.viewfinder") {
                    Task { await atlas.captureCurrentScreen() }
                }
                .buttonStyle(.borderedProminent)
                if let status = atlas.status {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("\(atlas.nodes.count) telas")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button("Parar", role: .cancel) { atlas.stop() }
            } else if atlas.running {
                ProgressView()
                    .controlSize(.small)
                Text("\(atlas.nodes.count) telas")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Parar", role: .cancel) { atlas.stop() }
            } else {
                if let status = atlas.status {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button("Mapear") { startManual() }
                    .buttonStyle(.borderedProminent)
                    .disabled(bundleId.isEmpty || state.wdaUp != true)
                    .help(state.wdaUp == true
                          ? "Semiautomático: você navega no Simulator; a cada toque ele "
                            + "espera carregar e captura sozinho (voltar não duplica)"
                          : "WDA fora do ar — suba pela palette")
                Button("Mapear automático") { startAuto() }
                    .disabled(bundleId.isEmpty || state.wdaUp != true)
                    .help(state.wdaUp == true
                          ? "Crawl BFS: lança o app e toca em cada elemento sozinho"
                          : "WDA fora do ar — suba pela palette")
            }
        }
        .padding(10)
    }

    // MARK: - Barra do crawl ativo (local ou externo)

    /// Comandos viajam por arquivos-flag (CrawlControl) — funcionam igual pro
    /// crawl desta janela e pra um `ios-controller-cli audit` rodando fora.
    private func crawlBar(_ status: CrawlControl.Status) -> some View {
        HStack(spacing: 10) {
            Image(systemName: status.paused ? "pause.circle.fill" : "dot.radiowaves.left.and.right")
                .foregroundStyle(status.paused ? Color.orange : Color.green)
            Text("\(status.bundleId) · \(status.screens) telas · \(status.queued) na fila")
                .font(.callout.monospacedDigit())
                .lineLimit(1)
            if !status.isMine {
                Text("externo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .help("Crawl de outro processo (ex: ios-controller-cli audit)")
            }
            Spacer()
            Button(status.paused ? "Retomar" : "Pausar") {
                CrawlControl.setPaused(!status.paused)
            }
            Button("Parar", role: .destructive) {
                CrawlControl.requestStop()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Mapa

    private var map: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(0...atlas.maxDepthSeen, id: \.self) { depth in
                    column(depth)
                }
            }
            .padding(16)
        }
    }

    private func column(_ depth: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(depth == 0 ? "Root" : "Profundidade \(depth)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(atlas.nodes(at: depth)) { node in
                card(node)
            }
        }
    }

    private func card(_ node: AtlasController.Node) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = node.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor)))
            }
            Label(node.edge ?? "launch", systemImage: node.edge == nil ? "play" : "hand.tap")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 10) {
                Label("\(node.elementCount)", systemImage: "square.grid.2x2")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("Elementos de a11y na tela")
                if node.issueCount > 0 {
                    Label("\(node.issueCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Issues de acessibilidade")
                }
            }
        }
        .frame(width: 150)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.open(URL(fileURLWithPath: node.imagePath))
        }
        .help(node.edge ?? "Tela inicial")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Atlas de navegação", systemImage: "map")
        } description: {
            Text("Mapear: você navega no Simulator e cada toque vira captura sozinho "
                 + "(voltar não duplica; \"Capturar tela\" força). Mapear automático: "
                 + "crawl BFS toca em cada elemento e monta o mapa com checagens de a11y.")
        } actions: {
            Button("Mapear") { startManual() }
                .buttonStyle(.borderedProminent)
                .disabled(bundleId.isEmpty || state.wdaUp != true)
            Button("Mapear automático") { startAuto() }
                .disabled(bundleId.isEmpty || state.wdaUp != true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startManual() {
        atlas.startManual(udid: udid, bundleId: bundleId)
    }

    private func startAuto() {
        atlas.startAuto(udid: udid, bundleId: bundleId,
                        maxScreens: maxScreens, maxDepth: maxDepth)
    }
}
