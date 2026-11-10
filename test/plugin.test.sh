#!/usr/bin/env bash

# The plugin as the Omarchy shell and its marketplace take it: the manifest,
# what a plugin folder may hold, and the owl-desktop command in a throwaway
# home, with no shell running.
#
#   bash test/plugin.test.sh

set -euo pipefail

repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

ok() { echo "ok   $*"; }
fail() { echo "FAIL $*" >&2; exit 1; }

m=$repo/manifest.json
id=io.github.johannso.owl-desktop

jq -e '.schemaVersion == 1' "$m" >/dev/null || fail "manifest: schemaVersion isn't the number 1"
for field in id name version author description kinds entryPoints; do
  jq -e --arg f "$field" 'has($f) and (.[$f] | length) > 0' "$m" >/dev/null || fail "manifest: no $field"
done
[[ $(jq -r .id "$m") == "$id" ]] || fail "manifest: the id isn't $id"
[[ $(jq -r .id "$m") != omarchy.* ]] || fail "manifest: the id is in the reserved omarchy.* namespace"
jq -e '.kinds == ["service"] and (.entryPoints | keys) == ["service"]' "$m" >/dev/null || fail "manifest: it is one service"
entry=$(jq -r .entryPoints.service "$m")
[[ $entry != /* && $entry != *..* && -f $repo/$entry ]] || fail "manifest: the service's file $entry isn't in the plugin"
(($(jq -r '.version | length' "$m") <= 64)) || fail "manifest: the version is longer than 64 characters"
ok "manifest: one service, $entry, as $id"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$repo" || fail "omarchy plugin validate refuses it"
  ok "omarchy plugin validate accepts it"
fi

link=$(find "$repo" -name .git -prune -o -name node_modules -prune -o -type l -print -quit)
[[ -z $link ]] || fail "a symlink in the plugin folder, which the shell refuses: $link"
for f in README.md LICENSE; do [[ -s $repo/$f ]] || fail "the marketplace wants a root $f"; done
for f in bin/owl-desktop bin/omarchy-widgets owl/owl-source; do [[ -x $repo/$f ]] || fail "$f isn't executable"; done
grep -q "omarchy plugin add" "$repo/README.md" || fail "the README doesn't say how to install it"
grep -q "omarchy plugin remove $id" "$repo/README.md" || fail "the README doesn't say how to remove it"
ok "the folder: no symlinks, a README with install and removal, a license, commands executable"

# The shell loads plugins into its own process: nothing here may start another.
if grep -nE 'quickshell +(-n +)?-p|\bqs +(-n +)?-p' "$repo"/*.qml "$repo/bin/omarchy-widgets" >/dev/null; then
  fail "something starts a Quickshell of its own"
fi
grep -q "^ShellRoot" "$repo"/*.qml && fail "a ShellRoot: the plugin's root is an Item the shell creates"
ok "nothing starts a second Quickshell"

version=$(jq -r .version "$m")
grep -q "^## $version " "$repo/CHANGELOG.md" || fail "CHANGELOG.md has no entry for $version"
ok "the changelog has $version"

export HOME=$tmp/home
export PATH=$tmp/bin:$PATH
unset XDG_CONFIG_HOME XDG_STATE_HOME OWL_WIDGETS
mkdir -p "$HOME/.config/hypr" "$tmp/bin"
# No shell to ask: every call to it fails, as when the plugin isn't loaded.
# And no processes to find: the test never touches a Quickshell that runs.
for stub in omarchy-shell quickshell pgrep; do
  printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/$stub"
  chmod +x "$tmp/bin/$stub"
done
owl=$repo/bin/owl-desktop

[[ $("$owl" folder) == "$HOME/.config/omarchy-widgets" ]] || fail "folder: not Omalauncher's by default"
mkdir -p "$HOME/.config/owl-desktop"
echo 'folder = "~/mine"' >"$HOME/.config/owl-desktop/style.toml"
[[ $("$owl" folder) == "$HOME/mine" ]] || fail "folder: doesn't follow style.toml"
[[ $(OWL_WIDGETS=/else "$owl" folder) == /else ]] || fail "folder: doesn't follow OWL_WIDGETS"
ok "folder: Omalauncher's, style.toml's, or OWL_WIDGETS"

out=$("$owl" status)
grep -q "not loaded" <<<"$out" || fail "status: doesn't say the plugin isn't loaded"
if "$owl" list >/dev/null 2>&1; then fail "list: answered with no plugin loaded"; fi
set +e
"$owl" nonsense >/dev/null 2>&1
code=$?
set -e
[[ $code == 2 ]] || fail "an unknown command exits $code, not 2"
ok "status, list and usage with no plugin loaded"

hypr=$HOME/.config/hypr/autostart.lua
printf '%s\n' 'o.launch_on_start("something-else")' '' \
  '-- OWL widgets on the desktop (owl-desktop autostart off removes this).' \
  'o.launch_on_start("/somewhere/bin/owl-desktop run")' >"$hypr"
out=$("$owl" status)
grep -q "owl-desktop migrate" <<<"$out" || fail "status: doesn't point to migrate"
"$owl" migrate --yes >/dev/null
grep -q owl-desktop "$hypr" && fail "migrate: 1.x is still in autostart.lua"
grep -q something-else "$hypr" || fail "migrate: the rest of autostart.lua is gone"
ls "$hypr".bak.* >/dev/null 2>&1 || fail "migrate: kept no copy of autostart.lua"
out=$("$owl" migrate --yes)
grep -q "nothing of owl-desktop 1.x" <<<"$out" || fail "migrate again: found something"
ok "migrate: 1.x out of autostart, a copy kept, the rest left alone"

echo "all passed"
