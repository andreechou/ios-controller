import Foundation
import IOSControllerCore
import Observation

/// Tipos de "cérebro" disponíveis numa aba de chat. Todos dirigem o simulador
/// via WDA — muda só quem decide: um CLI no terminal embutido (o próprio CLI
/// fala com o WDA/MCP) ou um modelo via API (o ChatController fala com o WDA).
enum SessionKind: String, Codable, CaseIterable, Identifiable {
    case claudeTerminal, claudeAPI, openAIAPI, codexTerminal, openCode, piCode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeTerminal: "Claude"
        case .claudeAPI: "Claude API"
        case .openAIAPI: "OpenAI API"
        case .codexTerminal: "Codex"
        case .openCode: "OpenCode"
        case .piCode: "PiCode"
        }
    }

    var icon: String {
        switch self {
        case .claudeTerminal: "apple.terminal"
        case .claudeAPI: "sparkles"
        case .openAIAPI: "brain.head.profile"
        case .codexTerminal: "chevron.left.forwardslash.chevron.right"
        case .openCode: "curlybraces"
        case .piCode: "function"
        }
    }

    /// Comando injetado no PTY ao abrir a aba (kinds de terminal).
    var terminalCommand: String? {
        switch self {
        case .claudeTerminal: "claude"
        case .codexTerminal: "codex"
        case .openCode: "opencode"
        case .piCode: "picode"
        case .claudeAPI, .openAIAPI: nil
        }
    }

    /// Provider usado pelos kinds de API.
    var provider: ProviderID? {
        switch self {
        case .claudeAPI: .anthropic
        case .openAIAPI: .openai
        default: nil
        }
    }

    var isTerminal: Bool { terminalCommand != nil }
}

struct ChatSession: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: SessionKind
    var title: String

    init(kind: SessionKind) {
        self.id = UUID()
        self.kind = kind
        self.title = kind.title
    }
}

/// Abas de chat: lista persistida (UserDefaults), controllers de API vivos por
/// aba (não persistidos — sessão de conversa morre com o app; terminal idem).
@MainActor
@Observable
final class SessionsStore {
    private static let defaultsKey = "chatSessions"

    var sessions: [ChatSession] = []
    var selectedID: ChatSession.ID?

    @ObservationIgnored private var controllers: [UUID: ChatController] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([ChatSession].self, from: data),
           !saved.isEmpty {
            sessions = saved
        } else {
            sessions = [ChatSession(kind: .claudeTerminal)]
        }
        selectedID = sessions.first?.id
    }

    func add(_ kind: SessionKind) {
        // Título único quando repete o tipo: "Claude 2", "Claude 3"…
        var session = ChatSession(kind: kind)
        let twins = sessions.filter { $0.kind == kind }.count
        if twins > 0 { session.title = "\(kind.title) \(twins + 1)" }
        sessions.append(session)
        selectedID = session.id
        persist()
    }

    func close(_ id: ChatSession.ID) {
        sessions.removeAll { $0.id == id }
        controllers[id] = nil
        if selectedID == id { selectedID = sessions.last?.id }
        if sessions.isEmpty {
            sessions = [ChatSession(kind: .claudeTerminal)]
            selectedID = sessions.first?.id
        }
        persist()
    }

    func controller(for session: ChatSession) -> ChatController {
        if let c = controllers[session.id] { return c }
        let provider = session.kind.provider ?? .anthropic
        let c = ChatController(provider: provider)
        controllers[session.id] = c
        return c
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
