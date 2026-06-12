# iOS Controller

AI-driven user testing for the iOS Simulator. Write a goal in natural language
and a persona; an LLM agent reads the screen, interacts, and reports UX friction
— real-user simulation, not a scripted UI test.

The app is a RocketSim-style **floating palette** pinned to the real Simulator
window (no screen mirroring — the Simulator *is* the interface). On-demand
windows: **Steps** (tail of `~/.ios-controller/feed.jsonl`) and **Atlas** (a live
navigation treeline). The brain lives outside the app: Claude Code drives via
WDA/MCP.

```
┌─────────────┐    ┌──────────────────┐    ┌──────────────┐
│  config     │ →  │  RunCoordinator  │ ←→ │  Ledger      │
│  (app/cli)  │    │   (the loop)     │    │  (JSONL)     │
└─────────────┘    └────────┬─────────┘    └──────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐  ┌──────────┐  ┌──────────────┐
        │  Driver  │  │  Agent   │  │  Providers   │
        │  (WDA)   │  │ (decide) │  │ (4 models)   │
        └──────────┘  └──────────┘  └──────────────┘
```

## The loop

`observe` (a11y tree + screenshot) → `decide` (tool call) → append to ledger →
`perform` (action on the sim) → repeat until the agent calls `report` or the
budget (steps/tokens) runs out.

## Setup

```sh
brew install xcodegen
git submodule add https://github.com/appium/WebDriverAgent vendor/WebDriverAgent
xcodegen generate
export ANTHROPIC_API_KEY=...   # or OPENAI / DEEPSEEK / OPENROUTER
```

Before any command, bring WDA up: `IOSCTL_UDID=<UDID> scripts/start-wda.sh`.

## Run

App: `open IOSController.xcodeproj` → ▶

CLI:
```sh
ios-controller-cli run --udid <UDID> --bundle com.example.app \
          --goal "Sign up and create my first list" \
          --persona "First-time user" \
          --provider deepseek
```

## Modes

Five ways to drive the sim — the **brain** is pluggable, the **hands** (WDA)
never change: autonomous LLM (app/CLI), Claude Code (MCP), deterministic audit,
or by hand via WDA (`scripts/wda.sh`). See [`docs/MODES.md`](docs/MODES.md).

The memory-preferred order when driving: **WDA direct** first (Claude Code is the
brain, no API key), **MCP server** second, **API-key autonomous loop** last.

## Atlas — navigation map

The Atlas window builds a screen-by-screen tree of the app under test. Two modes:

- **Mapear** (semi-automatic) — launches the app at root, then watches: you
  navigate the Simulator by hand and each tap that changes the screen is captured
  automatically (it waits for the page to settle first). Going back to an
  already-seen screen just re-anchors — no duplicates. A **Capturar tela** button
  forces a capture. You stay in control of where it goes.
- **Mapear automático** — deterministic BFS crawler (`AuditCrawler`): launches the
  app and taps every interactive element itself, deduping by `ScreenSignature`,
  running a11y checks (missing label, tap target < 44pt) on each unique screen.

A running crawl (from the app **or** a CLI `audit`) is shown and controllable from
both the palette and the Atlas window — **pause / resume / stop**. Control travels
through flag files in `~/.ios-controller/crawl/` (`status.json` heartbeat + `pause`
/ `stop`), so any process can command any crawl without IPC.

## Audit (CLI)

Deterministic, no LLM — walks every reachable screen by replay-from-root, captures
a screenshot of each unique screen, runs a11y checks, and emits a self-contained
HTML gallery.

```sh
ios-controller-cli audit --udid <UDID> --bundle com.example.app \
          --max-screens 60 --max-depth 4 --out audit.html
```

## State

Builds and runs — app, `ios-controller-cli`, `ios-controller-mcp`, and tests
(green). All layers implemented: WDA driver (HTTP), perception (a11y + screenshot),
agent (tool-use), 4 providers, ledger, suite, and audit. Pending refinements are
listed in `CLAUDE.md` (TODO).
