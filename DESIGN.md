# Design

How the plugins are built. What they are and why is in [OVERVIEW.md](OVERVIEW.md).

## Contents

1. [Code conventions](#1-code-conventions)
2. [Repository layout](#2-repository-layout)
3. [Plugin manifest](#3-plugin-manifest)
4. [Architecture](#4-architecture)
5. [Bar widget](#5-bar-widget)
6. [Panel](#6-panel)
7. [Look and feel](#7-look-and-feel)
8. [Settings](#8-settings)
9. [Dependencies and setup](#9-dependencies-and-setup)
10. [Noctalia and external commands](#10-noctalia-and-external-commands)
11. [Data and state](#11-data-and-state)
12. [Text and translations](#12-text-and-translations)
13. [Checks and testing](#13-checks-and-testing)
14. [Publishing](#14-publishing)
15. [Glossary](#15-glossary)

## 1. Code conventions

1. Plugins are written in Luau for Noctalia v5. Each entry script starts with `--!nonstrict`, the mode `.luaurc` sets.
2. Entry scripts are named after their entry kind: `widget.luau`, `panel.luau`, `service.luau`, `shortcut.luau`, `launcher.luau`, `layer.luau`. A plugin with two entries of one kind adds a word: `panel_setup.luau`.
3. Code that more than one entry uses lives in `lib/` and is loaded with `require("./lib/<name>.luau")`.
4. Names: `camelCase` for variables and functions, as in Noctalia's API; `PascalCase` for types; `UPPER_SNAKE_CASE` for constants.
5. The top level of a script only sets up state and watchers. Work happens in callbacks.
6. UI callbacks are functions, not names of global functions.
7. Code is plain and readable. No generated, minified or obfuscated code.

## 2. Repository layout

1. Each plugin is one top-level directory. Its name is the part of the plugin id after `/`: `omerfuyar/agenda` lives in `agenda/`.
2. A directory name must also be free in community-plugins, where names are first come, first served. Before a plugin is created, its name is checked there.
3. A plugin directory holds:
   - `plugin.toml`, the manifest (section 3);
   - the entry scripts and `lib/` (section 1);
   - `translations/en.json` (section 12);
   - `README.md` and `thumbnail.webp` (section 14.2);
   - any other files its scripts read, such as sounds or helper scripts.
4. A plugin directory holds at most 200 files.

## 3. Plugin manifest

1. `id` is `omerfuyar/<directory>`. `author` is `omerfuyar`. `license` is `MIT`.
2. `version` is `MAJOR.MINOR.PATCH` and goes up with every change to the plugin.
3. A new plugin sets `plugin_api` to the newest level Noctalia documents. Later it is raised only when the plugin starts to use something a newer level adds.
4. `description` is at most 120 characters. Details go in the plugin's README.
5. `tags` is required and uses only the tags community-plugins allows.
6. `icon` is a Tabler glyph name.
7. `dependencies` lists every external command the plugin runs (section 9).

## 4. Architecture

1. A plugin with data to fetch has a `service.luau`. The service is the only entry that fetches. It keeps a model, as plain data, in `noctalia.state`.
2. The widget and the panel watch the model with `noctalia.state.watch` and only render it.
3. A user action in the widget or panel either runs one command directly or asks the service through `noctalia.state`.
4. A plugin with nothing to fetch has no service.

```
service.luau ── fetches ──► noctalia.state ──► widget.luau (bar)
                                         └───► panel.luau  (details and controls)
```

## 5. Bar widget

1. The bar widget is each plugin's main surface.
2. It shows one glyph and, when there is room, a short text. On a vertical bar it shows only the glyph.
3. A tooltip gives the details that do not fit.
4. Left click opens the plugin's panel. Scroll changes the plugin's main value when it has one, such as brightness. Middle click keeps Noctalia's default: the widget's settings.
5. When setup is needed, the widget shows a warning glyph, and its click opens the setup card (section 9).
6. When there is nothing to show, the widget hides instead of showing zeros or errors.

## 6. Panel

1. The panel holds the details and controls that do not fit the bar.
2. Its height follows its content, up to a limit.
3. Long lists scroll inside the panel.
4. It shows a placeholder while data loads, and never an empty frame.

## 7. Look and feel

1. Colors are palette roles, such as `primary`, `on_surface` or `surface_container/0.6`. UI code has no hex colors, so plugins follow every theme and light or dark mode.
2. Sizes use `controlSize` and Noctalia's default fonts. In the bar, labels and glyphs inherit the bar's font and color.
3. Icons are Tabler glyphs, as in Noctalia's own widgets.
4. Button variants follow their meaning: `primary` for the main action, `destructive` for actions that delete or stop, `ghost` for small actions.
5. Nothing depends on one machine. Monitors come from `noctalia.outputs()`, paths from `noctalia.expandPath` and `noctalia.pluginDataDir()`.

## 8. Settings

1. Every setting is declared in `plugin.toml` with a type and a default that works for most people.
2. A plugin has few settings. Rarely used ones are `advanced`.
3. A setting that only matters for one choice of another setting uses `visible_when`.
4. Settings that change how the bar widget looks are widget settings. All others are plugin settings.

## 9. Dependencies and setup

1. A plugin first uses what Noctalia provides (section 10). It runs an external command only when Noctalia cannot do the job.
2. Every external command is listed in `dependencies` and in the README's Requirements.
3. On start, the service checks each required command with `noctalia.commandExists`.
4. When something is missing, the panel shows a setup card in place of its normal content. The card names what is missing and has one button that installs it in a terminal with `noctalia.runInTerminal`. The bar widget shows the setup state as section 5 says.
5. One-time setup that needs root, such as loading a kernel module, uses the same card.
6. A missing optional command only hides the feature that needs it.

## 10. Noctalia and external commands

1. Noctalia's runtime API covers monitors, wallpaper, calendar events, system stats, idle time, notifications, the on-screen display, sounds, files, HTTP and downloads. Plugins use it before any external command.
2. Shell features, such as brightness and night light, are reached with `noctalia msg` through `noctalia.runAsync`.
3. Hyprland is reached with `hyprctl -j` through `noctalia.runAsync`.
4. Commands with any changing value use the argument list form of `noctalia.runAsync`, never a shell string.
5. Nothing blocks. Commands, HTTP and file reads are asynchronous, and the UI renders again when their results arrive.

## 11. Data and state

1. Data shared between a plugin's entries is in `noctalia.state`. It lives in memory only.
2. Data that must survive a restart is JSON in `noctalia.pluginDataDir()`. Nothing is written to the plugin's own directory, because updates replace it.
3. Remote images are downloaded to the data directory before they are shown.

## 12. Text and translations

1. Every text the user sees goes through `noctalia.tr` or `noctalia.trp`.
2. `translations/en.json` holds every key, including each setting's `label_key` and `description_key`.
3. Only English is written here. Other languages come from Noctalia's translation service.

## 13. Checks and testing

### 13.1 Static checks

`.github/scripts/check.sh` checks every plugin without running Noctalia:

1. It runs the validator of community-plugins, from a fixed commit, on this repository. The validator checks manifests, entry scripts, translations, READMEs and thumbnails as community-plugins does.
2. When luau-lsp is installed, it checks every Luau file against `noctalia.d.luau`, which it fetches from official-plugins when it is missing.
3. Fetched files go to `ignore/` and are not committed.

### 13.2 Live test

`.github/scripts/live.sh <plugin>` tests one plugin in the running Noctalia:

1. It adds the repository as the plugin source `dev`, the first time.
2. It reloads Noctalia's config and enables the plugin. Because `dev` is a path source, Noctalia loads the plugin from the working tree, and later edits to Luau files reload by themselves.
3. It takes a screenshot of the focused monitor into `ignore/shots/` and prints its path, so the agent can look at the result.

Panels and IPC events are tested with `noctalia msg panel-toggle <id>:<panel>` and `noctalia msg plugin <id>:<entry> <target> <event> [payload]`, followed by another screenshot.

### 13.3 The owner's machine

1. Live tests run only on the owner's machine, where Noctalia runs. The clone lives there, and Claude Code works on it either by running there or from a cloud session attached to the folder through Remote Control.
2. The machine needs `noctalia`, `git`, `python3` and `curl`. `luau-lsp` is optional.

### 13.4 CI

On every pull request, CI runs `check.sh`.

## 14. Publishing

### 14.1 This repository as a source

1. Anyone can add the repository to Noctalia as a git plugin source and install its plugins.
2. `catalog.toml` is the source's index. On every push to `main`, CI generates it with the catalog script of community-plugins, from the same fixed commit as the validator, and commits it.

### 14.2 community-plugins

1. A finished plugin is offered to community-plugins in its own pull request, unchanged.
2. Its `README.md` follows the template of community-plugins: a title, a short explanation, the plugin table, Usage, Requirements, Settings, and IPC and Notes when needed.
3. `thumbnail.webp` is 960 × 540 pixels and made with the thumbnail generator that community-plugins links.
4. A plugin with a visible surface has screenshots in its README.

### 14.3 Other authors' plugins

1. A plugin directory in community-plugins belongs to its author. A change to it needs the author's approval.
2. A change is offered as an issue or pull request that mentions the author.
3. When the author does not answer or does not agree, the feature becomes a plugin here under a new name, and its README credits the original.

## 15. Glossary

| Term              | Meaning                                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| Bar widget        | A plugin's item in Noctalia's bar: the `[[widget]]` entry.                                              |
| community-plugins | The repository `noctalia-dev/community-plugins`, Noctalia's store of community plugins.                 |
| Entry             | One part of a plugin, such as a bar widget, panel or service, with its own script.                      |
| IPC               | Commands sent to the running Noctalia with `noctalia msg`.                                              |
| luau-lsp          | The Luau language server. Its `analyze` command checks Luau files from the command line.                |
| official-plugins  | The repository `noctalia-dev/official-plugins`, plugins by Noctalia's team. It holds `noctalia.d.luau`. |
| Palette role      | A named color of the user's theme, such as `primary`.                                                   |
| Panel             | A plugin's pop-up surface: the `[[panel]]` entry.                                                       |
| Path source       | A plugin source that is a local folder. Noctalia reads its plugins straight from the folder.            |
| Service           | A plugin's background entry with no UI: the `[[service]]` entry.                                        |
| Setup card        | The panel content that names a missing requirement and offers to install it.                            |
