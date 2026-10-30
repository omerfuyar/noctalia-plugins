--!nonstrict
-- Process Manager panel: running apps grouped by name, with their CPU and memory now. A
-- group opens to its processes. End asks a process to stop; one that does not stop gets
-- Force end. Renders "processes.model" and sends actions on "processes.command".

local GROUP_HEIGHT = 48
local PROCESS_HEIGHT = 52
local MAX_LIST_HEIGHT = 460
local MAX_GROUPS = 40

local model = nil
local query = ""
local sortBy = "cpu"
local allUsers = false
local expanded = {} -- group names that are open
local icons = {} -- app icon path by name, or false when there is none
-- Looking up an icon is slow, and a render has 25 ms: a few new ones per render.
local ICONS_PER_RENDER = 4
local iconLookups = 0

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("processes.command", command)
end

local render

local function memoryText(bytes)
  if bytes >= 1024 ^ 3 then
    return string.format("%.1f GB", bytes / 1024 ^ 3)
  end
  return string.format("%d MB", math.floor(bytes / 1024 ^ 2 + 0.5))
end

local function cpuText(cpu)
  return cpu >= 10 and string.format("%d%%", math.floor(cpu + 0.5)) or string.format("%.1f%%", cpu)
end

local function matches(process)
  if query == "" then
    return true
  end
  local needle = query:lower()
  return process.name:lower():find(needle, 1, true) ~= nil
    or process.args:lower():find(needle, 1, true) ~= nil
    or tostring(process.pid) == query
    or process.user:lower() == needle
end

-- Groups the visible processes by name, with totals, sorted as chosen.
local function groups()
  local byName, list = {}, {}
  for _, process in ipairs(model.processes or {}) do
    if (allUsers or process.uid == model.myUid) and matches(process) then
      local group = byName[process.name]
      if group == nil then
        group = { name = process.name, key = process.name:lower(), processes = {}, cpu = 0, memory = 0,
          stuck = false, denied = false }
        byName[process.name] = group
        table.insert(list, group)
      end
      table.insert(group.processes, process)
      group.cpu += process.cpu
      group.memory += process.memory
      group.stuck = group.stuck or process.stuck
      group.denied = group.denied or process.denied
    end
  end
  local function before(a, b)
    if sortBy == "memory" then
      return a.memory > b.memory
    elseif sortBy == "name" then
      return (a.key or a.name) < (b.key or b.name)
    end
    return a.cpu > b.cpu
  end
  table.sort(list, before)
  for _, group in ipairs(list) do
    table.sort(group.processes, before)
  end
  return list
end

local function pidsOf(processes)
  local pids = {}
  for _, process in ipairs(processes) do
    table.insert(pids, process.pid)
  end
  return pids
end

