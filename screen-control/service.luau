--!nonstrict
-- Screen Control service: reads each monitor's brightness, keeps the dim levels and runs
-- the dimming layer, and reads and sets night light.
--
-- Brightness and night light belong to Noctalia: they are set with `noctalia msg`, and night
-- light is read back from Noctalia's settings. Noctalia has no way to read brightness, so
-- the built-in display's is read from sysfs, and an external monitor's with ddcutil.
--
-- Publishes "screen-control.model" and takes commands on "screen-control.command".

local Level = require("./lib/level.luau")

local DIM_LAYER = "dim"
local DDC_REFRESH_MS = 30000
-- After a change, the read-back value may lag; reading waits this long.
local SETTLE_MS = 1500

local dataFile = (noctalia.pluginDataDir() or "") .. "/dims.json"

local monitors = {} -- { name, label, internal, brightness, bus }, in noctalia.outputs() order
local dims = {} -- dim level by key: "output:<name>", or "workspace:<name>" per workspace
local workspaces = {} -- active workspace name by output name
local backlight = nil -- { output, path, max }
local lastSetMs = {}
local lastDdcMs = -DDC_REFRESH_MS
local pending = {} -- latest value to send, by command key
local sending = {}

local function perWorkspace()
  return noctalia.getConfig("per_workspace") and noctalia.commandExists("hyprctl")
end

local function dimKey(name)
  local workspace = workspaces[name]
  if perWorkspace() and workspace then
    return "workspace:" .. workspace
  end
  return "output:" .. name
end

local function findMonitor(name)
  for _, monitor in ipairs(monitors) do
    if monitor.name == name then
      return monitor
    end
  end
  return nil
end

local function nightMode()
  if not noctalia.getSetting("nightlight.enabled") then
    return "off"
  end
  return noctalia.getSetting("nightlight.force") and "on" or "scheduled"
end

local function publish()
  local model = { monitors = {}, perWorkspace = perWorkspace() and true or false }
  local anyDim = false
  for _, monitor in ipairs(monitors) do
    local dim = dims[dimKey(monitor.name)] or 0
    anyDim = anyDim or dim > 0
    table.insert(model.monitors, {
      name = monitor.name,
      label = monitor.label,
      internal = monitor.internal,
      brightness = monitor.brightness,
      dim = dim,
      workspace = workspaces[monitor.name],
    })
  end
  model.night = {
    mode = nightMode(),
    temperature = noctalia.getSetting("nightlight.temperature_night") or 4000,
  }
  noctalia.state.set("screen-control.model", model)
  if anyDim then
    noctalia.layer.show(DIM_LAYER)
  else
    noctalia.layer.hide(DIM_LAYER)
  end
end

local function save()
  local text = noctalia.json.encode({ dims = dims })
  if text then
    noctalia.writeFile(dataFile, text)
  end
end

-- Runs one command per key at a time and drops values that a newer one replaced, so a
-- dragged slider does not queue up dozens of commands.
local function send(key, argv)
  pending[key] = argv
  if sending[key] then
    return
  end
  local next = pending[key]
  pending[key] = nil
  sending[key] = true
  noctalia.runAsync(next, function()
    sending[key] = false
    if pending[key] then
      send(key, pending[key])
    end
  end, 10000)
end

local function setBrightness(monitor, value)
  monitor.brightness = value
  lastSetMs[monitor.name] = noctalia.nowMs()
  send("brightness:" .. monitor.name,
    { "noctalia", "msg", "brightness-set", monitor.name, string.format("%.3f", value) })
end

local function setLevel(name, level)
  local monitor = findMonitor(name)
  if monitor == nil then
    return
  end
  local brightness, dim = Level.toScreen(level, monitor.brightness ~= nil)
  if brightness and math.abs(brightness - monitor.brightness) > 0.001 then
    setBrightness(monitor, brightness)
  end
  local key = dimKey(name)
  dims[key] = dim > 0.005 and dim or nil
  save()
