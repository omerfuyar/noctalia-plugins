# Resurrect

Save your system's setup to a git repository: the packages you installed, your dotfiles,
the services that start by themselves and Noctalia's settings. On a new install, one
script brings it all back.

![Resurrect panel](screenshots/panel.webp)

## Plugin

| Field   | Value                                                    |
| ------- | -------------------------------------------------------- |
| ID      | `omerfuyar/resurrect`                                    |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

| Command                                | Needed   | What for                                                                                        |
| -------------------------------------- | -------- | ----------------------------------------------------------------------------------------------- |
| `git`                                  | Required | Keeps each save as a commit, and pushes it when a remote is set. Without it, the panel says so. |
| `sh`                                   | Required | Runs the plugin's save script. It comes with every Linux system.                                |
| `systemctl`                            | Optional | Lists and restores the services that start by themselves. Without it, services are not saved.   |
| `xdg-open`                             | Optional | Opens the repository folder. Without it, that button is hidden.                                 |
| `pacman`, `apt-mark`, `dnf`, `flatpak` | Optional | List installed packages; each one the system has is used. Without any, no packages are saved.   |
| `paru` or `yay`                        | Optional | Restore AUR packages. Without them, the AUR list stays in `packages/aur.txt`.                   |

## Usage

Add the **Resurrect** widget to the bar. The setup is saved once a day, and when you
press **Save now** in the panel.

![Resurrect in the bar](screenshots/bar.webp)

- The panel shows when the setup was last saved, where, and how many packages, services,
  Noctalia plugins, dotfiles and steps of your own the last save held.
- Choose the dotfiles in the settings, such as `~/.config/hypr` and `~/.config/kitty`.
  Links are followed, so files kept elsewhere, as with GNU Stow, are saved themselves.
- To keep a copy off this computer, set **Push to** to a private git repository.
- **Restore…** opens a terminal that asks before each step.

On a new install, before anything else:

```sh
git clone <your repository> ~/resurrect
~/resurrect/restore.sh
```

The script asks which computer's save to use when there is no save of this computer, then
installs the saved packages, puts back the dotfiles and Noctalia's settings, turns on the
saved Noctalia plugins and services, and runs your own steps. It asks before each of
these, and copies any file it would replace to `~/.local/state/resurrect/backup-<date>`
first.

```sh
noctalia msg panel-toggle omerfuyar/resurrect:panel
```

### The repository

| Path                | What it holds                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------------- |
| `computers/<name>/` | What Resurrect saved on the computer with that hostname. One repository can hold several computers. |
| `hooks/save/`       | Your own steps for each save. Resurrect never changes this folder.                                  |
| `hooks/restore/`    | Your own steps for restoring. Resurrect never changes this folder.                                  |
| `restore.sh`        | The restore script, updated on each save.                                                           |

Anything else in the repository is yours too: Resurrect only writes `computers/<name>/` of
the computer it runs on, and `restore.sh`.

### Your own steps

Put an executable script in `hooks/save/` to run it on every save, and one in
`hooks/restore/` to offer it on restore. They run in name order, from the repository's
folder, with these variables:

| Variable             | Value                                                    |
| -------------------- | -------------------------------------------------------- |
| `RESURRECT_REPO`     | The repository's folder.                                 |
| `RESURRECT_COMPUTER` | The hostname of the computer whose save it is.           |
| `RESURRECT_DIR`      | That computer's folder in the repository, for its files. |

Whatever a save step writes into the repository is committed with the save. A save step
that fails stops the save, and the panel shows it. For example, to also save a database:

```sh
#!/bin/sh
# hooks/save/20-notes
cp ~/.local/share/notes/notes.db "$RESURRECT_DIR/notes.db"
```

```sh
#!/bin/sh
# hooks/restore/20-notes
mkdir -p ~/.local/share/notes
cp "$RESURRECT_DIR/notes.db" ~/.local/share/notes/notes.db
```

The panel's hooks button opens the folder and creates it when it is missing.

## Settings

| Setting    | Type          | Default              | Description                                                                |
| ---------- | ------------- | -------------------- | -------------------------------------------------------------------------- |
| `folder`   | `folder`      | `~/resurrect`        | The git repository the setup is saved in. It is created when missing.      |
| `remote`   | `string`      | `""`                 | A git remote to push each save to. Empty keeps the saves on this computer. |
| `files`    | `string_list` | `["~/.config/hypr"]` | Files and folders in the home folder to save.                              |
| `daily`    | `bool`        | `true`               | Save once a day while Noctalia runs.                                       |
| `packages` | `bool`        | `true`               | Advanced. Save the list of installed packages.                             |
| `services` | `bool`        | `true`               | Advanced. Save which services start by themselves.                         |
| `noctalia` | `bool`        | `true`               | Advanced. Save Noctalia's config and settings.                             |

## IPC

Save now:

```sh
noctalia msg plugin omerfuyar/resurrect:service all save
```

## Notes

- Do not add files with passwords, tokens or keys to the dotfiles when the repository
  is pushed, and push only to a private repository.
- Only packages installed on purpose are saved, not their dependencies.
- Each save is a git commit, so older setups stay in the repository's history.
- Saves from version 1.0, at the top of the repository, move into `computers/<name>/` on the first save.
