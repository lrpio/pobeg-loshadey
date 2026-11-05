#!/usr/bin/env bash
# Сборка, проверки и публикация в Roblox через Open Cloud.
# Нужны переменные окружения: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID.
# VERSION_TYPE=Saved — сохранить без публикации (по умолчанию Published).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ROBLOX_API_KEY:?Нужен ROBLOX_API_KEY (ключ Open Cloud с правом публикации места)}"
: "${ROBLOX_UNIVERSE_ID:?Нужен ROBLOX_UNIVERSE_ID (ID опыта)}"
: "${ROBLOX_PLACE_ID:?Нужен ROBLOX_PLACE_ID (ID места)}"
ROJO="${ROJO:-rojo}"; LUNE="${LUNE:-lune}"
command -v "$ROJO" >/dev/null || ROJO="$HOME/.cargo/bin/rojo"
command -v "$LUNE" >/dev/null || LUNE="$HOME/.cargo/bin/lune"
mkdir -p build
"$ROJO" build -o build/CursedForest.rbxl
"$LUNE" run tests/syntax.luau
"$LUNE" run tests/logic.luau
"$LUNE" run tests/place.luau
echo "Публикую в опыт $ROBLOX_UNIVERSE_ID, место $ROBLOX_PLACE_ID (${VERSION_TYPE:-Published})…"
curl --fail-with-body -sS -X POST \
  "https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=${VERSION_TYPE:-Published}" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/CursedForest.rbxl
echo
echo "Готово."
