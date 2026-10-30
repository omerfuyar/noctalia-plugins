--!nonstrict
-- Resurrect panel: when the setup was last saved and where, what is saved, and the Save
-- and Restore buttons. Renders "resurrect.model" and sends actions on "resurrect.command".

local model = nil
local confirming = false

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("resurrect.command", command)
end

local render

local function statusCard()
  local title, color, glyph
  if model.running then
    title, color, glyph = noctalia.tr("status.saving"), "primary", "loader-2"
  elseif model.error then
    title, color, glyph = noctalia.tr("status.failed"), "error", "alert-circle"
  elseif model.lastMs then
    local time = noctalia.formatTime("%Y-%m-%d %H:%M", math.floor(model.lastMs / 1000))
    title, color, glyph = noctalia.tr("status.saved", { time = time }), "primary", "circle-check"
  else
    title, color, glyph = noctalia.tr("status.never"), "on_surface_variant", "clock"
  end
  local lines = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = glyph, size = 20, color = color }),
      ui.label({ text = title, fontWeight = "semibold", flexGrow = 1 }),
    }),
  }
  if model.error then
    table.insert(lines, ui.label({ text = model.error, color = "error", maxLines = 3 }))
  end
  table.insert(lines, ui.label({ text = noctalia.tr("status.folder", { folder = model.folder }), color = "on_surface_variant" }))
  table.insert(lines, ui.label({
    text = model.remote ~= "" and noctalia.tr("status.remote", { remote = model.remote }) or noctalia.tr("status.local"),
    color = "on_surface_variant",
    maxLines = 2,
  }))
  return ui.column({ gap = 8, padding = 12, radius = 12, fill = "surface_container_high" }, lines)
end

-- One kind of thing a save holds, with how many the last save had.
local function includedRow(glyph, text, on, count)
  local children = {
    ui.glyph({ name = on and glyph or "minus", size = 16, color = on and "primary" or "on_surface_variant" }),
    ui.label({ text = text, color = on and "on_surface" or "on_surface_variant", maxLines = 2, flexGrow = 1 }),
  }
  if on and count then
    table.insert(children, ui.label({ text = tostring(count), color = "on_surface_variant" }))
  end
  return ui.row({ gap = 8, align = "center", flexGrow = 1 }, children)
end

local function included()
  local counts = model.counts
  local files = #model.files > 0 and table.concat(model.files, ", ") or noctalia.tr("saved.no_files")
  -- Until a save has counted them, the steps are named without a number.
  local hookText = counts.hooks and noctalia.trp("saved.hooks", counts.hooks) or noctalia.tr("saved.hooks_any")
  local hookRow = { includedRow("terminal-2", hookText, counts.hooks ~= 0) }
  if model.canOpen then
    table.insert(hookRow, ui.button({ glyph = "folder", variant = "ghost", controlSize = "sm",
      tooltip = noctalia.tr("saved.open_hooks"), onClick = function() send({ action = "hooks" }) end }))
  end
  return ui.column({ gap = 6 }, {
    ui.label({ text = noctalia.tr("saved.title"), color = "on_surface_variant" }),
    includedRow("package", noctalia.tr("saved.packages"), model.packages, counts.packages),
    includedRow("file-text", noctalia.tr("saved.files", { files = files }), #model.files > 0, counts.files),
    includedRow("settings", noctalia.tr("saved.services"), model.services, counts.services),
    includedRow("adjustments", noctalia.tr("saved.noctalia"), model.noctalia, counts.plugins),
    ui.row({ gap = 4, align = "center" }, hookRow),
  })
end

local function actions()
  if confirming then
    return ui.column({ gap = 8 }, {
      ui.label({ text = noctalia.tr("restore.confirm") }),
      ui.row({ gap = 8, justify = "end" }, {
        ui.button({ text = noctalia.tr("restore.cancel"), variant = "ghost", onClick = function()
          confirming = false
          render()
        end }),
        ui.button({ text = noctalia.tr("restore.start"), glyph = "terminal-2", variant = "primary", onClick = function()
          confirming = false
          send({ action = "restore" })
          panel.close()
        end }),
      }),
    })
  end
  local buttons = {}
  if model.canOpen then
    table.insert(buttons, ui.button({ glyph = "folder", variant = "ghost", tooltip = noctalia.tr("actions.open"),
      onClick = function() send({ action = "open" }) end }))
  end
  table.insert(buttons, ui.spacer({ flexGrow = 1 }))
  table.insert(buttons, ui.button({
    text = noctalia.tr("actions.restore"),
    variant = "ghost",
    enabled = model.canRestore,
    onClick = function()
      confirming = true
      render()
    end,
  }))
  table.insert(buttons, ui.button({
    text = noctalia.tr("actions.save"),
    glyph = "device-floppy",
    variant = "primary",
    enabled = not model.running,
    onClick = function() send({ action = "save" }) end,
  }))
  return ui.row({ gap = 8, align = "center" }, buttons)
end

render = function()
  if model == nil then
    panel.render(ui.column({ padding = 16 }, {
      ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }),
    }))
    return
  end
  local header = ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = "lifebuoy", size = 20, color = "primary" }),
    ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold" }),
  })
  if not model.ready then
    panel.render(ui.column({ gap = 12, padding = 16 }, {
      header,
      ui.label({ text = noctalia.tr("setup.body"), color = "on_surface_variant" }),
    }))
    return
  end
  panel.render(ui.column({ gap = 14, padding = 16 }, {
    header,
    statusCard(),
    included(),
    ui.separator({}),
    actions(),
  }))
end

noctalia.state.watch("resurrect.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  confirming = false
  model = noctalia.state.get("resurrect.model") or model
  render()
end
