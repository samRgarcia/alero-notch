# Alero

**English** · [Español](#español)

Alero turns your Mac's notch into a panel: hover over the notch and it opens.

Website: https://notch.samdev.space

## Install

```bash
curl -fsSL https://notch.samdev.space/install.sh | bash
```

Or download `Alero.dmg` from the [latest release](https://github.com/samRgarcia/alero-notch/releases/latest) and drag the app into Applications. Alero is free.

## Features

- **System audio**: what's playing in any app (browser video, Spotify, Music), with previous, pause, next and a progress bar. While something plays, an indicator shows next to the notch.
- **Battery, volume and brightness**: a small indicator with the percentage when you plug in the charger or change the volume or brightness.
- **File tray**: drag files onto the notch to keep them handy, open them, drag them into another app or send them with AirDrop.
- **Calendar**: today's and tomorrow's events, with a "Join" button for Meet, Zoom, Teams or Webex links.
- **Notes and timer**: a quick note that saves itself and a 5, 15 or 25 minute timer.
- **Clipboard**: the last 20 texts you copied; one click copies them again.
- **Resource monitor**: total CPU and memory usage and the top 8 processes, sortable by CPU or memory.
- **Settings** (menu bar icon): which tabs and indicators to show, open delay, haptics and open at login.

The app follows the system language: Spanish when macOS is in Spanish, English otherwise. It also works on displays without a notch.

## Requirements

- macOS 14 or later, Apple silicon or Intel
- To build: Xcode 15 or later (or the Command Line Tools with Swift 5.9+)
- For system audio: `cmake` (`brew install cmake`) and an internet connection the first time

## Build and run

```bash
bash build-app.sh
```

The script builds the app, creates `build/Alero.app`, signs it locally and opens it. Quit from the Alero icon in the menu bar. Don't use `swift run`: without the `.app` bundle macOS can't show the permission prompts.

macOS will ask for two permissions: **Automation** (Spotify / Music) and **Calendars**.

## Create the installer

```bash
bash make-dmg.sh
```

Creates `build/Alero-<version>.dmg` for Apple silicon and Intel. Without a paid Apple developer account the installer is unsigned: macOS blocks it on other Macs until the user allows it in System Settings › Privacy & Security. Instructions for signing and notarizing are at the top of `make-dmg.sh`.

## Publish a release

```bash
bash release.sh
```

Builds the installer and publishes it to [GitHub Releases](https://github.com/samRgarcia/alero-notch/releases) under the version in `Support/Info.plist` (for example `v0.1.0`). The website and `install.sh` always download `Alero.dmg` from the latest release, so publishing a release is all it takes to ship an update. To release a new version, raise `CFBundleShortVersionString` in `Support/Info.plist`, commit, push and run the script again. Needs the GitHub CLI (`brew install gh`, then `gh auth login`).

## Website

The `website/` folder is the full site (`index.html`, `install.sh`, the feature video), in English and Spanish. Downloads come from GitHub Releases. To publish it on Vercel:

```bash
cd website
npx vercel --prod
```

## Feature video

The 30-second video on the website is a [HyperFrames](https://github.com/heygen-com/hyperframes) composition in `video/`. To render it again after editing `video/gen.py`:

```bash
cd video
python3 gen.py
npx hyperframes render -o ../website/media/alero-features.mp4
```

## Project layout

| File | Contents |
| --- | --- |
| `Sources/Alero/AleroMain.swift` | App start-up and menu bar icon |
| `Sources/Alero/NotchController.swift` | Window over the notch, hover detection, open and close |
| `Sources/Alero/Services.swift` | Audio, battery, file tray, calendar, timer |
| `Sources/Alero/Extras.swift` | Settings, volume and brightness indicators, clipboard, progress bar |
| `Sources/Alero/Monitor.swift` | Resource monitor |
| `Sources/Alero/Views.swift` | SwiftUI interface |
| `Sources/Alero/Strings.swift` | Spanish / English text selection |
| `Support/` | Info.plist, permission texts in both languages, icons |

## Limitations

- System audio uses Apple's private MediaRemote framework through [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). A macOS update may break it; if so, Alero falls back to Spotify and Music only.
- The brightness indicator uses a private framework and only works with the built-in display.
- The volume indicator is shown in addition to the macOS one; it doesn't replace it.
- The resource monitor shows no per-process GPU usage and can only quit regular apps.
- Clipboard history lives in memory and is cleared when the app quits.

---

## Español

[English](#alero) · **Español**

Alero convierte el notch de tu Mac en un panel: pasa el cursor por el notch y se abre.

Sitio web: https://notch.samdev.space

### Instalar

```bash
curl -fsSL https://notch.samdev.space/install.sh | bash
```

O descarga `Alero.dmg` desde la [última versión](https://github.com/samRgarcia/alero-notch/releases/latest) y arrastra la app a Aplicaciones. Alero es gratis.

### Funciones

- **Audio del sistema**: lo que suena en cualquier app (video en el navegador, Spotify, Música), con anterior, pausa, siguiente y barra de progreso. Mientras suena, aparece un indicador junto al notch.
- **Batería, volumen y brillo**: un indicador con el porcentaje al conectar el cargador o al cambiar el volumen o el brillo.
- **Bandeja de archivos**: arrastra archivos al notch para tenerlos a la mano, abrirlos, arrastrarlos a otra app o enviarlos por AirDrop.
- **Calendario**: eventos de hoy y mañana, con botón "Unirse" para enlaces de Meet, Zoom, Teams o Webex.
- **Notas y temporizador**: una nota rápida que se guarda sola y un temporizador de 5, 15 o 25 minutos.
- **Portapapeles**: los últimos 20 textos copiados; un clic los vuelve a copiar.
- **Monitor de recursos**: uso total de CPU y memoria y los 8 procesos que más consumen, ordenables por CPU o memoria.
- **Ajustes** (icono de la barra de menús): qué pestañas e indicadores mostrar, retraso al abrir, vibración y abrir al iniciar sesión.

La app sigue el idioma del sistema: español si macOS está en español, inglés en cualquier otro caso. También funciona en pantallas sin notch.

### Requisitos

- macOS 14 o posterior, Apple silicon o Intel
- Para compilar: Xcode 15 o posterior (o las Command Line Tools con Swift 5.9+)
- Para el audio del sistema: `cmake` (`brew install cmake`) y conexión a internet la primera vez

### Compilar y abrir

```bash
bash build-app.sh
```

El script compila, crea `build/Alero.app`, la firma localmente y la abre. Para salir, usa el icono de Alero en la barra de menús. No uses `swift run`: sin el paquete `.app` macOS no puede mostrar los avisos de permisos.

macOS pedirá dos permisos: **Automatización** (Spotify / Música) y **Calendarios**.

### Crear el instalador

```bash
bash make-dmg.sh
```

Genera `build/Alero-<versión>.dmg` para Apple silicon e Intel. Sin una cuenta de desarrollador de Apple de pago el instalador va sin firma: macOS lo bloquea en otros equipos hasta que el usuario lo autoriza en Ajustes del Sistema › Privacidad y seguridad. Las instrucciones para firmar y notarizar están al inicio de `make-dmg.sh`.

### Publicar una versión

```bash
bash release.sh
```

Genera el instalador y lo publica en [GitHub Releases](https://github.com/samRgarcia/alero-notch/releases) con la versión de `Support/Info.plist` (por ejemplo `v0.1.0`). El sitio y `install.sh` descargan siempre `Alero.dmg` de la última versión, así que publicar una versión basta para distribuir una actualización. Para sacar una versión nueva, sube `CFBundleShortVersionString` en `Support/Info.plist`, haz commit y push, y vuelve a ejecutar el script. Necesita la herramienta de GitHub (`brew install gh` y luego `gh auth login`).

### Sitio web

La carpeta `website/` es el sitio completo (`index.html`, `install.sh`, el video de funciones), en inglés y español. Las descargas vienen de GitHub Releases. Para publicarlo en Vercel:

```bash
cd website
npx vercel --prod
```

### Video de funciones

El video de 30 segundos del sitio es una composición de [HyperFrames](https://github.com/heygen-com/hyperframes) en `video/`. Para volver a generarlo después de editar `video/gen.py`:

```bash
cd video
python3 gen.py
npx hyperframes render -o ../website/media/alero-features.mp4
```

### Límites

- El audio del sistema usa el framework privado MediaRemote de Apple a través de [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). Una actualización de macOS puede romperlo; si pasa, Alero vuelve al modo Spotify y Música.
- El indicador de brillo usa un framework privado y solo funciona con la pantalla integrada.
- El indicador de volumen se suma al de macOS; no lo reemplaza.
- El monitor de recursos no muestra GPU por proceso y solo puede cerrar apps normales.
- El historial del portapapeles vive en memoria y se borra al cerrar la app.
