import SwiftUI
import IOSControllerCore

/// Palette flutuante estilo RocketSim: cola na lateral da janela real do
/// Simulator (nada de espelhar tela — o Simulator É a interface) e concentra
/// ações rápidas: screenshot, gravação, Steps, Atlas, WDA.
struct PaletteView: View {
    @Environment(AppState.self) private var state
    @Environment(CaptureController.self) private var capture
    @Environment(\.openWindow) private var openWindow
    @AppStorage("followSimulator") private var followSim = true
    @AppStorage("defaultUDID") private var udid = "booted"
    @State private var window: NSWindow?
    @State private var crawl: CrawlControl.Status?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            row(capture.isRecording ? "Parar gravação" : "Gravar tela",
                icon: capture.isRecording ? "stop.circle.fill" : "record.circle",
                tint: capture.isRecording ? .red : nil,
                trailing: { recordingClock }) {
                capture.toggleRecording(udid: udid)
            }
            row("Screenshot", icon: "camera") { capture.screenshot(udid: udid) }
            Divider()
            row("Steps", icon: "list.bullet.rectangle") { openWindow(id: "steps") }
            row("Atlas", icon: "map") { openWindow(id: "atlas") }
            if let crawl {
                Divider()
                crawlRow(crawl)
            }
            if state.wdaUp == false {
                Divider()
                row(state.wdaStarting ? "Subindo WDA…" : "Subir WDA",
                    icon: "antenna.radiowaves.left.and.right") {
                    state.startWDA()
                }
                .disabled(state.wdaStarting)
            }
            if let error = capture.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 224)
        .background(WindowAccessor { window = $0 })
        .task {
            state.startStatusPolls()
            state.startFeedTail()
            #if DEBUG
            // Harness visual: `defaults write md.chou.ioscontroller.app
            // debugOpenWindow steps,atlas` abre cenas no launch — clique
            // programático não existe sem permissão de acessibilidade.
            if let ids = UserDefaults.standard.string(forKey: "debugOpenWindow") {
                for id in ids.split(separator: ",") { openWindow(id: String(id)) }
            }
            #endif
            await followSimulator()
        }
        .task {
            // Heartbeat do crawl (deste app ou do CLI) — a linha só existe
            // enquanto ~/.ios-controller/crawl/status.json estiver fresco.
            while !Task.isCancelled {
                crawl = CrawlControl.current()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: - Crawl ativo (local ou externo) — pausar/parar via CrawlControl

    private func crawlRow(_ status: CrawlControl.Status) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button {
                    openWindow(id: "atlas")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: status.paused
                              ? "pause.circle.fill" : "dot.radiowaves.left.and.right")
                            .foregroundStyle(status.paused ? Color.orange : Color.green)
                        Text("Crawl · \(status.screens) telas")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Abrir o Atlas")

                Spacer(minLength: 0)

                Button {
                    CrawlControl.setPaused(!status.paused)
                } label: {
                    Image(systemName: status.paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .help(status.paused ? "Retomar o crawl" : "Pausar o crawl")

                Button {
                    CrawlControl.requestStop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .tint(.red)
                .help("Parar o crawl (o parcial vira resultado)")
            }
            Text("\(status.queued) na fila · \(status.bundleId)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Header: saúde + pin + settings

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .help(state.wdaUp == true ? "WDA no ar" :
                      state.wdaUp == false ? "WDA fora do ar" : "Verificando WDA…")
            VStack(alignment: .leading, spacing: 0) {
                Text(state.simName ?? "Simulator")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if let bundle = state.sessionBundle {
                    Text(bundle)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Toggle(isOn: $followSim) {
                Image(systemName: "pin")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .help("Colar a palette na janela do Simulator")
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Ajustes (alvo, projeto)")
        }
    }

    private var statusColor: Color {
        switch state.wdaUp {
        case true: .green
        case false: .red
        default: .gray
        }
    }

    @ViewBuilder
    private var recordingClock: some View {
        if let started = capture.recordingStarted {
            TimelineView(.periodic(from: started, by: 1)) { context in
                let secs = Int(context.date.timeIntervalSince(started))
                Text(String(format: "%d:%02d", secs / 60, secs % 60))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Linhas de ação

    private func row(
        _ title: String, icon: String, tint: Color? = nil,
        @ViewBuilder trailing: () -> some View = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer(minLength: 0)
                trailing()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(tint ?? .primary)
    }

    // MARK: - Seguir o Simulator

    /// Poll leve (CGWindowList) — reposiciona quando o Simulator anda.
    /// Pin desligado = palette livre.
    private func followSimulator() async {
        while !Task.isCancelled {
            if followSim, let window,
               let origin = SimWindowLocator.paletteOrigin(paletteSize: window.frame.size),
               abs(window.frame.origin.x - origin.x) > 1 || abs(window.frame.origin.y - origin.y) > 1 {
                window.setFrameOrigin(origin)
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
    }
}

#Preview {
    PaletteView()
        .environment(AppState())
        .environment(CaptureController())
}
