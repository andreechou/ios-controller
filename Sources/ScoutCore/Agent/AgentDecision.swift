import Foundation

/// O que o agente decidiu num passo. Vai inteiro pro ledger.
public struct AgentDecision: Sendable, Codable {
    public enum Status: String, Sendable, Codable {
        case `continue`, succeeded, failed, gaveUp
    }

    /// Narração do que o agente "vê" e por que escolheu a ação (pro feed de UX).
    public var reasoning: String
    /// Próxima ação a executar. nil quando o run encerra (status != continue).
    public var action: Action?
    public var status: Status
    /// Notas de fricção acumuladas (labels ambíguas, dead ends, etc).
    public var friction: [String]

    public init(reasoning: String, action: Action?, status: Status, friction: [String] = []) {
        self.reasoning = reasoning
        self.action = action
        self.status = status
        self.friction = friction
    }
}
