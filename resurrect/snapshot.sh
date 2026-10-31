#!/bin/sh
# Saves this device's setup into a git repository, for restore.sh to bring back.
#   snapshot.sh <repo> <remote> <packages> <services> <noctalia> <share> [path...] [-- path...]
# <remote> may be empty. <packages>, <services>, <noctalia> and <share> are "true" or "false".
# Each path is a full path to a file or folder under the home folder. Paths after -- are
# kept on this device only.
#
# What the plugin saves of this device goes into devices/<hostname>/, so devices sharing one
# repository never overwrite each other. With <share>, the files go into shared/ instead,
# except the ones kept on this device, and share.sh brings in what other devices changed.
# Then every executable file in hooks/save/ runs, in name order, for the owner's own steps.
# Prints "count <what> <number>" lines, share.sh's lines, then "saved" or "unchanged", and
# "pushed".
set -u

repo=$1
remote=$2
packages=$3
services=$4
noctalia=$5
share=$6
shift 6
here=$(cd "$(dirname "$0")" && pwd)
device=$(uname -n)

# A new device starts from the remote's saves, so all devices share one history.
if [ ! -d "$repo/.git" ] && [ -n "$remote" ] && [ -z "$(ls -A "$repo" 2>/dev/null)" ] &&
  [ -n "$(git ls-remote "$remote" 2>/dev/null)" ]; then
  git clone -q "$remote" "$repo" || exit 2
fi
mkdir -p "$repo" || exit 1
cd "$repo" || exit 1
[ -d .git ] || git init -q || exit 1

