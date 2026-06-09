#!/usr/bin/env bash
# wda.sh — driver manual do simulador via WebDriverAgent (:8100).
# Dirige o sim "na mão" daqui (Claude Code / terminal) — sem LLM, sem o loop do
# scout. Pré: WDA no ar (scripts/start-wda.sh). A sessão fica em /tmp/wda-sid.
#
#   wda.sh session <bundleId>     abre o app e cria a sessão
#   wda.sh shot [out.png]         screenshot (default /tmp/wda-shot.png)
#   wda.sh source                 árvore de a11y (json)
#   wda.sh tap <x> <y>            toca em (x,y) em pontos
#   wda.sh type "texto"          digita no campo focado
#   wda.sh swipe <x1> <y1> <x2> <y2>   arrasta (scroll)
#   wda.sh status | close
set -euo pipefail

WDA="${WDA_URL:-http://127.0.0.1:8100}"
SIDFILE=/tmp/wda-sid
sid() { cat "$SIDFILE" 2>/dev/null || { echo "sem sessão — rode: wda.sh session <bundle>" >&2; exit 1; }; }

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
    curl -s -X POST "$WDA/session" -H 'Content-Type: application/json' \
      -d "{\"capabilities\":{\"alwaysMatch\":{\"bundleId\":\"$2\"}}}" \
      | python3 -c 'import sys,json;print(json.load(sys.stdin)["value"]["sessionId"])' | tee "$SIDFILE" ;;
  shot)
    out="${2:-/tmp/wda-shot.png}"
    curl -s "$WDA/screenshot" | python3 -c "import sys,json,base64;open('$out','wb').write(base64.b64decode(json.load(sys.stdin)['value']))"
    echo "$out" ;;
  source)
    curl -s "$WDA/session/$(sid)/source?format=json" ;;
  tap)
    pointer "$2" "$3" "$2" "$3" 50 ;;
  swipe)
    pointer "$2" "$3" "$4" "$5" 250 ;;
  type)
    python3 - "$(sid)" "$2" "$WDA" <<'PY'
import sys, json, urllib.request
sid, txt, base = sys.argv[1], sys.argv[2], sys.argv[3]
body = json.dumps({"value": [txt]}).encode()
urllib.request.urlopen(urllib.request.Request(
    f"{base}/session/{sid}/wda/keys", data=body,
    headers={"Content-Type": "application/json"}), timeout=60)
PY
    ;;
  status)
    curl -s "$WDA/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["value"]["state"])' ;;
  close)
    curl -s -X DELETE "$WDA/session/$(sid)" >/dev/null && rm -f "$SIDFILE" && echo "fechada" ;;
  *)
    grep '^#' "$0" | sed 's/^# \{0,1\}//' ;;
esac
