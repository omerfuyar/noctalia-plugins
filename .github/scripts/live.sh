#!/usr/bin/env bash
# Live test of one plugin in the running Noctalia (DESIGN.md, section 13.2).
#   live.sh <plugin>           load the plugin, put its widgets in the bar, take a screenshot
#   live.sh --remove <plugin>  take its widgets out of the bar and disable it
# Prints the screenshot path, then the plugin's new warnings and errors from Noctalia's log.
# Otherwise prints only problems. Exits 1 when the plugin logged errors.
set -euo pipefail

remove=false
if [[ ${1:-} == --remove ]]; then
  remove=true
  shift
fi
if (($# != 1)); then
  echo "usage: live.sh [--remove] <plugin-directory>" >&2
  exit 2
fi

root=$(git rev-parse --show-toplevel)
plugin=${1%/}
manifest="$root/$plugin/plugin.toml"
if [[ ! -f $manifest ]]; then
  echo "no plugin.toml in $plugin" >&2
  exit 1
fi
if ! command -v noctalia >/dev/null; then
  echo "noctalia is not installed here: live tests run on the owner's machine" >&2
  exit 1
fi

read_manifest() {
  python3 -c '
import sys, tomllib
m = tomllib.load(open(sys.argv[1], "rb"))
print(m["id"])
for w in m.get("widget", []):
    print(m["id"] + ":" + w["id"])
' "$manifest"
}
mapfile -t lines < <(read_manifest)
id=${lines[0]}
widgets=("${lines[@]:1}")

# Adds or removes the widgets at the start of the first bar's end section.
# The change is saved in Noctalia's settings overrides, so it lasts until --remove.
bar=$(noctalia msg config-get 'bar.order[0]' | tr -d "'\"[:space:]")
place_widgets() {
  local current updated
  current=$(noctalia msg config-get "bar.$bar.end")
  updated=$(python3 -c '
import ast, sys
current = ast.literal_eval(sys.argv[2])
widgets = sys.argv[3:]
kept = [w for w in current if w not in widgets]
items = kept if sys.argv[1] == "remove" else widgets + kept
print("[" + ", ".join("\x27" + w + "\x27" for w in items) + "]")
' "$1" "$current" "${widgets[@]}")
  noctalia msg config-set "bar.$bar.end" "$updated" >/dev/null
}

if $remove; then
  ((${#widgets[@]})) && place_widgets remove
  noctalia msg plugins disable "$id" >/dev/null
  exit 0
fi

# The source "dev" is ignore/live/, which links to every plugin of the working tree.
# It is not the repository root: Noctalia reads only catalog.toml when a path source has
# one, and the root's catalog.toml lists only what is on main.
live="$root/ignore/live"
mkdir -p "$live"
find "$live" -maxdepth 1 -type l -delete
for dir in "$root"/*/; do
  if [[ -f $dir/plugin.toml ]]; then
    ln -s "../../$(basename "$dir")" "$live/$(basename "$dir")"
  fi
done
if ! grep -qxF "dev path $live" <<<"$(noctalia msg plugins source list)"; then
  noctalia msg plugins source remove dev >/dev/null 2>&1 || true
  noctalia msg plugins source add dev path "$live" >/dev/null
fi

log="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/noctalia.log"
log_start=$(stat -c %s "$log" 2>/dev/null || echo 0)

noctalia msg config-reload >/dev/null
# Disabling first makes every entry load again, so its errors land after log_start.
# The widgets leave the bar first, or the bar warns that they are unknown.
# "plugins enable" answers "ok" even when the plugin is missing, so check the list instead.
((${#widgets[@]})) && place_widgets remove
noctalia msg plugins disable "$id" >/dev/null
noctalia msg plugins enable "$id" >/dev/null
enabled=false
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if grep -qE "^$id \[dev\] [^ ]+ enabled( |$)" <<<"$(noctalia msg plugins list)"; then
    enabled=true
    break
  fi
  sleep 0.5
done
if ! $enabled; then
  echo "$id did not load from the dev source; see $log" >&2
  exit 1
fi
((${#widgets[@]})) && place_widgets add
sleep 2

# Screenshot of the focused monitor.
shots="$root/ignore/shots"
mkdir -p "$shots"
marker=$(mktemp)
noctalia msg screenshot-fullscreen --directory "$shots" --format png --save-to-file \
  --no-copy-to-clipboard --no-pipe-to-command --no-annotate --no-freeze-screen --no-show-cursor >/dev/null
shot=""
for _ in 1 2 3 4 5 6; do
  shot=$(find "$shots" -maxdepth 1 -type f -newer "$marker" -print -quit)
  [[ -n $shot ]] && break
  sleep 0.5
done
rm -f "$marker"
if [[ -z $shot ]]; then
  echo "no screenshot was saved in $shots" >&2
  exit 1
fi
echo "$shot"

# The plugin's warnings and errors since the reload. A smaller log means it was rotated.
if [[ -f $log ]]; then
  (($(stat -c %s "$log") < log_start)) && log_start=0
  problems=$(tail -c +"$((log_start + 1))" "$log" | grep -E '\[(WRN|ERR)\]' | grep -F "$id" || true)
  if [[ -n $problems ]]; then
    echo "$problems"
    grep -q '\[ERR\]' <<<"$problems" && exit 1
  fi
fi
exit 0
