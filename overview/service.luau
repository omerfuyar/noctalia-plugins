--!nonstrict
-- Overview service: reads Hyprland's monitors, workspaces and windows when the panel opens,
-- and runs what the panel asks: focus a window, switch workspace, move a window.
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
      })
    end
  end

  return { hyprland = true, monitors = monitors, workspaces = workspaces }
end

local reading = false

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
          noctalia.state.set("overview.model", build(m, w, c))
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
