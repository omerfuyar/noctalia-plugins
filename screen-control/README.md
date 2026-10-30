# Screen Control

One bar item for everything about your screens: the brightness of each monitor, dimming
further than the lowest brightness, night light with its schedule, and caffeine. Each
workspace can also keep its own dimming.

![Screen Control panel](screenshots/panel.webp)

## Plugin

| Field   | Value                                                                  |
| ------- | ---------------------------------------------------------------------- |
| ID      | `omerfuyar/screen-control`                                             |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service`; layer: `dim` |

## Requirements

| Command      | Needed   | What for                                                                                                                                                  |
| ------------ | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `noctalia`   | Required | Sets brightness, night light and caffeine, which are Noctalia's own.                                                                                      |
| `hyprsunset` | Optional | Dims below the lowest brightness by lowering the gamma, on Hyprland. The plugin starts it when it is not running. Without it, a black layer dims instead. |
| `hyprctl`    | Optional | Talks to hyprsunset, and finds the workspace on each monitor. Without it, a black layer dims, and each workspace cannot keep its own dimming.             |
| `ddcutil`    | Optional | Reads the brightness of external monitors; Noctalia uses it too, when **Brightness → ddcutil** is on. Without it, external monitors can still be dimmed.  |

## Usage

Add the **Screen Control** widget to the bar. It shows a sun, or a moon while night light
is on, and turns the accent color while its monitor is dimmed.

![Screen Control in the bar, with night light on](screenshots/bar.webp)

- Scroll on the widget to change the brightness of the monitor the bar is on. Below the
  lowest brightness, scrolling down dims further.
- Click it to open the panel. Each monitor has one slider: its right part is the
  brightness, and its left part dims below the lowest brightness ("Dim 30%").
- Under **Night light**, pick **Off**, **Scheduled** or **On**, and set the warmth.
  **Scheduled** runs from sunset to sunrise where Noctalia's location is; turn on
  **Set the times myself** to type a start and end time instead, such as `21:30` and
  `07:00`.
- **Caffeine** keeps the screen on and stops it from locking, using Noctalia's caffeine.

```sh
noctalia msg panel-toggle omerfuyar/screen-control:panel
```

## Settings

| Setting         | Type     | Default | Description                                                                                                                                                                 |
| --------------- | -------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `max_dim`       | `int`    | `75`    | How dark the screens can get below their lowest brightness, in percent.                                                                                                     |
| `dim_method`    | `select` | `gamma` | How the screens get darker below their lowest brightness: `gamma`, with hyprsunset, or `overlay`, a black layer. Gamma falls back to the layer where hyprsunset is missing. |
| `per_workspace` | `bool`   | `false` | Each workspace keeps its own dimming. Needs Hyprland.                                                                                                                       |

## IPC

Move the focused monitor up or down the same scale as the slider, by 5% or by the given
percent. Bound to the brightness keys, this dims past the lowest brightness.

```sh
noctalia msg plugin omerfuyar/screen-control:service all up
noctalia msg plugin omerfuyar/screen-control:service all down 10
```

Set night light, or switch caffeine on and off:

```sh
noctalia msg plugin omerfuyar/screen-control:service all night scheduled
noctalia msg plugin omerfuyar/screen-control:service all caffeine
```

## Notes

- Gamma dimming is one level for all screens, since hyprsunset sets every screen alike.
  It does not show in screenshots or recordings. When the plugin stops, gamma goes back
  to full.
- Night light and its times are Noctalia's own settings, so they stay after a restart.
  Custom times also set when Noctalia's automatic dark mode switches. Noctalia's own
  night light widget switches a temporary state that plugins cannot read, so the panel
  may not match it until night light is changed here or in Noctalia's settings.
- Noctalia cannot report caffeine, so the panel shows it as this plugin last set it. When
  Noctalia restarts with caffeine on here, the plugin turns it on again.
- The black layer dims each screen on its own, but also darkens screenshots.
- The lowest brightness is Noctalia's **Minimum brightness**, but never below 1%, since
  some backlights turn off at 0.
