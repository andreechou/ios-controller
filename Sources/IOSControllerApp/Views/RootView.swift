import SwiftUI

/// Layout nativo de 3 colunas (sidebar · conteúdo · inspetor), como Mail/Notas.
struct RootView: View {
    var body: some View {
        NavigationSplitView {
            RunConfigView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 320, max: 400)
        } content: {
            SimulatorPaneView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            StepFeedView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        }
    }
}

#Preview {
    RootView().environment(AppState())
}
