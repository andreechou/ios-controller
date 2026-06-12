import Foundation

/// Controle de crawl por arquivos em `~/.ios-controller/crawl/` — qualquer
/// processo (app, CLI, Claude Code) enxerga e comanda o crawl em andamento
/// sem IPC. Protocolo:
///
/// - `status.json` — heartbeat do crawler: pid, bundle, progresso, pausado.
///   Atualizado a cada iteração; fresco (< 15s) = crawler vivo.
/// - `pause` — existe = crawler dorme no início da próxima iteração até sumir.
/// - `stop`  — existe = crawler encerra (truncated) e consome a flag.
///
/// Um crawl por vez (um sim, um WDA) — o pid no status detecta concorrência.
public enum CrawlControl {
    public struct Status: Codable, Sendable {
        public var pid: Int32
        public var bundleId: String
        public var screens: Int
        public var queued: Int
        public var paused: Bool
        public var startedAt: Date
        public var updatedAt: Date

        public var isMine: Bool { pid == ProcessInfo.processInfo.processIdentifier }
    }

    private static var dir: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/.ios-controller/crawl")
    }
    public static var statusURL: URL { dir.appending(path: "status.json") }
    private static var stopURL: URL { dir.appending(path: "stop") }
    private static var pauseURL: URL { dir.appending(path: "pause") }

    // MARK: - Lado do crawler

    static func publish(bundleId: String, screens: Int, queued: Int,
                        paused: Bool, startedAt: Date) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let status = Status(pid: ProcessInfo.processInfo.processIdentifier,
                            bundleId: bundleId, screens: screens, queued: queued,
                            paused: paused, startedAt: startedAt, updatedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(status) {
            try? data.write(to: statusURL, options: .atomic)
        }
    }

    /// true = stop pedido; consome a flag (próximo crawl não herda o pedido).
    static func consumeStop() -> Bool {
        guard FileManager.default.fileExists(atPath: stopURL.path) else { return false }
        try? FileManager.default.removeItem(at: stopURL)
        return true
    }

    static func isPaused() -> Bool {
        FileManager.default.fileExists(atPath: pauseURL.path)
    }

    /// Fim de crawl: some com heartbeat e flags pra não assombrar o próximo.
    static func clear() {
        try? FileManager.default.removeItem(at: statusURL)
        try? FileManager.default.removeItem(at: stopURL)
        try? FileManager.default.removeItem(at: pauseURL)
    }

    // MARK: - Lado de quem comanda

    /// Status do crawl vivo (heartbeat fresco) ou nil.
    public static func current(maxAge: TimeInterval = 15) -> Status? {
        guard let data = try? Data(contentsOf: statusURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let status = try? decoder.decode(Status.self, from: data),
              Date().timeIntervalSince(status.updatedAt) < maxAge else { return nil }
        return status
    }

    public static func requestStop() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: stopURL.path, contents: nil)
    }

    public static func setPaused(_ paused: Bool) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if paused {
            FileManager.default.createFile(atPath: pauseURL.path, contents: nil)
        } else {
            try? FileManager.default.removeItem(at: pauseURL)
        }
    }
}
