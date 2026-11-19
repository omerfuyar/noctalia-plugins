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

# Luau files, with luau-lsp from a fixed release, checked against its checksum. The API types
# come from official-plugins, from a fixed commit; delete noctalia.d.luau after changing it.
types=285c6b7e793664cc66aaf4bdfbd43c5bd2f9608f
lsp_version=1.70.1
lsp_sha256=1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567
lsp_dir="ignore/luau-lsp-$lsp_version"
lsp="$lsp_dir/luau-lsp"
if [[ ! -x $lsp ]]; then
  if [[ $(uname -sm) != "Linux x86_64" ]]; then
    echo "luau-lsp is only fetched on Linux x86_64: Luau files were not checked" >&2
    exit 1
  fi
  mkdir -p "$lsp_dir"
  curl -fsSL -o "$lsp_dir/luau-lsp.zip" \
    "https://github.com/JohnnyMorganz/luau-lsp/releases/download/$lsp_version/luau-lsp-linux-x86_64.zip"
  echo "$lsp_sha256  $lsp_dir/luau-lsp.zip" | sha256sum -c --quiet
  python3 -I -m zipfile -e "$lsp_dir/luau-lsp.zip" "$lsp_dir"
  chmod +x "$lsp"
fi
mapfile -t files < <(git ls-files --cached --others --exclude-standard -- '*.luau' ':!:noctalia.d.luau')
if ((${#files[@]})); then
  if [[ ! -f noctalia.d.luau ]]; then
    curl -fsSL -o noctalia.d.luau \
      "https://raw.githubusercontent.com/noctalia-dev/official-plugins/$types/noctalia.d.luau"
  fi
  # luau-lsp's [INFO] lines are not problems.
  if ! "$lsp" analyze --platform=standard --definitions=@noctalia=noctalia.d.luau \
    --base-luaurc=.luaurc "${files[@]}" >"$lsp_dir/output" 2>&1; then
    status=1
  fi
  grep -v '^\[INFO\]' "$lsp_dir/output" >&2 || true
fi

exit "$status"
