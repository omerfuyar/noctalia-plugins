# Roadmap: Omarchy → Noctalia v5 plugins

Decided 2026-10-29. Target: Noctalia v5 (Luau plugins) on CachyOS + Hyprland (Lua config).

## Dropped (good enough today, or out of scope)

| Omarchy plugin | Why dropped |
|---|---|
| jkoestinger.vpn | NoctaProton VPN covers the user's needs |
| ssupt.audio-control | Built-in audio already shows per-app streams and mic |
| ssupt.bluetooth-audio | Built-in Bluetooth works fine |
| sirjul1337.lock-explorer | Fragile; Noctalia's lock screen is good |
| Anything AI-targeted | User preference — no AI features in these plugins |
| clipbasket, notification-center, mpris, vitals, tray, altswitch, keyboard-layout-switcher, community.network, screen-time, omarchroma | Built into Noctalia |
| yaqazah, quran-motivation, omaland, keycap | Covered by community plugins already in use |
| omaplug, what-changed | Omarchy-only |

## New plugins (ranked: value first, then effort)

| # | Plugin (working name) | Ported from | What makes it better than what Noctalia has | Difficulty |
|---|---|---|---|---|
| 1 | **Screen Control** | onatvural.screen-comfort (+ parts of im0001gt.screens) | One bar widget + panel: per-monitor brightness, **extra dimming below the backlight minimum** (click-through `[[layer]]` overlay), night light toggle/force, optional per-workspace dim. The built-in brightness widget has none of the extras. | Easy–Medium |
| 2 | **Otoru** (yt-dlp) | ussego.otoru | Paste a URL → pick audio/video → queue, progress in the bar. Nothing similar exists. Setup card offers to install `yt-dlp`/`ffmpeg`. | Easy |
| 3 | **Agenda** | tmn73.calendar | "Next up" in the bar, countdown, Join button for meeting links, today/week list. Uses `noctalia.calendarEvents()` so it reuses Noctalia's own calendar sync — **zero setup**. Event creation is out of scope at first (built-in calendars are read-only). | Easy–Medium |
| 4 | **Workspace Overview** | mirador | Fullscreen overview of Hyprland workspaces with app icons, click to focus, drag to move. v1 uses icons (`appIconPath`); live previews would need a `ui.pixelStream` companion (v2, Hard). | Medium (v1) / Hard (v2) |
| 5 | **Phone Cam** | infiniv.dori | Use an Android phone as a webcam / mirror. Reuses dori's helper scripts. Needs v4l2loopback (one-time root setup → guided pop-up). | Medium |
| 6 | **Display Layout** | im0001gt.screens | Monitor arrangement with snapping, profiles, scale, VRR/HDR, workspace→monitor mapping, writing Hyprland's Lua monitor config. **First ask the Hyprland Settings author** whether they want these as PRs (see below). | Hard |
| 7 | **Radio** | akshar.radio-atlas | Browse world radio by country/genre with favorites; MPRIS control. Check `fel/radio` and `nilsonlinux/world-radio` first — contributing may beat a new plugin. A globe needs `ui.pixelStream` (stretch goal). | Medium (Hard with globe) |
| 8 | **Resurrect** | tsouth89.resurrect | Snapshot packages, dotfiles, Noctalia config and enabled services into a git vault; restore on a new CachyOS install. Rewrite capture targets for CachyOS/Noctalia paths. | Medium–Hard |

## Improve plugins already in use

Changes to another author's plugin need their sign-off, so each item starts with an issue/PR
that @-mentions the author. Audit each plugin's code before proposing anything.

| Plugin | Starting ideas (to confirm in the audit) |
|---|---|
| Crashes | Fold in **faultline**: failed systemd units and journal errors since boot, next to coredumps. Make the AI diagnosis optional / off by default. |
| Hyprland Settings | Bring the Omarchy **screens** monitor features (drag layout with snapping, profiles, HDR/VRR, workspace mapping) — or do this as plugin #6 if the author declines. |
| Network Toolkit | Compare against the built-in network panel and Omarchy's network plugin: Wi-Fi QR share, static IP for wired, DNS presets, VPN status in the same view. |
| Ayet Köşesi | Ideas from quran-motivation: offline fallback when the API is unreachable, rotation interval, bar-widget control. |
| Mawaqit | Compare with yaqazah: automatic location, calculation-method choice, offline timetable cache. |
| Process Monitor, Shelly, Keybind Cheatsheet, Default Apps | Audit for: sensible defaults, vertical-bar support, palette-only colors, missing translations, dependency pop-ups. |

## Order of work

1. **Setup** — create the repo, add `noctalia.d.luau` + luau-lsp, register the repo as a local
   source on the CachyOS machine.
2. **Otoru** — smallest complete plugin; learn the whole cycle including README, thumbnail and
   publishing.
3. **Screen Control** — daily-driver value; learns layers, IPC and multi-monitor.
4. **Agenda**.
5. **Crashes + faultline** PR — first contribution to someone else's plugin.
6. **Workspace Overview v1**.
7. **Display Layout** (or the Hyprland Settings PRs), **Phone Cam**, **Radio**, **Resurrect** —
   in whatever order matters most at the time.
