#!/bin/sh
# Saves this computer's setup into a git repository, for restore.sh to bring back.
#   snapshot.sh <repo> <remote> <packages> <services> <noctalia> [path...]
# <remote> may be empty. <packages>, <services> and <noctalia> are "true" or "false".
# Each path is a full path to a file or folder under the home folder.
#
# What the plugin saves goes into computers/<hostname>/, so computers sharing one repository
# never overwrite each other, and nothing else in the repository is touched. Then every
# executable file in hooks/save/ runs, in name order, for the owner's own steps.
# Prints "count <what> <number>" lines, then "saved" or "unchanged", and "pushed".
set -u

repo=$1
remote=$2
packages=$3
services=$4
noctalia=$5
shift 5
here=$(cd "$(dirname "$0")" && pwd)
computer=$(uname -n)

mkdir -p "$repo" || exit 1
cd "$repo" || exit 1
[ -d .git ] || git init -q || exit 1

# Version 1.0 saved at the top of the repository, with a README.md it wrote itself.
if head -n 1 README.md 2>/dev/null | grep -q '^Saved from '; then
  rm -rf packages services noctalia files README.md
fi

dir=computers/$computer
mkdir -p "$dir"

# Prints "count <what> <lines in the files>".
count() {
  what=$1
  shift
  echo "count $what $(cat "$@" 2>/dev/null | grep -c .)"
}

# Package lists, by package manager. Only what was installed on purpose.
rm -rf "$dir/packages"
if [ "$packages" = true ]; then
  mkdir -p "$dir/packages"
  if command -v pacman >/dev/null; then
    pacman -Qqen >"$dir/packages/pacman.txt"
    pacman -Qqem >"$dir/packages/aur.txt"
  fi
  if command -v apt-mark >/dev/null; then
    apt-mark showmanual >"$dir/packages/apt.txt"
  fi
  if command -v dnf >/dev/null; then
    dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null >"$dir/packages/dnf.txt"
  fi
  if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application >"$dir/packages/flatpak.txt"
  fi
  count packages "$dir"/packages/*.txt
fi

# Services that start by themselves, for the system and for this user.
rm -rf "$dir/services"
if [ "$services" = true ] && command -v systemctl >/dev/null; then
  mkdir -p "$dir/services"
  systemctl list-unit-files --state=enabled --no-legend --type=service,timer,socket |
    awk '{print $1}' >"$dir/services/system.txt"
  systemctl --user list-unit-files --state=enabled --no-legend --type=service,timer,socket |
    awk '{print $1}' >"$dir/services/user.txt"
  count services "$dir/services/system.txt" "$dir/services/user.txt"
fi

# Noctalia's config, the settings changed in its settings window, and the plugins that are on.
rm -rf "$dir/noctalia"
if [ "$noctalia" = true ]; then
  mkdir -p "$dir/noctalia/config" "$dir/noctalia/state"
  [ -d "$HOME/.config/noctalia" ] && cp -a "$HOME/.config/noctalia/." "$dir/noctalia/config/"
  [ -f "$HOME/.local/state/noctalia/settings.toml" ] &&
    cp -a "$HOME/.local/state/noctalia/settings.toml" "$dir/noctalia/state/"
  if command -v noctalia >/dev/null; then
    noctalia msg plugins list 2>/dev/null | awk '$4 == "enabled" {print $1}' >"$dir/noctalia/plugins.txt"
    count plugins "$dir/noctalia/plugins.txt"
  fi
fi

# Dotfiles, kept at their place under the home folder. Nested git folders are left out.
rm -rf "$dir/files"
for path in "$@"; do
  case $path in
    "$HOME"/*) ;;
    *) echo "skipped, not in the home folder: $path"; continue ;;
  esac
  [ -e "$path" ] || { echo "skipped, missing: $path"; continue; }
  relative=${path#"$HOME"/}
  mkdir -p "$dir/files/$(dirname "$relative")"
  # Links are followed, so files kept elsewhere, as with GNU Stow, are saved themselves.
  cp -RL --preserve=mode,timestamps "$path" "$dir/files/$relative"
done
files=0
if [ -d "$dir/files" ]; then
  find "$dir/files" -name .git -prune -exec rm -rf {} +
  files=$(find "$dir/files" -type f | wc -l)
fi
echo "count files $files"

cp "$here/restore.sh" restore.sh
chmod +x restore.sh

# The owner's own steps. Each gets the repository, this computer's name and its folder.
hooks=0
if [ -d hooks/save ]; then
  for hook in hooks/save/*; do
    [ -f "$hook" ] && [ -x "$hook" ] || continue
    hooks=$((hooks + 1))
    RESURRECT_REPO=$(pwd) RESURRECT_COMPUTER=$computer RESURRECT_DIR=$(pwd)/$dir "$hook" ||
      { echo "hook failed: $hook"; exit 3; }
  done
fi
echo "count hooks $hooks"

git add -A
if git diff --cached --quiet; then
  echo "unchanged"
else
  git -c user.name="${USER:-resurrect}" -c user.email="${USER:-resurrect}@$computer" \
    commit -q -m "Snapshot of $computer on $(date '+%Y-%m-%d %H:%M')" || exit 1
  echo "saved"
fi

if [ -n "$remote" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$remote"
  else
    git remote add origin "$remote"
  fi
  git push -q -u origin HEAD || exit 2
  echo "pushed"
fi
