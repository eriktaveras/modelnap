# Interruptor Ollama

App de la barra de menús de macOS para **encender y apagar Ollama** y ver qué modelo ocupa la memoria.
Hecha por [Taveras Solutions](https://taverassolutions.com). Proyecto independiente, no afiliado a Ollama.

- macOS 14 o superior · Apple Silicon e Intel (binario universal)
- Instalador: `dist/Interruptor-Ollama-<versión>.dmg`

## Cómo se usa

- **Clic en el cerebro** de la barra de menús: se abre el panel.
  - **Botón de encendido**: apaga o enciende Ollama.
  - **Memoria**: el modelo cargado y cuánto ocupa de la RAM, con *Liberar* para sacarlo sin apagar.
  - **Modelos instalados**: pasa el ratón por encima y pulsa *Cargar*.
- **Clic derecho**: encender/apagar, ver el log, abrir al iniciar sesión, *Acerca de*, salir.
- **Cuadrado del ícono**: teal = encendido, naranja parpadeando = arrancando o apagando, sin cuadrado = apagado.

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
"$B" --snapshot panel.png [dark|light]   # captura del panel sin abrir la barra
```

## Compilar

```bash
./build.sh            # app en ./build
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

Tipografías: Instrument Serif, DM Sans y JetBrains Mono (SIL Open Font License, en `Resources/Fonts`).
