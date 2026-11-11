# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OmaLauncher++ Desktop: a **service plugin of the Omarchy shell** (Quickshell, Omarchy 4.5+) that draws OWL widgets (`.owl` files in `~/.config/omarchy-widgets`) on the desktop, over the wallpaper and under the windows. There is no build step: the repository root *is* the plugin folder. The shell reads `manifest.json`, creates `Service.qml` as an `Item` in its own process, and hands it `shell` and `manifest`.

Its look and behavior deliberately follow the phone launcher OmaLauncher++ (grid, names, defaults, wording). Comments cite the Kotlin file each piece mirrors; keep that parity when changing settings or UI text.

## Commands

```sh
node test/layout.test.mjs      # Layout.js
node test/store.test.mjs       # Store.js
bash test/plugin.test.sh       # manifest, folder rules, bin/owl-desktop in a throwaway HOME
omarchy plugin validate .
shellcheck --severity=warning bin/owl-desktop test/plugin.test.sh

# qmllint, exactly as CI runs it (needs Omarchy's quickshell for the QML types)
/usr/lib/qt6/bin/qmllint --max-warnings 0 --json lint.json \
  --block-scope-var-declaration disable --uncreatable-type disable *.qml
```

The node tests are one file each with an inline `test(name, fn)` helper and no runner, so there is no single-test filter: run the file. They load `Layout.js`/`Store.js` by stripping the `.pragma library` line and evaluating the rest, which is why each of those files ends with a guarded `module.exports`. A function added to `Layout.js` must also be added to that export list to be testable.

### Trying a change live

The shell only loads plugins from `~/.config/omarchy/plugins/io.github.johannso.owl-desktop` and **refuses symlinks**, so copy or clone the checkout there (don't link it), then `omarchy plugin enable io.github.johannso.owl-desktop`. Saved changes reload by themselves; `bin/owl-desktop logs` shows the shell's log. After `omarchy plugin update`, `omarchy-restart-shell` is needed because the shell keeps running already-loaded code.

## Architecture

**`Service.qml` is the hub.** Every other QML file receives it as `app` and reads state from it. It owns:

- places (config/state dirs, the widget folder: `$OWL_WIDGETS`, else `style.toml`'s `folder`, else the default)
- the style (`Style.js` parses `~/.config/owl-desktop/style.toml`; the file is watched and written from `Style.js`'s `TEMPLATE` on first start)
- the theme palette and font, read from Omarchy's current theme, and Hyprland's `decoration:rounding` → `corner`/`cornerScale`
- the folder scan (`files`), kept fresh by `inotifywait` or a 2 s poll
- the layout (`~/.local/state/owl-desktop/layout.json`), changed only through `saveScreen()`
- the `OwlHost` instance, which overrides the runtime's actions with Omarchy's way of doing them (terminal, `ask()`, `launcher()`, MPRIS `media()`, `dnd()`)
- `run()` / `widgets()`: the only way anything spawns a process; `widgets()` calls `bin/omarchy-widgets`
- the `IpcHandler` with target `owl-desktop`

**Per monitor**, a `Variants` over `Quickshell.screens` creates a `Desktop.qml` scope holding three layer surfaces: `DesktopWindow` (Bottom layer: grid, tiles, arranging, input, pause-when-covered), `ScreenWindow` (Overlay: a widget's `screen { }`), and `StoreWindow` (the store panel). `Tile.qml` is one framed widget wrapping the runtime's `OwlWidget`.

**Pure logic lives in `.pragma library` JS, not QML**, so it runs under node:

- `Layout.js`: cells per monitor as `{ file: { x, y, w, h, hidden?, opacity?, border? } }` (faces are `{ face: true }`). Every function returns a new map, or `null` when the change doesn't fit; tiles never overlap or leave the grid. Callers must handle `null`.
- `Store.js`: catalog parsing, version comparison, install records.
- `Style.js`: `DEFAULTS`, `KEYS` (toml name → property, range), `parse`, `TEMPLATE`. A new setting touches all four, plus the table in `docs/USAGE.md`.

**The CLI is a thin client.** `bin/owl-desktop` forwards to the plugin through `omarchy-shell owl-desktop <call>` (the `IpcHandler`), or execs `bin/omarchy-widgets` for store/agent commands. An IPC call takes all its declared arguments (`""` for none) and returns a string. Adding a command usually means: an `IpcHandler` function in `Service.qml`, a case in `bin/owl-desktop` (and its header comment, which is the `help` text — `usage()` prints lines 3–34 of the file, so adjust that range if the header grows), and `docs/USAGE.md`.

## Constraints

- **Never start a second Quickshell** and never use `ShellRoot`: the plugin's root is an `Item` the shell creates. `test/plugin.test.sh` greps for `quickshell -p` / `qs -p` in the QML and `bin/omarchy-widgets`.
- **No symlinks anywhere in the repo**, and `bin/owl-desktop`, `bin/omarchy-widgets`, `owl/owl-source` must stay executable (same test).
- **Vendored code**: `owl/` is the upstream OWL runtime (pinned in `owl/VERSION`); `bin/omarchy-widgets` and `starter/` come from omalauncher-omarchy-plugin. Prefer doing desktop-specific work in the host (`Service.qml`'s `OwlHost`) over editing them. Any local change must be listed in `owl/PATCHES.md` or `bin/PATCHES.md`; real runtime bugs belong upstream at SimonSchubert/omarchy-widgets. CI's qmllint covers only the root `*.qml`, not `owl/`.
- The plugin writes only its own files (widget folder, `style.toml`, layout, widget state). It must not edit the shell's, Hyprland's or other programs' configuration; `owl-desktop migrate` is the one prompted exception.

## Releases and docs

A release bumps `manifest.json`'s `version` and needs a matching `## <version> ` heading in `CHANGELOG.md` (the plugin test fails otherwise). `Service.qml` also carries a fallback version string for when the manifest is missing; keep it in step. User-facing changes go in `CHANGELOG.md` and `docs/USAGE.md` (which also has the settings table, the IPC call list and a repository map).

Commit subjects are short, plain sentences describing what changes for the user (e.g. "Corners follow Hyprland's rounding"), with releases prefixed by the version (`2.1.0: …`).

`owl/LANGUAGE.md` is the guide to the OWL language, and `owl/RUNTIME.md` says where the desktop runtime differs from the phone.
