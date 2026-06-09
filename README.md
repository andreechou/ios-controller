# scout

Teste de usuário dirigido por IA pro iOS Simulator. Escreva um objetivo em
linguagem natural e uma persona; um agente LLM lê a tela, interage, e reporta
fricção de UX — simulação de usuário real, não teste scriptado.

```
┌─────────────┐    ┌──────────────────┐    ┌──────────────┐
│  config     │ →  │  RunCoordinator  │ ←→ │  Ledger      │
│  (app/cli)  │    │   (o loop)       │    │  (JSONL)     │
└─────────────┘    └────────┬─────────┘    └──────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐  ┌──────────┐  ┌──────────────┐
        │  Driver  │  │  Agent   │  │  Providers   │
        │  (WDA)   │  │ (decide) │  │ (4 modelos)  │
        └──────────┘  └──────────┘  └──────────────┘
```

## Loop

`observe` (a11y + screenshot) → `decide` (tool call) → registra no ledger →
`perform` (ação no sim) → repete até `report` do agente ou esgotar budget
(steps/tokens).

## Setup

```sh
brew install xcodegen
git submodule add https://github.com/appium/WebDriverAgent vendor/WebDriverAgent
xcodegen generate
export ANTHROPIC_API_KEY=...   # ou OPENAI/DEEPSEEK/OPENROUTER
```

## Rodar

App: `open Scout.xcodeproj` → ▶
CLI:
```sh
scout-cli --udid <UDID> --bundle com.exemplo.app \
          --goal "Cadastrar e criar minha primeira lista" \
          --persona "Usuário de primeira viagem" \
          --provider deepseek
```

## Modos

Cinco formas de dirigir o sim — o **cérebro** é plugável, as **mãos** (WDA) não
mudam: LLM autônomo (app/CLI), Claude Code (MCP), audit determinístico, ou na mão
via WDA (`scripts/wda.sh`). Veja [`docs/MODES.md`](docs/MODES.md).

## Estado

Compila e roda — app, `scout-cli`, `scout-mcp` e testes (verdes). Todas as
camadas implementadas: driver WDA (HTTP), percepção (a11y+screenshot), agente
(tool-use), 4 providers, ledger, suite e audit. Refinamentos pendentes listados
em `CLAUDE.md` (TODO).
