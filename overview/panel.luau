--!nonstrict
-- Overview panel: every workspace as a small picture of its windows. A click on a window
-- goes to it, a click on a workspace switches to it, and a window dragged onto another
-- workspace moves there. Renders "overview.model" and sends actions on "overview.command".

local Layout = require("./lib/layout.luau")

local CARD_WIDTH = 256
local PER_ROW = 4
local GAP = 4
local DRAG_TYPE = "omerfuyar/overview:window"
-- A card's title line and the gap below it.
local CARD_HEADER = 26
local MAX_LIST_HEIGHT = 760

local model = nil

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("overview.command", command)
end

local function focusWindow(window)
  send({ action = "focus", address = window.address })
  panel.close()
end

local function windowTile(window, width, height)
  local iconSize = math.max(math.min(32, width - 12, height - 12), 12)
  local icon = window.class ~= "" and noctalia.appIconPath(window.class, iconSize) or nil
  local children = {
    icon and ui.image({ path = icon, width = iconSize, height = iconSize })
      or ui.glyph({ name = "app-window", size = iconSize, color = "on_surface_variant" }),
  }
  if height >= 56 and width >= 72 then
    table.insert(children, ui.label({ text = window.title, maxLines = 1, fontSize = 11,
      width = width - 12, color = "on_surface_variant" }))
  end
  return ui.dragSource({
    key = window.address,
    dragType = DRAG_TYPE,
    payload = window.address,
    grabCursor = false,
    width = width,
    height = height,
    gap = 4,
    padding = 4,
    align = "center",
    justify = "center",
    radius = 6,
    fill = "surface_container_high",
    border = window.focused and "primary" or "outline_variant",
    borderWidth = window.focused and 2 or 1,
    tooltip = window.title,
    onClick = function() focusWindow(window) end,
  }, { ui.column({ gap = 4, align = "center", justify = "center", flexGrow = 1 }, children) })
end

local function renderNode(node, width, height)
  if node.window then
    return windowTile(node.window, width, height)
  end
  local row = node.direction == "row"
  local sizes = Layout.sizes(row and width or height, node.shares, GAP)
  local children = {}
  for index, child in ipairs(node.children) do
    table.insert(children, row and renderNode(child, sizes[index], height) or renderNode(child, width, sizes[index]))
  end
  local container = row and ui.row or ui.column
  return container({ gap = GAP, width = width, height = height }, children)
end

local function preview(workspace, width, height)
  local tiled, floating = {}, {}
  for _, window in ipairs(workspace.windows) do
    table.insert(window.floating and floating or tiled, window)
  end
  local children = {}
  if #tiled > 0 then
    local floatHeight = #floating > 0 and 28 + GAP or 0
    table.insert(children, renderNode(Layout.tree(tiled), width, height - floatHeight))
  end
  if #floating > 0 then
    local chips = {}
    for _, window in ipairs(floating) do
      table.insert(chips, windowTile(window, 28, 28))
    end
    table.insert(children, ui.row({ gap = GAP, height = #tiled > 0 and 28 or height, align = "center",
      justify = "center" }, chips))
  end
  return children
end

local function card(workspace, monitor, active)
  local width = CARD_WIDTH
  local height = math.floor(width * monitor.height / monitor.width)
  local inner = height - 2 * 6
  local zone = ui.dropZone({
    accepts = { DRAG_TYPE },
    value = tostring(workspace.id),
    onDrop = function(address, value)
      send({ action = "move", address = address, workspace = value })
    end,
    width = width,
    height = height,
    padding = 6,
    gap = GAP,
    radius = 10,
    align = "center",
    justify = "center",
    fill = active and "primary/0.12" or "surface_container",
    border = active and "primary" or "outline_variant",
    borderWidth = active and 2 or 1,
  }, #workspace.windows > 0 and preview(workspace, width - 12, inner) or {
    ui.label({ text = noctalia.tr("workspace.empty"), color = "on_surface_variant" }),
  })
  local count = #workspace.windows
  return ui.column({
    key = "ws" .. workspace.id,
    gap = 6,
    width = width,
    onClick = function()
      send({ action = "switch", workspace = workspace.id })
      panel.close()
    end,
  }, {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = noctalia.tr("workspace.name", { name = workspace.name }),
        color = active and "primary" or "on_surface", fontWeight = "semibold", flexGrow = 1 }),
      ui.label({ text = noctalia.trp("workspace.windows", count), color = "on_surface_variant" }),
    }),
    zone,
  })
