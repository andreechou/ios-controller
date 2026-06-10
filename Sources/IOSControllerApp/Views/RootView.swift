import SwiftUI

/// Cockpit: chrome 100% nativo (titlebar + toolbar do sistema, botões padrão),
/// split próprio (HStack + AdaptiveLayout). O container de colunas é nosso de
/// propósito: o NavigationSplitView/inspector do macOS 26 clipa conteúdo ao
/// encolher a janela — comprovado nesta base mesmo com bindings passivos.
/// Esquerda: chat multi-abas (CLIs/API dirigindo o WDA). Centro: simulador.
/// Direita: Steps ao vivo | Tests declarados.
struct RootView: View {
    @Environment(AppState.self) private var state
    @AppStorage("prefCockpit") private var prefCockpit = true
    @AppStorage("prefSteps") private var prefSteps = true
    @AppStorage("mediumPanel") private var mediumPanelRaw = AdaptiveLayout.SidePanel.cockpit.rawValue
    @State private var band: AdaptiveLayout.Band = .wide
    @State private var contentWidth: CGFloat = 1200

    private var resolution: AdaptiveLayout.Resolution {
        AdaptiveLayout.resolve(
            band: band, preferCockpit: prefCockpit, preferSteps: prefSteps,
            mediumPanel: AdaptiveLayout.SidePanel(rawValue: mediumPanelRaw) ?? .cockpit)
    }

    /// Painéis proporcionais à janela, com clamps — encolher a janela encolhe
    /// o painel até o piso legível; o conteúdo interno trunca/quebra linha.
    /// Pisos amarrados aos limiares do AdaptiveLayout.
    private var cockpitWidth: CGFloat { min(460, max(280, contentWidth * 0.30)) }
    private var stepsWidth: CGFloat { min(400, max(260, contentWidth * 0.26)) }

    var body: some View {
        HStack(spacing: 0) {
            if resolution.cockpit {
                ChatPaneView()
                    .frame(width: cockpitWidth)
                    .transition(.move(edge: .leading))
                divider
            }

            SimulatorPaneView()
                .frame(minWidth: 280, maxWidth: .infinity)

            if resolution.steps {
                divider
                TestsPaneView()
                    .frame(width: stepsWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.snappy(duration: 0.25), value: resolution)
        .navigationTitle("iOS Controller")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    prefCockpit.toggle()
                    if prefCockpit { mediumPanelRaw = AdaptiveLayout.SidePanel.cockpit.rawValue }
                } label: {
                    Label("Chat", systemImage: "sidebar.leading")
                }
                .help("Mostra/esconde o painel de chat")
            }
            ToolbarItem(placement: .primaryAction) {
                // Sumiu o painel por falta de espaço, some o botão junto.
                if resolution.steps || band == .wide {
                    Button {
                        prefSteps.toggle()
                        if prefSteps { mediumPanelRaw = AdaptiveLayout.SidePanel.steps.rawValue }
                    } label: {
                        Label("Steps", systemImage: "sidebar.trailing")
                    }
                    .help("Mostra/esconde o painel Steps · Tests")
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            contentWidth = width
            let next = AdaptiveLayout.band(width: width, current: band)
            if next != band { band = next }
        }
        .task {
            // Bootstrap independe do painel visível: espelho do sim + tail do feed + saúde.
            state.startPreview(udid: "booted")
            state.startFeedTail()
            state.startStatusPolls()
            #if DEBUG
            // Harness visual: `defaults write md.chou.ioscontroller.app debugWindowWidth
            // -float 800` força a largura no launch — única forma confiável de testar
            // as bandas por screenshot (restore de frame externo é ignorado no 26).
            let w = UserDefaults.standard.double(forKey: "debugWindowWidth")
            if w > 0 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if let win = NSApp.windows.first {
                    var f = win.frame
                    f.size = CGSize(width: w, height: 700)
                    win.setFrame(f, display: true, animate: false)
                }
            }
            #endif
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
    }
}

#Preview {
    RootView().environment(AppState())
}
