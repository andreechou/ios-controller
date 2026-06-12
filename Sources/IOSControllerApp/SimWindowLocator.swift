import AppKit
import SwiftUI

/// Localiza a janela do Simulator.app na tela via CGWindowList — só frames e
/// dono (não exige permissão de gravação de tela, que só protege títulos).
/// É o que permite a palette "colar" no Simulator estilo RocketSim.
@MainActor
enum SimWindowLocator {
    /// Frame (coordenadas AppKit, y pra cima) da maior janela do Simulator.
    /// Maior área = a janela do device (ignora paletas/HUDs do próprio Simulator).
    static func simulatorWindowFrame() -> NSRect? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var best: NSRect?
        for info in list {
            guard info[kCGWindowOwnerName as String] as? String == "Simulator",
                  (info[kCGWindowLayer as String] as? Int ?? 1) == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Double],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"],
                  w > 200, h > 300
            else { continue }
            // CG usa origem no topo-esquerdo do display primário, y pra baixo.
            let rect = NSRect(x: x, y: primaryHeight - y - h, width: w, height: h)
            if best.map({ rect.width * rect.height > $0.width * $0.height }) ?? true {
                best = rect
            }
        }
        return best
    }

    /// Origem pra palette ancorar na lateral direita do Simulator, topo
    /// alinhado. Se não couber na tela, vai pra esquerda.
    static func paletteOrigin(paletteSize: NSSize) -> NSPoint? {
        guard let sim = simulatorWindowFrame() else { return nil }
        let gap: CGFloat = 12
        var x = sim.maxX + gap
        let screen = NSScreen.screens.first { $0.frame.intersects(sim) } ?? NSScreen.main
        if let visible = screen?.visibleFrame, x + paletteSize.width > visible.maxX {
            x = sim.minX - paletteSize.width - gap
        }
        return NSPoint(x: x, y: sim.maxY - paletteSize.height)
    }
}

/// Entrega o NSWindow que hospeda a view — a palette precisa dele pra se mover.
struct WindowAccessor: NSViewRepresentable {
    var onWindow: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onWindow(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
