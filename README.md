# Interruptor Ollama

App de la barra de menús de macOS para **encender y apagar Ollama** y ver qué modelo ocupa la memoria.
Hecha por [Taveras Solutions](https://taverassolutions.com). Proyecto independiente, no afiliado a Ollama.

- macOS 14 o superior · Apple Silicon e Intel (binario universal)
- Instalador: `dist/Interruptor-Ollama-<versión>.dmg`

## Cómo se usa

- **Clic en el cerebro** de la barra de menús: se abre el panel.
  - **Botón de encendido**: apaga o enciende Ollama.
  - **Memoria del Mac**: cuánta RAM usa el Mac (mismo cálculo que el Monitor de Actividad), qué parte es el
    modelo, la presión de memoria del sistema y *Liberar* para sacar el modelo sin apagar Ollama.
  - **Modelos instalados**: pasa el ratón por encima y pulsa *Cargar*.
- **⌥⌘O** desde cualquier app enciende o apaga Ollama (se desactiva en Ajustes). Si otra app usa la misma
  combinación, macOS no avisa y no se sabe cuál de las dos la recibe.
- **Ajustes** (engranaje):
  - **Liberar memoria sin uso**: nunca, 5, 15, 30 o 60 min. Si el modelo no genera nada en ese tiempo se
    descarga; Ollama sigue encendido y lo recarga con el siguiente mensaje.
  - Atajo de teclado, abrir al iniciar sesión e idioma (automático, español o inglés).
- **Clic derecho**: encender/apagar, ver el log, abrir al iniciar sesión, *Acerca de*, salir.
- **Punto del ícono**: verde = encendido, ámbar parpadeando = arrancando o apagando, sin punto = apagado.

### Cómo detecta que un modelo está «sin uso»

Ollama no expone la hora de la última petición. Cada modelo cargado corre en un proceso `ollama runner` que
solo gasta CPU mientras trabaja: medido con gemma4 26B, 0,06 s de CPU en 30 s de reposo frente a 0,99 s al
generar 104 tokens. La app suma la CPU de los runners cada 2,5 s; si sube más de 0,08 s, o cambia el modelo
cargado, cuenta como uso. La lógica está en `IdleTracker` (`Sources/Activity.swift`) y tiene pruebas.

## Cómo sabe apagar Ollama

Cada Mac lo arranca distinto, y matar el proceso no siempre sirve (un LaunchAgent con `KeepAlive` lo relanza).
La app detecta el mecanismo y lo apaga por ese mismo camino:

| Si Ollama viene de… | Apagar | Encender |
|---|---|---|
| **Ollama.app** (ollama.com) | cierra la app | abre la app |
| **`brew services`** o un LaunchAgent propio con `ollama serve` | `launchctl bootout` | `launchctl bootstrap` |
| **`ollama serve`** lanzado a mano | `SIGTERM` al servidor | lanza `ollama serve` (log en `~/Library/Logs/Interruptor Ollama`) |

Si Ollama no está instalado, el botón lleva a ollama.com/download.

## Firma

La app y el instalador van firmados con **Developer ID Application: Erik Manuel Taveras Tavarez (794R79NU32)**
y notarizados por Apple, así que abren sin avisos de Gatekeeper.

## Terminal

```bash
B="/Applications/Interruptor Ollama.app/Contents/MacOS/InterruptorOllama"
"$B" --status | --on | --off
"$B" --memory                            # memoria del Mac y CPU de los runners
"$B" --idle-test 20                      # prueba la liberación automática con 20 s de límite
"$B" --snapshot panel.png [dark|light] [settings] [-AppleLanguages "(en)"]
```

## Compilar

```bash
./build.sh            # app en ./build
./build.sh --test     # pruebas de IdleTracker
./build.sh --install  # copia a ~/Applications y la relanza
./package.sh          # instalador dist/Interruptor-Ollama-<VERSION>.dmg (+ .sha256)
```

`package.sh` usa [dmgbuild](https://github.com/dmgbuild/dmgbuild) vía `uvx`. Para la versión que se comparte:

```bash
DEVELOPER_ID="Developer ID Application: Erik Manuel Taveras Tavarez (794R79NU32)" \
NOTARY_PROFILE=taveras-notary ./package.sh
```

Firma con runtime endurecido, notariza la app y el dmg, y grapa los dos tickets. Sin esas variables sale una
build ad-hoc solo para pruebas locales. El perfil `taveras-notary` vive en el llavero
(`xcrun notarytool store-credentials`).

Traducciones en `Resources/<idioma>.lproj/Localizable.strings`; la clave es el texto en español.
