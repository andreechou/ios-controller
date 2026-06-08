import Foundation
import ScoutCore

/// Mantém o driver vivo entre chamadas de tool (o simulador continua bootado
/// entre uma ação e a próxima). Prepara de forma preguiçosa na primeira chamada.
///
/// Configuração via ambiente:
///   SCOUT_UDID       — UDID do simulador (ou "booted")
///   SCOUT_BUNDLE_ID  — bundle id do app sob teste
///   SCOUT_APP_PATH   — (opcional) .app pra instalar antes
actor DriverSession {
    private let driver: WebDriverAgentDriver
    private var prepared = false

    init() {
        let env = ProcessInfo.processInfo.environment
        let udid = env["SCOUT_UDID"] ?? "booted"
        let bundle = env["SCOUT_BUNDLE_ID"] ?? ""
        driver = WebDriverAgentDriver(
            config: .init(udid: udid, bundleId: bundle, appPath: env["SCOUT_APP_PATH"]))
    }

    private func ensurePrepared() async throws {
        guard !prepared else { return }
        try await driver.prepare()
        prepared = true
    }

    func observe() async throws -> ScreenObservation {
        try await ensurePrepared()
        return try await driver.observe()
    }

    func perform(_ action: Action) async throws -> ActionOutcome {
        try await ensurePrepared()
        return try await driver.perform(action)
    }
}
