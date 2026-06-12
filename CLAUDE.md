# iOS Controller

Ferramenta nativa de macOS que dirige o iOS Simulator com um agente de IA pra
rodar **testes de usuário** (não testes de UI scriptados): você escreve um
objetivo em linguagem natural + uma persona, e o agente lê a tela, interage e
reporta fricção de UX.

O app (estilo RocketSim) é uma **palette flutuante** colada na janela real do
Simulator — nada de espelhar tela. Ações rápidas: screenshot, gravação de vídeo,
status/start do WDA. Janelas sob demanda: **Steps** (tail do
`~/.ios-controller/feed.jsonl`) e **Atlas** (treeline de navegação ao vivo via
`AuditCrawler`). O cérebro fica fora do app: Claude Code dirige via WDA/MCP.

## Arquitetura

Três camadas, com `IOSControllerCore` compartilhado entre app e CLI:

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
xcodegen generate          # gera IOSController.xcodeproj a partir de project.yml
open IOSController.xcodeproj
# ou headless:
xcodebuild -scheme ios-controller-cli -destination 'platform=macOS' build
```

## Convenções

- Swift 6, strict concurrency. Driver e Agent são `actor`s.
- Os 4 providers são prioridade — nenhum é cortado. Keys via env:
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`.
- Sem App Store em v1: Personal Team signing.
- Pra estender o vocabulário do agente: adicione um case em `Action`, uma
  `ToolSpec` em `ToolSchema.all`, e o mapeamento em `ToolSchema.action(from:)`.

## Modos de operação

- **Loop interno** (`ios-controller-cli`): o cérebro é um modelo via API
  (`ModelProvider`). Autônomo, headless, bom pra CI.
- **Servidor MCP** (`ios-controller-mcp`): o cérebro é o Claude Code. O iOS Controller expõe o
  `SimulatorDriver` como tools MCP (`observe`, `tap`, `type_text`, `scroll`,
  `tap_element`, `launch`). `observe` devolve a árvore de a11y (texto) +
  screenshot (imagem) — é assim que o Claude Code "vê" a tela.

Ambos compartilham `IOSControllerCore`. Pra usar o MCP:

```sh
xcodebuild -scheme ios-controller-mcp -configuration Release -derivedDataPath .build build
# binário em .build/Build/Products/Release/ios-controller-mcp; o .mcp.json aponta pra
# .build/release/ios-controller-mcp, então crie o symlink uma vez:
#   mkdir -p .build/release && ln -sf ../Build/Products/Release/ios-controller-mcp .build/release/ios-controller-mcp
```

O `.mcp.json` já registra o servidor `iOS Controller`; configure `IOSCTL_UDID` e
`IOSCTL_BUNDLE_ID` por env. Depois, num chat do Claude Code: "abra o app e tente
se cadastrar" — ele chama as tools, lê a11y+screenshot e decide cada toque.

## Processos de teste & auditoria (CLI)

- **run** — objetivo único exploratório.
  `ios-controller-cli run --udid <U> --bundle <B> --goal "..." --persona "..."`
- **suite** — processo declarativo. JSON (`examples/onboarding.suite.json`) com
  cenários (`goal`, `persona`, `expectedOutcome`, `failOnFriction`). Gera HTML
  pass/fail por cenário.
  `ios-controller-cli suite examples/onboarding.suite.json --udid <U> --out report.html`
- **audit** — navega TODAS as telas (BFS por replay-from-root), captura screenshot
  de cada tela única e roda checagens de a11y (label ausente, toque < 44pt). Gera
  galeria HTML auto-contida. Determinístico, sem LLM; dedupe por `ScreenSignature`.
  `ios-controller-cli audit --udid <U> --bundle <B> --max-screens 60 --max-depth 4 --out audit.html`

Antes de qualquer comando, suba o WDA: `IOSCTL_UDID=<U> scripts/start-wda.sh`.

## TODO (prioridade)

1. Loop de tool-result no modo loop interno: devolver `ActionOutcome` ao modelo.
2. Atlas: arestas desenhadas entre pai/filho (hoje a relação é por coluna +
   label da ação) e export do mapa.
3. Recuperação de telas atrás de gestos não-tap (swipe, long-press) no crawler.
4. Assertions mais ricas no `Scenario` (ex: "tela final deve conter label X").
5. Endpoints WDA podem variar por versão — validar tap/keys/drag no seu setup.
6. Palette: seguir o Simulator por AX observer em vez de poll (hoje 800ms).
