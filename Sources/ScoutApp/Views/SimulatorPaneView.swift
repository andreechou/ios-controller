import SwiftUI

/// Pane do simulador. v1: placeholder + último screenshot.
/// Futuro: embutir a janela do Simulator (SkyLight/CGWindow capture) ou
/// renderizar o stream de screenshots ao vivo.
struct SimulatorPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack {
            Text("SIMULADOR").font(Theme.monoSmall).foregroundStyle(Theme.muted)
            Spacer()
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.border, lineWidth: 1)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 48)).foregroundStyle(Theme.muted)
                        Text(state.phase.rawValue)
                            .font(Theme.monoSmall).foregroundStyle(Theme.muted)
                    }
                }
                .aspectRatio(0.46, contentMode: .fit)
                .padding(24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
