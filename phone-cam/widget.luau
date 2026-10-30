--!nonstrict
-- Phone Cam bar widget: a phone glyph, a camera while the webcam runs.
-- Renders "phone-cam.model" from service.luau; a click opens the panel.

local PANEL = "omerfuyar/phone-cam:panel"

local model = nil

local function running(job)
  return job ~= nil and job.status == "running"
end

local function render()
  if model == nil then
    return
  end
  local webcam, mirror = running(model.webcam), running(model.mirror)
  local glyph = webcam and "camera" or "device-mobile"
  -- color nil keeps the bar's own color.
  local color = (webcam or mirror) and "primary" or nil
  if not model.ready then
    glyph, color = "alert-triangle", "error"
  end
  barWidget.render(ui.glyph({ name = glyph, color = color }))

  if not model.ready then
    barWidget.setTooltip(noctalia.tr("widget.setup", { list = table.concat(model.missing, ", ") }))
  elseif webcam then
    barWidget.setTooltip(noctalia.tr("widget.webcam", { name = model.webcam.name }))
  elseif mirror then
    barWidget.setTooltip(noctalia.tr("widget.mirror", { name = model.mirror.name }))
  else
    barWidget.setTooltip(noctalia.tr("widget.idle"))
  end
end

noctalia.state.watch("phone-cam.model", function(value)
  model = value
  render()
end)

function update()
  noctalia.setUpdateInterval(60000)
  model = model or noctalia.state.get("phone-cam.model")
  render()
end

function onClick()
  noctalia.togglePanel(PANEL)
end

-- Right click starts or stops the webcam.
function onRightClick()
  noctalia.state.set("phone-cam.command", { action = "webcam", n = noctalia.nowMs() })
end
