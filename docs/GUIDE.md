# How Noctalia v5 plugins work

A working guide for building bar-first Noctalia plugins. Based on docs.noctalia.dev and the
`noctalia-dev/community-plugins` README as of 2026-10-29. Items marked **(verify)** were not
confirmed in the docs and should be checked on a real machine before relying on them.

---

## 1. The big picture

- Noctalia v5 is a native shell. Plugins are **Luau** scripts plus a static `plugin.toml`.
  QML/Quickshell plugins are v4-only and are **rejected** by the community repo.
- Each entry (widget, panel, service, ...) runs in its **own isolated Luau VM**, off the UI
  thread, with time budgets per call. A slow script cannot freeze the shell, but it also means
  entries **cannot share Lua variables** — they talk through `noctalia.state`.
- UI is **declarative**: you build a tree with `ui.*` constructors and call `render(tree)`.
  Noctalia diffs it and updates native controls. You never draw pixels yourself.
- Plugins are trusted, unsandboxed code. They can run commands, read files and use HTTP.

### What this means coming from Omarchy

| Omarchy (Quickshell QML) | Noctalia v5 |
|---|---|
| `manifest.json` | `plugin.toml` |
| `BarWidget.qml` | `[[widget]]` + `widget.luau` |
| `Panel.qml` | `[[panel]]` + `panel.luau` |
| `Service.qml` | `[[service]]` + `service.luau` |
| `Overlay.qml` | `[[layer]]` (plugin_api ≥ 36) |
| `Process { }` | `noctalia.runAsync` / `runStream` |
| `Style.*` tokens | palette role strings: `"primary"`, `"on_surface"`, `"surface_container/0.6"` |
| `~/.config/omarchy/shell.json` | typed `[[setting]]` schema, edited in Noctalia's settings UI |
| `omarchy-shell summon <id>` | `noctalia msg panel-toggle author/plugin:panel` |

Bash/Python helper scripts from Omarchy plugins can usually be **kept as-is** (declare them).
The QML UI has to be **rewritten** as `ui.*` trees.

---

## 2. Anatomy of a plugin

```
my-plugin/
  plugin.toml            # identity, entries, settings schema
  widget.luau            # bar widget entry
  panel.luau             # panel entry
  service.luau           # optional background logic
  lib/util.luau          # shared code, loaded with require("./lib/util.luau") (api ≥ 22)
  translations/en.json   # every label_key / description_key, flattened dotted keys
  README.md              # becomes the plugin page on noctalia.dev
  thumbnail.webp         # 960×540 card image
```

### Minimal working plugin (from the official docs)

```toml
id         = "me/hello"
name       = "Hello"
version    = "1.0.0"
plugin_api = 3
author     = "me"

[[widget]]
id    = "hello"
entry = "widget.luau"
```

```lua
function update()
  noctalia.setUpdateInterval(1000)
  barWidget.setGlyph("puzzle")
  barWidget.setText("Hello")
end

function onClick()
  noctalia.notify("Hello", "you clicked me")
end
```

### Manifest essentials

- Required: `id` (`author/plugin`, lowercase), `name`, `version` (strict `X.Y.Z`), `plugin_api`.
- Optional: `author`, `license` (default MIT), `icon`, `description` (≤120 chars for the
  community repo), `tags` (from the approved list), `dependencies` (every external command you
  call — **mandatory** for community review).
- `plugin_api` = the oldest API level you need. New community plugins use the current level
  (43 at time of writing). Some useful gates: function callbacks 9, `require` 22, argv
  `runAsync` 24, `getSetting` 26, `getColor` 31, tooltips 32, layers 36, calendar events 37,
  OSD 39, pixel streams 40, color picker 41, content-height panels 42.

### Entry kinds

| Kind | Use it for | Notes |
|---|---|---|
| `[[widget]]` | The bar item. **Your main surface.** | One control tall. No text input, select or scroll. Clicks, scroll, tooltips work. |
| `[[panel]]` | The pop-up opened from the widget | Fixed size from manifest (`width`/`height`, or `height = "content"` + `max_height` at api 42). Full control set. |
| `[[service]]` | Background polling, caching, state | Headless. Publishes to `noctalia.state`. |
| `[[shortcut]]` | Control Center toggle tile | `shortcut.setActive/setIcon/setLabel`. |
| `[[launcher_provider]]` | `/prefix` results in the launcher | `onQuery` → `launcher.setResults`. |
| `[[desktop_widget]]` | Desktop tiles | User owns position/size. No tooltips. |
| `[[layer]]` | Your own layer-shell surface | Overlays, dimmers, OSD-like things. `click_through = true` for passive overlays. |

### Callbacks you will use most

`update()` (timer), `onClick()`, `onRightClick()`, `onScroll(axis, steps, startsGesture)`,
`onOpen(context)` / `onClose()` for panels, `onConfigChanged()`, `onIpc(event, payload)`,
`onExit(signal, reason)`. The top level of each script runs once at load — set up state and
`noctalia.state.watch(...)` there.

