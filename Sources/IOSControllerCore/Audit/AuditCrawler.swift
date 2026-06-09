import Foundation

/// Navega sistematicamente todas as telas alcançáveis e captura screenshot de
/// cada tela única, rodando checagens de a11y.
///
/// Estratégia: **BFS por replay a partir do root**. Cada tela é alcançada
/// relançando o app e reproduzindo a sequência de toques desde o início — o que
/// é robusto (sem depender de gestos de "voltar" frágeis). Telas idênticas são
/// deduplicadas por `ScreenSignature`. Determinístico, sem LLM.
public struct AuditCrawler: Sendable {
    let driver: WebDriverAgentDriver
    let bundleId: String
    let maxScreens: Int
    let maxDepth: Int

    public init(driver: WebDriverAgentDriver, bundleId: String,
                maxScreens: Int = 60, maxDepth: Int = 4) {
        self.driver = driver; self.bundleId = bundleId
        self.maxScreens = maxScreens; self.maxDepth = maxDepth
    }

    public func crawl(onScreen: (@Sendable (AuditScreen) -> Void)? = nil) async throws -> AuditResult {
        let started = Date()
        try await driver.prepare()

        var visited = Set<String>()
        var screens: [AuditScreen] = []
        var frontier: [[TapTarget]] = [[]]   // caminhos a partir do root
        var truncated = false

        while !frontier.isEmpty {
            if screens.count >= maxScreens { truncated = true; break }
            let path = frontier.removeFirst()

            // Reseta ao root e reproduz o caminho.
            _ = try await driver.perform(.launch(bundleId: bundleId))
            _ = try await driver.perform(.wait(ms: 800))
            var obs = try await driver.observe()

            var broken = false
            for target in path {
                guard let (x, y) = resolve(target, obs.accessibility.nodes) else { broken = true; break }
                _ = try await driver.perform(.tap(x: x, y: y))
                _ = try await driver.perform(.wait(ms: 500))
                obs = try await driver.observe()
            }
            if broken { continue }   // caminho não reproduzível — pula

            let sig = ScreenSignature.of(obs.accessibility)
            guard !visited.contains(sig) else { continue }
            visited.insert(sig)

            let screen = AuditScreen(
                signature: sig,
                pathDescription: describe(path),
                screenshotPNG: obs.screenshotPNG,
                nodeCount: obs.accessibility.nodes.count,
                issues: A11yChecks.run(on: obs.accessibility))
            screens.append(screen)
            onScreen?(screen)

            // Enfileira os filhos (cada elemento tocável vira um novo caminho).
            if path.count < maxDepth {
                for target in tappableTargets(obs.accessibility.nodes) {
                    frontier.append(path + [target])
                }
            }
        }

        try await driver.teardown()
        return AuditResult(bundleId: bundleId, screens: screens,
                           startedAt: started, finishedAt: Date(), truncated: truncated)
    }

    // MARK: - Resolução de alvos

    private func tappableTargets(_ nodes: [AccessibilitySnapshot.Node]) -> [TapTarget] {
        var seen: [String: Int] = [:]
        var targets: [TapTarget] = []
        for node in nodes where WDASource.isInteractive(node.role) && node.enabled {
            let key = "\(node.role)|\(node.label ?? "")"
            let occ = seen[key, default: 0]
            seen[key] = occ + 1
            targets.append(.init(role: node.role, label: node.label ?? "", occurrence: occ))
        }
        return targets
    }

    private func resolve(_ target: TapTarget,
                         _ nodes: [AccessibilitySnapshot.Node]) -> (Double, Double)? {
        let matches = nodes.filter { $0.role == target.role && ($0.label ?? "") == target.label }
        guard target.occurrence < matches.count else { return nil }
        return matches[target.occurrence].frame.center
    }

    private func describe(_ path: [TapTarget]) -> String {
        path.isEmpty ? "root" : "root → " + path.map { "tap \($0.describe)" }.joined(separator: " → ")
    }
}
