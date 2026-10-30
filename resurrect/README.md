# Resurrect

Save your system's setup to a git repository: the packages you installed, your dotfiles,
the services that start by themselves and Noctalia's settings. On a new install, one
script brings it all back.

![Resurrect panel](screenshots/panel.webp)

## Plugin

| Field | Value |
| --- | --- |
| ID | `omerfuyar/resurrect` |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

- `git` keeps the saves. Without it, the panel says so.
- `sh` runs the plugin's save script, and `systemctl` lists the services.
- `xdg-open` opens the repository folder. Without it, that button is hidden.
- Package lists come from whichever of `pacman`, `apt`, `dnf` and `flatpak` the system
  has. Restoring AUR packages needs `paru` or `yay`.

## Usage

Add the **Resurrect** widget to the bar. The setup is saved once a day, and when you
press **Save now** in the panel.

![Resurrect in the bar](screenshots/bar.webp)

- The panel shows when the setup was last saved, where, and what each save holds.
- Choose the dotfiles in the settings, such as `~/.config/hypr` and `~/.config/kitty`.
  Links are followed, so files kept elsewhere, as with GNU Stow, are saved themselves.
- To keep a copy off this computer, set **Push to** to a private git repository.
- **Restore…** opens a terminal that asks before each step.

On a new install, before anything else:

```sh
git clone <your repository> ~/resurrect
~/resurrect/restore.sh
```

The script installs the saved packages, puts back the dotfiles and Noctalia's settings,
and turns on the saved services. It asks before each of these steps, and copies any file
it would replace to `~/.local/state/resurrect/backup-<date>` first.

```sh
noctalia msg panel-toggle omerfuyar/resurrect:panel
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `folder` | `folder` | `~/resurrect` | The git repository the setup is saved in. It is created when missing. |
| `remote` | `string` | `""` | A git remote to push each save to. Empty keeps the saves on this computer. |
| `files` | `string_list` | `["~/.config/hypr"]` | Files and folders in the home folder to save. |
| `daily` | `bool` | `true` | Save once a day while Noctalia runs. |
| `packages` | `bool` | `true` | Advanced. Save the list of installed packages. |
| `services` | `bool` | `true` | Advanced. Save which services start by themselves. |
| `noctalia` | `bool` | `true` | Advanced. Save Noctalia's config and settings. |

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
- Based on ideas from Omarchy's resurrect plugin.
