#!/usr/bin/env bash
# Live test of one plugin in the running Noctalia (DESIGN.md, section 13.2).
# Prints the path of a screenshot taken after the plugin loads. Otherwise prints only problems.
set -euo pipefail

if (($# != 1)); then
  echo "usage: live.sh <plugin-directory>" >&2
  exit 2
fi

root=$(git rev-parse --show-toplevel)
manifest="$root/${1%/}/plugin.toml"
if [[ ! -f $manifest ]]; then
  echo "no plugin.toml in $1" >&2
  exit 1
fi
if ! command -v noctalia >/dev/null; then
  echo "noctalia is not installed here: live tests run on the owner's machine" >&2
  exit 1
fi

id=$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["id"])' "$manifest")

# Load plugins straight from this working tree.
if ! noctalia msg plugins source list | grep -qF "$root"; then
  noctalia msg plugins source add dev path "$root" >/dev/null
fi
noctalia msg config-reload >/dev/null
noctalia msg plugins enable "$id" >/dev/null
sleep 1

# Screenshot of the focused monitor.
shots="$root/ignore/shots"
mkdir -p "$shots"
marker=$(mktemp)
noctalia msg screenshot-fullscreen --directory "$shots" --format png --save-to-file \
  --no-copy-to-clipboard --no-pipe-to-command --no-annotate --no-freeze-screen --no-show-cursor >/dev/null
sleep 1
shot=$(find "$shots" -maxdepth 1 -type f -newer "$marker" -print | head -n 1)
rm -f "$marker"
if [[ -z $shot ]]; then
  echo "no screenshot was saved in $shots" >&2
  exit 1
fi
echo "$shot"
