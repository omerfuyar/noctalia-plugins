--!nonstrict
-- Agenda panel: the next event with a Join button, then the coming days' events.

local Agenda = require("./lib/agenda.luau")

local lastMinute = -1

local function noCalendar()
  return ui.column({ gap = 12, padding = 16 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "calendar-off", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("setup.title"), fontWeight = "semibold" }),
    }),
    ui.label({ text = noctalia.tr("setup.body"), color = "on_surface_variant" }),
    ui.row({ justify = "end" }, {
      ui.button({
        text = noctalia.tr("setup.open"),
        glyph = "settings",
        variant = "primary",
        onClick = function()
          Agenda.openCalendarSettings()
          panel.close()
        end,
      }),
    }),
  })
end

local function joinButton(event, now, compact)
  if event.url == "" then
    return nil
  end
  local active = Agenda.isNow(event, now) or Agenda.isSoon(event, now)
  return ui.button({
    text = not compact and noctalia.tr("event.join") or nil,
    glyph = "video",
    variant = active and "primary" or "ghost",
    controlSize = "sm",
    tooltip = compact and noctalia.tr("event.join") or nil,
    onClick = function()
      Agenda.join(event)
      panel.close()
    end,
  })
end

local function nextCard(event, now)
  local details = {
    ui.label({ text = Agenda.isNow(event, now) and noctalia.tr("card.now") or noctalia.tr("card.next"),
      color = "primary", fontWeight = "semibold" }),
    ui.label({ text = event.title, fontWeight = "bold", fontSize = 16, maxLines = 2 }),
    ui.label({ text = `{Agenda.range(event)} · {Agenda.countdown(event, now)}`, color = "on_surface_variant" }),
  }
  if event.location ~= "" then
    table.insert(details, ui.row({ gap = 4, align = "center" }, {
      ui.glyph({ name = "map-pin", size = 14, color = "on_surface_variant" }),
      ui.label({ text = event.location, color = "on_surface_variant", maxLines = 1 }),
    }))
  end
  local children = { ui.column({ gap = 4, flexGrow = 1 }, details) }
  local join = joinButton(event, now, false)
  if join then
    table.insert(children, join)
  end
  return ui.row({ gap = 12, align = "center", padding = 12, radius = 12, fill = "surface_container_high" }, children)
end

local function eventRow(event, now)
  -- The calendar's own color from Noctalia, as in Noctalia's calendar views.
  local color = event.colorHex ~= "" and event.colorHex or "primary"
  local sub = `{Agenda.range(event)} · {event.calendarName}`
  local children = {
    ui.box({ width = 4, height = 32, radius = 2, fill = color }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = event.title, maxLines = 2 }),
      ui.label({ text = sub, color = "on_surface_variant", maxLines = 1 }),
    }),
  }
  local join = joinButton(event, now, true)
  if join then
    table.insert(children, join)
  end
  return ui.row({ key = event.id .. event.startMs, gap = 10, align = "center", paddingV = 4 }, children)
end

local function render()
  local now = noctalia.nowMs()
  local events = Agenda.events()
  if events == nil then
    panel.render(noCalendar())
    return
  end

  local count = noctalia.getConfig("days") or 7
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "calendar", size = 20, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontWeight = "semibold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = Agenda.date(math.floor(now / 1000)), color = "on_surface_variant" }),
    }),
  }

  local focus = Agenda.focus(events, now)
  if focus then
    table.insert(children, nextCard(focus, now))
  end

  local days = Agenda.days(events, now, count)
  if #days == 0 then
    table.insert(children, ui.label({ text = noctalia.trp("panel.empty", count), color = "on_surface_variant" }))
  else
    local rows = {}
    for _, day in ipairs(days) do
      -- The next event is already in the card above.
      local dayRows = {}
      for _, event in ipairs(day.events) do
        if event ~= focus or day.index > 0 then
          table.insert(dayRows, eventRow(event, now))
        end
      end
      if #dayRows > 0 then
        table.insert(rows, ui.label({ key = "day" .. day.index, text = Agenda.dayLabel(day),
          color = "primary", fontWeight = "semibold" }))
        table.move(dayRows, 1, #dayRows, #rows + 1, rows)
      end
    end
    if #rows > 0 then
      table.insert(children, ui.scroll({ gap = 6, flexGrow = 1 }, rows))
    end
  end

  panel.render(ui.column({ gap = 12, padding = 16 }, children))
end

function onOpen(_context)
  lastMinute = -1
  panel.setWantsSecondTicks(true)
  update()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

-- Renders again once a minute, so countdowns stay right while the panel is open.
function update()
  local minute = math.floor(noctalia.nowMs() / 60000)
  if minute ~= lastMinute then
    lastMinute = minute
    render()
  end
end
