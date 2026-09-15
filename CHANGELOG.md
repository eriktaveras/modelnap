# Changelog

Todos los cambios notables de ModelNap (antes «Interruptor Ollama»). El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones, [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

## [1.2.1] — 2026-09-15

### Cambiado
- **Proyecto open source** bajo licencia MIT; el nombre y el logo quedan reservados (`TRADEMARKS.md`).
- **Logo propio** (un modelo durmiendo la siesta) en el ícono de la app, la cabecera, la barra de menús y el
  instalador. Sustituye al cerebro de SF Symbols, cuya licencia no permite usarlo como ícono de app ni logo.

### Añadido
- Archivos del logo para la web en `docs/logo` (SVG, PNG, favicon).
- Capturas en inglés del panel oscuro y de los ajustes.
- `CONTRIBUTING.md`, `SECURITY.md`, plantillas de issues y PR, y compilación con pruebas en GitHub Actions.

## [1.2.0] — 2026-09-15

### Cambiado
- **Nuevo nombre: ModelNap.** Web en [modelnap.com](https://modelnap.com). Identificador
  `com.taverassolutions.modelnap`: los ajustes de «Interruptor Ollama» no se heredan.
- *Acerca de* e instalador con el nuevo lema: «Deja dormir a tus modelos locales y recupera la memoria del Mac».

### Añadido
- Modo `--snapshot … demo` e imágenes del README generadas con `docs/generate-images.sh`.

### Corregido
- La línea «sin uso · se libera en…» del modelo cargado ya no se corta.

## [1.1.0] — 2026-09-14

### Añadido
- Liberación automática de la memoria tras 5, 15, 30 o 60 minutos sin uso, midiendo la CPU de los procesos
  `ollama runner`. Ollama sigue encendido y recarga el modelo con el siguiente mensaje.
- Atajo global **⌥⌘O** para encender o apagar Ollama.
- Tarjeta *Memoria del Mac*: RAM usada, parte del modelo y presión de memoria del sistema.
- Ajustes dentro del panel: liberación sin uso, atajo, inicio de sesión e idioma.
- Interfaz en inglés y selector de idioma (automático, español, inglés).
- Modos de terminal `--memory` e `--idle-test`.

### Cambiado
- Vuelve la identidad visual verde de la primera versión.

## [1.0.0] — 2026-09-14

### Añadido
- App de barra de menús para encender y apagar Ollama.
- Detección del mecanismo de arranque: Ollama.app, `brew services`, LaunchAgent propio u `ollama serve`.
- Modelo en memoria con *Liberar* y lista de modelos instalados con *Cargar*.
- Binario universal, instalador `.dmg` firmado con Developer ID y notarizado por Apple.

[Sin publicar]: https://github.com/eriktaveras/modelnap/compare/v1.2.1...main
[1.2.1]: https://github.com/eriktaveras/modelnap/releases/tag/v1.2.1
[1.2.0]: https://github.com/eriktaveras/modelnap/releases/tag/v1.2.0
[1.1.0]: https://github.com/eriktaveras/modelnap/releases/tag/v1.1.0
[1.0.0]: https://github.com/eriktaveras/modelnap/releases/tag/v1.0.0