end

local function step(name, delta)
  local monitor = findMonitor(name)
  if monitor then
    setLevel(name, Level.fromScreen(monitor.brightness, dims[dimKey(name)] or 0) + delta)
  end
end

local function configSet(path, value)
  send("config:" .. path, { "noctalia", "msg", "config-set", path, tostring(value) })
end

local function setNightMode(mode)
  configSet("nightlight.enabled", mode ~= "off")
  configSet("nightlight.force", mode == "on")
end

local function readBacklight()
  if backlight == nil then
    return
  end
  local monitor = findMonitor(backlight.output)
  if monitor == nil or noctalia.nowMs() - (lastSetMs[monitor.name] or 0) < SETTLE_MS then
    return
  end
  noctalia.readFileAsync(backlight.path .. "/brightness", function(text)
    local raw = tonumber(text and noctalia.string.trim(text) or "")
    if raw and noctalia.nowMs() - (lastSetMs[monitor.name] or 0) >= SETTLE_MS then
      local value = math.clamp(raw / backlight.max, 0, 1)
      if monitor.brightness == nil or math.abs(monitor.brightness - value) > 0.001 then
        monitor.brightness = value
        publish()
      end
    end
  end)
end

-- Noctalia picks the backlight of the built-in display the same way: the one named in
-- its settings, otherwise the first one.
local function findBacklight()
  local internal = nil
  for _, monitor in ipairs(monitors) do
    if monitor.internal then
      internal = monitor
      break
    end
  end
  if internal == nil then
    return
  end
  local function use(device)
    local path = device:find("/") and device or "/sys/class/backlight/" .. device
    noctalia.readFileAsync(path .. "/max_brightness", function(text)
      local max = tonumber(text and noctalia.string.trim(text) or "")
      if max and max > 0 then
        backlight = { output = internal.name, path = path, max = max }
        readBacklight()
      end
    end)
  end
  -- The whole table, since asking for a missing key logs a warning.
  local settings = noctalia.getSetting("brightness") or {}
  local perMonitor = type(settings.monitor) == "table" and settings.monitor[internal.name] or nil
  local configured = type(perMonitor) == "table" and perMonitor.backlight_device or nil
  if type(configured) == "string" and configured ~= "" then
    use(configured)
    return
  end
  noctalia.runAsync({ "noctalia", "msg", "brightness-list-backlight-devices" }, function(result)
    local first = result.exitCode == 0 and (result.stdout or ""):match("^%s*(%S+)")
    if first and first ~= "error:" then
      use(first)
    end
  end)
end

-- ddcutil reads an external monitor's brightness. Noctalia sets it with ddcutil too, so it
-- is only read when Noctalia's ddcutil support is on.
local function readDdc()
  if not noctalia.getSetting("brightness.enable_ddcutil") or not noctalia.commandExists("ddcutil") then
    return
  end
  lastDdcMs = noctalia.nowMs()
  local function readBus(monitor)
    noctalia.runAsync({ "ddcutil", "--noconfig", "--bus", tostring(monitor.bus), "getvcp", "10", "--brief" },
      function(result)
        local current, max = (result.stdout or ""):match("VCP 10 C (%d+) (%d+)")
        current, max = tonumber(current), tonumber(max)
        if current and max and max > 0 and noctalia.nowMs() - (lastSetMs[monitor.name] or 0) >= SETTLE_MS then
          monitor.brightness = math.clamp(current / max, 0, 1)
          publish()
        end
      end, 20000)
  end
  noctalia.runAsync({ "ddcutil", "--noconfig", "detect", "--brief" }, function(result)
    -- Each display is a block: "Display 1", then "I2C bus: /dev/i2c-6" and
    -- "DRM connector: card1-DP-1". Blocks that are not "Display N" cannot be controlled.
    for block in ((result.stdout or "") .. "\n\n"):gmatch("(.-)\n%s*\n") do
      local bus = block:match("^%s*Display %d+.-I2C bus:%s*/dev/i2c%-(%d+)")
      local connector = block:match("DRM connector:%s*card%d+%-(%S+)")
      local monitor = connector and findMonitor(connector)
      if bus and monitor and not monitor.internal then
        monitor.bus = tonumber(bus)
        readBus(monitor)
      end
    end
  end, 20000)
