#!/bin/sh
# Brings back a setup saved by Resurrect, on this device. Run it from the saved
# repository: ./restore.sh
# It asks which device's save to use, then before each step. Files it would replace are
# first copied to a backup folder. Last, it offers each of the owner's hooks/restore/ steps.
set -u

cd "$(dirname "$0")" || exit 1
repo=$(pwd)
backup=$HOME/.local/state/resurrect/backup-$(date '+%Y%m%d-%H%M%S')

ask() {
  printf '\n%s [y/N] ' "$1"
  read -r answer
  [ "$answer" = y ] || [ "$answer" = Y ]
}

# Copies the content of folder $1 over folder $2, which is under the home folder. A file
# that is already there is first copied to the same place under $backup.
put_back() {
  source=$1
  target=$2
  relative=${target#"$HOME"}
  (cd "$source" && find . -type f -o -type l) | while read -r file; do
    file=${file#./}
    if [ -e "$target/$file" ]; then
      mkdir -p "$(dirname "$backup$relative/$file")"
      cp -a "$target/$file" "$backup$relative/$file"
    fi
    mkdir -p "$(dirname "$target/$file")"
    cp -a "$source/$file" "$target/$file"
  done
}

# This device's own save when there is one, the only one, or the one the user picks.
device=$(uname -n)
if [ ! -d "devices/$device" ]; then
  set --
  for folder in devices/*/; do
    [ -d "$folder" ] && set -- "$@" "$(basename "$folder")"
  done
  if [ $# -eq 1 ]; then
    device=$1
  elif [ $# -gt 1 ]; then
    echo "Saves of these devices are here: $*"
    printf 'Which one should this device get? '
    read -r device
  fi
fi
if [ -d "devices/$device" ]; then
  echo "Restoring the save of $device."
  cd "devices/$device" || exit 1
fi

if [ -d packages ] && ask "Install the saved packages?"; then
  if [ -f packages/pacman.txt ] && command -v pacman >/dev/null; then
    # shellcheck disable=SC2024 # the list is read by this user, not by root
    sudo pacman -S --needed - <packages/pacman.txt
  fi
  # Packages kept by hand in the repository's packages/extra.txt, such as ones pacman
  # counts as dependencies and so leaves out of the saved lists.
  if [ -f "$repo/packages/extra.txt" ] && command -v pacman >/dev/null; then
    sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$repo/packages/extra.txt" | sudo pacman -S --needed -
  fi
  if [ -s packages/aur.txt ]; then
    helper=$(command -v paru || command -v yay || true)
    if [ -n "$helper" ]; then
      "$helper" -S --needed - <packages/aur.txt
    else
      echo "AUR packages need paru or yay; they are listed in packages/aur.txt."
    fi
  fi
  if [ -f packages/apt.txt ] && command -v apt-get >/dev/null; then
    xargs -a packages/apt.txt sudo apt-get install -y
  fi
  if [ -f packages/dnf.txt ] && command -v dnf >/dev/null; then
    xargs -a packages/dnf.txt sudo dnf install -y
  fi
  if [ -s packages/flatpak.txt ] && command -v flatpak >/dev/null; then
    xargs -a packages/flatpak.txt flatpak install -y
  fi
fi

# Files shared between devices first, then this device's own, which win.
if { [ -d "$repo/shared/files" ] || [ -d files ]; } &&
  ask "Put back the saved dotfiles? Replaced files go to $backup"; then
  [ -d "$repo/shared/files" ] && put_back "$repo/shared/files" "$HOME"
  [ -d files ] && put_back files "$HOME"
fi

if [ -d noctalia ] && ask "Put back Noctalia's settings?"; then
  [ -d noctalia/config ] && put_back noctalia/config "$HOME/.config/noctalia"
  [ -d noctalia/state ] && put_back noctalia/state "$HOME/.local/state/noctalia"
fi

if [ -s noctalia/plugins.txt ] && command -v noctalia >/dev/null &&
  ask "Turn on the saved Noctalia plugins? Noctalia must be running."; then
  while read -r plugin; do
    noctalia msg plugins enable "$plugin" >/dev/null || echo "skipped: $plugin"
  done <noctalia/plugins.txt
fi

if [ -d services ] && ask "Turn on the saved services?"; then
  # One at a time, so a unit this system does not have does not stop the others.
  [ -f services/system.txt ] && while read -r unit; do
    sudo systemctl enable "$unit" 2>/dev/null || echo "skipped: $unit"
  done <services/system.txt
  [ -f services/user.txt ] && while read -r unit; do
    systemctl --user enable "$unit" 2>/dev/null || echo "skipped: $unit"
  done <services/user.txt
fi

# The owner's own steps, in name order, each with the same variables as when saving.
cd "$repo" || exit 1
if [ -d hooks/restore ]; then
  for hook in hooks/restore/*; do
    [ -f "$hook" ] && [ -x "$hook" ] || continue
    if ask "Run your step $(basename "$hook")?"; then
      RESURRECT_REPO=$repo RESURRECT_DEVICE=$device RESURRECT_DIR=$repo/devices/$device "$hook" ||
        echo "The step $(basename "$hook") failed."
    fi
  done
fi

[ -d "$backup" ] && echo "Replaced files were saved in $backup."
echo "Done. Log out and back in to load everything."
printf 'Press Enter to close. '
read -r _
