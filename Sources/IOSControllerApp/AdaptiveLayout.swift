import CoreGraphics

/// Regras responsivas da janela — puro e testável: largura → banda → painéis.
///
/// - `compact`: só o simulador (janela encolhe até ~320pt sem clipar nada)
/// - `medium`:  simulador + UM painel lateral (o que o usuário abriu por último)
/// - `wide`:    tudo que o usuário preferir (cockpit e steps independentes)
///
/// Existe porque o NavigationSplitView/inspector do macOS 26 clipa conteúdo
/// abaixo dos próprios mínimos ao encolher a janela (verificado nesta base
/// repetidas vezes, inclusive com bindings 100% passivos). O container é
/// nosso; os componentes dentro dele seguem nativos.
///
/// Histerese de 40pt pra banda não "piscar" no limiar durante o arrasto.
enum AdaptiveLayout {
    enum Band: String {
        case compact, medium, wide
    }

    enum SidePanel: String {
        case cockpit, steps
    }

    /// Limiares ≥ soma dos PISOS dos painéis no RootView (cockpit clamp-min 280 ·
    /// sim 280 · steps clamp-min 260 · divisores) + folga. Painéis são
    /// proporcionais à janela com clamps; se mudar um piso lá, confira aqui —
    /// senão a banda aceita janela menor que o conteúdo e clipa.
    static let mediumThreshold: CGFloat = 600   // ≥ 280 + 280 + divisor + folga
    static let wideThreshold: CGFloat = 860     // ≥ 280 + 280 + 260 + divisores + folga
    static let hysteresis: CGFloat = 40

    /// Banda nova dada a largura atual — depende da banda corrente (histerese:
    /// pra SUBIR de banda precisa passar o limiar + 40pt; pra descer, basta cruzar).
    static func band(width: CGFloat, current: Band) -> Band {
        switch current {
        case .wide:
            if width < mediumThreshold { return .compact }
            if width < wideThreshold { return .medium }
            return .wide
        case .medium:
            if width < mediumThreshold { return .compact }
            if width >= wideThreshold + hysteresis { return .wide }
            return .medium
        case .compact:
            if width >= wideThreshold + hysteresis { return .wide }
            if width >= mediumThreshold + hysteresis { return .medium }
            return .compact
        }
    }

    /// Painéis efetivamente visíveis: banda limita, preferência decide,
    /// `mediumPanel` desempata na banda média (último painel aberto vence).
    struct Resolution: Equatable {
        public var cockpit: Bool
        public var steps: Bool
    }

    static func resolve(band: Band, preferCockpit: Bool, preferSteps: Bool,
                        mediumPanel: SidePanel) -> Resolution {
        switch band {
        case .wide:
            return Resolution(cockpit: preferCockpit, steps: preferSteps)
        case .medium:
            let pick: SidePanel?
            switch mediumPanel {
            case .cockpit: pick = preferCockpit ? .cockpit : (preferSteps ? .steps : nil)
            case .steps: pick = preferSteps ? .steps : (preferCockpit ? .cockpit : nil)
            }
            return Resolution(cockpit: pick == .cockpit, steps: pick == .steps)
        case .compact:
            return Resolution(cockpit: false, steps: false)
        }
    }
}
