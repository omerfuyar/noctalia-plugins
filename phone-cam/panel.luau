--!nonstrict
-- Phone Cam panel: the phone to use, the webcam with its camera choice, and the phone's
-- screen. Renders "phone-cam.model" and sends actions on "phone-cam.command".

local model = nil

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("phone-cam.command", command)
end

local function card(glyph, color, title, lines, buttons)
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = glyph, size = 20, color = color }),
      ui.label({ text = title, fontWeight = "semibold" }),
    }),
  }
  for _, line in ipairs(lines) do
    table.insert(children, ui.label({ text = line, color = "on_surface_variant" }))
  end
  if buttons and #buttons > 0 then
    table.insert(children, ui.row({ gap = 8, justify = "end" }, buttons))
  end
  return ui.column({ gap = 10, padding = 12, radius = 12, fill = "surface_container_high" }, children)
end

local function setupCard()
  local list = table.concat(model.missing, ", ")
  local buttons = {
    ui.button({ text = noctalia.tr("setup.check"), variant = "ghost", onClick = function() send({ action = "open" }) end }),
  }
  if model.installCommand then
    table.insert(buttons, ui.button({
      text = noctalia.tr("setup.install"),
      glyph = "terminal-2",
      variant = "primary",
      onClick = function() noctalia.runInTerminal(model.installCommand) end,
    }))
  end
  local lines = { noctalia.tr("setup.body", { list = list }) }
  table.insert(lines, model.installCommand or noctalia.tr("setup.manual", { list = list }))
  return card("alert-triangle", "error", noctalia.tr("setup.title"), lines, buttons)
end

local function selectedDevice()
  for _, device in ipairs(model.devices) do
    if device.serial == model.selected then
      return device
    end
  end
  return nil
end

local function deviceBlock()
  if #model.devices == 0 then
    return card("device-mobile-off", "on_surface_variant", noctalia.tr("device.none"), {
      noctalia.tr("device.step1"),
      noctalia.tr("device.step2"),
    })
  end
  local rows = {}
  for _, device in ipairs(model.devices) do
    local selected = device.serial == model.selected
    local status = device.state == "device" and noctalia.tr("device.ready")
      or device.state == "unauthorized" and noctalia.tr("device.unauthorized")
      or noctalia.tr("device.offline")
    table.insert(rows, ui.row({
      key = device.serial,
      gap = 10,
      align = "center",
      padding = 8,
      radius = 8,
      fill = selected and "primary/0.12" or "surface_container/0.6",
      onClick = function() send({ action = "select", serial = device.serial }) end,
    }, {
      ui.glyph({ name = "device-mobile", size = 18, color = selected and "primary" or "on_surface_variant" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = device.name, maxLines = 1 }),
        ui.label({ text = status, color = device.state == "device" and "on_surface_variant" or "error", maxLines = 2 }),
      }),
    }))
  end
  return ui.column({ gap = 6 }, rows)
end

local function facingButton(value)
  local active = model.facing == value
  return ui.button({
    text = noctalia.tr("webcam." .. value),
    variant = active and "secondary" or "ghost",
    selected = active,
    controlSize = "sm",
    flexGrow = 1,
    onClick = function() send({ action = "facing", facing = value }) end,
  })
end

local function jobError(kind, job)
  return ui.row({ gap = 8, align = "center" }, {
    ui.label({ text = job.error or "", color = "error", flexGrow = 1, maxLines = 3 }),
    ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", tooltip = noctalia.tr("error.dismiss"),
      onClick = function() send({ action = "dismiss", kind = kind }) end }),
  })
end

local function webcamBlock(ready)
  local job = model.webcam
  local running = job and job.status == "running"
  if model.loopback == nil then
    return card("camera-off", "on_surface_variant", noctalia.tr("webcam.title"), {
      noctalia.tr("webcam.no_loopback"),
    }, {
      ui.button({ text = noctalia.tr("setup.check"), variant = "ghost", onClick = function() send({ action = "open" }) end }),
      ui.button({ text = noctalia.tr("webcam.setup"), glyph = "terminal-2", variant = "primary",
        onClick = function() noctalia.runInTerminal(model.loopbackCommand) end }),
    })
  end
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "camera", size = 18, color = running and "primary" or "on_surface_variant" }),
      ui.label({ text = noctalia.tr("webcam.title"), flexGrow = 1 }),
      ui.button({
        text = running and noctalia.tr("webcam.stop") or noctalia.tr("webcam.start"),
        glyph = running and "player-stop" or "player-play",
        variant = running and "destructive" or "primary",
        controlSize = "sm",
        enabled = running or ready,
        onClick = function() send({ action = "webcam" }) end,
      }),
    }),
    ui.row({ gap = 6 }, { facingButton("back"), facingButton("front") }),
    ui.label({
      text = running and noctalia.tr("webcam.running", { name = job.name, camera = model.loopback.name })
        or noctalia.tr("webcam.hint", { camera = model.loopback.name }),
      color = "on_surface_variant",
    }),
  }
  if job and job.status == "failed" then
    table.insert(children, jobError("webcam", job))
  end
  return ui.column({ gap = 8 }, children)
end

local function mirrorBlock(ready)
  local job = model.mirror
  local running = job and job.status == "running"
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "device-mobile", size = 18, color = running and "primary" or "on_surface_variant" }),
      ui.label({ text = noctalia.tr("mirror.title"), flexGrow = 1 }),
      ui.button({
        text = running and noctalia.tr("mirror.stop") or noctalia.tr("mirror.start"),
        variant = running and "destructive" or "ghost",
        controlSize = "sm",
        enabled = running or ready,
        onClick = function() send({ action = "mirror" }) end,
      }),
    }),
  }
  if job and job.status == "failed" then
    table.insert(children, jobError("mirror", job))
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
      ui.glyph({ name = "device-mobile", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold" }),
    }),
  }
  if not model.ready then
    table.insert(children, setupCard())
  else
    local device = selectedDevice()
    local ready = device ~= nil and device.state == "device"
    table.insert(children, deviceBlock())
    table.insert(children, ui.separator({}))
    table.insert(children, webcamBlock(ready))
    table.insert(children, ui.separator({}))
    table.insert(children, mirrorBlock(ready))
  end
  panel.render(ui.column({ gap = 14, padding = 16 }, children))
end

noctalia.state.watch("phone-cam.model", function(value)
  model = value
  render()
end)

function onOpen(_context)
  send({ action = "open" })
  model = noctalia.state.get("phone-cam.model") or model
  render()
end

function onClose()
  send({ action = "close" })
end
