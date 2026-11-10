# OWL widgets on the Omarchy desktop

Omalauncher's widgets, written in OWL, on your desktop: over the wallpaper and
under the windows, on the launcher's home-screen grid, framed and colored as
the phone frames them, in the current Omarchy theme.

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
  from an edge, take it off, put it back
- `requires { pacman: [...] }`: a tile that needs a missing package says
  `needs jq` with an **install** button, as on the phone
- clicks beside the tiles still reach the desktop (double-click for the
  wallpaper picker, right double-click for themes)
- widgets pause while tiled windows cover the desktop, as the phone's pause
  on a page that isn't showing

## Start it

`install.sh` (see the README) does all of this. By hand, from a clone:

```sh
bin/owl-desktop link        # owl-desktop on your PATH (~/.local/bin)
owl-desktop start           # now
owl-desktop autostart on    # and with every Hyprland session
```

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

From the store and with your agent, as in Omalauncher's desktop app:

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
picks the next one, Delete takes it off the desktop. The bar at the bottom puts
back what you took off (or what had no room left), and has Create, Store,
Style and Folder. A widget's own bar has Edit, Share, Take off (Uninstall for
one from the store) and, with more monitors, Next screen.

`owl-desktop arrange` starts arranging on the focused monitor without a
click, and `owl-desktop done` ends it. You may want a key for it in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Arrange widgets", "owl-desktop toggle")
```

## Style

`~/.config/owl-desktop/style.toml`, written with every setting on the first
start and applied as you save it. The `[widgets]` settings are Omalauncher's
own, with its names and defaults:

| setting | default | |
| --- | --- | --- |
| `widgets.gaps-in` | 6 | dp between two widgets |
| `widgets.gaps-out` | 6 | dp from the widgets to the screen's edges |
| `widgets.opacity` | 0.88 | how much a widget covers the wallpaper |
| `widgets.border-width` | 2 | the outline in dp; 0 draws none |
| `widgets.border` | "theme" | the outline: the theme's muted, a theme color, or #rrggbb |
| `widgets.border-focused` | "theme" | the widget being typed into or arranged: the accent |
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
  agent setup (`agents`), this style file (`style`, `settings`) or the store.
- `media()` controls the MPRIS player, `dnd()` Omarchy's do-not-disturb.
- `frost` draws only the node's background: the wallpaper is another
  program's surface, which a widget can't blur.
- A tile has no long press of its own: holding it arranges, as on the phone.

## Commands

`owl-desktop help` lists them all; also `status`, `stop`, `restart`, `list`
(the widgets, where they are and what's wrong with them), `screen <file>`,
`reload` and `logs`.

## Files

| | |
| --- | --- |
| `~/.config/omarchy-widgets/` | the widgets, and `.errors/` |
| `~/.config/owl-desktop/style.toml` | how they look |
| `~/.local/state/owl-desktop/layout.json` | where each one is, per monitor |
| `~/.local/state/owl-desktop/<file>.json` | what a widget persists (`.secrets.json`: its secrets, yours only) |
| `~/.local/state/omarchy-widgets/installed.json` | what came from the store |

To remove it: `owl-desktop autostart off`, `owl-desktop stop`, and delete
`~/.local/bin/owl-desktop`, the clone (`~/.local/share/owl-desktop`) and
`~/.local/state/owl-desktop`. Your widgets stay.

## Layout of the repository

| | |
| --- | --- |
| `shell.qml` | the entry: theme, font, the folder, the layout, the host |
| `Desktop.qml`, `DesktopWindow.qml` | a monitor: its grid, tiles, arranging and input |
| `Tile.qml` | one widget, framed as on the phone |
| `ScreenWindow.qml` | a widget's `screen { }` |
| `Layout.js`, `Style.js` | where tiles go, and style.toml; `node test/layout.test.mjs` |
| `owl/` | the OWL runtime (`owl/PATCHES.md`) |
| `bin/owl-desktop` | the command |
| `install.sh` | installs and updates it |
| `bin/omarchy-widgets`, `starter/` | Omalauncher's desktop app's store command and starter widgets (MIT) |
