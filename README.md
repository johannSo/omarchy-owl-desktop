# OmaLauncher++ Desktop

An [Omarchy](https://omarchy.org) shell plugin that puts the home screen of
[OmaLauncher++](https://github.com/johannSo/omalauncher.pp) on your desktop:
its OWL widgets over the wallpaper and under the windows, on the launcher's
grid, framed and colored as the phone frames them, in your current theme.

The widgets are `.owl` files in `~/.config/omarchy-widgets`, drawn by the
official [OWL runtime for Quickshell](https://github.com/SimonSchubert/omarchy-widgets/tree/main/runtimes/quickshell),
so a widget that works on the phone works here unchanged. The Omarchy shell
loads the plugin as a service: there is no second Quickshell, no autostart
line and no daemon of its own.

![The starter widgets on an Omarchy desktop: today, fetch and the koi pond](preview.png)

- **Home's grid**: 69 dp cells with 6 dp gaps, tiles of the theme's background
  at 0.88 over the wallpaper, a 2 dp outline in the theme's border color, and
  the accent on the one you type into or arrange
- **Faces** (`face "…" { }`) as the whole screen behind the tiles, and a
  widget's `screen { }` in the launcher's panel over everything
- **Arranging as on the phone**: hold or right-click a widget, drag it, resize
  it from an edge, remove it, put it back
- **Each widget's own look**: its opacity and whether it has an outline, kept
  with its place, as OmaLauncher++ 2.5 keeps them in home's layout
- **Corners**: every widget, panel, bar and button is as round as Hyprland's windows
  (`decoration:rounding`); `corners.hyprland = false` takes `corners.scale`
  instead, 0 square to 1 round like stock Android
- **The widget store**, as the launcher has it: every reviewed widget and face
  of [SimonSchubert/omarchy-widgets](https://github.com/SimonSchubert/omarchy-widgets),
  with what each installs and runs shown before you add it
- **Your agent**: create, edit, share and publish widgets with Omarchy's
  default coding agent
- Clicks beside the tiles still reach the desktop, and widgets pause while
  tiled windows cover them

## Install

Needs Omarchy 4.5 or newer (the Quattro shell).

```sh
omarchy plugin add https://github.com/johannSo/omarchy-owl-desktop.git --enable
```

The shell clones the plugin to
`~/.config/omarchy/plugins/io.github.johannso.owl-desktop` and loads it. The
first start puts the launcher's three starter widgets in the widget folder
(the weather, `fetch` and the koi pond) if you have none of them yet.

For the `owl-desktop` command, link it onto your PATH once:

```sh
~/.config/omarchy/plugins/io.github.johannso.owl-desktop/bin/owl-desktop link
```

Hold or right-click a widget to arrange the desktop, and press **browse
store** there (or run `owl-desktop store`) to get widgets and faces.
`owl-desktop help` lists the commands, and [docs/USAGE.md](docs/USAGE.md)
explains everything else.

### Update

```sh
omarchy plugin update io.github.johannso.owl-desktop
```

### Remove

```sh
omarchy plugin remove io.github.johannso.owl-desktop
rm -f ~/.local/bin/owl-desktop        # if you linked the command
```

To only take the widgets off the desktop, `omarchy plugin disable
io.github.johannso.owl-desktop`. Either way your widgets
(`~/.config/omarchy-widgets`), style (`~/.config/owl-desktop`) and layout
(`~/.local/state/owl-desktop`) stay; delete them if you don't want them.

### Coming from owl-desktop 1.x

Version 1 was a Quickshell instance of its own, started from Hyprland's
autostart. After adding the plugin, run:

```sh
owl-desktop migrate
```

It stops the standalone instance and, after asking, takes its line out of
`~/.config/hypr/autostart.lua` (a copy is kept). Your widgets, style and
layout are the same files, so the desktop comes up as you left it. You can
delete the old clone (`~/.local/share/owl-desktop`) afterwards.

## What it needs and what it touches

- **Packages**: `curl`, `jq` and `perl` for the store command (Omarchy ships
  them), and optionally `inotify-tools`, without which a new file shows within
  two seconds instead of at once. A widget may ask for packages of its own in
  `requires { pacman: [...] }`; its tile then says so with an **install**
  button, which opens a terminal that runs `sudo pacman -S --needed` for
  exactly those packages after you confirm. Nothing is installed otherwise.
- **Network**: the store's catalog and previews from
  `simonschubert.github.io/omarchy-widgets`, when you open the store, and
  whatever a widget you installed fetches itself.
- **Files**: it writes only its own: the widget folder, `style.toml`, the
  layout and widgets' saved state (see [docs/USAGE.md](docs/USAGE.md#files)).
  It doesn't change the shell's configuration, Hyprland's or any other
  program's. `owl-desktop migrate` edits `autostart.lua` only when you run it
  and say yes.
- **Widgets run commands**: an OWL widget can run shell commands as you. The
  store shows the commands of a reviewed widget before you add it; read a
  widget from anywhere else before you save it to the folder.

## How to contribute

- Open an issue or a pull request. To try a checkout, copy or clone it to
  `~/.config/omarchy/plugins/io.github.johannso.owl-desktop` (no symlinks: the
  shell refuses them) and `omarchy plugin enable io.github.johannso.owl-desktop`;
  saved changes reload by themselves, and `owl-desktop logs` shows the shell's
  log.
- Before a pull request, run `node test/layout.test.mjs`,
  `node test/store.test.mjs`, `bash test/plugin.test.sh` and
  `omarchy plugin validate .`. CI runs them with qmllint and shellcheck (see
  `.github/workflows/ci.yml` for the exact commands).
- `owl/` is the upstream runtime, vendored. Fix bugs in it at
  [SimonSchubert/omarchy-widgets](https://github.com/SimonSchubert/omarchy-widgets),
  and list any local change in `owl/PATCHES.md`.
- Send widgets to the store with `owl-desktop publish <file>`, not to this repo.

## ToDo

- [ ] The store's official tab: the widgets that come with OmaLauncher++.

## License

MIT (see [LICENSE](LICENSE)). `owl/`, `bin/omarchy-widgets` and `starter/` are
by Simon Schubert, also MIT; [THIRD_PARTY.md](THIRD_PARTY.md) says what comes
from where.

OmaLauncher++ Desktop is not affiliated with or endorsed by Omarchy or
Omalauncher.
