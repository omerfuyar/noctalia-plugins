--!nonstrict
-- Keyboard panel: every language you type in, from the compositor's layouts and fcitx5's
-- input methods, with the active one marked. A click switches to it, ✕ removes it, and the
-- pickers below add a layout or an input method. Renders "keyboard.model" and sends actions
-- on "keyboard.command".

local model = nil

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("keyboard.command", command)
end

local function entryRow(entry)
  local active = entry.key == model.current
  return ui.row({
    key = entry.key,
    gap = 10,
    align = "center",
    paddingH = 8,
    paddingV = 6,
    radius = 8,
    fill = active and "primary/0.12" or nil,
    onClick = function() send({ action = "choose", key = entry.key }) end,
  }, {
    ui.label({ text = entry.short, width = 32, fontWeight = "semibold", color = active and "primary" or "on_surface" }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = entry.name, maxLines = 1 }),
      ui.label({
        text = noctalia.tr(entry.kind == "layout" and "entry.layout" or "entry.input_method"),
        color = "on_surface_variant",
        fontSize = 11,
      }),
    }),
    active and ui.glyph({ name = "check", size = 16, color = "primary" }) or ui.box({ width = 16 }),
    entry.removable and ui.button({
      glyph = "x",
      variant = "ghost",
      controlSize = "sm",
      tooltip = noctalia.tr("panel.remove"),
      onClick = function()
        if entry.kind == "layout" then
          send({ action = "remove_layout", index = entry.index })
        else
          send({ action = "remove_im", id = entry.id })
        end
      end,
    }) or ui.box({ width = 32 }),
  })
end

-- A picker that adds the chosen one of <items> with <add>, then shows its placeholder again.
local function picker(key, placeholder, items, label, add)
  local options = {}
  for _, item in ipairs(items) do
    table.insert(options, label(item))
  end
  return ui.select({
    key = key .. #items,
    options = options,
    placeholder = placeholder,
    enabled = #items > 0,
    onChange = function(index)
      local item = items[(tonumber(index) or -1) + 1]
      if item then
        add(item)
      end
    end,
  })
end

-- Adding layouts and input methods, and giving the layouts back to Hyprland's config.
local function addBlock()
  local catalog = model.catalog
  if catalog == nil then
    return ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" })
  end
  local have = {}
  for _, entry in ipairs(model.entries) do
    if entry.kind == "layout" then
      have[entry.code] = true
    end
  end
  local layouts = {}
  for _, layout in ipairs(catalog.layouts) do
    if not have[layout.code] then
      table.insert(layouts, layout)
    end
  end
  local children = {
    picker("add-layout", noctalia.tr("panel.add_layout"), layouts,
      function(layout) return layout.name end,
      function(layout) send({ action = "add_layout", code = layout.code }) end),
  }
  if model.fcitx then
    if #catalog.ims > 0 then
      table.insert(children, picker("add-im", noctalia.tr("panel.add_im"), catalog.ims,
        function(im) return im.name end,
        function(im) send({ action = "add_im", id = im.id }) end))
    else
      table.insert(children, ui.label({ text = noctalia.tr("panel.no_more_ims"), color = "on_surface_variant", maxLines = 3 }))
    end
  end
  if model.managed then
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = noctalia.tr("panel.managed"), color = "on_surface_variant", flexGrow = 1, maxLines = 3 }),
      ui.button({
        text = noctalia.tr("panel.reset"),
        variant = "ghost",
        controlSize = "sm",
        onClick = function() send({ action = "reset_layouts" }) end,
      }),
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
      ui.glyph({ name = "keyboard", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold" }),
    }),
  }
  if not model.ready then
    table.insert(children, ui.label({ text = noctalia.tr("panel.none"), color = "on_surface_variant", maxLines = 3 }))
  else
    local rows = {}
    for _, entry in ipairs(model.entries) do
      table.insert(rows, entryRow(entry))
    end
    table.insert(children, ui.column({ gap = 4 }, rows))
  end
  table.insert(children, ui.separator({}))
  table.insert(children, addBlock())
  panel.render(ui.column({ gap = 12, padding = 16 }, children))
end

noctalia.state.watch("keyboard.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "open" })
  model = noctalia.state.get("keyboard.model") or model
  render()
end
