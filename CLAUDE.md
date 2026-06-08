# scout

Ferramenta nativa de macOS que dirige o iOS Simulator com um agente de IA pra
rodar **testes de usuário** (não testes de UI scriptados): você escreve um
objetivo em linguagem natural + uma persona, e o agente lê a tela, interage e
reporta fricção de UX.

## Arquitetura

Três camadas, com `ScoutCore` compartilhado entre app e CLI:

- **Driver** (`Driver/`) — `SimulatorDriver` protocol abstrai o alvo.
  `WebDriverAgentDriver` dirige a responder chain via WDA; `Simctl` cobre
  boot/install/launch/screenshot.
- **Percepção** (`Perception/`) — `Observation` = árvore de a11y (barata em
  tokens) + screenshot (visão quando necessário).
- **Agente** (`Agent/`) — `Agent` faz uma rodada percepção→decisão; tool-use
  mapeado 1:1 com `Action` via `ToolSchema`.
- **Providers** (`Providers/`) — `AnthropicProvider` (Messages) +
  `OpenAICompatibleProvider` (OpenAI/DeepSeek/OpenRouter por base URL).
- **Run** (`Run/`) — `RunCoordinator` é o loop central, emite eventos via
  `AsyncStream`.
- **Ledger** (`Ledger/`) — append-only JSONL, um arquivo por run. Sem update,
  sem delete.

## Build

```sh
xcodegen generate          # gera Scout.xcodeproj a partir de project.yml
open Scout.xcodeproj
# ou headless:
xcodebuild -scheme scout-cli -destination 'platform=macOS' build
```

## Convenções

- Swift 6, strict concurrency. Driver e Agent são `actor`s.
- Os 4 providers são prioridade — nenhum é cortado. Keys via env:
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`.
- Sem App Store em v1: Personal Team signing.
- Pra estender o vocabulário do agente: adicione um case em `Action`, uma
  `ToolSpec` em `ToolSchema.all`, e o mapeamento em `ToolSchema.action(from:)`.

## Modos de operação

- **Loop interno** (`scout` app / `scout-cli`): o cérebro é um modelo via API
  (`ModelProvider`). Autônomo, headless, bom pra CI.
- **Servidor MCP** (`scout-mcp`): o cérebro é o Claude Code. O scout expõe o
  `SimulatorDriver` como tools MCP (`observe`, `tap`, `type_text`, `scroll`,
  `tap_element`, `launch`). `observe` devolve a árvore de a11y (texto) +
  screenshot (imagem) — é assim que o Claude Code "vê" a tela.

Ambos compartilham `ScoutCore`. Pra usar o MCP:

```sh
xcodebuild -scheme scout-mcp -configuration Release -derivedDataPath .build build
# binário em .build/Build/Products/Release/scout-mcp; o .mcp.json aponta pra
# .build/release/scout-mcp, então crie o symlink uma vez:
#   mkdir -p .build/release && ln -sf ../Build/Products/Release/scout-mcp .build/release/scout-mcp
```

O `.mcp.json` já registra o servidor `scout`; configure `SCOUT_UDID` e
`SCOUT_BUNDLE_ID` por env. Depois, num chat do Claude Code: "abra o app e tente
se cadastrar" — ele chama as tools, lê a11y+screenshot e decide cada toque.

## Processos de teste & auditoria (CLI)

- **run** — objetivo único exploratório.
  `scout-cli run --udid <U> --bundle <B> --goal "..." --persona "..."`
- **suite** — processo declarativo. JSON (`examples/onboarding.suite.json`) com
  cenários (`goal`, `persona`, `expectedOutcome`, `failOnFriction`). Gera HTML
  pass/fail por cenário.
  `scout-cli suite examples/onboarding.suite.json --udid <U> --out report.html`
- **audit** — navega TODAS as telas (BFS por replay-from-root), captura screenshot
  de cada tela única e roda checagens de a11y (label ausente, toque < 44pt). Gera
  galeria HTML auto-contida. Determinístico, sem LLM; dedupe por `ScreenSignature`.
  `scout-cli audit --udid <U> --bundle <B> --max-screens 60 --max-depth 4 --out audit.html`

Antes de qualquer comando, suba o WDA: `SCOUT_UDID=<U> scripts/start-wda.sh`.

## TODO (prioridade)

1. Loop de tool-result no modo loop interno: devolver `ActionOutcome` ao modelo.
2. Captura da janela do Simulator no `SimulatorPaneView` (hoje é placeholder).
3. Recuperação de telas atrás de gestos não-tap (swipe, long-press) no crawler.
4. Assertions mais ricas no `Scenario` (ex: "tela final deve conter label X").
5. Endpoints WDA podem variar por versão — validar tap/keys/drag no seu setup.
