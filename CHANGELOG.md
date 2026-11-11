# Changelog

The most important changes in each release.

## Unreleased

- Corners follow Hyprland's `decoration:rounding`, as its windows do: the
  widgets, a widget's own `corners`, and everything else the desktop draws
  (the store, a widget's `screen { }` panel, the arranging bars and buttons). `corners.hyprland = false` in
  `style.toml` goes back to `corners.scale`.

## 2.0.0 – 2026-11-10

Rewritten as a plugin of the Omarchy shell (Omarchy 4.5's Quattro shell), and
named OmaLauncher++ Desktop after the launcher whose home screen it follows.

- The shell loads it as a service (`manifest.json`, `Service.qml`): no second
  Quickshell, no line in Hyprland's autostart. Install it with
  `omarchy plugin add https://github.com/johannSo/omarchy-owl-desktop.git --enable`,
  update it with `omarchy plugin update`, remove it with `omarchy plugin remove`.
- `install.sh` and `update.sh` are gone. `owl-desktop migrate` stops a
  standalone 1.x and takes it out of autostart; widgets, style and layout are
  the same files as before.
- The plugin answers the shell's IPC: `omarchy-shell owl-desktop toggle` in a
  key binding, and the rest of what `owl-desktop` asks of it.
- `owl-desktop enable` and `disable` (`start` and `stop` still work) switch the
  plugin on and off; `owl-desktop autostart` and `run` are gone.
- Each widget can have its own look, as in OmaLauncher++ 2.5: its opacity and
  whether it has an outline, from its bar while arranging or
  `owl-desktop look <file> --opacity 0.5 --border off`, kept with its place in
  `layout.json`.
- `corners.scale` in `style.toml`, OmaLauncher++'s: 0 square (Omarchy), 0.5
  soft, 1 round.
- The arranging bars use the launcher's words: edit, share, remove, create
  with an agent, browse store.
- `omarchy-widgets open` opens the plugin's store rather than a desktop app.

## 1.0.0 – 2026-11-10

- OWL widgets on the Omarchy desktop as a Quickshell instance of its own:
  the launcher's grid, faces, `screen { }`, arranging, per-monitor layouts,
  the store, `style.toml`, and `install.sh` with autostart.
