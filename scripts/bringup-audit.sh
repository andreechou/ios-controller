#!/usr/bin/env bash
# Bringup completo end-to-end: builda o WebDriverAgentRunner, sobe o WDA em :8100
# e roda um `iOS Controller audit` contra um app já instalado no simulador — sem precisar
# de API key. Prova que o pipeline inteiro funciona.
#
# Pré-requisito (uma vez, fora deste script — integra código externo):
#   git submodule add https://github.com/appium/WebDriverAgent vendor/WebDriverAgent
#
# Uso:
#   scripts/bringup-audit.sh [UDID] [BUNDLE_ID]
#   defaults: UDID = simulador bootado; BUNDLE_ID = com.apple.Preferences (app de fábrica)
set -euo pipefail

UDID="${1:-$(xcrun simctl list devices booted | grep -oE '[0-9A-Fa-f-]{36}' | head -1)}"
BUNDLE="${2:-com.apple.Preferences}"
WDA="vendor/WebDriverAgent/WebDriverAgent.xcodeproj"
DD=/tmp/wda-dd
CLI=.build/Build/Products/Debug/ios-controller-cli

[ -n "$UDID" ]        || { echo "✗ nenhum simulador bootado. Rode: xcrun simctl boot <UDID>"; exit 1; }
[ -d vendor/WebDriverAgent ] || { echo "✗ falta o submodule WDA. Rode primeiro:"; \
    echo "  git submodule add https://github.com/appium/WebDriverAgent vendor/WebDriverAgent"; exit 1; }
[ -x "$CLI" ]         || { echo "✗ ios-controller-cli não buildado. Rode: xcodebuild -project IOSController.xcodeproj -scheme ios-controller-cli -destination 'platform=macOS' -derivedDataPath .build build"; exit 1; }

echo "→ alvo: simulador $UDID · app $BUNDLE"

echo "→ [1/4] build-for-testing do WebDriverAgentRunner (1ª vez demora alguns min)…"
xcodebuild -project "$WDA" -scheme WebDriverAgentRunner \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" build-for-testing

echo "→ [2/4] subindo WDA em :8100 (background)…"
xcodebuild -project "$WDA" -scheme WebDriverAgentRunner \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" test-without-building >/tmp/wda.log 2>&1 &
WDA_PID=$!
trap 'kill $WDA_PID 2>/dev/null || true' EXIT

echo "→ aguardando :8100…"
for _ in $(seq 1 90); do curl -sf http://127.0.0.1:8100/status >/dev/null 2>&1 && break; sleep 1; done
curl -sf http://127.0.0.1:8100/status >/dev/null 2>&1 || { echo "✗ WDA não respondeu — veja /tmp/wda.log"; exit 1; }
echo "✓ WDA pronto"

echo "→ [3/4] audit de $BUNDLE…"
"$CLI" audit --udid "$UDID" --bundle "$BUNDLE" --max-screens 20 --out audit.html

echo "→ [4/4] relatório: audit.html"
open audit.html
echo "✓ done. (WDA continua até este script sair — Ctrl-C encerra)"
