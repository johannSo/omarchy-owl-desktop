# OWL widgets on the Omarchy desktop

OmaLauncher++'s widgets, written in OWL, on your desktop: over the wallpaper
and under the windows, on the launcher's home-screen grid, framed and colored
as the phone frames them, in the current Omarchy theme. It is a plugin of the
Omarchy shell, which loads it as a service and draws it in its own process.

The language and the drawing are the OWL runtime for Quickshell that
Omalauncher's author keeps next to the launcher and tests against its compiler
(`owl/`, see `owl/RUNTIME.md`). A widget that works on the phone works here as
it is, and the other way round. This project adds the desktop around it:

- one layer surface per monitor, below the windows, inside the bar's room
- the phone's grid: 69 dp cells, 6 dp gaps, tiles of the theme's background at
  0.88 over the wallpaper with a 2 dp square outline in the theme's border
  color, the accent while you type into one or arrange it
- faces (`face "…" { }`) as the whole screen behind the tiles
- a widget's `screen { }` in the launcher's overlay panel, over everything
- arranging as on the phone: hold or right-click a widget, drag it, resize it
  from an edge, remove it, put it back
- a widget's own look, as OmaLauncher++ keeps it on a tile: its opacity and
  whether it has an outline
- `corners.scale`: every frame's corner radius, square by default
- `requires { pacman: [...] }`: a tile that needs a missing package says
  `needs jq` with an **install** button, as on the phone
- clicks beside the tiles still reach the desktop (double-click for the
  wallpaper picker, right double-click for themes)
- widgets pause while tiled windows cover the desktop, as the phone's pause
  on a page that isn't showing

## Start it

```sh
omarchy plugin add https://github.com/johannSo/omarchy-owl-desktop.git --enable
~/.config/omarchy/plugins/io.github.johannso.owl-desktop/bin/owl-desktop link
```

