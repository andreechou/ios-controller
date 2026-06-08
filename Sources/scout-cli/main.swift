import Foundation
import ScoutCore

// scout-cli — três subcomandos, todos sobre o mesmo ScoutCore:
//   run    objetivo único dirigido pelo agente
//   suite  processo de teste (vários cenários de um JSON)
//   audit  navega todas as telas e captura screenshots pra auditar
//
//   scout-cli run    --udid <U> --bundle <B> --goal "..." [--persona "..."] [--provider ...]
//   scout-cli suite  <suite.json> --udid <U> [--out report.html]
//   scout-cli audit  --udid <U> --bundle <B> [--max-screens 60] [--max-depth 4] [--out audit.html]

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
    write(ReportRenderer.suiteHTML(result), to: arg("out") ?? "scout-suite.html")

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
    write(ReportRenderer.auditHTML(result), to: arg("out") ?? "scout-audit.html")

default:
    fail("comando desconhecido: \(command) (use run | suite | audit)")
}
