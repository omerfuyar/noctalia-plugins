# Agenda

Shows your next calendar event in the bar, with a countdown as it gets close and a Join
button for meetings. It reads the calendars you already set up in Noctalia, so there is
nothing else to configure.

## Plugin

| Field | Value |
| --- | --- |
| ID | `omerfuyar/agenda` |
| Entries | Bar widget: `widget`; panel: `panel` |

## Requirements

- At least one calendar account in Noctalia's settings, under Calendar. Until one is set
  up, the panel offers to open that page.
- `noctalia` opens that settings page, and `xdg-open` opens meeting links.

## Usage

Add the **Agenda** widget to the bar.

- During the day, the bar shows the time and title of the next event.
- From 15 minutes before an event, the bar counts down and turns the accent color; while
  an event runs, it shows "Now". A `+1` means another event starts at the same time.
- Right click the widget to join the meeting it shows. Its tooltip has the details.
- Left click opens the panel: the next event with a **Join** button, then the events of
  the coming days. All-day events appear only in the panel.

```sh
noctalia msg panel-toggle omerfuyar/agenda:panel
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `days` | `int` | `7` | How many days, from today on, the panel lists. |
| `soon_minutes` | `int` | `15` | Minutes before an event when the countdown starts and Join is highlighted. |
| `hidden_calendars` | `string_list` | `[]` | Advanced. Names of calendars to leave out, such as a holiday calendar. |
| `show_title` | `bool` | `true` | Widget setting. Show the event's title in the bar, or only its time. |

## Notes

- Times use the formats from Noctalia's calendar settings.
- Reminders come from Noctalia itself (Calendar, Reminders), so Agenda does not send its own.
- Events are read-only, as in Noctalia's calendar.
- Based on ideas from the Omarchy plugin [calendar](https://github.com/tmn73/omarchy-calendar).
