import Foundation
import IOSControllerCore
import Observation

/// Um teste de usuário declarado: objetivo + persona + alvo + cérebro.
struct TestCase: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Novo teste"
    var goal = ""
    var persona = ""
    var bundleId = ""
    var provider: ProviderID = .anthropic
    var maxSteps = 40
}

/// Testes persistidos em ~/.ios-controller/tests.json (fora do repo do app
/// testado, junto dos runs/feed — é estado da ferramenta, não do projeto).
@MainActor
@Observable
final class TestStore {
    private static let url = URL(
        fileURLWithPath: NSHomeDirectory() + "/.ios-controller/tests.json")

    var tests: [TestCase] = []

    init() {
        if let data = try? Data(contentsOf: Self.url),
           let saved = try? JSONDecoder().decode([TestCase].self, from: data) {
            tests = saved
        }
    }

    func upsert(_ test: TestCase) {
        if let i = tests.firstIndex(where: { $0.id == test.id }) {
            tests[i] = test
        } else {
            tests.append(test)
        }
        persist()
    }

    func remove(_ id: TestCase.ID) {
        tests.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        try? FileManager.default.createDirectory(
            at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(tests) {
            try? data.write(to: Self.url)
        }
    }
}
