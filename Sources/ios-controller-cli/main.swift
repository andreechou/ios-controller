import Foundation
import IOSControllerCore

// ios-controller-cli — três subcomandos, todos sobre o mesmo IOSControllerCore:
//   run    objetivo único dirigido pelo agente
//   suite  processo de teste (vários cenários de um JSON)
//   audit  navega todas as telas e captura screenshots pra auditar
//
//   ios-controller-cli run    --udid <U> --bundle <B> --goal "..." [--persona "..."] [--provider ...]
//   ios-controller-cli suite  <suite.json> --udid <U> [--out report.html]
//   ios-controller-cli audit  --udid <U> --bundle <B> [--max-screens 60] [--max-depth 4] [--out audit.html]

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: "--\(name)"), i + 1 < a.count else { return nil }
    return a[i + 1]
}
func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("erro: \(msg)\n".utf8)); exit(2)
}
func write(_ html: String, to path: String) {
    try? html.write(toFile: path, atomically: true, encoding: .utf8)
    print("→ relatório: \(path)")
}

let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "run"

switch command {

case "run":
    guard let udid = arg("udid"), let bundle = arg("bundle"), let goal = arg("goal") else {
        fail("run requer --udid, --bundle e --goal")
    }
    let pid = ProviderID(rawValue: arg("provider") ?? "anthropic") ?? .anthropic
    let config = RunConfig(goal: goal, persona: arg("persona") ?? "Usuário de primeira viagem",
                           udid: udid, bundleId: bundle, appPath: arg("app"),
                           provider: pid, model: ProviderRegistry.defaultModel(for: pid),
                           maxSteps: Int(arg("max-steps") ?? "40") ?? 40)
    let provider = try ProviderRegistry().provider(for: pid)
    let agent = Agent(provider: provider, model: config.model, goal: goal, persona: config.persona)
    let driver = WebDriverAgentDriver(config: .init(udid: udid, bundleId: bundle, appPath: arg("app")))
    let coordinator = RunCoordinator(driver: driver, agent: agent, ledger: JSONLLedger(), config: config)
    for await event in await coordinator.run() {
        switch event {
        case .phaseChanged(let p): print("== \(p.rawValue) ==")
        case .step(let i, let d, let o):
            print("[\(i)] \(o.map { $0.ok ? "✓" : "✗" } ?? "·") \(d.reasoning)")
        case .finished(let s):
            print("\nveredito: \(s.outcome?.rawValue ?? "?") | passos: \(s.step) | tokens: \(s.tokensUsed)")
            s.friction.forEach { print("  • \($0)") }
        }
    }

case "suite":
    guard CommandLine.arguments.count > 2 else { fail("suite requer caminho do JSON") }
    guard let udid = arg("udid") else { fail("suite requer --udid") }
    let suite = try TestSuite.load(from: URL(fileURLWithPath: CommandLine.arguments[2]))
    print("processo: \(suite.name) — \(suite.scenarios.count) cenários")
    let result = try await SuiteRunner(suite: suite, udid: udid).run { r in
        print("  \(r.passed ? "✓" : "✗") \(r.scenario.id): \(r.actualOutcome.rawValue)")
    }
    print("\n\(result.passed)/\(result.results.count) passou")
    write(ReportRenderer.suiteHTML(result), to: arg("out") ?? "ios-controller-suite.html")

case "audit":
    guard let udid = arg("udid"), let bundle = arg("bundle") else {
        fail("audit requer --udid e --bundle")
    }
    let driver = WebDriverAgentDriver(config: .init(udid: udid, bundleId: bundle))
    let crawler = AuditCrawler(driver: driver, bundleId: bundle,
                               maxScreens: Int(arg("max-screens") ?? "60") ?? 60,
                               maxDepth: Int(arg("max-depth") ?? "4") ?? 4)
    print("auditando \(bundle) …")
    let result = try await crawler.crawl { screen in
        print("  + \(screen.signature) (\(screen.issues.count) issues) — \(screen.pathDescription)")
    }
    print("\n\(result.screens.count) telas, \(result.totalIssues) issues\(result.truncated ? " (truncado)" : "")")
    write(ReportRenderer.auditHTML(result), to: arg("out") ?? "ios-controller-audit.html")

case "demo":
    // Gera relatórios de exemplo SEM WDA: screenshot REAL do simulador + árvore
    // de a11y sintética. As checagens (A11yChecks), assinatura (ScreenSignature)
    // e o render (ReportRenderer) são os de produção — é exatamente o HTML que
    // `audit`/`suite` geram. Útil pra ver o output sem subir o WebDriverAgent.
    let udid = arg("udid") ?? "booted"
    let shot = (try? Simctl().screenshotPNG(udid: udid)) ?? Data()
    if shot.isEmpty { print("aviso: sem screenshot (simulador bootado?) — cards sem imagem") }

    func node(_ id: String, _ role: String, _ label: String?, _ w: Double, _ h: Double)
        -> AccessibilitySnapshot.Node {
        .init(id: id, role: role, label: label, value: nil, enabled: true,
              frame: .init(x: 20, y: 100, width: w, height: h))
    }

    // Tela 1: lista (Button sem label + alvo 30x30 → missing-label + touch-target)
    let listas = AccessibilitySnapshot(nodes: [
        node("0", "StaticText", "Minhas Listas", 200, 30),
        node("0.1", "Button", "Nova Lista", 200, 44),
        node("0.2", "Button", "", 30, 30),
        node("0.3", "Cell", "Compras", 360, 48),
        node("0.4", "Cell", "Trabalho", 360, 48),
    ])
    // Tela 2: form (TextField com 40pt de altura → touch-target)
    let novaLista = AccessibilitySnapshot(nodes: [
        node("0", "TextField", "Nome da lista", 300, 40),
        node("0.1", "Button", "Salvar", 100, 44),
        node("0.2", "Button", "Cancelar", 100, 44),
    ])

    let screens = [
        AuditScreen(signature: ScreenSignature.of(listas), pathDescription: "root",
                    screenshotPNG: shot, nodeCount: listas.nodes.count,
                    issues: A11yChecks.run(on: listas)),
        AuditScreen(signature: ScreenSignature.of(novaLista),
                    pathDescription: "root → tap Button 'Nova Lista'",
                    screenshotPNG: shot, nodeCount: novaLista.nodes.count,
                    issues: A11yChecks.run(on: novaLista)),
    ]
    let auditResult = AuditResult(bundleId: "com.apple.reminders (demo)", screens: screens,
                                  startedAt: Date(), finishedAt: Date(), truncated: false)
    write(ReportRenderer.auditHTML(auditResult), to: "demo-audit.html")

    func scen(_ id: String, _ goal: String, _ persona: String, fof: Bool = false) -> Scenario {
        Scenario(id: id, goal: goal, persona: persona, expectedOutcome: .succeeded, failOnFriction: fof)
    }
    let scenarioResults = [
        ScenarioResult(scenario: scen("criar-lista", "Criar lista 'Compras' e adicionar 'Café'",
                                      "Primeira viagem, com pressa"),
                       actualOutcome: .succeeded, passed: true, steps: 12, tokens: 8400,
                       friction: [], failureReason: nil),
        ScenarioResult(scenario: scen("marcar-concluido", "Marcar um lembrete como concluído",
                                      "Recorrente, com pressa"),
                       actualOutcome: .succeeded, passed: true, steps: 9, tokens: 5200,
                       friction: ["Alvo de toque do checkbox menor que 44pt"], failureReason: nil),
        ScenarioResult(scenario: scen("buscar", "Buscar um lembrete e abri-lo",
                                      "Curioso explorando", fof: true),
                       actualOutcome: .succeeded, passed: false, steps: 15, tokens: 11000,
                       friction: ["Botão '+' sem label de a11y", "Ambíguo: 'Pronto' vs 'Salvar'"],
                       failureReason: "fricção detectada (2)"),
    ]
    let suiteResult = SuiteResult(suite: "Reminders — primeiro uso (demo)", results: scenarioResults,
                                  startedAt: Date(), finishedAt: Date())
    write(ReportRenderer.suiteHTML(suiteResult), to: "demo-suite.html")

    print("\n✓ demo: demo-audit.html + demo-suite.html")
    print("  screenshot real do sim · árvore a11y sintética · checks/render reais")

default:
    fail("comando desconhecido: \(command) (use run | suite | audit | demo)")
}