end

-- A drop target for a window that should get a workspace of its own.
local function newCard(monitor, id)
  local width = CARD_WIDTH
  local height = math.floor(width * monitor.height / monitor.width)
  return ui.column({ key = "new" .. monitor.name, gap = 6, width = width }, {
    ui.label({ text = noctalia.tr("workspace.new"), color = "on_surface_variant", fontWeight = "semibold" }),
    ui.dropZone({
      accepts = { DRAG_TYPE },
      value = tostring(id),
      onDrop = function(address, value)
        send({ action = "move", address = address, workspace = value })
      end,
      width = width,
      height = height,
      radius = 10,
      align = "center",
      justify = "center",
      border = "outline_variant",
      borderWidth = 1,
    }, {
      ui.glyph({ name = "plus", size = 28, color = "on_surface_variant" }),
    }),
  })
end

local function monitorSection(monitor, showName, nextId)
  local cards = {}
  for _, workspace in ipairs(model.workspaces) do
    if workspace.monitor == monitor.name then
      table.insert(cards, card(workspace, monitor, workspace.id == monitor.active))
    end
  end
  table.insert(cards, newCard(monitor, nextId))

  local rows = {}
  for start = 1, #cards, PER_ROW do
    table.insert(rows, ui.row({ gap = 16 }, table.move(cards, start, math.min(start + PER_ROW - 1, #cards), 1, {})))
  end
  -- Each row is a title line and a card; rows and the monitor name are 14 apart.
  local cardHeight = math.floor(CARD_WIDTH * monitor.height / monitor.width)
  local height = #rows * (CARD_HEADER + cardHeight) + (#rows - 1) * 14
  local children = {}
  if showName then
    height += 20 + 14
    table.insert(children, ui.row({ gap = 6, align = "center" }, {
      ui.glyph({ name = "device-desktop", size = 16, color = "on_surface_variant" }),
      ui.label({ text = monitor.name, color = "on_surface_variant" }),
    }))
  end
  table.move(rows, 1, #rows, #children + 1, children)
  return ui.column({ key = "mon" .. monitor.name, gap = 14 }, children), height
end

local function render()
  if model == nil then
    panel.render(ui.column({ padding = 20 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    }))
    return
  end
  if not model.hyprland then
    panel.render(ui.column({ padding = 20, gap = 8 }, {
      ui.label({ text = noctalia.tr("panel.not_hyprland"), color = "on_surface_variant" }),
    }))
    return
  end

  local nextId = 1
  for _, workspace in ipairs(model.workspaces) do
    nextId = math.max(nextId, workspace.id + 1)
  end

  -- A scroll in a panel that follows its content needs a height of its own.
  local sections, contentHeight = {}, 0
  for index, monitor in ipairs(model.monitors) do
    local section, height = monitorSection(monitor, #model.monitors > 1, nextId + index - 1)
    table.insert(sections, section)
    contentHeight += height + (index > 1 and 20 or 0)
  end

  panel.render(ui.column({ gap = 16, padding = 20 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "layout-grid", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold", flexGrow = 1 }),
      ui.label({ text = noctalia.tr("panel.hint"), color = "on_surface_variant" }),
    }),
    ui.scroll({ gap = 20, height = math.min(contentHeight, MAX_LIST_HEIGHT) }, sections),
  }))
end

noctalia.state.watch("overview.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "refresh" })
  render()
end
