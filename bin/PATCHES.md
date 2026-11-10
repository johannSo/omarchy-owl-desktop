# The store command and the starters, and what changed in them here

`omarchy-widgets` and `../starter/` are Omalauncher's desktop app's store
command and starter widgets, from
[SimonSchubert/omalauncher-omarchy-plugin](https://github.com/SimonSchubert/omalauncher-omarchy-plugin)
at 8be142a (MIT, see `LICENSE.omarchy-widgets`). Changed here so the store
can work as the phone's does:

- `install` and `remove` take `--faces`: a face from the store's `faces.json`,
  installed as `market-face-<author>-<name>.owl` and recorded in
  `installed-faces.json`, apart from the widgets, as the phone keeps them.
- `install` records the reviewed file's SHA-256 with the rest, so the store
  can tell whether updating would replace your changes.
- `remove` moves the file to `.removed/` in the widget folder, as the phone
  does, rather than deleting it.
- `starter/installed.json` has each starter file's SHA-256.
- `open` and `toggle` open the plugin's store through the Omarchy shell
  (`omarchy-shell owl-desktop store`) rather than starting the desktop app's
  own Quickshell: a plugin must not start a second one.