Note: middle-click on any widget opens its settings by default. Free it with
`[widget.actions] middle = "none"` only if you really need it.

---

## 3. The recommended architecture for bar-first plugins

```
service.luau  ── polls / streams data ──► noctalia.state.set("model", {...})
                                              │
widget.luau   ◄── state.watch("model") ───────┤   compact bar view + tooltip
panel.luau    ◄── state.watch("model") ───────┘   detailed view + controls
   │
   └── user action ──► runAsync(...) or state.set("command", ...) ──► service
```

Why: one place fetches data (no duplicate `hyprctl`/`nmcli` calls per monitor's bar), the widget
stays tiny, and the panel is just a richer view of the same model. `noctalia.state` is copied
plain data and is in-memory only; persist anything long-lived with
`noctalia.writeFile(noctalia.pluginDataDir() .. "/x.json", noctalia.json.encode(t))`.

Use `pluginDataDir()` for user data, **never** `pluginDir()` — git updates rewrite it.

---

## 4. Declarative UI cheat sheet

```lua
local function view(model)
  return ui.column({ gap = 8, padding = 12 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "sun", size = 18, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "bold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.toggle({ checked = model.night, onChange = function(v) setNight(v == "true") end }),
    }),
    ui.slider({ min = 0, max = 100, step = 1, value = model.brightness,
                onChange = function(v) preview(v) end,
                onDragEnd = function() commit() end }),
  })
end

function onOpen() panel.render(view(current)) end
```

- Layout: `ui.column`, `ui.row`, `ui.scroll`, `ui.spacer`, `ui.separator`, `ui.box`.
- Content: `ui.label`, `ui.glyph` (Tabler/Nerd glyph names), `ui.image` (local files only —
  `noctalia.download` first), `ui.markdown`, `ui.progress`, `ui.graph`.
- Controls: `ui.button` (variants: default, primary, secondary, destructive, outline, ghost),
  `ui.toggle`, `ui.slider`, `ui.select`, `ui.input`, `ui.colorPicker`, drag/drop.
- Toggle `onChange` gives the **string** `"true"`/`"false"`; sliders give numbers; selects give
  an index.
- Re-render freely; use `key` on list rows to keep identity.
- **No canvas.** Custom visuals = boxes, graphs, progress bars, or `ui.pixelStream` fed by a
  companion process (advanced; e.g. live window previews or a globe).

### Staying visually native (non-negotiable for these plugins)

- Colors: **only palette roles** (`primary`, `on_surface`, `surface_container`, `error`, ...)
  with optional alpha (`primary/0.6`). No hex colors in UI code; they break theme changes.
- Sizes: use `controlSize` (`sm`/`md`/`lg`) and the default fonts. In the bar, let labels and
  glyphs inherit the bar font and color.
- Icons: Tabler glyph names, like the built-in widgets.
- Respect `barWidget.isVertical()` — show a glyph-only form on vertical bars.
- Text through `noctalia.tr(...)`, so the plugin can be translated on Noctalia Translate.

---

## 5. Runtime API you will reach for

| Need | API |
|---|---|
| Run a command | `noctalia.runAsync({ "hyprctl", "-j", "monitors" }, function(r) ... r.stdout ... end)` |
| Follow a long-lived stream | `noctalia.runStream(cmd, onLine)` |
| Check a dependency | `noctalia.commandExists("yt-dlp")` |
| Open a terminal (for installs) | `noctalia.runInTerminal("sudo pacman -S --needed yt-dlp")` |
| HTTP / downloads | `noctalia.http({url=...}, cb)`, `noctalia.download(url, dest, cb)` |
| Files | `readFile`, `writeFile`, `listDir`, `fileExists`, `pluginDataDir()` |
| Settings | `noctalia.getConfig(key)`; shell config via `noctalia.getSetting("bar.position")` |
| Monitors | `noctalia.outputs()` → name, size, position, scale, focused |
| Notifications / OSD | `noctalia.notify`, `notifyError`, `noctalia.osd.show(icon, value, {progress=})` |
| Calendar | `noctalia.calendarEvents()` — Noctalia's own synced, read-only events |
| System stats | `noctalia.systemStats()`, `cpuCores()`, `diskStats(path)` |
| Idle | `noctalia.idle.watch(seconds, cb)` |
| Open panels / settings | `noctalia.togglePanel("me/x:panel")`, `noctalia.openSettings()` |
| Theme | `noctalia.isDarkMode()`, `noctalia.getColor(role)` |
| Shell actions | `runAsync({"noctalia","msg","brightness-set","DP-1","40%"})`, `nightlight-toggle`, ... |

Use the **argv table form** of `runAsync` whenever a value is dynamic — it avoids shell quoting
bugs and injection.

Hyprland access: there is no Hyprland API in the plugin runtime. Use `hyprctl -j ...` through
`runAsync`, or `runStream` on the Hyprland event socket (that needs `socat`; polling `hyprctl`
avoids the extra dependency). **(verify)** whether any compositor events are exposed to plugins.

---

## 6. UX rules turned into code patterns

**Zero-setup defaults.** Every `[[setting]]` gets a sensible `default`. Hide rarely used options
with `advanced = true`. Show dependent options only when relevant with
`visible_when = { key = "mode", values = ["custom"] }`.

**Dependency check with a friendly pop-up, only when needed:**

```lua
local REQUIRED = { "yt-dlp", "ffmpeg" }

local function missingDeps()
  local missing = {}
  for _, cmd in ipairs(REQUIRED) do
    if not noctalia.commandExists(cmd) then table.insert(missing, cmd) end
  end
  return missing
end

-- In the panel: if something is missing, render a setup card instead of the normal UI
local function setupCard(missing)
  return ui.column({ gap = 8, padding = 16 }, {
    ui.label({ text = noctalia.tr("setup.missing", { list = table.concat(missing, ", ") }) }),
    ui.button({ text = noctalia.tr("setup.install"), variant = "primary",
      onClick = function()
        noctalia.runInTerminal("sudo pacman -S --needed " .. table.concat(missing, " "))
      end }),
  })
end
```

The bar widget shows a small warning glyph + tooltip when setup is needed; clicking it opens the
panel on the setup card. No README-only setup steps.

**Never block the shell.** Everything external goes through `runAsync`/`http` callbacks. Show a
placeholder ("Loading…") and re-render when data arrives.

**Fail soft.** Absent sensors and failed commands → hide that row, don't show `0` or crash.

---

## 7. Development workflow (on the CachyOS machine)

1. Clone your plugins repo, e.g. `~/dev/noctalia-plugins`.
2. Register it once as a local source and enable a plugin:
   ```bash
   noctalia msg plugins source add dev path ~/dev/noctalia-plugins
   noctalia msg plugins enable me/hello
   ```
3. Edit `.luau` files → **hot reload**. Edit `plugin.toml` → applies on next config reload.
4. Poke IPC handlers:
   ```bash
   noctalia msg plugin me/hello:hello focused greet "hi"
   noctalia msg plugin me/hello:ticker all refresh
   noctalia msg panel-toggle me/hello:panel
   ```
5. Debug with `noctalia.log(...)` and read Noctalia's log output **(verify where it logs on
   your system — journal or terminal)**.
