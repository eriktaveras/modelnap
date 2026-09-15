# Contribuir a ModelNap

¡Gracias por querer ayudar! ModelNap es un proyecto pequeño que mantiene una sola persona, así que las
contribuciones se revisan cuando hay tiempo. *English speakers: issues and PRs in English are welcome too.*

## Dónde ayuda más ahora mismo

- **Probar con Ollama.app** (la app oficial de ollama.com). Es el caso más común y todavía no está verificado.
  Si lo usas, abre un issue con la plantilla de fallo contando si encender y apagar funciona.
- **Macs Intel** y versiones de macOS entre la 14 y la 26.
- **Traducciones**: copia `Resources/en.lproj` a `Resources/<idioma>.lproj` y traduce los valores (no las claves).
- **Otros motores** (LM Studio, MLX, llama.cpp): abre primero un issue para acordar el enfoque.

## Antes de abrir un PR

1. Abre un issue si el cambio no es pequeño, para no trabajar en algo que no encaje.
2. Compila y pasa las pruebas:
   ```bash
   ./build.sh --test
   ./build.sh
   ```
3. Si tocas la interfaz, adjunta capturas en claro y oscuro:
   ```bash
   B="build/ModelNap.app/Contents/MacOS/ModelNap"
   "$B" --snapshot panel.png light demo
   "$B" --snapshot panel-dark.png dark demo
   ```
4. Si añades o cambias textos, usa `tr("…")` con la frase en español como clave y añade la traducción en
   `Resources/en.lproj/Localizable.strings`.
5. Añade tu cambio a la sección «Sin publicar» de `CHANGELOG.md`.

## Estilo

- Swift sin dependencias externas; AppKit + SwiftUI compilados con `swiftc` (sin proyecto de Xcode).
- Comentarios y textos en español, como el resto del código.
- Nada de telemetría ni conexiones fuera de la API local de Ollama.
- El logo y el nombre están reservados (ver [TRADEMARKS.md](TRADEMARKS.md)); no hace falta tocarlos en un PR.

Al contribuir aceptas que tu código se publique bajo la [licencia MIT](LICENSE).
