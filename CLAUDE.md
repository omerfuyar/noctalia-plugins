# Noctalia plugins

Personal monorepo of Noctalia **v5** plugins (Luau + `plugin.toml`), many ported from Omarchy
(Quickshell QML) plugins. Laid out like `noctalia-dev/community-plugins` so it works as a
Noctalia git plugin source and each plugin can be PR'd upstream unchanged.

- How plugins work: `docs/GUIDE.md`
- What to build and in what order: `docs/ROADMAP.md`

## Layout

- One directory per plugin, named exactly after the part of the id after `/`
  (`<author>/screen-control` → `screen-control/`).
- Each plugin: `plugin.toml`, `*.luau`, `translations/en.json`, `README.md`
  (follow community-plugins `README_TEMPLATE.md`), `thumbnail.webp` (960×540).
- Root `catalog.toml` lists every plugin (one `[[plugin]]` row each). Keep it in sync with
  each `plugin.toml`. (Upstream community-plugins generates it in CI — never commit it there.)

## Product rules (the owner's priorities, in order)

1. **User-friendly first.** Sensible defaults; the plugin works right after enabling.
2. **Easy configuration.** Few settings, all typed `[[setting]]`s with defaults; rare ones
   `advanced = true`; dependent ones `visible_when`.
3. **Little to no manual setup or maintenance.** Minimal dependencies. If something is truly
   required (a package, a one-time root step), detect it with `noctalia.commandExists` and show
   an in-plugin setup card with a one-click action (`noctalia.runInTerminal(...)`), reachable
   from the bar widget. Never rely on README-only setup steps.
4. **Bar-first.** Primary surface is a `[[widget]]`; details and controls live in a `[[panel]]`
   opened from it. Support vertical bars (`barWidget.isVertical()` → glyph-only).
5. **Improve on Noctalia's defaults**, don't duplicate them (e.g. unified screen control:
   brightness + extra dimming + night light in one place).
6. **Look native, never machine-specific.** Palette role colors only (`primary`,
   `on_surface`, `surface_container/0.6`, ...) — no hex in UI code. Default fonts,
   `controlSize`, Tabler glyphs. No hardcoded monitor names, paths, usernames or screen sizes;
   query `noctalia.outputs()`, `noctalia.expandPath`, `pluginDataDir()`.
7. **No AI features** in these plugins.

## Code rules

- Architecture: a `service.luau` owns data fetching and publishes a plain-data model with
  `noctalia.state.set`; widget and panel `state.watch` it and only render.
- All external work is async (`runAsync` with **argv tables** for dynamic values, `http`,
  `readFileAsync`). Never block; render a placeholder, re-render on arrival.
- Persist user data in `noctalia.pluginDataDir()`, never in the plugin directory.
- All user-visible text via `noctalia.tr(...)` with keys in `translations/en.json`; English only
  (other locales come from Noctalia Translate).
- Declare every external command in `dependencies` and in the README's Requirements.
- Fail soft: missing sensor/command → hide that part, don't show zeros or errors in the bar.
- Bump `version` on every change. `plugin_api` = oldest level actually needed.
- Readable code only (community review rejects generated/minified code).

## Testing

Noctalia only runs on the owner's CachyOS machine, not in a cloud sandbox. Real testing means
running there:

```bash
noctalia msg plugins source add dev path ~/dev/noctalia-plugins
noctalia msg plugins enable <author>/<plugin>
noctalia msg panel-toggle <author>/<plugin>:<panel>
noctalia msg plugin <author>/<plugin>:<entry> all <event> <payload>
```

`.luau` edits hot-reload; `plugin.toml` edits apply on config reload. In a cloud session without
the machine attached, limit work to code + static checks and say what still needs a live test.
