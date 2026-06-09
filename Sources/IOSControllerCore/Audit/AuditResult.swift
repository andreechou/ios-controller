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
    public var screenshotPNG: Data
    public var nodeCount: Int
    public var issues: [A11yIssue]

    public init(signature: String, pathDescription: String, screenshotPNG: Data,
                nodeCount: Int, issues: [A11yIssue]) {
        self.signature = signature; self.pathDescription = pathDescription
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
