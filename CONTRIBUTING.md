# Contributing to ModelNap

Thanks for wanting to help! ModelNap is a small project maintained by one person, so contributions are reviewed
as time allows.

> 🇪🇸 **¿Hablas español?** Puedes abrir issues y PRs en español sin problema. Lee también el
> [README en español](README.es.md).

## Where help matters most right now

- **Testing with Ollama.app** (the official app from ollama.com). It's the most common setup and still unverified.
  If you use it, open an issue with the bug template and tell us whether turning Ollama on and off works.
- **Intel Macs** and macOS versions between 14 and 26.
- **Translations**: copy `Resources/en.lproj` to `Resources/<language>.lproj` and translate the values (not the keys).
- **Other engines** (LM Studio, MLX, llama.cpp): open an issue first so we can agree on the approach.

## Before opening a PR

1. Open an issue first if the change isn't small, so you don't work on something that won't fit.
2. Build and run the tests:
   ```bash
   ./build.sh --test
   ./build.sh
   ```
3. If you touch the UI, attach light and dark screenshots:
   ```bash
   B="build/ModelNap.app/Contents/MacOS/ModelNap"
   "$B" --snapshot panel.png light demo
   "$B" --snapshot panel-dark.png dark demo
   ```
4. If you add or change user-facing text, use `tr("…")` with the Spanish sentence as the key and add the English
   translation to `Resources/en.lproj/Localizable.strings`.
5. Add your change to the "Unreleased" section of `CHANGELOG.md`.

## Style

- Swift with no external dependencies; AppKit + SwiftUI built with `swiftc` (no Xcode project).
- Code comments are in Spanish, like the rest of the codebase. Comments in English are fine in your PR.
- No telemetry and no connections other than Ollama's local API.
- The name and logo are reserved (see [TRADEMARKS.md](TRADEMARKS.md)); PRs don't need to touch them.

By contributing, you agree that your code is released under the [MIT License](LICENSE).
