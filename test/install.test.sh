#!/usr/bin/env bash

# install.sh and update.sh in a throwaway home, starting nothing: install from
# a checkout, as the curl one-liner runs it (a clone), again, update.sh, then
# install.sh --uninstall.
#
#   bash test/install.test.sh

set -euo pipefail

repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME=$tmp/home
export PATH=$HOME/.local/bin:$PATH
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME OWL_DESKTOP_DIR OWL_DESKTOP_BRANCH
link=$HOME/.local/bin/owl-desktop
clone=$HOME/.local/share/owl-desktop
hypr=$HOME/.config/hypr/autostart.lua
mkdir -p "$(dirname "$hypr")"
echo 'o.launch_on_start("something-else")' >"$hypr"

ok() { echo "ok   $*"; }
fail() { echo "FAIL $*" >&2; exit 1; }
launches() { grep -c 'owl-desktop run' "$hypr" || true; }

# This checkout as it is now, uncommitted changes too, as a repository to
# clone: what the one-liner would get.
src=$tmp/src
cp -r "$repo" "$src"
rm -rf "$src/.git"
git -C "$src" init -q -b main
git -C "$src" add -A
git -C "$src" -c user.name=test -c user.email=test@localhost commit -q -m test
export OWL_DESKTOP_REPO=file://$src

"$src/install.sh" --no-start >/dev/null
[[ $(readlink "$link") == "$src/bin/owl-desktop" ]] || fail "from a checkout: the command isn't linked to it"
grep -qF "\"$src/bin/owl-desktop run\"" "$hypr" || fail "from a checkout: no autostart line"
grep -q something-else "$hypr" || fail "from a checkout: the rest of autostart.lua is gone"
ok "from a checkout: linked, starts with Hyprland"

out=$("$src/install.sh" --no-start)
grep -q "already starts with Hyprland" <<<"$out" || fail "again: autostart added twice"
[[ $(launches) == 1 ]] || fail "again: $(launches) autostart lines"
ok "again: nothing doubled"

(cd "$tmp" && bash -s -- --no-start <"$src/install.sh" >/dev/null)
[[ -f $clone/shell.qml ]] || fail "one-liner: no clone in $clone"
[[ $(readlink "$link") == "$clone/bin/owl-desktop" ]] || fail "one-liner: the command isn't linked to the clone"
grep -qF "\"$clone/bin/owl-desktop run\"" "$hypr" || fail "one-liner: autostart doesn't start the clone"
[[ $(launches) == 1 ]] || fail "one-liner: $(launches) autostart lines"
ok "one-liner: cloned, linked, autostart moved to the clone"

out=$(cd "$tmp" && bash -s -- --no-start <"$src/install.sh")
grep -q "Updating" <<<"$out" || fail "install again: didn't update the clone"
ok "install again: pulls the clone"

commit() { git -C "$src" -c user.name=test -c user.email=test@localhost commit -qam "$1"; }
echo "# a change" >>"$src/README.md"
commit "a change"
out=$(owl-desktop update)
[[ $(git -C "$clone" rev-parse HEAD) == $(git -C "$src" rev-parse HEAD) ]] || fail "update: the clone wasn't pulled"
grep -q "a change" <<<"$out" || fail "update: doesn't say what changed"
grep -q "Updated to" <<<"$out" || fail "update: the new update.sh didn't finish it"
out=$(owl-desktop update)
grep -q "already up to date" <<<"$out" || fail "update: pulled with nothing new"
echo "# another" >>"$src/README.md"
commit "another change"
out=$(cd "$tmp" && bash -s <"$src/update.sh")
grep -q "another change" <<<"$out" || fail "update through curl: didn't find the install"
echo "# mine" >>"$clone/README.md"
if owl-desktop update >/dev/null 2>&1; then fail "update: went over local changes"; fi
git -C "$clone" checkout -q README.md
[[ $(launches) == 1 ]] || fail "update: changed autostart.lua"
ok "update: pulls what's new and says so, through curl too; leaves local changes and autostart alone"

(cd "$tmp" && bash -s -- --uninstall <"$src/install.sh" >/dev/null)
[[ ! -e $link && ! -L $link ]] || fail "uninstall: the command is still there"
[[ ! -e $clone ]] || fail "uninstall: the clone is still there"
[[ $(launches) == 0 ]] || fail "uninstall: still in autostart.lua"
grep -q 'OWL widgets' "$hypr" && fail "uninstall: its comment is still in autostart.lua"
grep -q something-else "$hypr" || fail "uninstall: the rest of autostart.lua is gone"
[[ -d $src ]] || fail "uninstall: removed a checkout"
ok "uninstall: command, clone and autostart gone, the rest kept"

echo "all passed"
