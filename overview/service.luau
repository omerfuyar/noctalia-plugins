--!nonstrict
-- Overview service: reads Hyprland's monitors, workspaces and windows when the panel opens,
-- takes a small picture of each window with grim, and runs what the panel asks: focus a
-- window, switch workspace, move a window.
--
-- Hyprland takes dispatchers in Lua when its config is Lua, and in the older form
-- otherwise; dispatch() tries Lua first.
--
-- Publishes "overview.model" and takes commands on "overview.command".

local function onHyprland()
  return noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE") ~= nil and noctalia.commandExists("hyprctl")
end

local function decode(result)
  if result.exitCode ~= 0 then
    return nil
  end
  local value = noctalia.json.decode(result.stdout or "")
  return type(value) == "table" and value or nil
end

local function idOf(value)
  return type(value) == "table" and value.id or value
end

-- Builds the model from the three hyprctl answers. Window positions are kept relative to
-- their monitor, in logical pixels.
local function build(monitorList, workspaceList, clientList)
  local monitors, monitorById, monitorByName = {}, {}, {}
  for _, m in ipairs(monitorList) do
    local scale = m.scale or 1
    local width, height = m.width / scale, m.height / scale
    if m.transform == 1 or m.transform == 3 or m.transform == 5 or m.transform == 7 then
      width, height = height, width
    end
    local monitor = {
      id = m.id,
      name = m.name,
      x = m.x,
      y = m.y,
      width = width,
      height = height,
      active = idOf(m.activeWorkspace),
      focused = m.focused == true,
    }
    table.insert(monitors, monitor)
    monitorById[m.id] = monitor
    monitorByName[m.name] = monitor
  end

  local workspaces, workspaceById = {}, {}
  for _, w in ipairs(workspaceList) do
    -- Special workspaces have negative ids and live outside the usual flow.
    if w.id > 0 then
      local monitor = monitorByName[w.monitor] or monitorById[w.monitorID]
      local workspace = { id = w.id, name = w.name, monitor = monitor and monitor.name or "", windows = {} }
      table.insert(workspaces, workspace)
      workspaceById[w.id] = workspace
    end
  end
  table.sort(workspaces, function(a, b) return a.id < b.id end)

  for _, c in ipairs(clientList) do
    local workspace = workspaceById[idOf(c.workspace)]
    local monitor = workspace and monitorByName[workspace.monitor]
    if workspace and monitor and c.mapped ~= false and c.hidden ~= true then
      table.insert(workspace.windows, {
        address = c.address,
        class = c.class or "",
        title = c.title or "",
        x = c.at[1] - monitor.x,
        y = c.at[2] - monitor.y,
        width = c.size[1],
        height = c.size[2],
        floating = c.floating == true,
        focused = c.focusHistoryID == 0,
        stableId = c.stableId,
      })
    end
  end

  return { hyprland = true, monitors = monitors, workspaces = workspaces }
end

local reading = false

-- Pictures are taken at this share of the window's size: enough for a card.
local PREVIEW_SCALE = "0.25"
local previewDir = (noctalia.pluginDataDir() or "") .. "/previews"
local previewFiles = {} -- files of the last pictures, removed before new ones are taken
local generation = 0

-- Takes a picture of every window, even on hidden workspaces, with grim and the window's
-- toplevel id. Each round has new file names, so the panel does not show a cached picture.
local function capture(model)
  if not noctalia.commandExists("grim") then
    return
  end
  for _, path in ipairs(previewFiles) do
    noctalia.removeFile(path)
  end
  previewFiles = {}
  generation += 1
  noctalia.mkdirAll(previewDir)
  local pending = 0
  for _, workspace in ipairs(model.workspaces) do
    for _, window in ipairs(workspace.windows) do
      if window.stableId then
        local path = `{previewDir}/{window.stableId}-{generation}.png`
        pending += 1
        table.insert(previewFiles, path)
        noctalia.runAsync({ "grim", "-T", window.stableId, "-s", PREVIEW_SCALE, path }, function(result)
          pending -= 1
          if result.exitCode == 0 then
            window.preview = path
          end
          -- One update when all pictures are there.
          if pending == 0 then
            noctalia.state.set("overview.model", model)
          end
        end, 5000)
      end
    end
  end
end

local function refresh()
  if not onHyprland() then
    noctalia.state.set("overview.model", { hyprland = false })
    return
  end
  if reading then
    return
  end
  reading = true
  noctalia.runAsync({ "hyprctl", "-j", "monitors" }, function(monitors)
    noctalia.runAsync({ "hyprctl", "-j", "workspaces" }, function(workspaces)
      noctalia.runAsync({ "hyprctl", "-j", "clients" }, function(clients)
        reading = false
        local m, w, c = decode(monitors), decode(workspaces), decode(clients)
        if m and w and c then
          local model = build(m, w, c)
          noctalia.state.set("overview.model", model)
          capture(model)
        end
      end)
    end)
  end)
end

