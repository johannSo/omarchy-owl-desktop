#!/usr/bin/env bash

# Install owl-desktop: Omalauncher's OWL widgets on the Omarchy desktop.
#
#   curl -fsSL https://raw.githubusercontent.com/johannSo/omarchy-owl-desktop/main/install.sh | bash
#   ./install.sh                      from a checkout: installs that checkout
#
#   --no-autostart   don't start the widgets with Hyprland
#   --no-start       don't start them now
#   --uninstall      stop them, take them out of Hyprland's autostart, and
#                    remove the command and the clone (your widgets, style
#                    and layout stay)
#
# Through curl, pass options with: ... | bash -s -- --no-autostart
# Running it again updates the install and restarts the widgets.
#
# OWL_DESKTOP_DIR     where to clone it (~/.local/share/owl-desktop)
# OWL_DESKTOP_REPO    what to clone (this repository)
# OWL_DESKTOP_BRANCH  which branch (main)

set -euo pipefail

REPO=${OWL_DESKTOP_REPO:-https://github.com/johannSo/omarchy-owl-desktop.git}
BRANCH=${OWL_DESKTOP_BRANCH:-main}
DEST=${OWL_DESKTOP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/owl-desktop}
PACKAGES=(quickshell curl jq perl inotify-tools git)

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { echo "install.sh: $*" >&2; exit 1; }

autostart=1 start=1 uninstall=0
for a in "$@"; do
  case $a in
    --no-autostart) autostart=0 ;;
    --no-start) start=0 ;;
    --uninstall) uninstall=1 ;;
    -h | --help) echo "usage: install.sh [--no-autostart] [--no-start] | --uninstall"; exit 0 ;;
    *) die "unknown option $a (--no-autostart, --no-start, --uninstall)" ;;
  esac
done

[[ $EUID -ne 0 ]] || die "run it as yourself, not as root"

if ((uninstall)); then
  link=$HOME/.local/bin/owl-desktop
  owl=""
  [[ -L $link && $(readlink -- "$link") == */bin/owl-desktop ]] && owl=$(readlink -f -- "$link")
  [[ -n $owl && -f $owl ]] || owl=$DEST/bin/owl-desktop
  if [[ -f $owl ]]; then
    bash "$owl" autostart off
    bash "$owl" stop
  fi
  if [[ -L $link && $(readlink -- "$link") == */bin/owl-desktop ]]; then
    rm -f -- "$link"
    echo "removed ~/.local/bin/owl-desktop"
  fi
  if [[ -d $DEST/.git && -f $DEST/shell.qml && -f $DEST/bin/owl-desktop ]]; then
    rm -rf -- "$DEST"
    echo "removed ${DEST/#"$HOME"/\~}"
  fi
  say "Uninstalled."
  echo "Kept your widgets (~/.config/omarchy-widgets), style (~/.config/owl-desktop) and layout (~/.local/state/owl-desktop); delete them if you don't want them."
  exit 0
fi

# 1. Packages (Omarchy ships them all; this only fills gaps).
if command -v pacman >/dev/null 2>&1; then
  mapfile -t missing < <(pacman -T "${PACKAGES[@]}" || true)
  if ((${#missing[@]})); then
    say "Installing ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
else
  for c in quickshell curl jq perl git; do
    command -v "$c" >/dev/null 2>&1 || die "$c is not installed"
  done
fi

# 2. The app: this checkout, or a clone of the repository.
here=""
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
  here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  [[ -f $here/shell.qml && -f $here/bin/owl-desktop ]] || here=""
fi

if [[ -n $here ]]; then
  app=$here
  say "Installing from $app"
elif [[ -d $DEST/.git ]]; then
  app=$DEST
  say "Updating $app"
  git -C "$app" pull -q --ff-only
elif [[ -e $DEST ]]; then
  die "$DEST exists and isn't a clone of $REPO; move it away or set OWL_DESKTOP_DIR"
else
  app=$DEST
  say "Cloning into $app"
  mkdir -p "$(dirname "$app")"
  git clone -q --depth 1 -b "$BRANCH" "$REPO" "$app"
fi

chmod +x "$app/bin/owl-desktop" "$app/bin/omarchy-widgets" "$app/owl/owl-source"
owl="$app/bin/owl-desktop"

# 3. The command.
"$owl" link
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "note: ~/.local/bin isn't on your PATH; add it, or run $owl" ;;
esac

# 4. With every Hyprland session.
if ((autostart)); then "$owl" autostart on; fi

# 5. Now.
if ((start)); then
  if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    "$owl" restart
  else
    echo "not in a Wayland session: run owl-desktop start from Hyprland"
  fi
fi

say "Done."
echo "Hold or right-click a widget to arrange the desktop; owl-desktop help lists the rest."
echo "Your widgets are .owl files in $("$owl" folder | sed "s|^$HOME|~|")."