6. Editor support: fetch `noctalia.d.luau` (type definitions, link in the community-plugins
   README) into the repo root and use luau-lsp (VS Code, Neovim and Zed configs exist in the
   community repo). `.luaurc` with `nonstrict` mode.
7. Precedence: your local/path source beats the built-in community source for the same id. That
   is how you test a modified version of someone else's plugin without renaming it.

---

## 8. Publishing

**Option A — your own source (immediate).** Lay your repo out like community-plugins (one
directory per plugin, named after the part of the id after `/`) with a root `catalog.toml`.
Anyone can install it with:

```bash
noctalia msg plugins source add <name> git https://github.com/<you>/noctalia-plugins
```

**Option B — community-plugins (discoverable in the store).** One plugin per PR, containing
`plugin.toml`, `.luau` files, `README.md` (follow `README_TEMPLATE.md`), `thumbnail.webp`
(960×540) and `translations/en.json`. Rules that get PRs rejected:

- obfuscated/minified/generated code, downloading and running remote code
- undeclared external commands
- QML/Quickshell or launching another UI runtime to draw
- more than 200 files in the plugin directory
- forgetting to bump `version`, committing `catalog.toml`, adding machine-translated locales

**Improving someone else's plugin:** plugin directories belong to their authors. A PR touching
another author's plugin needs **their sign-off** (except bug fixes or mechanical changes). So:
open an issue or PR and @-mention the author first; if they are unresponsive, publish your own
plugin under a new name and credit theirs.

---

## 9. Learning path

1. Read `noctalia/example` (widget + service + shortcut sharing state) and
   `noctalia/screen_recorder` in `noctalia-dev/official-plugins`.
2. Read `noctalia/timer` (desktop widget) and `noctalia/wallhaven:browser` (network-backed panel).
3. Build the smallest project on the roadmap end-to-end, including README, thumbnail and
   translations, so the publishing steps are learned once.

## Sources

- https://docs.noctalia.dev/noctalia/plugins/development/ (+ `manifest/`, `entries/`,
  `declarative-ui/`, `runtime-api/`, `workflow/`)
- https://docs.noctalia.dev/noctalia/ipc/system-controls/
- https://github.com/noctalia-dev/community-plugins (README)
- https://github.com/noctalia-dev/official-plugins
