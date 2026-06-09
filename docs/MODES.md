# Modos de operação — mãos × cérebro

O scout separa duas coisas:

- **Mãos/olhos** — quem mexe no simulador: toca, digita, arrasta, lê a tela.
  É **sempre o WDA** (WebDriverAgent), um servidor HTTP rodando dentro do sim.
- **Cérebro** — quem **decide** a próxima ação. Esse é **plugável**.

Trocar o cérebro dá os modos abaixo. As mãos não mudam.

```
CÉREBRO (decide)                     MÃOS (executa)
  ├─ LLM via API   ─┐
  ├─ Claude Code   ─┤── ações ──>  WDA (:8100, no sim) ──XCTest──> app
  ├─ você/eu (curl)─┤
  └─ ninguém       ─┘
```

## Os 5 modos

| # | modo | cérebro | interface | precisa key? | bom pra |
|---|------|---------|-----------|--------------|---------|
| 1 | **Scout.app** | LLM via API | GUI nativa macOS | sim | rodar e ver ao vivo |
| 2 | **scout-cli run/suite** | LLM via API | terminal | sim | CI, headless, batch |
| 3 | **scout-cli audit** | nenhum (algoritmo) | terminal | **não** | mapear telas + a11y |
| 4 | **scout-mcp** | **Claude Code** | chat | não | dirigir conversando |
| 5 | **WDA direto** | você/eu (curl/`wda.sh`) | terminal/chat | não | controle fino, dev loop |

Modos 1–2: autônomos (um modelo decide sozinho). Modo 3: determinístico, sem IA.
Modo 4: Claude Code chama as tools do scout. **Modo 5**: fala HTTP direto no WDA,
sem passar pelo `ScoutCore` — é o mais cru e o mais flexível pra trabalhar daqui.

## WDA × MCP — não confundir

São camadas **opostas**. Ambos usam JSON, mas pra coisas diferentes.

| | **WDA** | **MCP** |
|---|---------|---------|
| o que é | servidor de automação dentro do sim | protocolo p/ um LLM chamar ferramentas |
| protocolo | HTTP + JSON (WebDriver) | JSON-RPC (stdio) |
| papel | atuador (tap/type/screenshot) | cola entre cérebro e tools |
| específico de iOS | sim | não (qualquer tool) |

No modo 4 os dois se encadeiam — `scout-mcp` é o **adaptador**:

```
Claude Code ──MCP──> scout-mcp ──HTTP──> WDA ──XCTest──> app no sim
```

## Modo 5 na prática — `scripts/wda.sh`

Driver manual do sim. Pré: WDA no ar (`scripts/start-wda.sh`). A sessão fica
em `/tmp/wda-sid`.

```sh
scripts/wda.sh session com.chou.midios   # abre o app, cria sessão
scripts/wda.sh shot                       # screenshot -> /tmp/wda-shot.png
scripts/wda.sh source                     # árvore de a11y (json)
scripts/wda.sh tap 200 548                # toca em (x,y) pt
scripts/wda.sh type "# Olá **mundo**"     # digita no campo focado
scripts/wda.sh swipe 300 600 300 200      # arrasta (scroll)
scripts/wda.sh close                      # encerra sessão
```

Foi exatamente isso (via curl cru) que escreveu a nota markdown de teste no
Midios — sem LLM, sem key: o **cérebro fui eu**, as mãos foram o WDA.

## Loop de desenvolvimento (código ↔ sim, tudo daqui)

Com o WDA no ar e acesso ao código do app, fecha o ciclo completo sem sair do chat:

```
1. editar código do app (Swift)
2. xcodebuild + simctl install            # rebuilda e instala no sim
3. wda.sh session <bundle> / tap / type   # exercita o fluxo
4. wda.sh shot  ->  Claude lê o screenshot # observa o resultado
5. achou bug? volta pro 1.
```

Cérebro = Claude Code (eu). Mãos = WDA. Olhos = screenshot. É o **inner loop**
de dev de iOS, dirigido por conversa.
