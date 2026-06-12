import SwiftUI

@main
struct IOSControllerApp: App {
    @State private var state = AppState()
    @State private var capture = CaptureController()
    @State private var atlas = AtlasController()

    var body: some Scene {
        // Janela principal = palette flutuante (estilo RocketSim): fica acima
        // das outras e cola na janela do Simulator. Sem espelho de tela.
        Window("iOS Controller", id: "palette") {
            PaletteView()
                .environment(state)
                .environment(capture)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        .defaultPosition(.topTrailing)
        .restorationBehavior(.disabled)

        // Feed de passos dos drivers externos (wda.sh / MCP) — sob demanda.
        Window("Steps", id: "steps") {
            StepFeedView()
                .environment(state)
        }
        .defaultSize(width: 380, height: 620)
        .restorationBehavior(.disabled)

        // Treeline de navegação: crawl ao vivo do app alvo.
        Window("Atlas", id: "atlas") {
            AtlasView()
                .environment(atlas)
                .environment(state)
        }
        .defaultSize(width: 1000, height: 720)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
    }
}
