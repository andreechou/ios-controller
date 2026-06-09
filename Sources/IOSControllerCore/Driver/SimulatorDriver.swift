import Foundation

/// Abstrai *o alvo que o agente dirige*. A implementação inicial usa
/// WebDriverAgent contra o iOS Simulator, mas o protocolo é deliberadamente
/// agnóstico pra você plugar device físico (WDA over USB) ou macOS app depois.
public protocol SimulatorDriver: Sendable {
    /// Garante que o alvo está pronto (sim booted, sessão WDA aberta).
    func prepare() async throws

    /// Captura o estado atual pra percepção do agente.
    func observe() async throws -> ScreenObservation

    /// Executa uma ação e retorna o resultado.
    func perform(_ action: Action) async throws -> ActionOutcome

    /// Limpa sessão/recursos ao fim do run.
    func teardown() async throws
}

public enum DriverError: Error, Sendable {
    case simulatorNotFound(udid: String)
    case wdaUnavailable(reason: String)
    case actionFailed(Action, reason: String)
    case observationFailed(reason: String)
}
