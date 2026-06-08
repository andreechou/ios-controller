import Foundation

/// Cliente HTTP fino sobre os endpoints REST do WebDriverAgent (fork Appium).
/// Endpoints podem variar levemente por versão do WDA — ajuste se necessário.
public actor WebDriverAgentClient {
    private let baseURL: URL
    private let session = URLSession(configuration: .ephemeral)

    public init(baseURL: URL) { self.baseURL = baseURL }

    // MARK: - Sessão

    /// Healthcheck. `/status` responde mesmo sem sessão — se não lançou, está de pé.
    public func isReady() async -> Bool {
        (try? await get("status")) != nil
    }

    /// Abre uma sessão W3C, opcionalmente lançando/instalando o app.
    public func createSession(bundleId: String, appPath: String?) async throws -> String {
        var always: [String: Any] = ["bundleId": bundleId]
        if let appPath { always["app"] = appPath }
        let body: [String: Any] = ["capabilities": ["alwaysMatch": always]]
        let value = try await post("session", body: body)
        // W3C: { value: { sessionId, capabilities } } | legacy: { sessionId }
        if let dict = value as? [String: Any], let sid = dict["sessionId"] as? String { return sid }
        throw DriverError.wdaUnavailable(reason: "sessionId ausente na resposta de /session")
    }

    public func deleteSession(_ id: String) async {
        _ = try? await delete("session/\(id)")
    }

    // MARK: - Percepção

    /// Árvore de elementos em JSON. `/source?format=json`.
    /// `sending`: valor recém-desserializado, nunca guardado no actor — região
    /// desconectada, transfere com segurança pro driver.
    public func sourceJSON(session id: String) async throws -> sending [String: Any] {
        let value = try await get("session/\(id)/source", query: ["format": "json"])
        guard let tree = value as? [String: Any] else {
            throw DriverError.observationFailed(reason: "source não é objeto JSON")
        }
        return tree
    }

    /// Screenshot PNG (base64 no campo `value`). Funciona session-less.
    public func screenshotPNG() async throws -> Data {
        let value = try await get("screenshot")
        guard let b64 = value as? String, let data = Data(base64Encoded: b64) else {
            throw DriverError.observationFailed(reason: "screenshot inválido")
        }
        return data
    }

    public func windowSize(session id: String) async throws -> (Double, Double) {
        let value = try await get("session/\(id)/window/size")
        let d = value as? [String: Any] ?? [:]
        return (d["width"] as? Double ?? 0, d["height"] as? Double ?? 0)
    }

    // MARK: - Ações

    public func tap(session id: String, x: Double, y: Double) async throws {
        _ = try await post("session/\(id)/wda/tap/0", body: ["x": x, "y": y])
    }

    public func typeText(session id: String, _ text: String) async throws {
        _ = try await post("session/\(id)/wda/keys", body: ["value": [text]])
    }

    public func drag(session id: String, fromX: Double, fromY: Double,
                     toX: Double, toY: Double, duration: Double = 0.3) async throws {
        _ = try await post("session/\(id)/wda/dragfromtoforduration",
                           body: ["fromX": fromX, "fromY": fromY, "toX": toX, "toY": toY,
                                  "duration": duration])
    }

    public func launchApp(session id: String, bundleId: String) async throws {
        _ = try await post("session/\(id)/wda/apps/launch", body: ["bundleId": bundleId])
    }

    public func terminateApp(session id: String, bundleId: String) async throws {
        _ = try await post("session/\(id)/wda/apps/terminate", body: ["bundleId": bundleId])
    }

    // MARK: - HTTP helpers

    private func get(_ path: String, query: [String: String] = [:]) async throws -> sending Any? {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { .init(name: $0.key, value: $0.value) } }
        return try await send(URLRequest(url: comps.url!))
    }

    private func post(_ path: String, body: [String: Any]) async throws -> sending Any? {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    private func delete(_ path: String) async throws -> sending Any? {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        return try await send(req)
    }

    /// Toda resposta WDA é `{ "value": ... }`. Devolve o conteúdo de `value`.
    private func send(_ req: URLRequest) async throws -> sending Any? {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DriverError.wdaUnavailable(reason: "HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1): \(body)")
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return (json as? [String: Any])?["value"]
    }
}
