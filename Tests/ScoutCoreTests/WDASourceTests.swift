import XCTest
@testable import ScoutCore

final class WDASourceTests: XCTestCase {

    /// Carrega a fixture pelo caminho do próprio arquivo de teste — não depende
    /// de simulador, WDA, nem bundle de recursos.
    private func loadFixture(_ name: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Parsing

    func testParsesVisibleInteractiveNodes() throws {
        let tree = try loadFixture("login-screen.json")
        let nodes = WDASource.parse(tree)

        // Campos e botão visíveis viram nós.
        XCTAssertTrue(nodes.contains { $0.role == "TextField" && $0.label == "Email" })
        XCTAssertTrue(nodes.contains { $0.role == "SecureTextField" && $0.label == "Senha" })
        XCTAssertTrue(nodes.contains { $0.role == "Button" && $0.label == "Entrar" })
    }

    func testExcludesInvisibleNodes() throws {
        let tree = try loadFixture("login-screen.json")
        let nodes = WDASource.parse(tree)
        // O botão "Escondido" tem isVisible = "0" → não deve aparecer.
        XCTAssertFalse(nodes.contains { $0.label == "Escondido" })
    }

    func testKeepsUnlabeledInteractiveNode() throws {
        let tree = try loadFixture("login-screen.json")
        let nodes = WDASource.parse(tree)
        // Botão sem label (24x24) é interativo → mantido pra ser auditado.
        XCTAssertTrue(nodes.contains { $0.role == "Button" && ($0.label ?? "").isEmpty
                                       && $0.frame.width == 24 })
    }

    // MARK: - Checagens de a11y

    func testA11yFlagsMissingLabelAndSmallTouchTarget() throws {
        let tree = try loadFixture("login-screen.json")
        let snapshot = AccessibilitySnapshot(nodes: WDASource.parse(tree))
        let issues = A11yChecks.run(on: snapshot)

        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }

        // O botão vazio 24x24 dispara as duas regras.
        XCTAssertEqual(errors.filter { $0.rule == "missing-label" }.count, 1)
        XCTAssertEqual(warnings.filter { $0.rule == "touch-target" }.count, 1)
    }

    // MARK: - Assinatura de tela

    func testSignatureIsStableAndDistinct() throws {
        let tree = try loadFixture("login-screen.json")
        let snapshot = AccessibilitySnapshot(nodes: WDASource.parse(tree))

        // Mesma tela → mesma assinatura.
        XCTAssertEqual(ScreenSignature.of(snapshot), ScreenSignature.of(snapshot))

        // Tela diferente (sem o botão Entrar) → assinatura diferente.
        let fewer = AccessibilitySnapshot(nodes: snapshot.nodes.filter { $0.label != "Entrar" })
        XCTAssertNotEqual(ScreenSignature.of(snapshot), ScreenSignature.of(fewer))
    }
}
