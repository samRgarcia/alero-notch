#!/bin/bash
# Alero installer for the Terminal / Instalador de Alero para la Terminal.
# Usage / Uso:  curl -fsSL https://notch.samdev.space/install.sh | bash
#
# What it does: downloads Alero.dmg from GitHub Releases, copies Alero.app to /Applications and opens it.
# It asks for no password and installs nothing else.
# Qué hace: descarga Alero.dmg desde GitHub Releases, copia Alero.app a /Applications y la abre.
# No pide contraseña ni instala nada más.
set -euo pipefail

# The installer comes from the latest GitHub release (override with ALERO_DMG_URL).
# El instalador viene de la última versión publicada en GitHub.
DMG_URL="${ALERO_DMG_URL:-https://github.com/samRgarcia/alero-notch/releases/latest/download/Alero.dmg}"

# Messages in Spanish when the system is in Spanish, English otherwise.
# Mensajes en español si el sistema está en español; en inglés en otro caso.
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    es*) ES=1 ;;
    *) ES=0 ;;
esac
say() {
    if [ "$ES" = "1" ]; then echo "$1"; else echo "$2"; fi
}

if [ "$(uname -s)" != "Darwin" ]; then
    say "Alero solo funciona en macOS." "Alero only runs on macOS." >&2
    exit 1
fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
    say "Alero necesita macOS 14 o posterior (tienes $(sw_vers -productVersion))." \
        "Alero needs macOS 14 or later (you have $(sw_vers -productVersion))." >&2
    exit 1
fi

TMP="$(mktemp -d)"
cleanup() {
    hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

say "Descargando Alero…" "Downloading Alero…"
curl -fL --progress-bar "$DMG_URL" -o "$TMP/Alero.dmg"

say "Instalando en /Applications…" "Installing to /Applications…"
mkdir "$TMP/mnt"
hdiutil attach "$TMP/Alero.dmg" -nobrowse -quiet -mountpoint "$TMP/mnt"
pkill -x Alero 2>/dev/null || true
rm -rf "/Applications/Alero.app"
cp -R "$TMP/mnt/Alero.app" /Applications/

say "Listo. Abriendo Alero…" "Done. Opening Alero…"
open "/Applications/Alero.app"
