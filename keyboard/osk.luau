--!nonstrict
-- Keyboard on-screen keyboard: a compact key grid in Noctalia's theme, docked at the bottom
-- of the screen or placed anywhere with its grip. The layer never takes the keyboard focus,
-- so each key goes to the window you type in, typed there with wtype. The keys follow the
-- active language: Turkish for TR, English otherwise. Shift, Ctrl and Alt hold for the next
-- key. Renders "keyboard.model".
--
-- A click on the grip starts a move: the service spreads the layer over the whole monitor,
-- the keyboard's outline follows the pointer, and a click puts it down there. Dropped at
-- the bottom edge, it docks again.

local model = nil
local shift, ctrl, alt = false, false, false

local function send(command)
  command.n = noctalia.nowMs()
  noctalia.state.set("keyboard.command", command)
end

-- Each key as { normal, shifted }.
local SETS = {
  EN = {
    { { "1", "!" }, { "2", "@" }, { "3", "#" }, { "4", "$" }, { "5", "%" }, { "6", "^" },
      { "7", "&" }, { "8", "*" }, { "9", "(" }, { "0", ")" }, { "-", "_" }, { "=", "+" } },
    { { "q", "Q" }, { "w", "W" }, { "e", "E" }, { "r", "R" }, { "t", "T" }, { "y", "Y" },
      { "u", "U" }, { "i", "I" }, { "o", "O" }, { "p", "P" }, { "[", "{" }, { "]", "}" } },
    { { "a", "A" }, { "s", "S" }, { "d", "D" }, { "f", "F" }, { "g", "G" }, { "h", "H" },
      { "j", "J" }, { "k", "K" }, { "l", "L" }, { ";", ":" }, { "'", "\"" }, { "\\", "|" } },
    { { "z", "Z" }, { "x", "X" }, { "c", "C" }, { "v", "V" }, { "b", "B" }, { "n", "N" },
      { "m", "M" }, { ",", "<" }, { ".", ">" }, { "/", "?" } },
  },
  TR = {
    { { "1", "!" }, { "2", "'" }, { "3", "^" }, { "4", "+" }, { "5", "%" }, { "6", "&" },
      { "7", "/" }, { "8", "(" }, { "9", ")" }, { "0", "=" }, { "*", "?" }, { "-", "_" } },
    { { "q", "Q" }, { "w", "W" }, { "e", "E" }, { "r", "R" }, { "t", "T" }, { "y", "Y" },
      { "u", "U" }, { "ı", "I" }, { "o", "O" }, { "p", "P" }, { "ğ", "Ğ" }, { "ü", "Ü" } },
    { { "a", "A" }, { "s", "S" }, { "d", "D" }, { "f", "F" }, { "g", "G" }, { "h", "H" },
      { "j", "J" }, { "k", "K" }, { "l", "L" }, { "ş", "Ş" }, { "i", "İ" }, { ",", ";" } },
    { { "z", "Z" }, { "x", "X" }, { "c", "C" }, { "v", "V" }, { "b", "B" }, { "n", "N" },
      { "m", "M" }, { "ö", "Ö" }, { "ç", "Ç" }, { ".", ":" } },
  },
}

local render

-- Docks when dropped this close to the bottom edge, in pixels.
local SNAP = 32
local PADDING, GAP, GRIP = 8, 5, 20

local ghost = nil -- while moving: { x, y } of the outline's top left
local wasMoving = false

local function size()
  local s = model and model.oskSize
  return s and s.width or 660, s and s.height or 220
end

-- The logical size of the monitor this layer is on.
local function outputSize()
  local name = layer.outputName()
  for _, output in ipairs(noctalia.outputs()) do
    if output.name == name or (name == nil and output.focused) then
      return output.width, output.height
    end
  end
  return 1920, 1080
end

-- Types text, or presses a key by its name with -k, holding Ctrl and Alt when they are on.
local function press(text, keyName)
  local argv = { "wtype" }
  if ctrl then
    table.insert(argv, "-M")
    table.insert(argv, "ctrl")
  end
  if alt then
    table.insert(argv, "-M")
    table.insert(argv, "alt")
  end
  if keyName then
    table.insert(argv, "-k")
    table.insert(argv, keyName)
  else
    table.insert(argv, "--")
    table.insert(argv, text)
  end
  noctalia.runAsync(argv)
  shift, ctrl, alt = false, false, false
  render()
end

local keyHeight = 32

local function key(label, onClick, options)
  options = options or {}
  return ui.button({
    text = label,
    glyph = options.glyph,
    variant = options.on and "primary" or "default",
    flexGrow = options.grow or 1,
    height = keyHeight,
    onClick = onClick,
  })
end

local function toggle(label, value, flip)
  return key(label, function()
    flip()
    render()
  end, { on = value, grow = 1.5 })
end

local function activeSet()
  for _, entry in ipairs(model and model.entries or {}) do
    if entry.key == model.current and SETS[entry.short] then
      return SETS[entry.short]
    end
  end
  return SETS.EN
end

