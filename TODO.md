# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness work on the owner's laptop only with gamma, not with the black layer, while the desktop works with both? Test again on the laptop's new install.

## Tasks

1. Every plugin shows a missing required command in its panel, as [DESIGN.md](.claude/docs/DESIGN.md), section 9.6, says.

## Plugins

Plugins to build:

1. Display Layout. Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Remind the owner: notifications need nothing of their own, since KDE Connect already sends the phone's notifications to Noctalia, and Phone Operate covers KDE Connect's actions; recommended scope is webcam and screen only.
3. Keyboard, next versions. Version 1 switches between Hyprland's layouts and fcitx5's input methods from one list. Still to build, as decided with the owner: adding and removing layouts and input methods from the panel, the layouts kept in the plugin's settings and applied while Noctalia runs, never written to Hyprland's config, and fcitx5's through its own configuration; then an on-screen keyboard that follows the theme: wvkbd colored from Noctalia's palette, or one of the plugin's own when wvkbd still looks out of place.
4. Screen Capture. Remind the owner first. Noctalia already takes region, full screen, window and annotated screenshots. Recommended: one trigger that uses those for pictures and adds what is missing, video with `gpu-screen-recorder` or `wf-recorder` and text from the screen with `tesseract`, as an alternative to the official screen recorder.
5. System Defaults. One place for the defaults a system keeps in XDG files: the app for each file type and link, the user folders such as Downloads and Pictures, and the default terminal. The community plugin Default Apps already sets the apps for file types; check what it lacks before building, and offer its author the rest first ([DESIGN.md](.claude/docs/DESIGN.md), section 14.3).
6. Plugin Launcher. Reach any plugin without a bar widget: each enabled plugin's panels and IPC events show in Noctalia's launcher, and a key can be bound to each, added to the compositor as [DESIGN.md](.claude/docs/DESIGN.md), section 10.7, says. Check first whether Noctalia already binds keys or lists panels in its launcher.
7. Wallpaper. The owner decides later. Noctalia's official Wallhaven plugin already browses Wallhaven; a plugin here would only add what it lacks, such as Wallhaven's seed, top range, colors and collections, and new wallpapers for Noctalia's own rotation.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
