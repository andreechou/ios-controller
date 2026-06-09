import Foundation

/// Uma ação que o agente decide executar contra o alvo.
/// Mapeada 1:1 com o tool-schema enviado ao modelo (ver `ToolSchema`).
public enum Action: Sendable, Codable, Equatable {
    /// Toque por coordenada absoluta em pontos (origem no canto superior esquerdo).
    case tap(x: Double, y: Double)
    /// Toque em um elemento identificado na árvore de acessibilidade.
    case tapElement(id: String)
    /// Digita texto no campo focado.
    case type(text: String)
    /// Scroll direcional. `amount` em pontos.
    case scroll(direction: ScrollDirection, amount: Double)
    /// Espera passiva — útil pra animações/carregamento.
    case wait(ms: Int)
    /// (Re)abre um bundle id no simulador.
    case launch(bundleId: String)
    /// Encerra o app sob teste.
    case terminate(bundleId: String)

    public enum ScrollDirection: String, Sendable, Codable {
        case up, down, left, right
    }
}

/// Resultado de executar uma `Action` — alimenta o ledger e o próximo passo.
public struct ActionOutcome: Sendable, Codable {
    public var ok: Bool
    public var detail: String?

    public init(ok: Bool, detail: String? = nil) {
        self.ok = ok
        self.detail = detail
    }
}
