#!/usr/bin/env bash
# Copies one plugin, as it is on main, onto its branch of the fork of community-plugins and
# pushes it (DESIGN.md, section 14.2).
#   publish.sh <plugin>
# The branch is the one of the author's open pull request that touches the plugin; without
# one, it is a branch named after the plugin, made again from community-plugins' main.
# Prints only problems, and the link to open a pull request when the branch has none.
set -euo pipefail

upstream=noctalia-dev/community-plugins
fork=omerfuyar/community-plugins

if (($# != 1)); then
  echo "usage: publish.sh <plugin-directory>" >&2
  exit 2
fi
root=$(git rev-parse --show-toplevel)
cd "$root"
plugin=${1%/}

git fetch -q origin main
if ! git cat-file -e "origin/main:$plugin/plugin.toml" 2>/dev/null; then
  echo "no $plugin/plugin.toml on main: merge the plugin first" >&2
  exit 1
fi
title=$(git show "origin/main:$plugin/plugin.toml" |
  python3 -I -c 'import sys, tomllib; m = tomllib.load(sys.stdin.buffer); print(m["name"], m["version"])')

clone=${XDG_CACHE_HOME:-$HOME/.cache}/noctalia-plugins/fork
if [[ ! -d $clone/.git ]]; then
  git clone -q --filter=blob:none "https://github.com/$fork" "$clone"
  git -C "$clone" remote add upstream "https://github.com/$upstream"
fi
git -C "$clone" fetch -q origin
git -C "$clone" fetch -q upstream main

branch=$(gh pr list -R "$upstream" --author @me --state open --json headRefName,files \
  --jq ".[] | select(any(.files[]; .path | startswith(\"$plugin/\"))) | .headRefName" | head -n 1)
open=true
if [[ -z $branch ]]; then
  branch=$plugin
  open=false
  git -C "$clone" switch -q -C "$branch" upstream/main
else
  git -C "$clone" switch -q -C "$branch" "origin/$branch"
fi

rm -rf "${clone:?}/$plugin"
git archive origin/main "$plugin" | tar -x -C "$clone"
git -C "$clone" add -A -- "$plugin"
if ! git -C "$clone" diff --cached --quiet; then
  git -C "$clone" commit -q -m "$title"
fi

if $open; then
  if [[ $(git -C "$clone" rev-parse HEAD) != $(git -C "$clone" rev-parse "origin/$branch") ]]; then
    git -C "$clone" push -q origin "$branch"
  fi
elif [[ $(git -C "$clone" rev-parse HEAD) == $(git -C "$clone" rev-parse upstream/main) ]]; then
  echo "$plugin on main is the same as in community-plugins: nothing to publish" >&2
else
  git -C "$clone" push -q --force origin "$branch"
  echo "https://github.com/$upstream/compare/main...${fork%%/*}:${fork#*/}:$branch"
fi
