# Overview

See every workspace and its windows at once, laid out as they are tiled. Click a window
to go to it, click a workspace to switch to it, and drag a window onto another workspace
to move it there.

![Overview panel](screenshots/panel.webp)

## Plugin

| Field   | Value                                                    |
| ------- | -------------------------------------------------------- |
| ID      | `omerfuyar/overview`                                     |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

| Command   | Needed   | What for                                                                                      |
| --------- | -------- | --------------------------------------------------------------------------------------------- |
| `hyprctl` | Required | Reads the workspaces and windows, and focuses and moves them. Overview works on Hyprland.     |
| `grim`    | Optional | Takes a small picture of each window. Without it, windows show as their app's icon and title. |

## Usage

Add the **Overview** widget to the bar and click it.

![Overview in the bar](screenshots/bar.webp)

- Each workspace shows its tiled windows in their places, as pictures of their content.
  Floating windows are small tiles under them.
- The active workspace and the focused window have an accent border.
- Click a window to focus it, or a workspace's title to switch to it. The overview closes.
- Drag a window onto another workspace to move it there without leaving the overview.
- Escape or a click outside closes the overview.

To open it with a key, bind the panel in Hyprland's config. With a Lua config:

```lua
hl.bind("SUPER + grave", hl.dsp.exec_cmd("noctalia msg panel-toggle omerfuyar/overview:panel"))
```

With the older config format:

```ini
bind = SUPER, grave, exec, noctalia msg panel-toggle omerfuyar/overview:panel
```

## Notes

- Pictures are taken each time the overview opens, so they show the windows as they were then. They are kept in the plugin's data folder.
- Works with both Hyprland config formats, Lua and the older one.
