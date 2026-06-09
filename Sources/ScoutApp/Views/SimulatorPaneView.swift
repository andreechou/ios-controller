import SwiftUI
import AppKit

/// Espelha a tela do simulador ao vivo (stream de screenshots do simctl).
struct SimulatorPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if let data = state.screenshot, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 12, y: 4)
                    .padding(24)
            } else {
                ContentUnavailableView {
                    Label("Simulador", systemImage: "iphone")
                } description: {
                    Text(state.phase == .idle ? "Sem preview" : state.phase.rawValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Simulador")
    }
}
