import Foundation

/// Wrapper fino sobre `xcrun simctl`. Tudo que precisa do simulador antes de o
/// WDA assumir: boot, install, launch, screenshot.
public struct Simctl: Sendable {
    public init() {}

    @discardableResult
    public func run(_ args: [String]) throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl"] + args
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown"
            throw DriverError.wdaUnavailable(reason: "simctl \(args.joined(separator: " ")): \(msg)")
        }
        return data
    }

    public func boot(udid: String) throws {
        // Ignora "already booted" (exit code 149) silenciosamente em produção.
        try? run(["boot", udid])
    }

    public func install(udid: String, appPath: String) throws {
        try run(["install", udid, appPath])
    }

    public func launch(udid: String, bundleId: String) throws {
        try run(["launch", udid, bundleId])
    }

    public func terminate(udid: String, bundleId: String) throws {
        try? run(["terminate", udid, bundleId])
    }

    /// Screenshot PNG do simulador (fallback de percepção visual).
    public func screenshotPNG(udid: String) throws -> Data {
        let tmp = NSTemporaryDirectory() + UUID().uuidString + ".png"
        try run(["io", udid, "screenshot", tmp])
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        return try Data(contentsOf: URL(fileURLWithPath: tmp))
    }
}
