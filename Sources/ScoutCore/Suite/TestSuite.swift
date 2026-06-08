import Foundation

/// Um processo de teste: metadados + lista de cenários. Carrega de JSON.
public struct TestSuite: Sendable, Codable {
    public var name: String
    public var bundleId: String
    public var provider: ProviderID
    public var model: String?
    public var scenarios: [Scenario]

    public init(name: String, bundleId: String, provider: ProviderID,
                model: String? = nil, scenarios: [Scenario]) {
        self.name = name; self.bundleId = bundleId
        self.provider = provider; self.model = model; self.scenarios = scenarios
    }

    public static func load(from url: URL) throws -> TestSuite {
        try JSONDecoder().decode(TestSuite.self, from: Data(contentsOf: url))
    }
}

/// Resultado agregado da suíte.
public struct SuiteResult: Sendable, Codable {
    public var suite: String
    public var results: [ScenarioResult]
    public var passed: Int { results.filter(\.passed).count }
    public var failed: Int { results.count - passed }
    public var startedAt: Date
    public var finishedAt: Date
}
