#!/bin/sh
# Saves this system's setup into a git repository, for restore.sh to bring back.
#   snapshot.sh <repo> <remote> <packages> <services> <noctalia> [path...]
# <remote> may be empty. <packages>, <services> and <noctalia> are "true" or "false".
# Each path is a full path to a file or folder under the home folder.
set -u

repo=$1
remote=$2
packages=$3
services=$4
noctalia=$5
shift 5
here=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$repo" || exit 1
cd "$repo" || exit 1
[ -d .git ] || git init -q || exit 1

# Package lists, by package manager. Only what was installed on purpose.
rm -rf packages
if [ "$packages" = true ]; then
  mkdir -p packages
  if command -v pacman >/dev/null; then
    pacman -Qqen >packages/pacman.txt
    pacman -Qqem >packages/aur.txt
  fi
  if command -v apt-mark >/dev/null; then
    apt-mark showmanual >packages/apt.txt
  fi
  if command -v dnf >/dev/null; then
    dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null >packages/dnf.txt
  fi
  if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application >packages/flatpak.txt
  fi
fi

# Services that start by themselves, for the system and for this user.
rm -rf services
if [ "$services" = true ] && command -v systemctl >/dev/null; then
  mkdir -p services
  systemctl list-unit-files --state=enabled --no-legend --type=service,timer,socket |
    awk '{print $1}' >services/system.txt
  systemctl --user list-unit-files --state=enabled --no-legend --type=service,timer,socket |
    awk '{print $1}' >services/user.txt
fi

# Noctalia's config and the settings changed in its settings window.
rm -rf noctalia
if [ "$noctalia" = true ]; then
  mkdir -p noctalia/config noctalia/state
  [ -d "$HOME/.config/noctalia" ] && cp -a "$HOME/.config/noctalia/." noctalia/config/
  [ -f "$HOME/.local/state/noctalia/settings.toml" ] && cp -a "$HOME/.local/state/noctalia/settings.toml" noctalia/state/
fi

# Dotfiles, kept at their place under the home folder. Nested git folders are left out.
rm -rf files
for path in "$@"; do
  case $path in
    "$HOME"/*) ;;
    *) echo "skipped, not in the home folder: $path"; continue ;;
  esac
  [ -e "$path" ] || { echo "skipped, missing: $path"; continue; }
  relative=${path#"$HOME"/}
  mkdir -p "files/$(dirname "$relative")"
  # Links are followed, so files kept elsewhere, as with GNU Stow, are saved themselves.
  cp -RL --preserve=mode,timestamps "$path" "files/$relative"
done
[ -d files ] && find files -name .git -prune -exec rm -rf {} +

cp "$here/restore.sh" restore.sh
chmod +x restore.sh
printf 'Saved from %s on %s.\nRestore with: ./restore.sh\n' "$(uname -n)" "$(date '+%Y-%m-%d %H:%M')" >README.md

git add -A
if git diff --cached --quiet; then
  echo "unchanged"
else
  git -c user.name="${USER:-resurrect}" -c user.email="${USER:-resurrect}@$(uname -n)" \
    commit -q -m "Snapshot of $(uname -n) on $(date '+%Y-%m-%d %H:%M')" || exit 1
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
