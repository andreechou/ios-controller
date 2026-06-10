#!/usr/bin/env bash
# wda.sh — driver manual do simulador via WebDriverAgent (:8100).
# Dirige o sim "na mão" daqui (Claude Code / terminal) — sem LLM, sem o loop do
# iOS Controller. Pré: WDA no ar (scripts/start-wda.sh). A sessão fica em /tmp/wda-sid.
#
# Cada ação é escrita em ~/.ios-controller/feed.jsonl — o IOSController.app segue esse
# arquivo e mostra os passos ao vivo no painel Steps. Após cada ação, um screenshot
# é arquivado em ~/.ios-controller/runs/wda-<ts>/NNN.png e referenciado no feed
# (campo "img") — trilha visual completa da sessão. IOSCTL_NO_AUTOSHOT=1 desliga.
#
#   wda.sh session <bundleId>     abre o app e cria a sessão (zera feed, novo rundir)
#   wda.sh shot [out.png]         screenshot avulso (também arquiva no rundir)
#   wda.sh source                 árvore de a11y (json)
#   wda.sh tap <x> <y>            toca em (x,y) em pontos
#   wda.sh type "texto"          digita no campo focado
#   wda.sh swipe <x1> <y1> <x2> <y2>   arrasta (scroll)
#   wda.sh status | close
set -euo pipefail

WDA="${WDA_URL:-http://127.0.0.1:8100}"
SIDFILE=/tmp/wda-sid
RUNDIRFILE=/tmp/wda-rundir
FEED="$HOME/.ios-controller/feed.jsonl"
sid() { cat "$SIDFILE" 2>/dev/null || { echo "sem sessão — rode: wda.sh session <bundle>" >&2; exit 1; }; }

# Escreve um passo no feed que o IOSController.app segue.
# feed <texto> [img] [kind] — JSON-escapado; ts sempre presente.
feed() {
  mkdir -p "$HOME/.ios-controller"
  python3 - "$1" "${2:-}" "${3:-}" <<'PY' >> "$FEED"
import json, sys, time
o = {"ts": time.strftime("%H:%M:%S"), "text": sys.argv[1], "ok": True}
if sys.argv[2]: o["img"] = sys.argv[2]
if sys.argv[3]: o["kind"] = sys.argv[3]
print(json.dumps(o))
PY
}

# Captura screenshot pro rundir e escreve o passo com a imagem anexada.
# snap <texto-do-passo> — fallback: passo sem imagem se captura falhar/desligada.
snap() {
  if [ -n "${IOSCTL_NO_AUTOSHOT:-}" ] || ! d=$(cat "$RUNDIRFILE" 2>/dev/null); then
    feed "$1"; return 0
  fi
  n=$(find "$d" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
  f=$(printf "%s/%03d.png" "$d" $((n + 1)))
  if curl -s "$WDA/screenshot" | python3 -c "import sys,json,base64;open('$f','wb').write(base64.b64decode(json.load(sys.stdin)['value']))" 2>/dev/null; then
    feed "$1" "$f"
  else
    feed "$1"
  fi
}

# pointer action W3C (tap/swipe). args: x1 y1 x2 y2 dur
pointer() {
  curl -s -X POST "$WDA/session/$(sid)/actions" -H 'Content-Type: application/json' -d @- <<JSON >/dev/null
{"actions":[{"type":"pointer","id":"finger1","parameters":{"pointerType":"touch"},"actions":[
 {"type":"pointerMove","duration":0,"x":$1,"y":$2},
 {"type":"pointerDown","button":0},
 {"type":"pointerMove","duration":$5,"x":$3,"y":$4},
 {"type":"pointerUp","button":0}]}]}
JSON
}

case "${1:-help}" in
  session)
    mkdir -p "$HOME/.ios-controller"; : > "$FEED"          # novo log por sessão
    rundir="$HOME/.ios-controller/runs/wda-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$rundir"; printf '%s' "$rundir" > "$RUNDIRFILE"
    curl -s -X POST "$WDA/session" -H 'Content-Type: application/json' \
      -d "{\"capabilities\":{\"alwaysMatch\":{\"bundleId\":\"$2\"}}}" \
      | python3 -c 'import sys,json;print(json.load(sys.stdin)["value"]["sessionId"])' | tee "$SIDFILE"
    feed "▶ session $2" "" "session"
    snap "tela inicial" ;;
  shot)
    out="${2:-/tmp/wda-shot.png}"
    curl -s "$WDA/screenshot" | python3 -c "import sys,json,base64;open('$out','wb').write(base64.b64decode(json.load(sys.stdin)['value']))"
    snap "screenshot"; echo "$out" ;;
  source)
    curl -s "$WDA/session/$(sid)/source?format=json" ;;
  tap)
    pointer "$2" "$3" "$2" "$3" 50; snap "tap ($2, $3)" ;;
  swipe)
    pointer "$2" "$3" "$4" "$5" 250; snap "swipe ($2,$3) → ($4,$5)" ;;
  type)
    python3 - "$(sid)" "$2" "$WDA" <<'PY'
import sys, json, urllib.request
sid, txt, base = sys.argv[1], sys.argv[2], sys.argv[3]
body = json.dumps({"value": [txt]}).encode()
urllib.request.urlopen(urllib.request.Request(
    f"{base}/session/{sid}/wda/keys", data=body,
    headers={"Content-Type": "application/json"}), timeout=60)
PY
    snap "type: $2" ;;
  status)
    curl -s "$WDA/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["value"]["state"])' ;;
  close)
    feed "■ close" "" "session"
    curl -s -X DELETE "$WDA/session/$(sid)" >/dev/null && rm -f "$SIDFILE" && echo "fechada" ;;
  *)
    grep '^#' "$0" | sed 's/^# \{0,1\}//' ;;
esac