-- End, then Force end once it did not stop, and the administrator's versions of both
-- when the processes belong to someone else.
local function actions(processes, stuck, denied)
  local pids = pidsOf(processes)
  local buttons = {}
  if denied and model.canElevate then
    table.insert(buttons, ui.button({
      text = noctalia.tr(stuck and "action.force_admin" or "action.end_admin"),
      variant = "destructive",
      controlSize = "sm",
      onClick = function() send({ action = stuck and "force" or "end", pids = pids, elevate = true }) end,
    }))
  elseif stuck then
    table.insert(buttons, ui.button({
      text = noctalia.tr("action.force"),
      variant = "destructive",
      controlSize = "sm",
      onClick = function() send({ action = "force", pids = pids }) end,
    }))
  else
    table.insert(buttons, ui.button({
      glyph = "x",
      variant = "ghost",
      controlSize = "sm",
      tooltip = noctalia.tr(#pids > 1 and "action.end_all" or "action.end"),
      onClick = function() send({ action = "end", pids = pids }) end,
    }))
  end
  return buttons
end

-- What the state letter means, when it explains why a process does not end.
local function stateNote(process)
  if process.state == "D" then
    return noctalia.tr("state.waiting"), "on_surface_variant"
  elseif process.state == "Z" then
    return noctalia.tr("state.zombie"), "on_surface_variant"
  elseif process.denied then
    return noctalia.tr("state.denied", { user = process.user }), "error"
  elseif process.stuck then
    return noctalia.tr("state.stuck"), "error"
  elseif process.ending then
    return noctalia.tr("state.ending"), "on_surface_variant"
  end
  return nil
end

local function processRow(process)
  local note, noteColor = stateNote(process)
  local detail = {
    ui.label({ text = process.args ~= "" and process.args or process.name, maxLines = 1, fontSize = 12 }),
    ui.label({
      text = note or noctalia.tr("process.detail", { pid = process.pid, user = process.user }),
      color = noteColor or "on_surface_variant",
      fontSize = 11,
      maxLines = 1,
    }),
  }
  local children = {
    ui.column({ gap = 2, flexGrow = 1 }, detail),
    ui.label({ text = cpuText(process.cpu), color = "on_surface_variant", width = 52 }),
    ui.label({ text = memoryText(process.memory), color = "on_surface_variant", width = 64 }),
  }
  table.move(actions({ process }, process.stuck, process.denied), 1, 1, #children + 1, children)
  return ui.row({ key = "p" .. process.pid, gap = 8, align = "center", height = PROCESS_HEIGHT, paddingH = 8 }, children)
end

local function groupRow(group)
  local open = expanded[group.name] == true
  if icons[group.name] == nil and iconLookups < ICONS_PER_RENDER then
    iconLookups += 1
    icons[group.name] = noctalia.appIconPath(group.name, 24) or false
  end
  local icon = icons[group.name] or nil
  local title = #group.processes > 1 and noctalia.tr("group.count", { name = group.name, count = #group.processes })
    or group.name
  local children = {
    ui.button({
      glyph = open and "chevron-down" or "chevron-right",
      variant = "ghost",
      controlSize = "sm",
      onClick = function()
        expanded[group.name] = not open or nil
        render()
      end,
    }),
    icon and ui.image({ path = icon, width = 22, height = 22 })
      or ui.glyph({ name = "terminal", size = 20, color = "on_surface_variant" }),
    ui.label({ text = title, maxLines = 1, flexGrow = 1, color = group.stuck and "error" or "on_surface" }),
    ui.label({ text = cpuText(group.cpu), width = 52 }),
    ui.label({ text = memoryText(group.memory), width = 64 }),
  }
  table.move(actions(group.processes, group.stuck, group.denied), 1, 1, #children + 1, children)
  return ui.row({
    key = "g" .. group.name,
    gap = 8,
    align = "center",
    height = GROUP_HEIGHT,
    paddingH = 4,
    radius = 8,
    fill = open and "surface_container_high" or nil,
  }, children)
end

local function sortButton(value)
  local active = sortBy == value
  return ui.button({
    text = noctalia.tr("sort." .. value),
    variant = active and "secondary" or "ghost",
    selected = active,
    controlSize = "sm",
    onClick = function()
      sortBy = value
      render()
    end,
  })
end

render = function()
  if model == nil or model.processes == nil then
    panel.render(ui.column({ padding = 16 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    }))
    return
  end
  if not model.ready then
    panel.render(ui.column({ padding = 16 }, {
      ui.label({ text = noctalia.tr("panel.no_ps"), color = "on_surface_variant" }),
    }))
    return
  end

  local rows, height = {}, 0
  iconLookups = 0
  local list = groups()
  for index, group in ipairs(list) do
    if index > MAX_GROUPS then
      break
    end
    table.insert(rows, groupRow(group))
    height += GROUP_HEIGHT
    if expanded[group.name] then
      for _, process in ipairs(group.processes) do
        table.insert(rows, processRow(process))
        height += PROCESS_HEIGHT
      end
    end
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = noctalia.tr("panel.none"), color = "on_surface_variant" }))
    height = 32
  end

  local listHeight = math.min(height + 2 * #rows, MAX_LIST_HEIGHT)
  panel.render(ui.column({ gap = 12, padding = 16 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "list-details", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold", flexGrow = 1 }),
      ui.button({
        text = noctalia.tr("panel.all_users"),
        variant = allUsers and "secondary" or "ghost",
        selected = allUsers,
        controlSize = "sm",
        onClick = function()
          allUsers = not allUsers
          render()
        end,
      }),
    }),
    ui.input({
      key = "search",
      value = query,
      placeholder = noctalia.tr("panel.search"),
      focus = true,
      onChange = function(text)
        query = noctalia.string.trim(text)
        render()
      end,
    }),
    ui.row({ gap = 6, align = "center" }, {
      sortButton("cpu"),
      sortButton("memory"),
      sortButton("name"),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = noctalia.trp("panel.apps", #list), color = "on_surface_variant" }),
    }),
    -- A scroll in a panel that follows its content needs a height of its own. The key
    -- changes with it, since a scroll keeps the height it was made with.
    ui.scroll({ key = "list" .. listHeight, gap = 2, height = listHeight }, rows),
  }))
end

noctalia.state.watch("processes.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "open" })
  render()
end

function onClose()
  send({ action = "close" })
end
