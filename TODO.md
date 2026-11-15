# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness work on the owner's laptop only with gamma, not with the black layer, while the desktop works with both? Test again on the laptop's new install.
3. Removing a layout in the Keyboard panel once closed Noctalia: a tooltip popup opened as the panel shrank, and Hyprland rejected it ("popup: initial roundtrip failed (compositor protocol error)"). Keyboard's ✕ buttons now have no tooltip. Is it a Noctalia bug to report, and do the other panels' buttons that vanish under the pointer need the same?

## Tasks

1. Every plugin shows a missing required command in its panel, as [DESIGN.md](.claude/docs/DESIGN.md), section 9.6, says.

## Audit

Less code, fewer dependencies, no shell where Luau can do the job. Each item goes once it is done.

### Keyboard

1. Broken in 1.4.2, cause not found: switching, the panel, the on-screen keyboard and both keys work in a live test, and the log has no error. Waits for the owner's answer.
2. `POLL` (`sh -c`): `hyprctl -j devices`, then `fcitx5-remote -n`. Two argv calls do it.
3. `DETAILS` and `CATALOG` (`sh -c` with `awk`, `sed`, `grep`): layout names from `evdev.lst`, and fcitx5's group and input methods through `gdbus`. Luau reads `evdev.lst` with `readFileAsync` once, runs `gdbus` with argv, and parses its answer.
4. `sh`, `awk`, `sed` and `grep` run but are not in `dependencies` or the README. They go with items 2 and 3.
5. `build()` runs `commandExists("wtype")` every second; once at start and on `recheck` is enough.

### Media Downloader

1. `RUNNER` (`sh -c`): starts yt-dlp detached and writes its log, pid and exit code. It stays, as the one wrapper a download needs to outlive a reload, but the pid line shrinks to `$!`: the service reads the boot id and the start time from `/proc` itself.
2. `SIGNAL` (`sh -c`): checks the pid file against the boot id and `/proc/<pid>/stat`, then signals. Luau reads those files; only `kill` runs, with argv. A check with signal 0 needs no command at all.
3. Cancelling before the pid file is written does nothing, and the job stays "cancelling" until it ends by itself. The service cancels it once the pid appears.
4. `sh` stays a dependency for `RUNNER`; `kill` and `xdg-open` stay.

### Overview

1. `CAPTURE` (`sh -c`): runs `grim` for each window. The service runs `grim` with argv, one window after another.
2. `rm -f "$1"/*.png` (`sh -c`) at start: `listDir` and `removeFile`.
3. `sh` leaves `dependencies` and the README.

### Plugin Hub

1. Bug: a plugin removed in Noctalia's settings still shows as off, and switching it on installs it again. Noctalia keeps an off plugin in `plugins/materialized/<source>/<dir>` and deletes that folder when it removes one. The hub lists an off plugin only while that folder holds its `plugin.toml`, and forgets it otherwise.
2. `DISCOVER` (`sh -c` with `awk`, `git`): the name, panels, settings and README commands of each plugin. With item 1 every listed plugin has its folder, so Luau reads its files with `readFileAsync` and parses them; the `git show` path goes.
3. `READ` in `lib/settings.luau` (`sh -c` with `awk`, `git`, `tr`): translations and setting fields. Luau reads the files and parses the manifest with `lib/toml.luau`.
4. `sh`, `awk` and `git` leave `dependencies` and the README.

### Process Manager

1. `READ` (`sh -c` with `ps`, `awk`, `cat`, `tr`, `head`, `cut`): every process, plus details of one. Luau lists `/proc` with `listDir` and reads `stat`, `status` and `cmdline` of each process, user names from `/etc/passwd`. Measure that one read of every process stays under 25 ms; if not, spread it over update ticks.
2. `getconf CLK_TCK; getconf PAGESIZE; id -u` (`sh -c`): the uid comes from `/proc/self/status`, memory from `VmRSS` in kB, so the page size is not needed; the clock rate is 100 on Linux.
3. `sh`, `ps` and `getconf` leave `dependencies` and the README; `kill`, `pkexec` and `sudo` stay.

### Resurrect

1. Eight `.sh` files and `settings.awk`, 1,900 lines, and 14 dependencies. Scope waits for the owner's answer.
2. `RUNNER` (`sh -c`) runs `snapshot.sh` detached, as a push can outlive the 60 s limit.
3. Scripts the owner runs in a terminal: `restore.sh` (also on a new install, before Noctalia), `review.sh` and `install.sh`.
4. `cmp`, `diff`, `find`, `du`, `xargs`, `mktemp`, `date` and `uname` run but are not in `dependencies` or the README.

### Screen Control

1. No shell. Its commands, `noctalia`, `hyprctl`, `hyprsunset`, `ddcutil` and `systemd-inhibit`, have no Luau replacement.

### Screen Time

1. No shell and no dependencies. Nothing to change.

### Repository

1. `rules.py` stops new `sh -c` outside an allowlist kept in it, with a reason for each entry.

## Plugins

Plugins to build:

1. Screen Control's layout on niri and sway, where a feature maps: arranging, modes, scale, rotation, VRR and turning a screen off on both, and workspaces on sway.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Remind the owner: notifications need nothing of their own, since KDE Connect already sends the phone's notifications to Noctalia, and Phone Operate covers KDE Connect's actions; recommended scope is webcam and screen only.
3. Screen Capture. Remind the owner first. Noctalia already takes region, full screen, window and annotated screenshots. Recommended: one trigger that uses those for pictures and adds what is missing, video with `gpu-screen-recorder` or `wf-recorder` and text from the screen with `tesseract`, as an alternative to the official screen recorder.
4. System Defaults. One place for the defaults a system keeps in XDG files: the app for each file type and link, the user folders such as Downloads and Pictures, and the default terminal. The community plugin Default Apps already sets the apps for file types; check what it lacks before building, and offer its author the rest first ([DESIGN.md](.claude/docs/DESIGN.md), section 14.3).
5. Wallpaper. The owner decides later. Noctalia's official Wallhaven plugin already browses Wallhaven; a plugin here would only add what it lacks, such as Wallhaven's seed, top range, colors and collections, and new wallpapers for Noctalia's own rotation.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Report to Noctalia that, in a panel with `height = "content"`, a `ui.scroll` with `flexGrow = 1` keeps the height of its first content, as its documentation does not say, so a long list is cut off instead of scrolling; and that `ui.scroll` ignores its `height`. The cause is in `ScrollView::doLayout`, which calls `setSize` while it is measured.
5. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
