# Alero

**English** · [Español](#español)

Alero turns your Mac's notch into a panel: hover over the notch and it opens.

Website: https://notch.samdev.space

## Install

```bash
curl -fsSL https://notch.samdev.space/install.sh | bash
```

Or download `Alero.dmg` from the website and drag the app into Applications. Alero is free.

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

Creates `build/Alero-<version>.dmg` for Apple silicon and Intel and copies it to `website/downloads/Alero.dmg`. Without a paid Apple developer account the installer is unsigned: macOS blocks it on other Macs until the user allows it in System Settings › Privacy & Security. Instructions for signing and notarizing are at the top of `make-dmg.sh`.

## Website

The `website/` folder is the full site (`index.html`, `install.sh`, `downloads/Alero.dmg`), in English and Spanish. To publish it on Vercel:

```bash
cd website
npx vercel --prod
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

O descarga `Alero.dmg` desde el sitio y arrastra la app a Aplicaciones. Alero es gratis.

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

Genera `build/Alero-<versión>.dmg` para Apple silicon e Intel y lo copia a `website/downloads/Alero.dmg`. Sin una cuenta de desarrollador de Apple de pago el instalador va sin firma: macOS lo bloquea en otros equipos hasta que el usuario lo autoriza en Ajustes del Sistema › Privacidad y seguridad. Las instrucciones para firmar y notarizar están al inicio de `make-dmg.sh`.

### Sitio web

La carpeta `website/` es el sitio completo (`index.html`, `install.sh`, `downloads/Alero.dmg`), en inglés y español. Para publicarlo en Vercel:

```bash
cd website
npx vercel --prod
```

### Límites

- El audio del sistema usa el framework privado MediaRemote de Apple a través de [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). Una actualización de macOS puede romperlo; si pasa, Alero vuelve al modo Spotify y Música.
- El indicador de brillo usa un framework privado y solo funciona con la pantalla integrada.
- El indicador de volumen se suma al de macOS; no lo reemplaza.
- El monitor de recursos no muestra GPU por proceso y solo puede cerrar apps normales.
- El historial del portapapeles vive en memoria y se borra al cerrar la app.
