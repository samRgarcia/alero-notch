#!/bin/bash
# Instalador de Alero para la Terminal.
# Uso:  curl -fsSL https://notch.samdev.space/install.sh | bash
#
# Qué hace: descarga Alero.dmg, copia Alero.app a /Applications y la abre.
# No pide contraseña ni instala nada más.
set -euo pipefail

# Dirección del sitio de Alero (se puede cambiar con la variable ALERO_BASE_URL)
BASE_URL="${ALERO_BASE_URL:-https://notch.samdev.space}"
DMG_URL="$BASE_URL/downloads/Alero.dmg"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Alero solo funciona en macOS." >&2
    exit 1
fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
    echo "Alero necesita macOS 14 o posterior (tienes $(sw_vers -productVersion))." >&2
    exit 1
fi

TMP="$(mktemp -d)"
cleanup() {
    hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "Descargando Alero…"
curl -fL --progress-bar "$DMG_URL" -o "$TMP/Alero.dmg"

echo "Instalando en /Applications…"
mkdir "$TMP/mnt"
hdiutil attach "$TMP/Alero.dmg" -nobrowse -quiet -mountpoint "$TMP/mnt"
pkill -x Alero 2>/dev/null || true
rm -rf "/Applications/Alero.app"
cp -R "$TMP/mnt/Alero.app" /Applications/

echo "Listo. Abriendo Alero…"
open "/Applications/Alero.app"
