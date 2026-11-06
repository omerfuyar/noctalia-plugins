--!nonstrict
-- Keyboard panel: every language you type in, from the compositor's layouts and fcitx5's
-- input methods, with the active one marked. A click switches to it. Renders
-- "keyboard.model" and sends actions on "keyboard.command".

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
  })
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
  panel.render(ui.column({ gap = 12, padding = 16 }, children))
end

noctalia.state.watch("keyboard.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "refresh" })
  model = noctalia.state.get("keyboard.model") or model
  render()
end
