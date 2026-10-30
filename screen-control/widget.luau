--!nonstrict
-- Screen Control bar widget: a sun, or a moon while night light is on.
-- Scroll moves the bar's monitor along the brightness and dim scale; a click opens the panel.

local Level = require("./lib/level.luau")

local PANEL = "omerfuyar/screen-control:panel"

local model = nil

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("screen-control.command", command)
end

-- The monitor this bar is on, or the first one.
local function ownMonitor()
  local name = barWidget.outputName()
  for _, monitor in ipairs(model.monitors) do
    if monitor.name == name then
      return monitor
    end
  end
  return model.monitors[1]
end

local function render()
  if model == nil or #model.monitors == 0 then
    return
  end
  local own = ownMonitor()
  local glyph = model.night.mode == "on" and "moon" or "sun"
  -- color nil keeps the bar's own color.
  local color = own.dim > 0 and "primary" or nil
  barWidget.render(ui.glyph({ name = glyph, color = color }))

  local rows = {}
  for _, monitor in ipairs(model.monitors) do
    table.insert(rows, { key = monitor.label, value = Level.text(monitor.brightness, monitor.dim) })
  end
  table.insert(rows, { key = noctalia.tr("night.title"), value = noctalia.tr("night." .. model.night.mode) })
  barWidget.setTooltip(rows)
end

noctalia.state.watch("screen-control.model", function(value)
  model = value
  render()
end)

function update()
  noctalia.setUpdateInterval(60000)
  model = model or noctalia.state.get("screen-control.model")
  render()
end

function onClick()
  noctalia.togglePanel(PANEL)
end

-- steps is negative for up.
function onScroll(axis, steps)
  if axis ~= "vertical" or model == nil or #model.monitors == 0 then
    return
  end
  send({ action = "step", output = ownMonitor().name, delta = -steps * Level.STEP })
end
