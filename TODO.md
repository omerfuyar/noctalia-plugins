# TODO

Open questions and pending tasks. When one is settled, write the decision where it belongs and remove it from here.

## Open questions

1. Where does Noctalia write its log file? `live.sh` should print the plugin's new errors after a test. The console level is set with `noctalia msg log-level-set debug`.
2. Do `check.sh` and `live.sh` work as written? Both are untested on the owner's machine: the `luau-lsp analyze` flags, the `noctalia msg plugins enable` reply when a plugin is already enabled, and the screenshot options.
3. Does a path source need `catalog.toml`, or does Noctalia find plugins in its folders without it?
4. Can plugins get Hyprland events from Noctalia, or must they poll `hyprctl`?
5. Can a plugin set the night light temperature, or only switch night light on and off?
6. Does `noctalia msg brightness-set` reach external monitors?
7. Formatter for Luau: StyLua, with which settings?
8. Can Overview show live window previews? It would need a helper that streams frames to `ui.pixelStream`.

## Plugins

Each plugin of [OVERVIEW.md](OVERVIEW.md), section 4, is to be built:

1. Screen Control.
2. Downloader.
3. Agenda.
4. Overview.
5. Display Layout. First ask the author of Hyprland Settings whether these features belong in that plugin (OVERVIEW.md, section 5).
6. Phone Cam.
7. Radio. First compare with `fel/radio` and `nilsonlinux/world-radio` in community-plugins; a contribution to one of them may serve better.
8. Resurrect.

## Contributions

1. Offer the Crashes change of OVERVIEW.md, section 5, to its author.
2. Review the other community plugins the owner uses against OVERVIEW.md, section 2: Ayet Köşesi, Default Apps, Hyprland Settings, Keybind Cheatsheet, Mawaqit, Network Toolkit, NoctaProton VPN, Process Monitor and Shelly. Propose changes to their authors.

## Repository

1. Install luau-lsp in CI, so CI also checks the Luau files.
