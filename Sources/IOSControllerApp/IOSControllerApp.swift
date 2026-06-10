import SwiftUI

@main
struct IOSControllerApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                // Piso = banda compact (só o simulador). A janela encolhe livre;
                // quem garante que nada clipa é o AdaptiveLayout colapsando
                // painéis por banda — não um mínimo duro somando os três.
                .frame(minWidth: 320, minHeight: 480)
        }
        .defaultSize(width: 1200, height: 800)
        // Sem forçar aparência: segue light/dark e o accent do sistema.

        Settings {
            SettingsView()
        }
    }
}
