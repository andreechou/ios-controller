import SwiftUI

/// Tema dark do app. Mesma linguagem visual dos seus projetos pessoais.
enum Theme {
    static let bg        = Color(hex: 0x0a0f1a)
    static let surface   = Color(hex: 0x111827)
    static let border    = Color(hex: 0x1f2937)
    static let text      = Color(hex: 0xe5e7eb)
    static let muted     = Color(hex: 0x6b7280)
    static let accent    = Color(hex: 0xf97316) // laranja TE
    static let success   = Color(hex: 0x22c55e)
    static let danger    = Color(hex: 0xef4444)

    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
