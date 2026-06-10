import SwiftUI
import AppKit

/// Mirrors the simulator screen live (simctl screenshot stream).
struct SimulatorPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let data = state.screenshot, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                } else {
                    ContentUnavailableView {
                        Label("Simulator", systemImage: "iphone")
                    } description: {
                        Text(state.phase == .idle ? "No preview" : state.phase.rawValue)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Saúde do cockpit: ● WDA · sim bootado · bundle da sessão · Start WDA.
    /// ViewThatFits: janela estreita degrada o texto antes de quebrar o layout.
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.wdaUp == true ? .green : state.wdaUp == false ? .red : .gray)
                .frame(width: 7, height: 7)
            ViewThatFits(in: .horizontal) {
                statusText(full: true)
                statusText(full: false)
                Text("WDA")
            }
            Spacer(minLength: 8)
            if state.wdaUp == false {
                Button(state.wdaStarting ? "Subindo…" : "Start WDA") {
                    state.startWDA()
                }
                .controlSize(.small)
                .disabled(state.wdaStarting)
                .help("Roda scripts/start-wda.sh (log em /tmp/wda-start.log)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private func statusText(full: Bool) -> some View {
        var parts = ["WDA :8100"]
        if let sim = state.simName { parts.append(sim) }
        if full, let bundle = state.sessionBundle { parts.append(bundle) }
        return Text(parts.joined(separator: " · "))
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