The first line installs and enables the plugin; the second puts the
`owl-desktop` command in `~/.local/bin`. The shell loads the plugin with every
session from then on. `owl-desktop disable` takes the widgets off the desktop
and `owl-desktop enable` shows them again (`omarchy plugin disable` and
`enable`, with the plugin's id).

The first start puts Omalauncher's three starter widgets in
the folder, as the phone and its desktop app do: the weather, `fetch` and the
koi pond.

## Widgets

A widget is one `.owl` file in `~/.config/omarchy-widgets`, the folder
Omalauncher's desktop app and its store use too. Save one there and it shows
up at the first free place on the monitor you're on; save it again and it
redraws. A file that doesn't compile shows why in its tile, and in
`.errors/<name>.txt` beside it, which is where a coding agent should look.

```owl
widget "uptime" {
  meta { description: "How long this machine has been up"; version: "1.0"; license: "MIT"; category: "system" }
  size: 3x1
  source up = cmd("uptime -p") every 1m
  Text { text: up ?? "…"; style: title }
}
```

The language is in `owl/LANGUAGE.md`, and in full in Omalauncher's
`app/src/main/assets/widgets/docs/`.

## The store

**browse store** in the arranging bar, `owl-desktop store`, or a widget's
`launcher("store")` opens the store as the phone has it: every reviewed widget
and face of [SimonSchubert/omarchy-widgets](https://github.com/SimonSchubert/omarchy-widgets),
in the launcher's panel over the desktop, drawn in your theme with previews
drawn in it.

- **widgets | faces** in the header switches between them; ↻ loads the store
  again.
- Search, or pick a tab: all, new, a category, or installed (with how many
  have an update).
- A card's line says what it is, `✓ installed`, `update available`, or that it
  needs a newer runtime. Click one, and its page beside the grid shows what it
  installs and the commands it runs before you add it.
- **add to your desktop** puts a widget at the first free place on this
  monitor and closes the store; **add as a face** shows a face behind your
  widgets. Either way it's installed only if the download is the reviewed
  file the page showed.
- An installed one's page has **update** (and says when updating would replace
  your changes, or when the update runs something new), **edit** and
  **share** (your agent, as below), **remove** (asked first; the file goes to
  `.removed/` in the widget folder), and **put it back** or **show it here**
  when it's off the desktop.
- Keys: type to search; Tab goes to the grid, the arrows through it, Tab again
  to the page's actions, Enter or Space presses one; Escape steps back, then
  closes.

`owl-desktop store <author/name>` opens one's page. A store widget's bar while
arranging has **Store page** too.

From a terminal, and with your agent, as in Omalauncher's desktop app:

```sh
owl-desktop install simonschubert/today   # a reviewed widget, after showing what it runs
owl-desktop new                            # your agent creates one in the folder
owl-desktop edit today                     # your agent changes one
owl-desktop share today                    # a link and a QR code for the phone
owl-desktop import '<link>'                # add one someone shared
owl-desktop publish my-widget              # your agent opens a pull request to the store
```

## Arranging

Hold or right-click a widget. Drag a tile to move it, drag an edge to resize
it, and click beside the tiles, or press Enter or Escape, when you're done.
With the keyboard: arrows move the selected tile, Shift+arrows resize it, Tab
picks the next one, Delete removes it from the desktop. The bar at the bottom
puts back what you removed (or what had no room left), and has create with an
agent, browse store, style and folder. A widget's own bar has edit, share,
its look (below), remove (uninstall for one from the store, with store page)
and, with more monitors, next screen.

`owl-desktop arrange` starts arranging on the focused monitor without a
click, and `owl-desktop done` ends it. You may want a key for it in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Arrange widgets", "omarchy-shell owl-desktop toggle")
```

Everything the command asks of the plugin goes through the shell's IPC
(`omarchy-shell owl-desktop <call>`): `arrange <file>`, `done`, `toggle`,
`reload`, `list`, `screen <file>`, `store <author/name>`, `style`,
`look <file> <opacity> <on|off>` and `status`. A call takes all its arguments;
pass `""` for none.

## A widget's own look

As OmaLauncher++ lets a tile in home's layout have its own `opacity` and
`border = false`, a widget here can differ from the style: while arranging,
its bar has **clearer** and **more solid** (a tenth at a time), **no outline**
or **outline**, and **style's look** to go back. From a terminal:

```sh
owl-desktop look today --opacity 0.5 --border off
owl-desktop look today --opacity style --border on    # the style's again
```

The look is kept with the widget's place in `layout.json` (`"opacity": 0.5,
"border": false`) and stays with it when it moves, is resized, or comes back
after being removed. The focused widget's outline shows either way.

## Style

`~/.config/owl-desktop/style.toml`, written with every setting on the first
start and applied as you save it. The `[widgets]` and `[corners]` settings are
OmaLauncher++'s own, with its names and defaults:

| setting | default | |
| --- | --- | --- |
| `widgets.gaps-in` | 6 | dp between two widgets |
| `widgets.gaps-out` | 6 | dp from the widgets to the screen's edges |
| `widgets.opacity` | 0.88 | how much a widget covers the wallpaper |
| `widgets.border-width` | 2 | the outline in dp; 0 draws none |
| `widgets.border` | "theme" | the outline: the theme's muted, a theme color, or #rrggbb |
| `widgets.border-focused` | "theme" | the widget being typed into or arranged: the accent |
| `corners.scale` | 0 | multiplies every frame's corner radius: 0 square (Omarchy), 0.5 soft, 1 round |
| `desktop.scale` | 1 | px per dp: 1.25 draws everything a quarter bigger |
| `desktop.cell` | 69 | a grid cell in dp, gap included |
| `desktop.folder` | "~/.config/omarchy-widgets" | where the widgets are |
| `desktop.pause-when-covered` | true | pause widgets behind tiled windows |
| `desktop.frame-rate` | 30 | the most frames a second an animation draws |

## Where it differs from the phone

What Android has and a desktop doesn't is in `owl/RUNTIME.md` ("How
faithful it is"): Shaders draw their `fallback`, `android.notifications`
and the app drawer are empty, `ws(...)` sources don't connect, and so on. Here
in particular:

- `terminal()` opens Omarchy's terminal, `app()` starts the command through
  uwsm, `ask()` opens Omarchy's default agent with the prompt, and
  `launcher()` opens Omarchy's theme menu (`themes`), app launcher (`drawer`),
  agent setup (`agents`), this style file (`style`, `settings`) or the store
  (`store`, the panel above).
- `media()` controls the MPRIS player, `dnd()` Omarchy's do-not-disturb.
- `frost` draws only the node's background: the wallpaper is another
  program's surface, which a widget can't blur.
- A tile has no long press of its own: holding it arranges, as on the phone.
- OmaLauncher++'s Android widgets, app tiles, pages, the prompt bar and the
  store's official tab are the phone's; the desktop has widgets and faces.
- `widgets.frost` isn't here: the wallpaper is another surface, as above.

## Commands

`owl-desktop help` lists them all; also `update`, `status`, `enable`,
`disable`, `list` (the widgets, where they are and what's wrong with them),
`screen <file>`, `look`, `reload`, `logs` (the Omarchy shell's log) and
`migrate` (from the standalone 1.x).

## Files

| | |
| --- | --- |
| `~/.config/omarchy-widgets/` | the widgets, and `.errors/` |
| `~/.config/owl-desktop/style.toml` | how they look |
| `~/.local/state/owl-desktop/layout.json` | where each one is, per monitor, and its own look |
| `~/.config/omarchy/plugins/io.github.johannso.owl-desktop/` | the plugin |
| `~/.local/state/owl-desktop/<file>.json` | what a widget persists (`.secrets.json`: its secrets, yours only) |
| `~/.local/state/omarchy-widgets/installed.json`, `installed-faces.json` | what came from the store |
| `~/.config/omarchy-widgets/.removed/` | what you removed |

To remove it, run `omarchy plugin remove io.github.johannso.owl-desktop`, and
delete `~/.local/bin/owl-desktop` if you linked the command. Your widgets,
style and `~/.local/state/owl-desktop` stay.

## Layout of the repository

| | |
| --- | --- |
| `manifest.json` | what the Omarchy shell reads: the plugin's id, and `Service.qml` as its service |
| `Service.qml` | the entry: theme, font, the folder, the layout, the host, the IPC |
| `Desktop.qml`, `DesktopWindow.qml` | a monitor: its grid, tiles, arranging and input |
| `Tile.qml` | one widget, framed as on the phone |
| `ScreenWindow.qml` | a widget's `screen { }` |
| `Layout.js`, `Style.js` | where tiles go, and style.toml; `node test/layout.test.mjs` |
| `test/` | `node test/layout.test.mjs`, `bash test/plugin.test.sh`; CI runs them with qmllint and shellcheck |
| `owl/` | the OWL runtime (`owl/PATCHES.md`) |
| `bin/owl-desktop` | the command |
| `StoreWindow.qml`, `StoreUi.qml`, `Store.js` | the store; `node test/store.test.mjs` |
| `bin/omarchy-widgets`, `starter/` | Omalauncher's desktop app's store command and starter widgets (MIT, `bin/PATCHES.md`) |
