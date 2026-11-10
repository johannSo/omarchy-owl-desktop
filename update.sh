#!/usr/bin/env bash

# Update owl-desktop: pull the latest version and restart the widgets if
# they're running. Your widgets, style, layout and autostart stay as they are.
#
#   owl-desktop update
#   curl -fsSL https://raw.githubusercontent.com/johannSo/omarchy-owl-desktop/main/update.sh | bash
#
# It updates the checkout it's run from, else the install ~/.local/bin/owl-desktop
# points to, else ~/.local/share/owl-desktop (OWL_DESKTOP_DIR).

set -euo pipefail

DEST=${OWL_DESKTOP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/owl-desktop}
PACKAGES=(quickshell qt6-imageformats curl jq perl inotify-tools git)

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { echo "update.sh: $*" >&2; exit 1; }
tilde() { if [[ $1 == "$HOME"* ]]; then echo "~${1#"$HOME"}"; else echo "$1"; fi; }

# The install to update.
locate() {
  local app="" link=$HOME/.local/bin/owl-desktop
  if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    app=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    [[ -f $app/shell.qml && -f $app/bin/owl-desktop ]] || app=""
  fi
  if [[ -z $app && -L $link && $(readlink -- "$link") == */bin/owl-desktop ]]; then
    app=$(dirname -- "$(dirname -- "$(readlink -f -- "$link")")")
  fi
  echo "${app:-$DEST}"
}

# 1. Pull, then hand over to the update.sh just pulled, which knows what the
#    new version needs.
pull() {
  local app
  app=$(locate)
  [[ -f $app/shell.qml ]] || die "owl-desktop isn't installed (no $(tilde "$app")); install it with install.sh"
  [[ -d $app/.git ]] || die "$(tilde "$app") isn't a git clone; install it again with install.sh"
  [[ -z $(git -C "$app" status --porcelain --untracked-files=no) ]] ||
    die "$(tilde "$app") has local changes; commit or stash them first"

  say "Updating $(tilde "$app")"
  local old new
  old=$(git -C "$app" rev-parse HEAD)
  git -C "$app" pull -q --ff-only || die "couldn't update; git -C $(tilde "$app") pull says why"
  new=$(git -C "$app" rev-parse HEAD)
  if [[ $old == "$new" ]]; then
    echo "already up to date ($(git -C "$app" log -1 --format='%h %s'))"
    return 0
  fi
  exec bash "$app/update.sh" --finish "$app" "$old"
}

# 2. In the new version: its packages, the command, and a restart.
finish() {
  local app=$1 old=$2
  git -C "$app" log --oneline --no-decorate "$old..HEAD"

  if command -v pacman >/dev/null 2>&1; then
    local missing
    mapfile -t missing < <(pacman -T "${PACKAGES[@]}" || true)
    if ((${#missing[@]})); then
      say "Installing ${missing[*]}"
      sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
  fi

  local owl=$app/bin/owl-desktop
  chmod +x "$owl" "$app/bin/omarchy-widgets" "$app/owl/owl-source" "$app/install.sh" "$app/update.sh"
  if [[ -L $HOME/.local/bin/owl-desktop ]]; then "$owl" link >/dev/null; fi

  local status
  status=$("$owl" status)
  if [[ ${status%%$'\n'*} == running ]]; then
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
      "$owl" restart >/dev/null
      echo "restarted the widgets"
    else
      echo "not in a Wayland session: run owl-desktop restart from Hyprland"
    fi
  fi
  say "Updated to $(git -C "$app" log -1 --format='%h %s')"
}

main() {
  [[ $EUID -ne 0 ]] || die "run it as yourself, not as root"
  case ${1:-} in
    "") pull ;;
    --finish) (($# == 3)) || die "--finish <app> <old commit>"; finish "$2" "$3" ;;
    -h | --help) echo "usage: update.sh"; exit 0 ;;
    *) die "unknown option $1" ;;
  esac
}

# All of it is read before any of it runs, so pulling a new update.sh over
# this one can't change it halfway.
main "$@"
exit
