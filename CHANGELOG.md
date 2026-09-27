# Changelog

All notable changes to ModelNap (formerly "Interruptor Ollama"). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [1.3.0] — 2026-09-27

### Changed
- README in English, with the Spanish version in `README.es.md`. `CONTRIBUTING.md`, `SECURITY.md`, issue and PR
  templates and this changelog are now in English, with Spanish notes.

### Added
- English hero and menu bar images for the README.
- **Splash (Inco AI) support.** A Splash card in the panel turns `splash serve` on and off, picks the model, shows
  its real memory (from `/status`, since its weights are file-mapped and don't show up as app memory) and adds
  them to the memory bar. Turning Splash on unloads Ollama's models first. Idle release applies too: Splash
  can't drop its model without quitting, so it's stopped. Startup errors are explained (e.g. how much free
  memory it needs versus how much there is). Terminal: `ModelNap --splash status | on [model] | off | idle-test N`.

- **Reorganized settings** in three sections: Ollama, Splash and General. Each engine has its own idle timer
  (Splash defaults to never, since it doesn't come back on its own), a "Start with" picker chooses between
  Ollama.app and a LaunchAgent when both are installed, Splash gets "Unload Ollama first" and a model picker,
  and there are log links for both engines.

### Fixed
- Ollama.app 0.34 refuses a quit request from another app ("User canceled"), so turning it off took 10 s and
  ended in a force quit. It now gets SIGTERM after 2 s and closes cleanly with its server (~2.3 s in total).
- With both Ollama.app and a LaunchAgent installed, turning Ollama on while it was off picked Ollama.app. The
  last mechanism that was running is now remembered across launches.

## [1.2.1] — 2026-09-15

### Changed
- **Open source** under the MIT License; the name and logo stay reserved (`TRADEMARKS.md`).
- **Original logo** (a model taking a nap) in the app icon, header, menu bar and installer. It replaces the
  SF Symbols brain, whose license doesn't allow using it as an app icon or logo.

### Added
- Logo assets for the web in `docs/logo` (SVG, PNG, favicon).
- English screenshots of the dark panel and the settings.
- `CONTRIBUTING.md`, `SECURITY.md`, issue and PR templates, and build + tests on GitHub Actions.

## [1.2.0] — 2026-09-15

### Changed
- **New name: ModelNap.** Website at [modelnap.com](https://modelnap.com). Bundle identifier
  `com.taverassolutions.modelnap`: settings from "Interruptor Ollama" don't carry over.
- *About* and installer with the new tagline.

### Added
- `--snapshot … demo` mode and README images generated with `docs/generate-images.sh`.

### Fixed
- The loaded model's "idle · frees in…" line no longer gets cut off.

## [1.1.0] — 2026-09-14

### Added
- Automatic memory release after 5, 15, 30 or 60 minutes idle, measured from the CPU time of the `ollama runner`
  processes. Ollama stays on and reloads the model with the next message.
- Global **⌥⌘O** shortcut to turn Ollama on or off.
- *Mac memory* card: RAM in use, the model's share and system memory pressure.
- Settings inside the panel: idle release, shortcut, open at login and language.
- English interface and language picker (automatic, Spanish, English).
- `--memory` and `--idle-test` command-line modes.

### Changed
- Back to the green visual identity of the first version.

## [1.0.0] — 2026-09-14

### Added
- Menu bar app to turn Ollama on and off.
- Start-mechanism detection: Ollama.app, `brew services`, custom LaunchAgent or `ollama serve`.
- Loaded model with *Free* and installed models list with *Load*.
- Universal binary and `.dmg` installer signed with a Developer ID and notarized by Apple.

[Unreleased]: https://github.com/eriktaveras/modelnap/compare/v1.3.0...main
[1.3.0]: https://github.com/eriktaveras/modelnap/releases/tag/v1.3.0
[1.2.1]: https://github.com/eriktaveras/modelnap/releases/tag/v1.2.1
[1.2.0]: https://github.com/eriktaveras/modelnap/tree/v1.2.0
[1.1.0]: https://github.com/eriktaveras/modelnap/tree/v1.1.0
[1.0.0]: https://github.com/eriktaveras/modelnap/tree/v1.0.0
