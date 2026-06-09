import SwiftUI
import AppKit

/// Pane do simulador: espelha a tela do sim ao vivo (stream de screenshots do
/// simctl, ~1.5 fps). Sem frame ainda → placeholder.
struct SimulatorPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack {
            Text("SIMULADOR").font(Theme.monoSmall).foregroundStyle(Theme.muted)
            Spacer()
            if let data = state.screenshot, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                    .padding(24)
            } else {
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
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
