#!/usr/bin/env bash
# Sobe o WebDriverAgentRunner no simulador alvo e mantém o WDA escutando em :8100.
# Pré: git submodule add https://github.com/appium/WebDriverAgent vendor/WebDriverAgent
set -euo pipefail

UDID="${IOSCTL_UDID:-booted}"
WDA_DIR="vendor/WebDriverAgent"

echo "→ subindo WebDriverAgentRunner no simulador $UDID …"
xcodebuild \
  -project "$WDA_DIR/WebDriverAgent.xcodeproj" \
  -scheme WebDriverAgentRunner \
  -destination "platform=iOS Simulator,id=$UDID" \
  test-without-building \
  -derivedDataPath /tmp/wda-dd &

echo "→ aguardando :8100 …"
until curl -sf http://127.0.0.1:8100/status >/dev/null 2>&1; do sleep 1; done
echo "✓ WDA pronto em http://127.0.0.1:8100"
wait
