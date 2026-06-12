import AppKit
import Observation

/// Captura do simulador via `simctl io`: screenshot pontual e gravação de
/// vídeo (start/stop). Arquivos em ~/.ios-controller/{screenshots,recordings};
/// ao terminar, revela no Finder.
@MainActor
@Observable
final class CaptureController {
    var isRecording = false
    var recordingStarted: Date?
    var lastError: String?

    @ObservationIgnored private var recorder: Process?
    @ObservationIgnored private var recordingURL: URL?

    private static var baseDir: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/.ios-controller")
    }

    func screenshot(udid: String) {
        let dir = Self.baseDir.appending(path: "screenshots")
        let url = dir.appending(path: "shot-\(Self.stamp()).png")
        Task.detached {
            let failure: String?
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                p.arguments = ["simctl", "io", udid, "screenshot", url.path]
                let err = Pipe()
                p.standardError = err
                try p.run()
                p.waitUntilExit()
                failure = p.terminationStatus == 0 ? nil
                    : (String(data: err.fileHandleForReading.readDataToEndOfFile(),
                              encoding: .utf8) ?? "screenshot falhou")
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run { [failure] in
                if let failure {
                    self.lastError = failure.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }

    func toggleRecording(udid: String) {
        isRecording ? stopRecording() : startRecording(udid: udid)
    }

    private func startRecording(udid: String) {
        let dir = Self.baseDir.appending(path: "recordings")
        let url = dir.appending(path: "rec-\(Self.stamp()).mp4")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["simctl", "io", udid, "recordVideo", "--codec=h264", "--force", url.path]
            p.terminationHandler = { proc in
                let status = proc.terminationStatus
                Task { @MainActor in self.finishedRecording(status: status) }
            }
            try p.run()
            recorder = p
            recordingURL = url
            recordingStarted = Date()
            isRecording = true
        } catch {
            lastError = "gravação falhou: \(error.localizedDescription)"
        }
    }

    /// SIGINT é o jeito documentado de encerrar o recordVideo finalizando o mp4.
    func stopRecording() {
        recorder?.interrupt()
    }

    private func finishedRecording(status: Int32) {
        isRecording = false
        recordingStarted = nil
        recorder = nil
        // SIGINT sai com 0/2 conforme a versão; o arquivo existir é o critério.
        if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else if status != 0 {
            lastError = "gravação terminou sem arquivo (status \(status))"
        }
        recordingURL = nil
    }

    nonisolated private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
