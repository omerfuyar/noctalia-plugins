--!nonstrict
-- Screen Control panel: one slider for each monitor, from dimmed through full brightness,
-- then night light. Renders "screen-control.model" and sends actions on "screen-control.command".

local Level = require("./lib/level.luau")

local NIGHT_MODES = { "off", "scheduled", "on" }

local model = nil

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("screen-control.command", command)
end

local function monitorBlock(monitor)
  local dimmed = monitor.dim > 0
  local title = { ui.label({ text = monitor.label, maxLines = 1 }) }
  if monitor.workspace then
    table.insert(title, ui.label({
      text = noctalia.tr("monitor.workspace", { name = monitor.workspace }),
      color = "on_surface_variant",
      maxLines = 1,
    }))
  end
  return ui.column({ key = monitor.name, gap = 6 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = monitor.internal and "device-laptop" or "device-desktop", size = 18,
        color = "on_surface_variant" }),
      ui.column({ gap = 2, flexGrow = 1 }, title),
      ui.label({ text = Level.text(monitor.brightness, monitor.dim), color = dimmed and "primary" or "on_surface" }),
    }),
    ui.slider({
      min = 0,
      max = 1,
      step = 0.01,
      value = Level.fromScreen(monitor.brightness, monitor.dim),
      onChange = function(value)
        send({ action = "level", output = monitor.name, level = tonumber(value) })
      end,
    }),
  })
end

local function modeButton(mode)
  local selected = model.night.mode == mode
  return ui.button({
    text = noctalia.tr("night." .. mode),
    variant = selected and "secondary" or "ghost",
    selected = selected,
    controlSize = "sm",
    flexGrow = 1,
    onClick = function() send({ action = "night", mode = mode }) end,
  })
end

local function timeInput(key, value, placeholder)
  return ui.input({
    key = "time-" .. key,
    value = value,
    placeholder = placeholder,
    width = 80,
    onChange = function(text)
      send({ action = "schedule", key = key, value = noctalia.string.trim(text) })
    end,
  })
end

-- Sunset to sunrise where Noctalia's location is, or times the user sets.
local function scheduleBlock()
  local night = model.night
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = noctalia.tr("night.custom"), color = "on_surface_variant", flexGrow = 1 }),
      ui.toggle({
        checked = night.custom,
        onChange = function(value) send({ action = "schedule", custom = value == "true" }) end,
      }),
    }),
  }
  if night.custom then
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = noctalia.tr("night.from"), color = "on_surface_variant" }),
      timeInput("sunset", night.start, "20:30"),
      ui.label({ text = noctalia.tr("night.until"), color = "on_surface_variant" }),
      timeInput("sunrise", night.finish, "07:30"),
    }))
    table.insert(children, ui.label({ text = noctalia.tr("night.dark_mode_note"), color = "on_surface_variant" }))
  elseif night.place ~= "" then
    table.insert(children, ui.label({ text = noctalia.tr("night.at_place", { place = night.place }),
      color = "on_surface_variant" }))
  else
    table.insert(children, ui.label({ text = noctalia.tr("night.no_place"), color = "on_surface_variant" }))
  end
  return ui.column({ gap = 8 }, children)
end

local function nightBlock()
  local buttons = {}
  for _, mode in ipairs(NIGHT_MODES) do
    table.insert(buttons, modeButton(mode))
  end
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "moon", size = 18, color = "on_surface_variant" }),
      ui.label({ text = noctalia.tr("night.title"), flexGrow = 1 }),
    }),
    ui.row({ gap = 6 }, buttons),
  }
  if model.night.mode == "scheduled" then
    table.insert(children, scheduleBlock())
  end
  if model.night.mode ~= "off" then
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = noctalia.tr("night.warmth"), color = "on_surface_variant", flexGrow = 1 }),
      ui.label({ text = `{model.night.temperature} K` }),
    }))
    -- Reversed, so that right is warmer, like the brightness slider's right is brighter.
    table.insert(children, ui.slider({
      min = 0,
      max = 5000,
      step = 100,
      value = 6500 - model.night.temperature,
      onChange = function(value)
        send({ action = "temperature", value = 6500 - (tonumber(value) or 2500) })
      end,
    }))
  end
  return ui.column({ gap = 8 }, children)
end

local function render()
  if model == nil then
    panel.render(ui.column({ padding = 16 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    }))
    return
  end

  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "sun", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold" }),
    }),
  }
  for _, monitor in ipairs(model.monitors) do
    table.insert(children, monitorBlock(monitor))
  end
  if model.sharedDim and #model.monitors > 1 then
    table.insert(children, ui.label({ text = noctalia.tr("panel.shared_dim"), color = "on_surface_variant" }))
  end
  table.insert(children, ui.separator({}))
  table.insert(children, nightBlock())
  panel.render(ui.column({ gap = 14, padding = 16 }, children))
end

noctalia.state.watch("screen-control.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "refresh" })
  model = noctalia.state.get("screen-control.model") or model
  render()
end
