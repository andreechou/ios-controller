import Foundation

/// Um alvo de toque resolvível por replay: identifica um elemento por
/// role + label + ocorrência (n-ésimo com mesmo role/label).
public struct TapTarget: Sendable, Codable {
    public var role: String
    public var label: String
    public var occurrence: Int
    public var describe: String { "\(role)\(label.isEmpty ? "" : " '\(label)'")" }
}

/// Uma tela única descoberta no crawl.
public struct AuditScreen: Sendable, Codable, Identifiable {
    public var id: String { signature }
    public var signature: String
    public var pathDescription: String   // como chegou aqui a partir do root
    /// Caminho estruturado desde o root (um TapTarget por toque). Permite
    /// montar a árvore de navegação: profundidade = path.count, aresta =
    /// path.last, pai = tela cujo caminho é path.dropLast().
    public var path: [TapTarget]
    public var screenshotPNG: Data
    public var nodeCount: Int
    public var issues: [A11yIssue]

    public init(signature: String, pathDescription: String, path: [TapTarget] = [],
                screenshotPNG: Data, nodeCount: Int, issues: [A11yIssue]) {
        self.signature = signature; self.pathDescription = pathDescription
        self.path = path
        self.screenshotPNG = screenshotPNG; self.nodeCount = nodeCount; self.issues = issues
    }
}

/// Resultado completo do audit.
public struct AuditResult: Sendable, Codable {
    public var bundleId: String
    public var screens: [AuditScreen]
    public var startedAt: Date
    public var finishedAt: Date
    public var truncated: Bool   // true se bateu o teto de telas/profundidade

    public init(bundleId: String, screens: [AuditScreen], startedAt: Date,
                finishedAt: Date, truncated: Bool) {
        self.bundleId = bundleId; self.screens = screens
        self.startedAt = startedAt; self.finishedAt = finishedAt; self.truncated = truncated
    }

    public var totalIssues: Int { screens.reduce(0) { $0 + $1.issues.count } }
}
