# Keyboard

Switch between every language you type in from one list: your keyboard layouts and fcitx5's
input methods, such as Hangul for Korean. Noctalia's own layout widget shows only the
compositor's layouts.

## Plugin

| Field   | Value                                                    |
| ------- | -------------------------------------------------------- |
| ID      | `omerfuyar/keyboard`                                     |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

| Command         | Needed               | What for                                                                                      |
| --------------- | -------------------- | --------------------------------------------------------------------------------------------- |
| `hyprctl`       | Required on Hyprland | Reads the keyboard layouts and switches every keyboard between them, and adds the switch key. |
| `fcitx5-remote` | Required with fcitx5 | Reads and switches fcitx5's input method. Without fcitx5, the list holds only the layouts.    |
| `gdbus`         | Required with fcitx5 | Reads fcitx5's input methods and their names. It comes with GLib.                             |

## Usage

Add the **Keyboard** widget to the bar. It shows the language you type in, such as `EN`,
`TR` or `KO`.

![Keyboard in the bar](screenshots/bar.webp)

- Right click or scroll on the widget to switch to the next language.
- Click it to see the whole list and pick one. Each keyboard layout of Hyprland's main
  keyboard is in it, and each fcitx5 input method that is more than a plain keyboard, such as
  Hangul, or that holds a layout Hyprland does not have.
- Picking a layout switches every keyboard to it, and puts fcitx5 back on plain typing.
  Picking an input method switches fcitx5 to it.
- Set **Switch key** in the settings, such as `SUPER + Space`, to switch from the keyboard.
  Keyboard adds it to Hyprland while Noctalia runs and leaves your config alone; a key that
  is already bound stays as it is.

```sh
noctalia msg panel-toggle omerfuyar/keyboard:panel
```

## Settings

| Setting   | Type     | Default | Description                                                                           |
| --------- | -------- | ------- | ------------------------------------------------------------------------------------- |
| `keybind` | `string` | `""`    | A key that switches to the next language, such as `SUPER + Space`. Empty adds no key. |

## IPC

Switch to the next or previous language, or to one by its short name:

```sh
noctalia msg plugin omerfuyar/keyboard:service all next
noctalia msg plugin omerfuyar/keyboard:service all previous
noctalia msg plugin omerfuyar/keyboard:service all set TR
```

## Notes

- Layouts come from Hyprland; on other compositors, only fcitx5's input methods are listed.
- The active language is read every second, so a switch made with fcitx5's own key shows too.
