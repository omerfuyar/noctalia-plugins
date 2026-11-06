--!nonstrict
-- Plugin Hub panel: Noctalia's own panels, every plugin you use and your own commands, each
-- with what it can do. A plugin's switch turns it on or off and its gear opens its settings.
-- Each action runs with ▶ and gets a key with its key button. Renders "hub.model" and sends
-- actions on "hub.command".

local LIST_HEIGHT = 460

local model = nil
local search = ""
local editing = nil -- the command whose key is being typed
local expanded = {} -- group id -> true while it shows its actions; a search shows them all

local render

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("hub.command", command)
end

local function matches(group, action)
  if search == "" then
    return true
  end
  local text = (group.title .. " " .. (action and (action.title .. " " .. action.command) or "")):lower()
  return text:find(search:lower(), 1, true) ~= nil
end

-- The key of an action: a field while it is typed, its key, or a button to add one.
local function keyControl(action)
  if not model.canBind then
    return nil
  end
  if editing == action.command then
    return ui.row({ gap = 4, align = "center" }, {
      ui.input({
        key = "key-" .. action.command,
        width = 130,
        controlSize = "sm",
        focus = true,
        value = model.keys[action.command] or "",
        placeholder = noctalia.tr("key.placeholder"),
        onSubmit = function(value)
          editing = nil
          send({ action = "set_key", command = action.command, key = value })
          render()
        end,
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        controlSize = "sm",
        onClick = function()
          editing = nil
          render()
        end,
      }),
    })
  end
  local key = model.keys[action.command]
  local state = key and model.status[key]
  local children = {}
  if state == "taken" or state == "invalid" then
    table.insert(children, ui.label({ text = noctalia.tr("key." .. state), color = "error", fontSize = 11 }))
  end
  table.insert(children, ui.button({
    text = key,
    glyph = key == nil and "keyboard" or nil,
    variant = key and "default" or "ghost",
    controlSize = "sm",
    onClick = function()
      editing = action.command
      render()
    end,
  }))
  return ui.row({ gap = 6, align = "center" }, children)
end

local function actionRow(action)
  local children = {
    ui.glyph({ name = action.kind == "panel" and "layout-sidebar" or "terminal-2", size = 16, color = "on_surface_variant" }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = action.title, maxLines = 1 }),
      action.kind == "command" and action.title ~= action.command
          and ui.label({ text = action.command, color = "on_surface_variant", fontSize = 11, maxLines = 1 })
        or nil,
    }),
  }
  local control = keyControl(action)
  if control then
    table.insert(children, control)
  end
  table.insert(children, ui.button({
    glyph = "player-play",
    variant = "ghost",
    controlSize = "sm",
    onClick = function()
      send({ action = "run", command = action.command })
      if action.kind == "panel" then
        panel.close()
      end
    end,
  }))
  if action.custom then
    table.insert(children, ui.button({
      glyph = "trash",
      variant = "ghost",
      controlSize = "sm",
      onClick = function() send({ action = "remove_custom", command = action.command }) end,
    }))
  end
  return ui.row({ key = action.command, gap = 8, align = "center", paddingH = 4 }, children)
end

local function groupHeader(group, open)
  local children = {
    ui.glyph({ name = open and "chevron-down" or "chevron-right", size = 16, color = "on_surface_variant" }),
    ui.label({ text = group.title, fontWeight = "semibold", flexGrow = 1, maxLines = 1 }),
  }
  if not open and group.enabled ~= false and #group.actions > 0 then
    table.insert(children, ui.label({ text = tostring(#group.actions), color = "on_surface_variant", fontSize = 11 }))
  end
  if group.plugin then
    if group.settings then
      table.insert(children, ui.button({
        glyph = "settings",
        variant = "ghost",
        controlSize = "sm",
        onClick = function()
          send({ action = "settings", id = group.id })
          panel.close()
        end,
      }))
    end
    table.insert(children, ui.toggle({
      checked = group.enabled == true,
      onChange = function(value) send({ action = "enable", id = group.id, on = value == "true" }) end,
    }))
  end
  return ui.row({
    gap = 8,
    align = "center",
    paddingH = 4,
    paddingV = 4,
    radius = 8,
    onClick = function()
      expanded[group.id] = not expanded[group.id] or nil
      render()
    end,
  }, children)
end

local function groupBlock(group)
  local rows = {}
  local headerMatches = matches(group, nil)
  if group.enabled ~= false then
    for _, action in ipairs(group.actions) do
      if headerMatches or matches(group, action) then
        table.insert(rows, actionRow(action))
      end
    end
  end
  if not headerMatches and #rows == 0 then
    return nil
  end
  local open = search ~= "" or expanded[group.id] == true
  local children = { groupHeader(group, open) }
  if not open then
    return ui.column({ key = "group-" .. group.id, gap = 4 }, children)
  end
  if group.enabled == false then
    table.insert(children, ui.label({ text = noctalia.tr("plugin.off"), color = "on_surface_variant", fontSize = 11 }))
  elseif group.custom then
    for _, row in ipairs(rows) do
      table.insert(children, row)
    end
    table.insert(children, ui.input({
      key = "add-custom-" .. #group.actions,
      controlSize = "sm",
      placeholder = noctalia.tr("custom.placeholder"),
      onSubmit = function(value)
        if noctalia.string.trim(value) ~= "" then
          send({ action = "add_custom", command = value })
        end
      end,
    }))
  elseif #rows == 0 then
    table.insert(children, ui.label({ text = noctalia.tr("plugin.nothing"), color = "on_surface_variant", fontSize = 11 }))
  else
    for _, row in ipairs(rows) do
      table.insert(children, row)
    end
  end
  return ui.column({ key = "group-" .. group.id, gap = 4 }, children)
end

render = function()
  if model == nil or not model.ready then
    panel.render(ui.column({ padding = 16 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    }))
    return
  end
  local blocks = {}
  for _, group in ipairs(model.groups) do
    local block = groupBlock(group)
    if block then
      if #blocks > 0 then
        table.insert(blocks, ui.separator({}))
      end
      table.insert(blocks, block)
    end
  end
  if #blocks == 0 then
    table.insert(blocks, ui.label({ text = noctalia.tr("panel.no_match"), color = "on_surface_variant" }))
  end
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "apps", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold", flexGrow = 1 }),
      ui.input({
        key = "search",
        width = 180,
        controlSize = "sm",
        placeholder = noctalia.tr("panel.search"),
        onChange = function(value)
          search = noctalia.string.trim(value)
          render()
        end,
      }),
    }),
  }
  if not model.canBind then
    table.insert(children, ui.label({ text = noctalia.tr("panel.no_keys"), color = "on_surface_variant", fontSize = 11, maxLines = 2 }))
  end
  table.insert(children, ui.scroll({ key = "list-" .. LIST_HEIGHT, height = LIST_HEIGHT, gap = 10 }, blocks))
  panel.render(ui.column({ gap = 12, padding = 16 }, children))
end

noctalia.state.watch("hub.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "refresh" })
  model = noctalia.state.get("hub.model") or model
  render()
end

function onClose()
  editing = nil
end
