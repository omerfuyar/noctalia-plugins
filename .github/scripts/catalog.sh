#!/usr/bin/env bash
# Generates catalog.toml (DESIGN.md, section 14.1). CI runs it on main. Prints only problems.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

# The catalog script of noctalia-dev/community-plugins, from the same commit as check.sh.
# It finds the repository root three directories above itself, so it must stay at this depth.
upstream=cd454463cdafa8684e7e886fd9bd9bc99b51b462
tools="ignore/upstream-${upstream:0:12}/scripts"
script="$tools/update-catalog.py"
if [[ ! -f $script ]]; then
  mkdir -p "$tools"
  curl -fsSL -o "$script" \
    "https://raw.githubusercontent.com/noctalia-dev/community-plugins/$upstream/.github/workflows/scripts/update-catalog.py"
fi

python3 -I "$script" >/dev/null
