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
        guard let data = try? encoder.encode(Envelope(ts: Date(), entry: entry)) else { return }
        var line = data
        line.append(0x0A) // newline

        if handle == nil {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        try? handle?.write(contentsOf: line)
        try? handle?.synchronize()
    }
}
