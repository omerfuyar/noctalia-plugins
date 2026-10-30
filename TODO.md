# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness not show on the owner's desktop, with gamma or with the black layer?

## Plugins

Plugins to build:

1. Display Layout. Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Remind the owner: notifications need nothing of their own, since KDE Connect already sends the phone's notifications to Noctalia, and Phone Operate covers KDE Connect's actions; recommended scope is webcam and screen only.
3. Keyboard. Remind the owner first. The built-in widget fails because fcitx5 runs a group of `keyboard-us` and `hangul` with hangul as default, and Hyprland's main keyboard is fcitx5's virtual one, so Noctalia reads that instead of the `us,tr` layouts. Recommended: one plugin that switches fcitx5 input methods when fcitx5 runs and the compositor's layouts otherwise, adds layouts, and shows an on-screen keyboard with `wvkbd`.
4. Screen Capture. Remind the owner first. Noctalia already takes region, full screen, window and annotated screenshots. Recommended: one trigger that uses those for pictures and adds what is missing, video with `gpu-screen-recorder` or `wf-recorder` and text from the screen with `tesseract`, as an alternative to the official screen recorder.
5. Process Manager. Lists processes with search and sorting, ends one, and force-ends one that does not stop. It shows no system totals, which Noctalia's system monitor already shows.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
