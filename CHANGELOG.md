# Changelog

Todos los cambios notables de Interruptor Ollama. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones, [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

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

[Sin publicar]: https://github.com/eriktaveras/interruptor-ollama/compare/v1.1.0...main
[1.1.0]: https://github.com/eriktaveras/interruptor-ollama/releases/tag/v1.1.0
[1.0.0]: https://github.com/eriktaveras/interruptor-ollama/releases/tag/v1.0.0
