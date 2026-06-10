import Foundation

/// Ledger append-only em JSONL. Uma linha por entrada, fsync a cada append.
public actor JSONLLedger: Ledger {
    private let url: URL
    private let encoder: JSONEncoder
    private var handle: FileHandle?

    public init(runId: String = UUID().uuidString,
                directory: URL = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent(".ios-controller/runs")) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("\(runId).jsonl")
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public var path: String { url.path }

    public func append(_ entry: LedgerEntry) async {
        struct Envelope: Codable { let ts: Date; let entry: LedgerEntry }
        // Trilha de auditoria não pode falhar em silêncio: qualquer erro de
        // encode/open/write/fsync vai pro stderr com o path — visível no terminal/CI.
        do {
            var line = try encoder.encode(Envelope(ts: Date(), entry: entry))
            line.append(0x0A) // newline

            if handle == nil {
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                let h = try FileHandle(forWritingTo: url)
                try h.seekToEnd()
                handle = h
            }
            try handle?.write(contentsOf: line)
            try handle?.synchronize()
        } catch {
            FileHandle.standardError.write(
                Data("ledger: falha ao gravar em \(url.path): \(error)\n".utf8))
        }
    }
}
