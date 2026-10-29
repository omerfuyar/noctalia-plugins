#!/usr/bin/env bash
# Static checks for every plugin (DESIGN.md, section 13.1). Prints only problems.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

# The validator of noctalia-dev/community-plugins, from a fixed commit.
upstream=cd454463cdafa8684e7e886fd9bd9bc99b51b462
tools="ignore/upstream-${upstream:0:12}/scripts"
validator="$tools/validate-plugins.py"
if [[ ! -f $validator ]]; then
  mkdir -p "$tools"
  curl -fsSL -o "$validator" \
    "https://raw.githubusercontent.com/noctalia-dev/community-plugins/$upstream/.github/workflows/scripts/validate-plugins.py"
fi

status=0
python3 -I "$validator" --root "$root" >/dev/null || status=1

# Luau files, when luau-lsp is installed.
if command -v luau-lsp >/dev/null; then
  if [[ ! -f noctalia.d.luau ]]; then
    curl -fsSL -o noctalia.d.luau \
      https://raw.githubusercontent.com/noctalia-dev/official-plugins/main/noctalia.d.luau
  fi
  mapfile -t files < <(git ls-files --cached --others --exclude-standard -- '*.luau' ':!:noctalia.d.luau')
  if ((${#files[@]})); then
    luau-lsp analyze --platform=standard --definitions=noctalia.d.luau --base-luaurc=.luaurc "${files[@]}" || status=1
  fi
fi

exit "$status"
