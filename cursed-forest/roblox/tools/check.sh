#!/usr/bin/env bash
# Все проверки без публикации
set -euo pipefail
cd "$(dirname "$0")/.."
ROJO="$(command -v rojo || echo "$HOME/.cargo/bin/rojo")"; LUNE="$(command -v lune || echo "$HOME/.cargo/bin/lune")"; SELENE="$(command -v selene || echo "$HOME/.cargo/bin/selene")"
"$LUNE" run tests/syntax.luau
"$LUNE" run tests/logic.luau
("$SELENE" src || true) | tail -3
mkdir -p build && "$ROJO" build -o build/CursedForest.rbxl
"$LUNE" run tests/place.luau
