import SwiftUI
@preconcurrency import SwiftTerm

/// Terminal real embutido (PTY) via SwiftTerm. Sobe um `zsh -l` (login) pra herdar
/// PATH/python3/curl — assim `scripts/wda.sh` roda direto daqui. Tudo que o wda.sh
/// faz cai em `~/.ios-controller/feed.jsonl`, que o `AppState` segue e mostra no Feed.
/// Cérebro = você no terminal; mãos = WDA; olhos = pane do Simulador ao lado.
struct TerminalView: NSViewRepresentable {
    /// Comando injetado no shell logo após abrir (ex.: "claude", "codex") —
    /// shell continua vivo quando o comando sai.
    var autoCommand: String? = nil

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let term = LocalProcessTerminalView(frame: .zero)
        // Env com TERM=xterm-256color + LANG — sem isso programas reclamam de terminal.
        let env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        // App aberto pelo Finder roda com cwd "/" — o filho herda. Começa direto no
        // projeto (defaults projectDir / IOSCTL_PROJECT_DIR), `claude` e wda.sh à mão.
        FileManager.default.changeCurrentDirectoryPath(AppState.projectDir)
        term.startProcess(executable: "/bin/zsh", args: ["-l"], environment: env)
        if let cmd = autoCommand {
            // Pequeno delay: deixa o zsh terminar o init antes de receber o comando.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak term] in
                term?.send(txt: cmd + "\n")
            }
        }
        return term
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