-- lua is a dispatcher call such as `hl.dsp.focus({ workspace = "2" })`; legacy is the same
-- in the older form, as hyprctl arguments.
local function dispatch(lua, legacy, onDone)
  noctalia.runAsync({ "hyprctl", "dispatch", lua }, function(result)
    if noctalia.string.trim(result.stdout or "") == "ok" then
      if onDone then onDone() end
      return
    end
    local argv = { "hyprctl", "dispatch" }
    table.move(legacy, 1, #legacy, #argv + 1, argv)
    noctalia.runAsync(argv, function()
      if onDone then onDone() end
    end)
  end)
end

-- %q makes a quoted Lua string, so names and addresses cannot break out of it.
local function quoted(value)
  return string.format("%q", tostring(value))
end

noctalia.state.watch("overview.command", function(command)
  if type(command) ~= "table" or not onHyprland() then
    return
  end
  local action = command.action
  if action == "refresh" then
    refresh()
  elseif action == "focus" and type(command.address) == "string" then
    local window = "address:" .. command.address
    dispatch(`hl.dsp.focus(\{ window = {quoted(window)} \})`, { "focuswindow", window })
  elseif action == "switch" and command.workspace then
    local workspace = tostring(command.workspace)
    dispatch(`hl.dsp.focus(\{ workspace = {quoted(workspace)} \})`, { "workspace", workspace })
  elseif action == "move" and type(command.address) == "string" and command.workspace then
    local window = "address:" .. command.address
    local workspace = tostring(command.workspace)
    dispatch(
      `hl.dsp.window.move(\{ workspace = {quoted(workspace)}, follow = false, window = {quoted(window)} \})`,
      { "movetoworkspacesilent", `{workspace},{window}` },
      refresh
    )
  end
end)

-- The key binding from the "keybind" setting, such as "SUPER + Tab". It is added to Hyprland
-- while Noctalia runs, never written to its config. A key that is already bound is left
-- alone, and Hyprland drops added bindings when it reloads, so update() checks it again.

local TOGGLE = "noctalia msg panel-toggle omerfuyar/overview:panel"
local MODIFIERS = { SHIFT = 1, CAPS = 2, CTRL = 4, CONTROL = 4, ALT = 8, MOD2 = 16, MOD3 = 32, SUPER = 64, MOD5 = 128 }

local bound = nil -- the key this plugin bound, as written in the setting
local warned = nil

-- "SUPER + SHIFT + Tab" -> modmask 65, key "Tab", and the older form "SUPER SHIFT,Tab".
local function parseKey(text)
  local parts = {}
  for part in text:gmatch("[^+]+") do
    table.insert(parts, noctalia.string.trim(part))
  end
  local key = table.remove(parts)
  if key == nil or key == "" then
    return nil
  end
  local mask = 0
  for _, modifier in ipairs(parts) do
    local value = MODIFIERS[modifier:upper()]
    if value == nil then
      return nil
    end
    mask += value
  end
  return mask, key, table.concat(parts, " ") .. "," .. key
end

local function unbind(key)
  local _, _, legacy = parseKey(key)
  noctalia.runAsync({ "hyprctl", "eval", `hl.unbind({quoted(key)})` }, function(result)
    if noctalia.string.trim(result.stdout or "") ~= "ok" then
      noctalia.runAsync({ "hyprctl", "keyword", "unbind", legacy or key })
    end
  end)
end

local function checkBinding()
  local wanted = noctalia.string.trim(noctalia.getConfig("keybind") or "")
  if not onHyprland() then
    return
  end
  if bound and bound ~= wanted then
    unbind(bound)
    bound = nil
  end
  if wanted == "" then
    return
  end
  local mask, key, legacy = parseKey(wanted)
  if mask == nil then
    if warned ~= wanted then
      warned = wanted
      noctalia.notifyError(noctalia.tr("keybind.invalid_title"), noctalia.tr("keybind.invalid", { key = wanted }))
    end
    return
  end
  noctalia.runAsync({ "hyprctl", "-j", "binds" }, function(result)
    local binds = decode(result) or {}
    for _, bind in ipairs(binds) do
      if bind.modmask == mask and tostring(bind.key):lower() == key:lower() then
        if bound ~= wanted and warned ~= wanted then
          warned = wanted
          noctalia.notifyError(noctalia.tr("keybind.taken_title"), noctalia.tr("keybind.taken", { key = wanted }))
        end
        return
      end
    end
    -- Not bound: either never added, or dropped by a Hyprland reload.
    bound = wanted
    local command = `hl.bind({quoted(wanted)}, hl.dsp.exec_cmd({quoted(TOGGLE)}))`
    noctalia.runAsync({ "hyprctl", "eval", command }, function(lua)
      if noctalia.string.trim(lua.stdout or "") ~= "ok" then
        noctalia.runAsync({ "hyprctl", "keyword", "bind", `{legacy},exec,{TOGGLE}` })
      end
    end)
  end)
end

function update()
  checkBinding()
end

function onConfigChanged()
  checkBinding()
end

function onExit()
  if bound then
    unbind(bound)
  end
end

noctalia.setUpdateInterval(5000)
