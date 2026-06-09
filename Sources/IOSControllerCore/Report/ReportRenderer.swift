import Foundation

/// Gera relatórios HTML auto-contidos (screenshots embutidos em base64).
/// Tema dark no padrão dos projetos pessoais.
public enum ReportRenderer {

    // MARK: - Audit (galeria de telas)

    public static func auditHTML(_ result: AuditResult) -> String {
        let cards = result.screens.map { screen -> String in
            let img = "data:image/png;base64,\(screen.screenshotPNG.base64EncodedString())"
            let badges = badgeRow(for: screen.issues)
            let issues = screen.issues.map { issue in
                "<li class=\"\(issue.severity.rawValue)\">[\(issue.rule)] \(esc(issue.message))</li>"
            }.joined()
            return """
            <div class="card">
              <img src="\(img)" alt="screen" loading="lazy"/>
              <div class="meta">
                <div class="path">\(esc(screen.pathDescription))</div>
                <div class="sig">\(screen.signature) · \(screen.nodeCount) nós</div>
                \(badges)
                \(issues.isEmpty ? "" : "<ul class=\"issues\">\(issues)</ul>")
              </div>
            </div>
            """
        }.joined(separator: "\n")

        let summary = """
        <header>
          <h1>iOS Controller · audit</h1>
          <div class="stats">
            <span><b>\(result.screens.count)</b> telas</span>
            <span><b>\(result.totalIssues)</b> issues</span>
            <span>\(esc(result.bundleId))</span>
            \(result.truncated ? "<span class=\"warn\">truncado (teto atingido)</span>" : "")
          </div>
        </header>
        """

        return page(title: "iOS Controller · audit", body: summary + "<div class=\"grid\">\(cards)</div>")
    }

    // MARK: - Suíte (tabela de cenários)

    public static func suiteHTML(_ result: SuiteResult) -> String {
        let rows = result.results.map { r -> String in
            let cls = r.passed ? "pass" : "fail"
            let friction = r.friction.isEmpty ? "—" :
                "<ul>" + r.friction.map { "<li>\(esc($0))</li>" }.joined() + "</ul>"
            return """
            <tr class="\(cls)">
              <td>\(r.passed ? "✓" : "✗")</td>
              <td>\(esc(r.scenario.id))</td>
              <td>\(esc(r.scenario.goal))</td>
              <td>\(r.actualOutcome.rawValue)</td>
              <td>\(r.steps)</td>
              <td>\(r.tokens)</td>
              <td>\(friction)</td>
            </tr>
            """
        }.joined()

        let summary = """
        <header>
          <h1>iOS Controller · \(esc(result.suite))</h1>
          <div class="stats">
            <span class="ok"><b>\(result.passed)</b> passou</span>
            <span class="warn"><b>\(result.failed)</b> falhou</span>
          </div>
        </header>
        """
        let table = """
        <table>
          <thead><tr><th></th><th>cenário</th><th>objetivo</th><th>veredito</th>
            <th>passos</th><th>tokens</th><th>fricção</th></tr></thead>
          <tbody>\(rows)</tbody>
        </table>
        """
        return page(title: "iOS Controller · \(result.suite)", body: summary + table)
    }

    // MARK: - Shell + helpers

    private static func badgeRow(for issues: [A11yIssue]) -> String {
        let errors = issues.filter { $0.severity == .error }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        var spans: [String] = []
        if errors > 0 { spans.append("<span class=\"badge err\">\(errors) erro</span>") }
        if warnings > 0 { spans.append("<span class=\"badge warn\">\(warnings) aviso</span>") }
        if spans.isEmpty { spans.append("<span class=\"badge ok\">ok</span>") }
        return "<div class=\"badges\">\(spans.joined())</div>"
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func page(title: String, body: String) -> String {
        """
        <!doctype html><html lang="pt-br"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(title))</title>
        <style>
          :root { --bg:#0a0f1a; --surface:#111827; --border:#1f2937;
                  --text:#e5e7eb; --muted:#6b7280; --accent:#f97316;
                  --ok:#22c55e; --err:#ef4444; }
          * { box-sizing: border-box; }
          body { margin:0; background:var(--bg); color:var(--text);
                 font-family: 'JetBrains Mono', ui-monospace, monospace; padding:24px; }
          h1 { color:var(--accent); margin:0 0 8px; font-size:20px; }
          header { border-bottom:1px solid var(--border); padding-bottom:16px; margin-bottom:24px; }
          .stats span { margin-right:16px; color:var(--muted); font-size:13px; }
          .ok b { color:var(--ok); } .warn { color:var(--err); }
          .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:16px; }
          .card { background:var(--surface); border:1px solid var(--border);
                  border-radius:10px; overflow:hidden; }
          .card img { width:100%; display:block; border-bottom:1px solid var(--border); }
          .meta { padding:10px; font-size:11px; }
          .path { color:var(--text); margin-bottom:4px; word-break:break-word; }
          .sig { color:var(--muted); margin-bottom:6px; }
          .badges .badge { display:inline-block; padding:2px 6px; border-radius:4px;
                           font-size:10px; margin-right:4px; }
          .badge.ok { background:rgba(34,197,94,.15); color:var(--ok); }
          .badge.err { background:rgba(239,68,68,.15); color:var(--err); }
          .badge.warn { background:rgba(249,115,22,.15); color:var(--accent); }
          ul.issues { margin:8px 0 0; padding-left:16px; color:var(--muted); }
          ul.issues li.error { color:var(--err); } ul.issues li.warning { color:var(--accent); }
          table { width:100%; border-collapse:collapse; font-size:13px; }
          th,td { text-align:left; padding:8px; border-bottom:1px solid var(--border);
                  vertical-align:top; }
          th { color:var(--muted); font-weight:normal; }
          tr.pass td:first-child { color:var(--ok); } tr.fail td:first-child { color:var(--err); }
          td ul { margin:0; padding-left:16px; }
        </style></head><body>\(body)</body></html>
        """
    }
}
