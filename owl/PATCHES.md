# The runtime, and what changed in it here

This folder is the OWL runtime for Quickshell from
[SimonSchubert/omarchy-widgets](https://github.com/SimonSchubert/omarchy-widgets/tree/main/runtimes/quickshell),
by Omalauncher's author, as `VERSION` names it (MIT, see `LICENSE`). Its own
README is `RUNTIME.md`, with how faithful it is to the launcher and where a
desktop differs. `LANGUAGE.md` is the store's guide to the language, which
`omarchy-widgets new` and `edit` hand to your agent.

It is used as it is, but for one line:

- `owl-source`: `android.modes`' `dnd` also reads the Omarchy shell's own
  do-not-disturb (`omarchy-shell notifications isDnd`); upstream reads mako's,
  which Omarchy 4.5 no longer runs.

Everything else the desktop needs is in the host (`Service.qml`'s `OwlHost`),
which overrides what Omarchy does its own way: the terminal, `ask()` with the
default agent, `launcher()`, `media()` through MPRIS and `dnd()`.

To take a newer runtime, copy `runtimes/quickshell/*` over these files, keep
`PATCHES.md` and `LANGUAGE.md` (the store's `docs/LANGUAGE.md`), apply the
line above again and update `VERSION`.
