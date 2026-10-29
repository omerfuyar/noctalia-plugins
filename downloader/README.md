# Downloader

Download a video or its audio from a link, with yt-dlp, right from the bar. Paste a link,
pick video or audio, and follow the queue and progress in the bar.

## Plugin

| Field | Value |
| --- | --- |
| ID | `omerfuyar/downloader` |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service` |

## Requirements

- `yt-dlp` downloads from the sites it supports, and `ffmpeg` joins video and audio and
  converts audio. When either is missing, the panel offers to install both in a terminal.
- `sh` and `kill` run and stop downloads. They come with every Linux system.
- `xdg-open` opens finished files and the download folder. Without it, those buttons are
  hidden.

## Usage

1. Add the **Downloader** widget to the bar and click it.
2. A link on the clipboard is filled in for you. Otherwise paste one, or press the
   clipboard button.
3. Pick **Video** or **Audio** and press **Download** or Enter.

Downloads run one at a time. While one runs, the bar shows its progress, and the tooltip
shows its name, speed and time left. The panel lists waiting and finished downloads; a
finished file opens with the play button, and a failed one can be tried again.

```sh
noctalia msg panel-toggle omerfuyar/downloader:panel
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `folder` | `folder` | `~/Downloads` | Where downloads are saved. |
| `video_quality` | `select` | `best` | Highest video resolution. A smaller video is used when the site has nothing this large. |
| `audio_format` | `select` | `mp3` | File type for audio downloads. `best` (Original) keeps the site's format without converting. |
| `notify` | `bool` | `true` | Notify when a download finishes or fails. |
| `whole_playlist` | `bool` | `false` | Advanced. For a link to a video in a playlist, download the whole playlist. A link to the playlist itself always downloads all of it. |

## IPC

Queue a link as video or audio. Without a link, the clipboard's text is used, so a key
binding can download whatever link was just copied.

```sh
noctalia msg plugin omerfuyar/downloader:service all video "https://example.com/watch/123"
noctalia msg plugin omerfuyar/downloader:service all audio
```

## Notes

- Videos are saved as MP4 when the site's formats allow it, otherwise as MKV.
- The queue and yt-dlp's output for each download are kept in the plugin's data folder.
  A download keeps running when Noctalia reloads the plugin.
- Some sites block downloads or need a login; yt-dlp's error is shown on the failed item.
- Based on ideas from the Omarchy plugin [otoru](https://github.com/ussego/otoru).
