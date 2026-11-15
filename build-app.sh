#!/bin/bash
# Compila Alero y arma Alero.app (necesario para los permisos de calendario y música).
#
# Variables opcionales:
#   UNIVERSAL=1   compila para Apple silicon e Intel a la vez (para distribuir)
#   SIGN_ID="Developer ID Application: Tu Nombre (TEAMID)"   firma para distribuir
#   NO_OPEN=1     no abre la app al terminar
set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="${SIGN_ID:--}"
ARCH_FLAGS=""
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
fi

# shellcheck disable=SC2086
swift build -c release $ARCH_FLAGS
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c release $ARCH_FLAGS --show-bin-path)"

APP="build/Alero.app"
RES="$APP/Contents/Resources"
mkdir -p "$APP/Contents/MacOS" "$RES"
cp -f "$BIN_DIR/Alero" "$APP/Contents/MacOS/Alero"
cp -f Support/Info.plist "$APP/Contents/Info.plist"
cp -f Support/AppIcon.icns "$RES/AppIcon.icns"
cp -f Support/MenuIcon.png "$RES/MenuIcon.png"
# Textos de permisos en inglés y español.
for LANG_DIR in en.lproj es.lproj; do
    mkdir -p "$RES/$LANG_DIR"
    cp -f "Support/$LANG_DIR/InfoPlist.strings" "$RES/$LANG_DIR/InfoPlist.strings"
done

# Firma local ("-") para uso propio, o con Developer ID para distribuir.
sign() {
    if [ "$SIGN_ID" = "-" ]; then
        codesign --force --sign - "$1"
    else
        codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
            --entitlements Support/Alero.entitlements "$1"
    fi
}

# Adaptador de MediaRemote: permite leer el audio de cualquier app (navegador, video, etc.).
# Es opcional. Sin él, Alero solo muestra Spotify y Música.
ADAPTER=".deps/mediaremote-adapter"
build_adapter() {
    command -v cmake >/dev/null 2>&1 || return 1
    command -v git >/dev/null 2>&1 || return 1
    if [ ! -d "$ADAPTER" ]; then
        git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git "$ADAPTER" || return 1
    fi
    cmake -S "$ADAPTER" -B "$ADAPTER/build" -DCMAKE_BUILD_TYPE=Release >/dev/null || return 1
    cmake --build "$ADAPTER/build" >/dev/null || return 1
    [ -d "$ADAPTER/build/MediaRemoteAdapter.framework" ] || return 1
    rm -rf "$RES/MediaRemoteAdapter.framework"
    cp -R "$ADAPTER/build/MediaRemoteAdapter.framework" "$RES/"
    cp -f "$ADAPTER/bin/mediaremote-adapter.pl" "$RES/"
    sign "$RES/MediaRemoteAdapter.framework"
}

if build_adapter; then
    echo "Audio del sistema: activado."
else
    echo "Aviso: no se pudo preparar el audio del sistema (falta cmake o falló la compilación)."
    echo "       Instala cmake con 'brew install cmake' y vuelve a ejecutar este script."
    echo "       Mientras tanto, Alero mostrará solo Spotify y Música."
fi

sign "$APP"
# Avisa a Finder de que la app cambió, para que muestre el icono nuevo.
touch "$APP"

echo "Listo: $APP"
if [ "${NO_OPEN:-0}" != "1" ]; then
    # Cierra la versión anterior, si está abierta, y abre la nueva.
    pkill -x Alero 2>/dev/null || true
    sleep 0.5
    open "$APP"
fi
