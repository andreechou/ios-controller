# Gotchas

Armadilhas reais encontradas — leia antes de mexer.

## WDA (validado no WebDriverAgent 13.2.4)
- **Tap / drag = W3C Actions** `POST /session/{id}/actions` (sequência de pointer).
  Os endpoints legados `/wda/tap/0` e `/wda/dragfromtoforduration` retornam
  **HTTP 404** ("Unhandled endpoint").
- **Digitar** = `/session/{id}/wda/keys` com `{"value":["texto"]}` (newlines OK).
- `/source?format=json` e `/screenshot` embrulham o payload em `{"value": ...}` —
  parseie o `.value`, não o wrapper (erro fácil de cometer).
- A11y tree: ache o alvo por `label`/`name`, toque no **centro do `rect`**. As
  coordenadas são **pontos** (ex.: tela 402×874pt), não pixels do screenshot.

## Swift 6 strict concurrency
- `[String: Any]` não é `Sendable` → `ToolSpec` é `@unchecked Sendable` (o JSON
  schema é constante imutável). Para devolver `[String:Any]` cruzando fronteira
  de actor, marque a função `-> sending`.
- O nome `Observation` colide com o **módulo** `Observation` por trás do macro
  `@Observable` (usado no app SwiftUI) → a struct de percepção é `ScreenObservation`.

## Build / Xcode
- Framework macOS **não assina ad-hoc** dentro do bundle de testes
  (`bundle format unrecognized`) → `IOSControllerCore` é **static library**.
- `INFOPLIST_KEY_*` é **ignorado** quando o target tem Info.plist explícito →
  ponha `CFBundleDisplayName` no `info.properties` (xcodegen merge).
- Test target precisa de `GENERATE_INFOPLIST_FILE: YES`.
- `.mcp.json` aponta pra `.build/release/...` (convenção SwiftPM), mas xcodebuild
  gera em `.build/Build/Products/Release/...` → crie symlink.

## App macOS
- App aberto pelo Finder **não herda o env do shell** → sem API keys. Use o campo
  de key na GUI (Keychain) ou lance o binário direto com a var setada.
- **Acessibilidade (System Events) pode estar bloqueada** → não dá pra screenshotar
  a janela do app macOS; observe via screenshots do simulador.

## Ambiente / shell
- O `cwd` pode resetar entre comandos bash → use **paths absolutos**.
- BSD `sed` **não tem `\b`** (word boundary) → use `perl`.
- Word-splitting quebra listas de arquivo → `find … -print0 | xargs -0`.
- Env vars do projeto: `IOSCTL_UDID` / `IOSCTL_BUNDLE_ID` / `IOSCTL_APP_PATH`.
