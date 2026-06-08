import Foundation

/// Árvore de acessibilidade achatada. Vira a representação textual barata que
/// o agente lê antes de recorrer ao screenshot.
public struct AccessibilitySnapshot: Sendable, Codable {
    public var nodes: [Node]

    public struct Node: Sendable, Codable, Identifiable {
        public var id: String
        public var role: String          // button, textField, staticText, ...
        public var label: String?
        public var value: String?
        public var enabled: Bool
        public var frame: Frame

        public struct Frame: Sendable, Codable, Equatable {
            public var x, y, width, height: Double
            public init(x: Double, y: Double, width: Double, height: Double) {
                self.x = x; self.y = y; self.width = width; self.height = height
            }
            /// Centro do elemento — alvo natural de um tap.
            public var center: (x: Double, y: Double) { (x + width / 2, y + height / 2) }
        }

        public init(id: String, role: String, label: String? = nil, value: String? = nil,
                    enabled: Bool = true, frame: Frame) {
            self.id = id; self.role = role; self.label = label
            self.value = value; self.enabled = enabled; self.frame = frame
        }
    }

    public init(nodes: [Node]) { self.nodes = nodes }

    /// Renderização compacta pro prompt — uma linha por nó interativo.
    public func promptDescription(maxNodes: Int = 60) -> String {
        nodes.prefix(maxNodes).map { n in
            let label = n.label ?? n.value ?? "—"
            let state = n.enabled ? "" : " (disabled)"
            return "[\(n.id)] \(n.role): \"\(label)\"\(state)"
        }.joined(separator: "\n")
    }
}
