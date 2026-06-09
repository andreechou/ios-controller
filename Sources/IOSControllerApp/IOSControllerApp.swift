import SwiftUI

@main
struct IOSControllerApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .frame(minWidth: 960, minHeight: 600)
        }
        // Sem forçar aparência: segue light/dark e o accent do sistema.
    }
}
