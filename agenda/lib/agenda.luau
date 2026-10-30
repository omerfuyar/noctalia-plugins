--!nonstrict
-- Shared by the widget and the panel: reads Noctalia's calendar events, picks the one to
-- show in the bar, groups the rest by day and formats times.

local Agenda = {}

local MINUTE_MS = 60 * 1000
local DAY_SECONDS = 24 * 60 * 60

-- Events from noctalia.calendarEvents(), without hidden calendars, sorted by start.
-- nil until Noctalia has synced its calendars once.
function Agenda.events()
  local all = noctalia.calendarEvents()
  if all == nil then
    return nil
  end
  local hidden = {}
  for _, name in ipairs(noctalia.getConfig("hidden_calendars") or {}) do
    hidden[name] = true
  end
  local events = {}
  for _, event in ipairs(all) do
    if not hidden[event.calendarName] then
      table.insert(events, event)
    end
  end
  table.sort(events, function(a, b)
    if a.startMs ~= b.startMs then
      return a.startMs < b.startMs
    end
    return a.allDay and not b.allDay
  end)
  return events
end

function Agenda.soonMs()
  return (noctalia.getConfig("soon_minutes") or 15) * MINUTE_MS
end

-- The event the bar shows: the next one when it starts soon, otherwise the one running
-- now, otherwise the next one. All-day events are left out. Also returns how many other
-- events start at the same time.
function Agenda.focus(events, now)
  local current, upcoming = nil, nil
  for _, event in ipairs(events) do
    if not event.allDay and event.endMs > now then
      if event.startMs <= now then
        current = current or event
      elseif upcoming == nil then
        upcoming = event
      end
    end
  end
  local focus = current or upcoming
  if upcoming and upcoming.startMs - now <= Agenda.soonMs() then
    focus = upcoming
  end
  if focus == nil then
    return nil, 0
  end
  local others = 0
  for _, event in ipairs(events) do
    if event ~= focus and not event.allDay and event.startMs == focus.startMs then
      others += 1
    end
  end
  return focus, others
end

function Agenda.isNow(event, now)
  return event.startMs <= now and event.endMs > now
end

function Agenda.isSoon(event, now)
  return event.startMs > now and event.startMs - now <= Agenda.soonMs()
end

-- Local midnight of the day that holds unixSeconds.
local function midnight(unixSeconds)
  local h = tonumber(noctalia.formatTime("%H", unixSeconds)) or 0
  local m = tonumber(noctalia.formatTime("%M", unixSeconds)) or 0
  local s = tonumber(noctalia.formatTime("%S", unixSeconds)) or 0
  return unixSeconds - (h * 3600 + m * 60 + s)
end

-- Days from today on, each with the events that touch it. Today keeps only events that
-- have not ended. Days without events are left out.
function Agenda.days(events, now, count)
  local days = {}
  local today = midnight(math.floor(now / 1000))
  for index = 0, count - 1 do
    -- Noon of each day, so a daylight saving change cannot skip or repeat a day.
    local start = midnight(today + index * DAY_SECONDS + DAY_SECONDS / 2)
    local finish = midnight(start + DAY_SECONDS + DAY_SECONDS / 2)
    local dayEvents = {}
    for _, event in ipairs(events) do
      local touches = event.startMs < finish * 1000 and event.endMs > start * 1000
      if touches and (index > 0 or event.endMs > now) then
        table.insert(dayEvents, event)
      end
    end
    if #dayEvents > 0 then
      table.insert(days, { index = index, startSeconds = start, events = dayEvents })
    end
  end
  return days
end

function Agenda.time(ms)
  local format = noctalia.getSetting("calendar.event_time_format") or "%H:%M"
  return noctalia.formatTime(format, math.floor(ms / 1000))
end

function Agenda.dayLabel(day)
  if day.index == 0 then
    return noctalia.tr("day.today")
  elseif day.index == 1 then
    return noctalia.tr("day.tomorrow")
  end
  return Agenda.date(day.startSeconds)
end

-- A date in the format of Noctalia's calendar. "%e" pads the day with a space; one is enough.
function Agenda.date(unixSeconds)
  local format = noctalia.getSetting("calendar.event_date_format") or "%A %e %B"
  local text = noctalia.formatTime(format, unixSeconds):gsub("%s+", " ")
  return text
end

-- "14:00 – 15:00", or "All day".
function Agenda.range(event)
  if event.allDay then
    return noctalia.tr("event.all_day")
  end
  return `{Agenda.time(event.startMs)} – {Agenda.time(event.endMs)}`
end

-- "in 5 min", "in 1 h 20 min", "now".
function Agenda.countdown(event, now)
  if event.startMs <= now then
    return noctalia.tr("countdown.now")
  end
  local minutes = math.ceil((event.startMs - now) / MINUTE_MS)
  if minutes < 60 then
    return noctalia.tr("countdown.minutes", { minutes = minutes })
  end
  return noctalia.tr("countdown.hours", { hours = math.floor(minutes / 60), minutes = minutes % 60 })
end

function Agenda.join(event)
  if event and event.url ~= "" then
    noctalia.runAsync({ "xdg-open", event.url })
  end
end

function Agenda.openCalendarSettings()
  noctalia.runAsync({ "noctalia", "msg", "settings-open", "calendar" })
end

return Agenda
