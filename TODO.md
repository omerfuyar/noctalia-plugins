# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness not show on the owner's desktop, with gamma or with the black layer?

## Plugins

Plugins to build or change:

1. Display Layout. Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Remind the owner: notifications need nothing of their own, since KDE Connect already sends the phone's notifications to Noctalia, and Phone Operate covers KDE Connect's actions; recommended scope is webcam and screen only.
3. Keyboard. Remind the owner first. The built-in widget fails because fcitx5 runs a group of `keyboard-us` and `hangul` with hangul as default, and Hyprland's main keyboard is fcitx5's virtual one, so Noctalia reads that instead of the `us,tr` layouts. Recommended: one plugin that switches fcitx5 input methods when fcitx5 runs and the compositor's layouts otherwise, adds layouts, and shows an on-screen keyboard with `wvkbd`.
4. Resurrect shares the setup between devices, on the `feature/resurrect-share` branch. Decided with the owner:
   - "Computer" becomes "device" everywhere: `devices/<name>/` in the repository, `RESURRECT_DEVICE` for hooks. A repository with `computers/` is moved on the first save.
   - Every saved file is shared through `shared/files/`, except the paths in a new setting, "Only this device", such as monitor layouts and GPU variables. Each device gets the files the others share.
   - On each save and when Noctalia starts, Resurrect fetches and applies what other devices changed, without asking. Each file is replaced in one step, after a backup. If Hyprland then reports config errors, the files go back and a notification says so. A file changed on two devices is not overwritten: the panel shows it, with "Keep mine" and "Take theirs".
   - Noctalia's settings.toml is merged one setting at a time, against the version this device last applied; the list of enabled plugins item by item. Settings tied to one device stay on it: idle, brightness, wallpaper, Resurrect's own folder, remote and "Only this device", and anything that names a monitor. `config.toml` and palettes are shared as files.
   - Packages that other devices have and this one does not are listed in the panel, with a button that installs them in a terminal and one that keeps a package off this device.
5. Screen Capture. Remind the owner first. Noctalia already takes region, full screen, window and annotated screenshots. Recommended: one trigger that uses those for pictures and adds what is missing, video with `gpu-screen-recorder` or `wf-recorder` and text from the screen with `tesseract`, as an alternative to the official screen recorder.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
