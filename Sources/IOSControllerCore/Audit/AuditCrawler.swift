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

    /// - Parameters:
    ///   - onScreen: chamado a cada tela única capturada (streaming).
    ///   - onSkip: chamado a cada caminho descartado (duplicata, alvo não
    ///     resolvido ou erro transitório) com a razão — visibilidade do BFS.
    public func crawl(onScreen: (@Sendable (AuditScreen) -> Void)? = nil,
                      onSkip: (@Sendable (_ path: String, _ reason: String) -> Void)? = nil) async throws -> AuditResult {
        let started = Date()
        defer { CrawlControl.clear() }   // heartbeat/flags não assombram o próximo crawl
        try await driver.prepare()

        var visited = Set<String>()
        var screens: [AuditScreen] = []
        var frontier: [[TapTarget]] = [[]]   // caminhos a partir do root
        var truncated = false

        while !frontier.isEmpty {
            if Task.isCancelled { truncated = true; break }   // Stop do chamador
            if CrawlControl.consumeStop() { truncated = true; break }   // Stop externo (arquivo)
            if screens.count >= maxScreens { truncated = true; break }

            // Pausa externa: dorme até a flag sumir, mantendo o heartbeat vivo.
            var stopRequested = false
            while CrawlControl.isPaused(), !stopRequested {
                CrawlControl.publish(bundleId: bundleId, screens: screens.count,
                                     queued: frontier.count, paused: true, startedAt: started)
                if Task.isCancelled || CrawlControl.consumeStop() {
                    stopRequested = true
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            if stopRequested { truncated = true; break }

            CrawlControl.publish(bundleId: bundleId, screens: screens.count,
                                 queued: frontier.count, paused: false, startedAt: started)
            let path = frontier.removeFirst()

            // Reseta ao root e reproduz o caminho. `launch` sozinho não basta:
            // num app já em foreground o /wda/apps/launch é no-op e o estado da
            // tela anterior vaza pro replay — terminate primeiro garante o root.
            // Erro transitório (timeout do WDA etc.) descarta só este caminho.
            do {
                _ = try? await driver.perform(.terminate(bundleId: bundleId))
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
                if broken {
                    onSkip?(describe(path), "alvo não resolvido no replay")
                    continue
                }

                let sig = ScreenSignature.of(obs.accessibility)
                guard !visited.contains(sig) else {
                    onSkip?(describe(path), "duplicata de \(sig)")
                    continue
                }
                visited.insert(sig)

                let screen = AuditScreen(
                    signature: sig,
                    pathDescription: describe(path),
                    path: path,
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
            } catch {
                onSkip?(describe(path), "erro: \(error)")
                continue   // tela inalcançável nesta passada — segue o BFS
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