end

local function isInternal(name)
  return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI")
end

local function loadOutputs()
  local old = {}
  for _, monitor in ipairs(monitors) do
    old[monitor.name] = monitor
  end
  monitors = {}
  for _, output in ipairs(noctalia.outputs()) do
    local internal = isInternal(output.name) and true or false
    local label = internal and noctalia.tr("monitor.builtin")
      or (output.description ~= "" and output.description or output.name)
    local previous = old[output.name]
    table.insert(monitors, {
      name = output.name,
      label = label,
      internal = internal,
      brightness = previous and previous.brightness,
      bus = previous and previous.bus,
    })
  end
  backlight = nil
  findBacklight()
  readDdc()
  publish()
end

local function readWorkspaces()
  if not perWorkspace() then
    if next(workspaces) then
      workspaces = {}
      publish()
    end
    return
  end
  noctalia.runAsync({ "hyprctl", "-j", "monitors" }, function(result)
    local list = result.exitCode == 0 and noctalia.json.decode(result.stdout or "")
    if type(list) ~= "table" then
      return
    end
    local changed = false
    for _, item in ipairs(list) do
      local workspace = type(item.activeWorkspace) == "table" and item.activeWorkspace.name or nil
      if type(item.name) == "string" and workspaces[item.name] ~= workspace then
        workspaces[item.name] = workspace
        changed = true
      end
    end
    if changed then
      publish()
    end
  end)
end

noctalia.state.watch("screen-control.command", function(command)
  if type(command) ~= "table" then
    return
  end
  local action = command.action
  if action == "level" and type(command.level) == "number" then
    setLevel(command.output, command.level)
  elseif action == "step" and type(command.delta) == "number" then
    step(command.output, command.delta)
  elseif action == "night" then
    setNightMode(command.mode)
  elseif action == "temperature" and type(command.value) == "number" then
    configSet("nightlight.temperature_night", math.floor(command.value))
  elseif action == "refresh" and noctalia.nowMs() - lastDdcMs >= DDC_REFRESH_MS then
    readDdc()
  end
  publish()
end)

-- noctalia msg plugin omerfuyar/screen-control:service all up [percent]
-- noctalia msg plugin omerfuyar/screen-control:service all down [percent]
-- Moves the focused monitor along the scale; "down" goes on into dimming.
function onIpc(event, payload)
  if event ~= "up" and event ~= "down" then
    return
  end
  local name = noctalia.focusedOutputName()
  if name == nil then
    return
  end
  local percent = tonumber(payload or "")
  local amount = percent and percent / 100 or Level.STEP
  step(name, event == "up" and amount or -amount)
  publish()
end

local lastNight = nil

function update()
  readBacklight()
  readWorkspaces()
  -- Night light can change in Noctalia's own settings.
  local night = `{nightMode()}{noctalia.getSetting("nightlight.temperature_night")}`
  if night ~= lastNight then
    lastNight = night
    publish()
  end
end

function onConfigChanged()
  noctalia.setUpdateInterval(perWorkspace() and 300 or 1000)
  readWorkspaces()
  publish()
end

function onOutputsChanged()
  loadOutputs()
end

noctalia.readFileAsync(dataFile, function(text)
  local saved = text and noctalia.json.decode(text)
  if type(saved) == "table" and type(saved.dims) == "table" then
    dims = saved.dims
  end
  loadOutputs()
  onConfigChanged()
end)
