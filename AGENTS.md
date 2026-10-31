# AGENTS.md · modelnap

ModelNap es una app nativa de barra de menús para macOS 14+ que enciende y apaga Ollama (y Splash) detectando cómo está instalado. También descarga de la RAM los modelos LLM locales que llevan un rato sin usarse y muestra la memoria del Mac. Se distribuye como binario universal firmado y notarizado.

## Stack

Swift 5 (compilado con swiftc de Swift 6.3 / Xcode 26) con AppKit, SwiftUI, ServiceManagement y Carbon; no tiene proyecto de Xcode ni dependencias externas. Usa scripts bash para compilar y empaquetar

## Comandos

- Tests: `./build.sh --test`
- Build: `./build.sh`

## Verificación

Este proyecto no se compila ni se prueba en la máquina de los agentes (En esta máquina no se puede compilar ni probar. Es una app solo para macOS: incluso el banco de pruebas (./build.sh --test) compila Ollama.swift y Splash.swift, que importan AppKit, y la build usa lipo, iconutil, codesign y targets *-apple-macos. En Linux no hay Xcode, ni toolchain de Swift con esos frameworks, ni esas herramientas. Lo verifica el CI de GitHub (.github/workflows/build.yml en macos-latest): ejecuta ./build.sh --test y ./build.sh, y luego comprueba el bundle con lipo -archs y code): lo verifica el CI de GitHub. No afirmes haberlo probado.

## Notas para agentes

El código está en Sources/*.swift, que se compila todo junto con swiftc (no hay Package.swift ni .xcodeproj). Si añades un archivo que necesiten las pruebas, inclúyelo en la lista de swiftc de la rama --test de build.sh. Las pruebas están en Tests/main.swift: es un ejecutable propio, no XCTest, y cubre IdleTracker y SplashActivity. Los comentarios del código van en español. Los textos visibles para el usuario usan tr("…") con la frase en español como clave; añade la traducción a Resources/en.lproj/Localizable.strings. Anota cada cambio en la sección Unreleased de CHANGELOG.md. No añadas telemetría, dependencias externas ni conexiones distintas de la API local de Ollama/Splash. No toques el nombre, el logo (Sources/Logo.swift, docs/logo), el bundle id ni TRADEMARKS.md. La versión está en VERSION. Las imágenes de docs/ se regeneran con docs/generate-images.sh, que solo funciona en macOS.

---
Propuesto por el Taller de hermes-web a partir de su reconocimiento del repo; revísalo antes de fusionar.
