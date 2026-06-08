import Foundation

/// Entrada do ledger append-only. Cada run vira um arquivo JSONL imutável —
/// reproduzível, auditável, e base do relatório de fricção.
public enum LedgerEntry: Sendable, Codable {
    case runStarted(goal: String, persona: String, provider: ProviderID, model: String)
    case decision(step: Int, decision: AgentDecision, tokens: Int)
    case action(step: Int, action: Action, outcome: ActionOutcome)
    case runFinished(outcome: AgentDecision.Status, steps: Int, tokens: Int, friction: [String])
    case error(String)

    public var timestamp: Date { Date() }
}

/// Append-only. Sem updates, sem deletes — só `append`.
public protocol Ledger: Sendable {
    func append(_ entry: LedgerEntry) async
}
