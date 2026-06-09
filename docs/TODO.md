# TODO — o que falta

## Prioridade
1. **Loop de tool-result** (modo loop interno): devolver o `ActionOutcome` ao
   modelo entre passos — hoje o agente decide a próxima ação sem receber o
   resultado da anterior.
2. **Crawler além do tap**: recuperar telas atrás de swipe / long-press. O audit
   só replica sequências de tap a partir do root.
3. **Assertions ricas no `Scenario`**: ex. "tela final deve conter o label X".
   Hoje só compara veredito + presença de fricção.
4. **Validar endpoints WDA por versão**: tap/drag/keys confirmados no 13.2.4 —
   outras versões podem variar (ver [GOTCHAS](GOTCHAS.md)).

## Melhorias
- Promover `wda.sh` a comando nativo **`ios-controller-cli drive`** (mode 5
  first-class no binário, não só shell script).
- Preview do sim é stream de screenshots (~1.5 fps). Embutir a janela real
  (ScreenCaptureKit / CGWindow capture) seria mais fluido.
- Revisar/atualizar os modelos default em `ProviderRegistry.defaultModel`.
- Cobertura de testes além de `WDASource` / `AgentDecision`.
- Signing: só Personal Team (sem App Store em v1).

## Resolvido nesta sessão (antes era TODO)
- ~~Captura da janela do Simulator no pane~~ → **preview ao vivo** via screenshots.
- ~~Camada HTTP do WDA marcada TODO~~ → **implementada + fix W3C Actions**.
