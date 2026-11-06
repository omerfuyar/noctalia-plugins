# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness work on the owner's laptop only with gamma, not with the black layer, while the desktop works with both? Test again on the laptop's new install.

## Tasks

1. Every plugin shows a missing required command in its panel, as [DESIGN.md](.claude/docs/DESIGN.md), section 9.6, says.
2. Resurrect keeps one source of truth when sharing is on. Decided with the owner:
   - `shared/` holds the dotfiles, the settings, one package list per package manager, the service lists, and what the shared hooks save.
   - `devices/<name>/` holds only what differs: `exclude.txt`, the shared packages and services this device leaves out, in place of `skip.txt`; `extra.txt`, the packages only this device keeps; `files/`, for **Only this device**; `settings.toml`, the settings tied to the hardware; and the device's own hooks. The full copies of the package and service lists, Noctalia's config, `settings.toml` and `plugins.txt` go.
   - A package installed on one device joins the shared list. Other devices list it in the panel, with **Install…** and **Not here**, which adds it to `exclude.txt`.
   - A package uninstalled on one device leaves the shared list. A device that still has it does not add it back by itself: the panel lists it, with **Share again** and **Only here**, which adds it to `extra.txt`. Services follow the same rules.
   - `hooks/` holds the shared hooks, which run on every device and save into `shared/`. `devices/<name>/hooks/` holds that device's own hooks, which save into its folder. The owner's dconf, VS Code and language, timezone and keyboard hooks become shared hooks.
   - A new install restores `shared/` and its own device folder when there is one, without asking which device to copy.
   - A repository in the current layout moves to this one on its next save.

## Plugins

Plugins to build:

1. Display Layout. Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Remind the owner: notifications need nothing of their own, since KDE Connect already sends the phone's notifications to Noctalia, and Phone Operate covers KDE Connect's actions; recommended scope is webcam and screen only.
3. Keyboard. Remind the owner first. The built-in widget fails because fcitx5 runs a group of `keyboard-us` and `hangul` with hangul as default, and Hyprland's main keyboard is fcitx5's virtual one, so Noctalia reads that instead of the `us,tr` layouts. Recommended: one plugin that switches fcitx5 input methods when fcitx5 runs and the compositor's layouts otherwise, adds layouts, and shows an on-screen keyboard with `wvkbd`.
4. Screen Capture. Remind the owner first. Noctalia already takes region, full screen, window and annotated screenshots. Recommended: one trigger that uses those for pictures and adds what is missing, video with `gpu-screen-recorder` or `wf-recorder` and text from the screen with `tesseract`, as an alternative to the official screen recorder.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
