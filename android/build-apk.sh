#!/usr/bin/env bash
# Пересборка APK: подставляет android/index.html в готовый APK и подписывает вашим ключом.
# Нужны: unzip, zip, zipalign и apksigner (Android SDK build-tools).
# Использование:
#   ./android/build-apk.sh pobeg-loshadey-2.1.apk ~/pobeg.jks POBEG pobeg-loshadey-2.2.apk
# Пароль ключа скрипт спросит сам.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,7p' "$0"; exit 1; }
OLD=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); KEY=$2; ALIAS=$3; OUT=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
HERE=$(cd "$(dirname "$0")" && pwd)
for t in unzip zip zipalign apksigner; do command -v $t >/dev/null || { echo "Не найден $t (поставьте Android build-tools)"; exit 1; }; done
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
unzip -q "$OLD" -d "$W/app"
rm -rf "$W/app/META-INF"
cp "$HERE/index.html" "$W/app/assets/index.html"
(cd "$W/app" && zip -qr -X "$W/unsigned.apk" AndroidManifest.xml resources.arsc classes.dex assets res)
zipalign -f -p 4 "$W/unsigned.apk" "$W/aligned.apk"
apksigner sign --ks "$KEY" --ks-key-alias "$ALIAS" --out "$OUT" "$W/aligned.apk"
apksigner verify "$OUT" && echo "Готово: $OUT"
