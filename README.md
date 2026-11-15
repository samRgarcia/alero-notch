# Alero

App para macOS que convierte el notch en un panel: pasa el cursor por el notch y se abre.

## Qué incluye

- **Audio del sistema**: lo que suena en cualquier app (video en el navegador, Spotify, Música, etc.), con anterior, pausa, siguiente y barra de progreso (clic para saltar). Mientras suena, aparece un indicador a los lados del notch. Requiere `cmake` al compilar; sin él solo se muestran Spotify y Música.
- **Batería**: al conectar el cargador, el notch muestra el porcentaje unos segundos. El nivel también aparece dentro del panel.
- **Volumen y brillo**: al cambiarlos, aparece un indicador con el porcentaje junto al notch.
- **Archivos**: arrastra archivos al notch; quedan en una bandeja para abrirlos, arrastrarlos a otra app o enviarlos por AirDrop. La bandeja se conserva al reiniciar.
- **Calendario**: eventos de hoy y mañana, con botón "Unirse" si traen enlace de Meet, Zoom, Teams o Webex.
- **Portapapeles**: los últimos 20 textos copiados; un clic los vuelve a copiar.
- **Monitor de recursos**: uso total de CPU y memoria, y los 8 procesos que más consumen, ordenables por CPU o memoria, con botón para cerrar apps. Solo mide mientras la pestaña está abierta.
- **Ajustes** (icono de la barra de menús): qué pestañas e indicadores mostrar, retraso al abrir, vibración y abrir al iniciar sesión.
- **Notas y temporizador**: una nota rápida que se guarda sola y un temporizador de 5, 15 o 25 minutos.

Funciona también en pantallas sin notch (aparece en el centro de la barra de menús).

## Requisitos

- macOS 14 o posterior
- Xcode 15 o posterior (o las Command Line Tools con Swift 5.9+)
- Para el audio del sistema: `cmake` (`brew install cmake`) y conexión a internet la primera vez

## Compilar y abrir

```bash
cd ~/Development/Alero
chmod +x build-app.sh
./build-app.sh
```

El script compila, crea `build/Alero.app`, la firma localmente y la abre.
Para salir, usa el icono de Alero en la barra de menús.

No uses `swift run`: sin el paquete `.app` macOS no muestra los permisos de calendario y la app se cierra al pedirlos.

## Permisos que pedirá macOS

- **Automatización** (Spotify / Música): para leer la canción y controlar la reproducción.
- **Calendarios**: para listar tus eventos.

Como la firma es local, macOS puede volver a pedir los permisos después de recompilar.

## Crear el instalador (.dmg)

```bash
bash make-dmg.sh
```

Genera `build/Alero-<versión>.dmg`, compilado para Apple silicon e Intel, con la app y un acceso a Aplicaciones.

- **Sin cuenta de desarrollador**: sirve para pruebas. En otros equipos macOS lo bloquea hasta que el usuario lo autoriza en Ajustes del Sistema > Privacidad y seguridad.
- **Para publicar**: firma con Developer ID y notariza. Las instrucciones están al inicio de `make-dmg.sh`.

## Sitio web de descarga

La carpeta `website/` es el sitio completo, listo para subir a cualquier hosting:

| Archivo | Contenido |
| --- | --- |
| `website/index.html` | Página con el botón de descarga y el comando de instalación |
| `website/install.sh` | Script que ejecuta el comando: descarga el `.dmg`, copia la app a Aplicaciones y la abre |
| `website/downloads/Alero.dmg` | El instalador; lo coloca ahí `make-dmg.sh` |

El sitio está configurado para `https://notch.samdev.space`. Sube el contenido de `website/` a la raíz de ese dominio, de modo que queden `https://notch.samdev.space/install.sh` y `https://notch.samdev.space/downloads/Alero.dmg`.

### Subir el proyecto a GitHub

```bash
cd ~/Development/Alero
git init -b main
git add .
git commit -m "Alero: primera versión"
gh repo create alero --public --source=. --push
```

El `.gitignore` deja fuera las carpetas de compilación. El instalador `website/downloads/Alero.dmg` sí se sube, para que el sitio pueda servirlo.

### Publicar en Vercel

```bash
cd website
npx vercel --prod
```

Es un sitio estático: sin framework ni comando de compilación. Después agrega `notch.samdev.space` en Project › Settings › Domains y crea en tu DNS el registro que Vercel indique. `website/vercel.json` hace que `install.sh` se sirva como texto y que las descargas no queden en caché.

## Rendimiento

- Batería, volumen y audio del sistema funcionan por avisos de macOS, sin consultas periódicas.
- El resto se revisa con un temporizador ligero que se pausa cuando la pantalla se apaga.
- Con el panel cerrado no hay animaciones, salvo la onda de audio mientras algo suena. Se puede desactivar en Ajustes, y se desactiva sola con "Reducir movimiento" de macOS.
- La carátula se guarda en tamaño reducido para no gastar GPU ni memoria.

## Estructura

| Archivo | Contenido |
| --- | --- |
| `Sources/Alero/AleroMain.swift` | Arranque de la app e icono de la barra de menús |
| `Sources/Alero/NotchController.swift` | Ventana sobre el notch, detección del cursor, abrir y cerrar |
| `Sources/Alero/Services.swift` | Música (AppleScript), bandeja, calendario (EventKit), temporizador |
| `Sources/Alero/Views.swift` | Interfaz en SwiftUI |
| `Sources/Alero/Extras.swift` | Ajustes, indicadores de volumen y brillo, portapapeles, barra de progreso |
| `Sources/Alero/Monitor.swift` | Monitor de recursos (CPU, memoria y procesos) |
| `Support/Info.plist` | Datos de la app y textos de permisos |
| `Support/AppIcon.icns` | Icono de la app: una aleta de tiburón (`AppIcon.png` es el original a 1024 px) |
| `Support/MenuIcon.png` | La misma aleta para la barra de menús |

## Límites de esta primera versión

- La bandeja guarda referencias a los archivos, no copias.
- El indicador de volumen se suma al de macOS, no lo reemplaza. El de brillo usa un framework privado y solo funciona con la pantalla integrada.
- El monitor no muestra GPU por proceso (macOS no lo ofrece públicamente) y solo puede cerrar apps normales, no procesos del sistema.
- El historial del portapapeles vive en memoria y se borra al cerrar la app.
- El audio del sistema usa el framework privado MediaRemote de Apple a través de [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). Una actualización de macOS puede romperlo; si pasa, Alero vuelve solo al modo Spotify y Música.
- Sin el adaptador, la carátula solo aparece con Spotify.
- Solo usa una pantalla: la que tiene notch, o la principal si no hay.
