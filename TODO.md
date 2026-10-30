# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Formatter for Luau: StyLua, with which settings?
2. Why does dimming below the lowest brightness not show on the owner's desktop, with gamma or with the black layer?

## Plugins

Plugins to build:

1. Display Layout. Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.
2. Phone Hub. Becomes the plugin on the `feature/phone-cam` branch: phone screen and phone as a webcam, both with scrcpy. When Iriun Webcam's camera is in use, Phone Hub leaves it alone and says so. Agree on the rest of the scope with the owner, such as notifications.
3. Keyboard. Switches keyboard layouts and input methods (fcitx5) in one place, adds layouts, and shows an on-screen keyboard. Discuss scope with the owner first.
4. Screen Capture. One trigger for a region or the whole screen, as a picture, a video or extracted text. Discuss scope with the owner first.

## Contributions

1. Ask Noctalia, in a feature request, for a plugin API to workspaces and windows, and to read brightness and caffeine. Plugins would then work on every compositor without their own commands.
2. Offer `[[layer]]` support to the validator of community-plugins. Until it has it, Screen Control cannot be offered there ([DESIGN.md](.claude/docs/DESIGN.md), section 13.1).
3. Offer Crashes a change to its author: also show failed services and errors from the system log since boot, and make the AI diagnosis optional.
4. Review the other community plugins the owner uses against the principles in README.md: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.
