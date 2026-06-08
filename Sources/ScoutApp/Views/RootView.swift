import SwiftUI
import ScoutCore

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HSplitView {
            RunConfigView()
                .frame(minWidth: 280, maxWidth: 340)
            SimulatorPaneView()
                .frame(minWidth: 280)
            StepFeedView()
                .frame(minWidth: 300)
        }
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
        .font(Theme.mono)
    }
}

#Preview {
    RootView().environment(AppState())
}
