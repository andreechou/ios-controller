import Foundation
import CryptoKit

/// Assinatura estável de uma tela, pra deduplicar no crawl. Normaliza a árvore
/// (role + label ordenados, ignorando valores dinâmicos) e tira SHA-256.
public enum ScreenSignature {
    public static func of(_ snapshot: AccessibilitySnapshot) -> String {
        let lines = snapshot.nodes
            .map { "\($0.role)|\($0.label ?? "")" }
            .sorted()
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(lines.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}
