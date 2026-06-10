import SwiftUI

/// Painel esquerdo: abas de chat, cada uma com um "cérebro" (CLIs no terminal
/// embutido ou modelos via API) dirigindo o simulador pelo WDA.
/// Conteúdo das abas fica montado num ZStack — trocar de aba não mata o PTY
/// nem a conversa; só alterna opacidade/hit-testing.
struct ChatPaneView: View {
    @Environment(AppState.self) private var state
    @State private var store = SessionsStore()

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
            ZStack {
                ForEach(store.sessions) { session in
                    content(for: session)
                        .opacity(session.id == store.selectedID ? 1 : 0)
                        .allowsHitTesting(session.id == store.selectedID)
                }
            }
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.sessions) { session in
                        tab(for: session)
                    }
                }
                .padding(.horizontal, 6)
            }

            Menu {
                ForEach(SessionKind.allCases) { kind in
                    Button {
                        store.add(kind)
                    } label: {
                        Label(kind.title, systemImage: kind.icon)
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 8)
            .help("Nova aba de chat")
        }
        .frame(height: 32)
    }

    private func tab(for session: ChatSession) -> some View {
        let selected = session.id == store.selectedID
        return HStack(spacing: 5) {
            Image(systemName: session.kind.icon)
                .imageScale(.small)
            Text(session.title)
                .font(.caption)
                .lineLimit(1)
            Button {
                store.close(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Fecha a aba")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(selected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { store.selectedID = session.id }
    }

    @ViewBuilder
    private func content(for session: ChatSession) -> some View {
        if session.kind.isTerminal {
            TerminalView(autoCommand: session.kind.terminalCommand)
        } else {
            APIChatView(controller: store.controller(for: session))
        }
    }
}

/// Conversa com um modelo via API que dirige o WDA por tools.
struct APIChatView: View {
    @Bindable var controller: ChatController
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List(controller.messages) { msg in
                    row(msg)
                        .id(msg.id)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .onChange(of: controller.messages.count) {
                    if let last = controller.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            HStack(spacing: 8) {
                TextField("Instrução pro agente (ex: abra o app e crie uma nota)",
                          text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .onSubmit(sendDraft)
                if controller.busy {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: sendDraft) {
                        Image(systemName: "arrow.up.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(10)
        }
    }

    private func sendDraft() {
        controller.send(draft)
        draft = ""
    }

    @ViewBuilder
    private func row(_ msg: ChatController.Message) -> some View {
        switch msg.role {
        case .user:
            HStack {
                Spacer(minLength: 24)
                Text(msg.text)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            }
        case .assistant:
            Text(msg.text)
                .textSelection(.enabled)
        case .action:
            Label(msg.text, systemImage: "hand.tap")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        case .error:
            Label(msg.text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
