import Foundation

/// Converte a árvore JSON do WDA (`/source?format=json`) em
/// `[AccessibilitySnapshot.Node]` achatados, com ids sintéticos por caminho.
public enum WDASource {
    /// Faz o parse e devolve os nós (já achatados). Cada nó ganha um id estável
    /// dentro do snapshot (ex: "0.2.1") pra o agente referenciar.
    public static func parse(_ tree: [String: Any]) -> [AccessibilitySnapshot.Node] {
        var out: [AccessibilitySnapshot.Node] = []
        walk(tree, path: "0", into: &out)
        return out
    }

    private static func walk(_ node: [String: Any], path: String,
                             into out: inout [AccessibilitySnapshot.Node]) {
        let role = shortRole(node["type"] as? String ?? "Other")
        let label = (node["label"] as? String) ?? (node["name"] as? String)
        let value = node["value"].flatMap { "\($0)" }
        let enabled = boolish(node["isEnabled"])
        let visible = boolish(node["isVisible"])
        let rect = node["rect"] as? [String: Any] ?? [:]
        let frame = AccessibilitySnapshot.Node.Frame(
            x: dbl(rect["x"]), y: dbl(rect["y"]),
            width: dbl(rect["width"]), height: dbl(rect["height"]))

        // Mantém só o que é perceptível e tem alguma identidade.
        if visible, frame.width > 0, frame.height > 0,
           (label?.isEmpty == false || isInteractive(role)) {
            out.append(.init(id: path, role: role, label: label, value: value,
                             enabled: enabled, frame: frame))
        }

        let children = node["children"] as? [[String: Any]] ?? []
        for (i, child) in children.enumerated() {
            walk(child, path: "\(path).\(i)", into: &out)
        }
    }

    static func isInteractive(_ role: String) -> Bool {
        ["Button", "TextField", "SecureTextField", "Switch", "Slider",
         "Cell", "Link", "SearchField", "Tab"].contains(role)
    }

    /// "XCUIElementTypeButton" -> "Button".
    private static func shortRole(_ raw: String) -> String {
        raw.replacingOccurrences(of: "XCUIElementType", with: "")
    }

    private static func boolish(_ v: Any?) -> Bool {
        if let b = v as? Bool { return b }
        if let s = v as? String { return s == "1" || s.lowercased() == "true" }
        if let i = v as? Int { return i != 0 }
        return false
    }

    private static func dbl(_ v: Any?) -> Double { (v as? Double) ?? Double(v as? Int ?? 0) }
}
