import XCTest

final class AdaptiveLayoutTests: XCTestCase {
    typealias L = AdaptiveLayout

    // MARK: - Bandas

    func testWideShrinksToMediumAndCompact() {
        XCTAssertEqual(L.band(width: 1200, current: .wide), .wide)
        XCTAssertEqual(L.band(width: 800, current: .wide), .medium)
        XCTAssertEqual(L.band(width: 500, current: .wide), .compact)
    }

    func testHysteresisOnGrowth() {
        // Subir de banda exige limiar + 40pt; cruzar de raspão não basta.
        XCTAssertEqual(L.band(width: L.wideThreshold + 10, current: .medium), .medium)
        XCTAssertEqual(L.band(width: L.wideThreshold + L.hysteresis, current: .medium), .wide)
        XCTAssertEqual(L.band(width: L.mediumThreshold + 10, current: .compact), .compact)
        XCTAssertEqual(L.band(width: L.mediumThreshold + L.hysteresis, current: .compact), .medium)
    }

    func testCompactJumpsStraightToWide() {
        XCTAssertEqual(L.band(width: 1400, current: .compact), .wide)
    }

    // MARK: - Resolução de painéis

    func testWideHonorsPreferences() {
        let r = L.resolve(band: .wide, preferCockpit: true, preferSteps: true, mediumPanel: .cockpit)
        XCTAssertEqual(r, .init(cockpit: true, steps: true))
        let r2 = L.resolve(band: .wide, preferCockpit: false, preferSteps: true, mediumPanel: .cockpit)
        XCTAssertEqual(r2, .init(cockpit: false, steps: true))
    }

    func testMediumShowsSinglePanelLastOpened() {
        // Ambos preferidos: vence o último aberto.
        let cockpitWins = L.resolve(band: .medium, preferCockpit: true, preferSteps: true, mediumPanel: .cockpit)
        XCTAssertEqual(cockpitWins, .init(cockpit: true, steps: false))
        let stepsWins = L.resolve(band: .medium, preferCockpit: true, preferSteps: true, mediumPanel: .steps)
        XCTAssertEqual(stepsWins, .init(cockpit: false, steps: true))
    }

    func testMediumFallsBackWhenLastOpenedIsOff() {
        // Último aberto foi steps, mas usuário fechou steps: cockpit entra no lugar.
        let r = L.resolve(band: .medium, preferCockpit: true, preferSteps: false, mediumPanel: .steps)
        XCTAssertEqual(r, .init(cockpit: true, steps: false))
        // Nenhum preferido: nenhum painel.
        let none = L.resolve(band: .medium, preferCockpit: false, preferSteps: false, mediumPanel: .cockpit)
        XCTAssertEqual(none, .init(cockpit: false, steps: false))
    }

    func testCompactHidesEverything() {
        let r = L.resolve(band: .compact, preferCockpit: true, preferSteps: true, mediumPanel: .steps)
        XCTAssertEqual(r, .init(cockpit: false, steps: false))
    }
}
