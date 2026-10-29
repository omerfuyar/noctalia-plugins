--!nonstrict
-- Agenda bar widget: the next calendar event of today, with a countdown when it is close.
-- Left click opens the panel, right click opens the event's meeting link.

local Agenda = require("./lib/agenda.luau")

local PANEL = "omerfuyar/agenda:panel"

local focus = nil

-- color nil keeps the bar's own color.
local function show(glyph, color, text)
  local children = { ui.glyph({ name = glyph, color = color }) }
  if text and not barWidget.isVertical() then
    table.insert(children, ui.label({ text = text, color = color, maxWidth = 260, maxLines = 1 }))
  end
  barWidget.render(ui.row({ gap = 6, align = "center" }, children))
end

local function isToday(event, now)
  return noctalia.formatTime("%Y%m%d", math.floor(event.startMs / 1000))
    == noctalia.formatTime("%Y%m%d", math.floor(now / 1000))
end

local function tooltip(event, now)
  local rows = {
    { key = noctalia.tr("tooltip.event"), value = event.title },
    { key = noctalia.tr("tooltip.when"), value = `{Agenda.range(event)} ({Agenda.countdown(event, now)})` },
    { key = noctalia.tr("tooltip.calendar"), value = event.calendarName },
  }
  if event.location ~= "" then
    table.insert(rows, { key = noctalia.tr("tooltip.location"), value = event.location })
  end
  if event.url ~= "" then
    table.insert(rows, { key = noctalia.tr("tooltip.join"), value = noctalia.tr("tooltip.right_click") })
  end
  return rows
end

local function render()
  local now = noctalia.nowMs()
  local events = Agenda.events()
  if events == nil then
    focus = nil
    show("calendar")
    barWidget.setTooltip(noctalia.tr("widget.no_calendar"))
    return
  end

  local others
  focus, others = Agenda.focus(events, now)
  if focus == nil then
    show("calendar")
    barWidget.setTooltip(noctalia.tr("widget.free"))
    return
  end

  barWidget.setTooltip(tooltip(focus, now))
  if not isToday(focus, now) and not Agenda.isNow(focus, now) then
    show("calendar")
    return
  end

  local title = noctalia.getConfig("show_title") and focus.title or nil
  local extra = others > 0 and ` +{others}` or ""
  local glyph = focus.url ~= "" and "video" or "calendar-event"
  if Agenda.isNow(focus, now) then
    local text = title and noctalia.tr("widget.now", { title = title }) or noctalia.tr("countdown.now")
    show(glyph, "primary", text .. extra)
  elseif Agenda.isSoon(focus, now) then
    local countdown = Agenda.countdown(focus, now)
    show(glyph, "primary", (title and `{title} {countdown}` or countdown) .. extra)
  else
    local time = Agenda.time(focus.startMs)
    show("calendar-event", nil, (title and `{time} {title}` or time) .. extra)
  end
end

function update()
  noctalia.setUpdateInterval(15000)
  render()
end

function onClick()
  noctalia.togglePanel(PANEL)
end

function onRightClick()
  Agenda.join(focus)
end
