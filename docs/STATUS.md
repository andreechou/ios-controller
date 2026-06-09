# Status — o que foi feito

iOS Controller compila e roda. Verificado ponta-a-ponta dirigindo apps reais no
Simulator: **audit do Carretel** (3 telas, 6 issues a11y) e **drive do Midios**
via WDA (escrever nota markdown, page info). Testes 7/7.

## Camadas (todas implementadas)

| camada | o que faz |
|--------|-----------|
| **Driver** | `WebDriverAgentDriver` (HTTP → WDA :8100), `Simctl` (boot/install/screenshot). Tap/drag via W3C Actions; keys via `/wda/keys`. |
| **Perception** | `ScreenObservation` = árvore a11y (barata) + screenshot. `WDASource` parseia `/source?format=json`. |
| **Agent** | `Agent` faz percepção→decisão; tool-use 1:1 com `Action` via `ToolSchema`. |
| **Providers** | Anthropic (Messages) + OpenAI-compatible (OpenAI/DeepSeek/OpenRouter por base URL). Keys por env. |
| **Run** | `RunCoordinator` (loop central, eventos via `AsyncStream`), `JSONLLedger` (append-only). |
| **Suite** | cenários declarativos (JSON) → relatório HTML pass/fail. |
| **Audit** | crawl BFS determinístico (replay-from-root), dedupe por `ScreenSignature`, checagens a11y → galeria HTML. Sem LLM. |
| **App** | `IOSController.app` SwiftUI nativo: config (Form), preview do sim ao vivo, feed de passos. |
| **MCP** | `ios-controller-mcp` expõe o sim como tools pro Claude Code. |

## Construído nesta sessão

- **Gerado + posto pra compilar** (Swift 6 strict): `ToolSpec @unchecked Sendable`,
  `sending` na cadeia HTTP do WDA, fix do `AsyncStream` no `RunCoordinator`,
  `Observation`→`ScreenObservation`, `IOSControllerCore` virou static library,
  Info.plist no target de testes.
- **Fix W3C Actions** pra tap/drag (endpoint legado sumiu no WDA 13.2.4).
- **Preview do sim ao vivo** no painel do app (screenshots ~1.5 fps via simctl, sem WDA).
- **Campo de API key na GUI** + Keychain (por provider; vazio cai pro env).
- **Visual nativo Apple** — `NavigationSplitView`, `Form` grouped, system colors,
  SF Symbols, `ContentUnavailableView`.
- **UI em inglês**.
- **Feed de driver externo** — qualquer driver (`wda.sh`/curl/MCP) escreve em
  `~/.ios-controller/feed.jsonl`, espelhado no painel direito do app ao vivo.
- **`scripts/wda.sh`** — driver manual do sim (session/shot/source/tap/type/swipe).
- **Docs** — `MODES.md` (5 modos, WDA≠MCP).
- **Rename** scout → iOS Controller; repo público.