# The other devices' latest saves, for share.sh: the remote's branch merged with this
# repository's own, the remote's side winning where both changed a file.
theirs=
if [ -n "$remote" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$remote"
  else
    git remote add origin "$remote"
  fi
  branch=$(git symbolic-ref --short HEAD)
  git fetch -q origin "$branch" 2>/dev/null
fi
if git rev-parse -q --verify HEAD >/dev/null; then
  theirs=HEAD
  if [ -n "$remote" ] && git rev-parse -q --verify "origin/$branch" >/dev/null; then
    theirs=$(git merge-tree --write-tree -X theirs HEAD "origin/$branch" 2>/dev/null | head -n 1)
    git cat-file -e "$theirs" 2>/dev/null || theirs=origin/$branch
  fi
elif [ -n "$remote" ] && git rev-parse -q --verify "origin/$branch" >/dev/null; then
  theirs=origin/$branch
fi

# Version 1.0 saved at the top of the repository, with a README.md it wrote itself. Only
# the files it wrote are removed: packages/exclude.txt and the like stay.
if head -n 1 README.md 2>/dev/null | grep -q '^Saved from '; then
  rm -rf README.md files noctalia/config noctalia/state services/system.txt services/user.txt \
    packages/pacman.txt packages/aur.txt packages/apt.txt packages/dnf.txt packages/flatpak.txt
  rmdir noctalia services packages 2>/dev/null || true
fi

# Version 1 kept each device's save in computers/<name>/. A folder already moved by another
# device is only removed: the next save of its device writes it again.
if [ -d computers ]; then
  for old in computers/*/; do
    [ -d "$old" ] || continue
    name=$(basename "$old")
    if [ -e "devices/$name" ]; then
      rm -rf "$old"
    else
      mkdir -p devices && mv "$old" "devices/$name"
    fi
  done
  rmdir computers 2>/dev/null || true
fi

dir=devices/$device
mkdir -p "$dir"

# Prints "count <what> <lines in the files>".
count() {
  what=$1
  shift
  echo "count $what $(cat "$@" 2>/dev/null | grep -c .)"
}

# Lines of a list you keep by hand, without comments and blank lines.
entries() {
  sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$1" 2>/dev/null
}

# Package lists, by package manager. Only what was installed on purpose, without the names
# that packages/exclude.txt matches: one regular expression per line, for the whole name.
rm -rf "$dir/packages"
if [ "$packages" = true ]; then
  mkdir -p "$dir/packages"
  exclude=$(mktemp)
  entries packages/exclude.txt >"$exclude"
  [ -s "$exclude" ] || echo '^$' >"$exclude"
  if command -v pacman >/dev/null; then
    pacman -Qqen | grep -vxEf "$exclude" >"$dir/packages/pacman.txt"
    pacman -Qqem | grep -vxEf "$exclude" >"$dir/packages/aur.txt"
  fi
  rm -f "$exclude"
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
# Links are followed, as for the dotfiles.
rm -rf "$dir/noctalia"
if [ "$noctalia" = true ]; then
  mkdir -p "$dir/noctalia/config" "$dir/noctalia/state"
  [ -d "$HOME/.config/noctalia" ] && cp -RL --preserve=mode,timestamps "$HOME/.config/noctalia/." "$dir/noctalia/config/"
  [ -f "$HOME/.local/state/noctalia/settings.toml" ] &&
    cp -L --preserve=mode,timestamps "$HOME/.local/state/noctalia/settings.toml" "$dir/noctalia/state/"
  if command -v noctalia >/dev/null; then
    noctalia msg plugins list 2>/dev/null | awk '$4 == "enabled" {print $1}' >"$dir/noctalia/plugins.txt"
    count plugins "$dir/noctalia/plugins.txt"
  fi
fi

# Dotfiles, kept at their place under the home folder. Nested git folders are left out.
# With sharing on, only the ones kept on this device are saved here.
rm -rf "$dir/files"
after=false
for path in "$@"; do
  if [ "$path" = -- ]; then
    after=true
    continue
  fi
  [ "$share" = true ] && ! $after && continue
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

if [ "$share" = true ]; then
  # Noctalia's config folder is shared like the dotfiles; its settings.toml one setting at
  # a time, when python3 is there to read TOML.
  if [ "$noctalia" = true ]; then
    sh "$here/share.sh" "$theirs" "$HOME/.config/noctalia" "$@" || exit 1
    if [ -f "$HOME/.local/state/noctalia/settings.toml" ] && command -v python3 >/dev/null; then
      their_settings=$(mktemp)
      [ -n "$theirs" ] && git show "$theirs:shared/noctalia/settings.toml" >"$their_settings" 2>/dev/null
      result=$(python3 -I "$here/settings.py" "$HOME/.local/state/noctalia/settings.toml" \
        "$their_settings" "$(git rev-parse --git-dir)/resurrect-settings") || {
        rm -f "$their_settings"
        echo "could not share Noctalia's settings"
        exit 1
      }
      rm -f "$their_settings"
      echo "$result"
      case $result in
        "settings applied 0"*) ;;
        *) command -v noctalia >/dev/null && noctalia msg config-reload >/dev/null 2>&1 ;;
      esac
    fi
  else
    sh "$here/share.sh" "$theirs" "$@" || exit 1
  fi
fi

cp "$here/restore.sh" restore.sh
chmod +x restore.sh

# The owner's own steps. Each gets the repository, this device's name and its folder.
hooks=0
if [ -d hooks/save ]; then
  for hook in hooks/save/*; do
    [ -f "$hook" ] && [ -x "$hook" ] || continue
    hooks=$((hooks + 1))
    RESURRECT_REPO=$(pwd) RESURRECT_DEVICE=$device RESURRECT_DIR=$(pwd)/$dir "$hook" ||
      { echo "hook failed: $hook"; exit 3; }
  done
fi
echo "count hooks $hooks"

git add -A

# Nothing that looks like a password or key is committed, since saves may be pushed. Known
# findings can be allowed in .gitleaksignore.
if command -v gitleaks >/dev/null &&
  ! found=$(gitleaks git --pre-commit --staged --redact --no-banner -v . 2>&1); then
  git reset -q
  echo "$found" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/^File:[[:space:]]*/secret found in: /p' | sort -u
  exit 4
fi

if git diff --cached --quiet; then
  echo "unchanged"
else
  git -c user.name="${USER:-resurrect}" -c user.email="${USER:-resurrect}@$device" \
    commit -q -m "Snapshot of $device on $(date '+%Y-%m-%d %H:%M')" || exit 1
  echo "saved"
fi

if [ -n "$remote" ]; then
  # Other devices push to the same repository. Their saves are in their own folders, and
  # share.sh already took in their shared files, so this save goes on top of theirs; a file
  # both changed keeps this device's version.
  branch=$(git symbolic-ref --short HEAD)
  if git fetch -q origin "$branch" 2>/dev/null; then
    if ! git -c user.name="${USER:-resurrect}" -c user.email="${USER:-resurrect}@$device" \
      rebase -q -X theirs "origin/$branch" >/dev/null 2>&1; then
      git rebase --abort 2>/dev/null
      echo "could not combine this save with the other devices' saves; see git status in $repo"
      exit 2
    fi
  fi
  git push -q -u origin HEAD || exit 2
  echo "pushed"
fi
