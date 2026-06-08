import Foundation

public struct A11yIssue: Sendable, Codable {
    public enum Severity: String, Sendable, Codable { case warning, error }
    public var severity: Severity
    public var rule: String
    public var nodeId: String
    public var message: String

    public init(severity: Severity, rule: String, nodeId: String, message: String) {
        self.severity = severity; self.rule = rule; self.nodeId = nodeId; self.message = message
    }
}

/// Checagens de acessibilidade rodadas em cada tela durante o audit.
public enum A11yChecks {
    /// Piso de área de toque no iOS (HIG): 44x44pt.
    static let minTouchTargetPt: Double = 44

    public static func run(on snapshot: AccessibilitySnapshot) -> [A11yIssue] {
        var issues: [A11yIssue] = []
        for node in snapshot.nodes where WDASource.isInteractive(node.role) {
            // 1) Elemento interativo sem label acessível.
            if (node.label ?? "").trimmingCharacters(in: .whitespaces).isEmpty,
               (node.value ?? "").isEmpty {
                issues.append(.init(severity: .error, rule: "missing-label",
                                    nodeId: node.id,
                                    message: "\(node.role) sem label de acessibilidade"))
            }
            // 2) Área de toque abaixo do piso de 44pt.
            if node.enabled,
               node.frame.width < minTouchTargetPt || node.frame.height < minTouchTargetPt {
                issues.append(.init(severity: .warning, rule: "touch-target",
                                    nodeId: node.id,
                                    message: String(format: "alvo %.0fx%.0fpt < 44x44pt (%@)",
                                                    node.frame.width, node.frame.height,
                                                    node.label ?? node.role)))
            }
        }
        return issues
    }
}
