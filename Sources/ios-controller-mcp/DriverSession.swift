import Foundation
import IOSControllerCore

/// Mantém o driver vivo entre chamadas de tool (o simulador continua bootado
/// entre uma ação e a próxima). Prepara de forma preguiçosa na primeira chamada.
///
/// Configuração via ambiente:
///   IOSCTL_UDID       — UDID do simulador (ou "booted")
///   IOSCTL_BUNDLE_ID  — bundle id do app sob teste
///   IOSCTL_APP_PATH   — (opcional) .app pra instalar antes
actor DriverSession {
    private let driver: WebDriverAgentDriver
    private var prepared = false

    init() {
        let env = ProcessInfo.processInfo.environment
        let udid = env["IOSCTL_UDID"] ?? "booted"
        let bundle = env["IOSCTL_BUNDLE_ID"] ?? ""
        driver = WebDriverAgentDriver(
            config: .init(udid: udid, bundleId: bundle, appPath: env["IOSCTL_APP_PATH"]))
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