local function keys()
  local _, height = size()
  keyHeight = math.max(20, math.floor((height - 2 * PADDING - GRIP - 5 * GAP) / 5))
  local rows = {
    -- The grip moves the keyboard; the button hides it.
    ui.row({ gap = GAP, align = "center", height = GRIP }, {
      ui.box({ width = 28 }),
      ui.row({
        flexGrow = 1,
        height = GRIP,
        align = "center",
        justify = "center",
        radius = 6,
        onClick = function() send({ action = "osk_move" }) end,
      }, {
        ui.glyph({ name = "grip-horizontal", size = 18, color = "on_surface_variant" }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        controlSize = "sm",
        width = 28,
        height = GRIP,
        onClick = function() send({ action = "osk", open = false }) end,
      }),
    }),
  }
  for index, keysOfRow in ipairs(activeSet()) do
    local row = {}
    if index == 2 then
      table.insert(row, key("Tab", function() press(nil, "Tab") end, { grow = 1.5 }))
    elseif index == 4 then
      table.insert(row, toggle("Shift", shift, function() shift = not shift end))
    end
    for _, pair in ipairs(keysOfRow) do
      local text = shift and pair[2] or pair[1]
      table.insert(row, key(text, function() press(text) end))
    end
    if index == 1 then
      table.insert(row, key("", function() press(nil, "BackSpace") end, { glyph = "backspace", grow = 1.5 }))
    elseif index == 3 then
      table.insert(row, key("", function() press(nil, "Return") end, { glyph = "corner-down-left", grow = 1.5 }))
    end
    table.insert(rows, ui.row({ gap = GAP }, row))
  end
  table.insert(rows, ui.row({ gap = GAP }, {
    toggle("Ctrl", ctrl, function() ctrl = not ctrl end),
    toggle("Alt", alt, function() alt = not alt end),
    key("", function() press(nil, "space") end, { glyph = "space", grow = 6 }),
    key("", function() press(nil, "Left") end, { glyph = "arrow-left" }),
    key("", function() press(nil, "Right") end, { glyph = "arrow-right" }),
  }))
  return ui.column({
    gap = GAP,
    padding = PADDING,
    fill = "surface_container/0.96",
    border = "outline_variant",
    borderWidth = 1,
    radius = 12,
    flexGrow = 1,
  }, rows)
end

-- Where the outline is drawn: docked at the bottom when it is near the bottom edge.
local function ghostPlace(width, height, outWidth, outHeight)
  if ghost.y >= outHeight - height - SNAP then
    return math.floor((outWidth - width) / 2), outHeight - height, true
  end
  return ghost.x, ghost.y, false
end

-- The monitor while moving: the outline and the space around it, each part a graph that
-- reports the pointer, so the outline can follow it anywhere.
local function moving()
  local width, height = size()
  local outWidth, outHeight = outputSize()
  if ghost == nil then
    local place = model.oskPlace or { docked = true }
    if place.docked then
      ghost = { x = math.floor((outWidth - width) / 2), y = outHeight - height }
    else
      ghost = { x = place.x, y = place.y }
    end
  end
  local x, y, docked = ghostPlace(width, height, outWidth, outHeight)
  -- A pointer at <nx, ny> of a part with its top left at <left, top> and this size.
  local function at(left, top, partWidth, partHeight)
    return function(nx, ny)
      local px = left + (tonumber(nx) or 0) * partWidth
      local py = top + (tonumber(ny) or 0) * partHeight
      ghost = {
        x = math.clamp(math.floor(px - width / 2), 0, math.max(0, outWidth - width)),
        y = math.clamp(math.floor(py - height / 2), 0, math.max(0, outHeight - height)),
      }
      render()
    end
  end
  local function part(props, left, top, partWidth, partHeight)
    props.values = {}
    props.color = "primary/0"
    props.onPointerMove = at(left, top, partWidth, partHeight)
    return ui.graph(props)
  end
  local half = math.floor((height - 24) / 2)
  local row = {}
  if x >= 1 then
    table.insert(row, part({ key = "left", width = x }, 0, y, x, height))
  end
  table.insert(row, ui.column({
    key = "ghost",
    width = width,
    fill = "primary/0.15",
    border = "primary",
    borderWidth = 2,
    radius = 12,
  }, {
    part({ key = "ghost-top", height = half }, x, y, width, half),
    ui.label({
      text = noctalia.tr(docked and "osk.drop_dock" or "osk.drop_here"),
      height = 24,
      textAlign = "center",
      color = "primary",
      fontWeight = "semibold",
    }),
    part({ key = "ghost-bottom", flexGrow = 1 }, x, y + half + 24, width, height - half - 24),
  }))
  table.insert(row, part({ key = "right", flexGrow = 1 }, x + width, y, outWidth - x - width, height))
  local column = {}
  if y >= 1 then
    table.insert(column, part({ key = "top", height = y }, 0, 0, outWidth, y))
  end
  table.insert(column, ui.row({ key = "middle", height = height }, row))
  table.insert(column, part({ key = "bottom", flexGrow = 1 }, 0, y + height, outWidth, outHeight - y - height))
  return ui.column({
    flexGrow = 1,
    fill = "surface/0.3",
    onClick = function()
      local dropX, dropY, dropDocked = ghostPlace(width, height, outWidth, outHeight)
      send({ action = "osk_place", docked = dropDocked, x = dropX, y = dropY })
    end,
  }, column)
end

render = function()
  local isMoving = model ~= nil and model.oskMoving == true
  if isMoving ~= wasMoving then
    ghost = nil
    wasMoving = isMoving
  end
  layer.render(isMoving and moving() or keys())
end

noctalia.state.watch("keyboard.model", function(value)
  model = value
  render()
end)
model = noctalia.state.get("keyboard.model")
render()
