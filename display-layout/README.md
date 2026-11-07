# Display Layout

One place for your screens. Arrange them by dragging, set each one's resolution, refresh
rate, scale, rotation, VRR and HDR, mirror one or turn it off, and choose which workspaces
open on which screen. Each set of connected screens remembers its own layout, so plugging a
monitor in brings its layout back.

## Plugin

| Field   | Value                                                     |
| ------- | --------------------------------------------------------- |
| ID      | `omerfuyar/display-layout`                                |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

| Command   | Needed               | What for                                                   |
| --------- | -------------------- | ---------------------------------------------------------- |
| `hyprctl` | Required on Hyprland | Reads the screens and their modes, and applies the layout. |
| `niri`    | Required on niri     | The same on niri, with `niri msg`.                         |
| `swaymsg` | Required on sway     | The same on sway.                                          |

Not every compositor can do everything:

| Feature                                     | Hyprland | niri | sway |
| ------------------------------------------- | -------- | ---- | ---- |
| Arrange, resolution, refresh rate, scale    | Yes      | Yes  | Yes  |
| Rotation, VRR, turning a screen off         | Yes      | Yes  | Yes  |
| HDR                                         | Yes      | No   | No   |
| Mirroring                                   | Yes      | No   | No   |
| Workspaces on a screen                      | Yes      | No   | Yes  |

What a compositor cannot do does not show.

## Usage

Add the **Display Layout** widget to the bar and click it, or run:

```sh
noctalia msg panel-toggle omerfuyar/display-layout:panel
```

- The top of the panel shows your screens to scale, as they are arranged. Drag a screen
  onto an edge of another to put it there: left, right, above or below, lined up at the
  start, the middle or the end of that edge.
- Click a screen to change it:
  - **Resolution and refresh rate**, from the modes the screen reports.
  - **Scale**, from the scales that give whole pixels.
  - **Rotation**.
  - **VRR**: off, on, or only for full-screen apps.
  - **HDR**, on screens that support it, with the brightness of normal content while it
    is on.
  - **Mirror**, to show another screen's picture on this one.
  - **Workspaces** that open on this screen, such as `1-5`.
  - **On**, to turn the screen off and on. The last screen that is on stays on.
- Changes apply at once. A change that can leave a screen dark, such as a new
  resolution, asks **Keep this layout?** for 15 seconds. **Keep** keeps it; **Undo**, or
  doing nothing, puts the screens back as they were.
- **Reset** forgets the layout of the screens connected now, and the compositor's own
  settings apply again.

Display Layout knows a screen by its make, model and serial, never by the port it is
plugged into. Each set of connected screens, such as the laptop alone or the laptop with a
monitor, keeps its own layout. A set of screens it has not seen keeps the compositor's own
layout until you change it.

The layout applies while Noctalia runs: when Noctalia starts, when screens are plugged in
or out, and after the compositor reloads its config. Display Layout never writes the
compositor's config. Before Noctalia starts, and after the plugin is removed, the
compositor's own settings apply. Leave other display tools, such as Hyprland Settings'
Displays page or kanshi, without rules for the same screens, or they change them back.

## Settings

| Setting        | Type  | Default | Description                                                                                |
| -------------- | ----- | ------- | ------------------------------------------------------------------------------------------ |
| `keep_seconds` | `int` | `15`    | Advanced. How long **Keep this layout?** waits before it puts the screens back, in seconds. |

## IPC

Apply the remembered layout again, or answer **Keep this layout?**:

```sh
noctalia msg plugin omerfuyar/display-layout:service all apply
noctalia msg plugin omerfuyar/display-layout:service all keep
noctalia msg plugin omerfuyar/display-layout:service all undo
```
