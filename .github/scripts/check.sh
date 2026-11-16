#!/usr/bin/env bash
# Static checks for every plugin (DESIGN.md, section 13.1). Prints only problems.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

# The validator community-plugins runs, shared from official-plugins, from a fixed commit. It
# needs langdetect, which goes into a virtual environment next to it.
upstream=99a892dc9cb3490634412701c45acd024fe0383b
tools="ignore/validator-${upstream:0:12}"
validator="$tools/validate-plugins.py"
if [[ ! -x $tools/venv/bin/python ]]; then
  mkdir -p "$tools"
  for file in validate-plugins.py requirements.txt; do
    curl -fsSL -o "$tools/$file" \
      "https://raw.githubusercontent.com/noctalia-dev/official-plugins/$upstream/.github/actions/validate-plugins/$file"
  done
  python3 -m venv "$tools/venv"
  "$tools/venv/bin/pip" install -q --disable-pip-version-check -r "$tools/requirements.txt"
fi

status=0
if ! "$tools/venv/bin/python" -I "$validator" --profile community --root "$root" >/dev/null; then
  status=1
fi

# This repository's own rules: no slow calls in panels and widgets, and no missing
# translation keys (rules.py).
python3 -I .github/scripts/rules.py || status=1

# Luau files, when luau-lsp is installed. The API types come from official-plugins, from a
# fixed commit; delete noctalia.d.luau after changing it.
types=285c6b7e793664cc66aaf4bdfbd43c5bd2f9608f
mapfile -t files < <(git ls-files --cached --others --exclude-standard -- '*.luau' ':!:noctalia.d.luau')
if ((${#files[@]})); then
  if command -v luau-lsp >/dev/null; then
    if [[ ! -f noctalia.d.luau ]]; then
      curl -fsSL -o noctalia.d.luau \
        "https://raw.githubusercontent.com/noctalia-dev/official-plugins/$types/noctalia.d.luau"
    fi
    luau-lsp analyze --platform=standard --definitions=@noctalia=noctalia.d.luau \
      --base-luaurc=.luaurc "${files[@]}" || status=1
  else
    echo "luau-lsp is not installed: Luau files were not checked" >&2
  fi
fi

exit "$status"
