--!nonstrict
-- Keyboard on-screen keyboard: a compact key grid in Noctalia's theme, docked at the bottom
-- of the screen or placed anywhere with its grip. The layer never takes the keyboard focus,
-- so each key goes to the window you type in, typed there with wtype. The keys follow the
-- active language: Turkish for TR, English otherwise. Shift, Ctrl and Alt hold for the next
-- key. Renders "keyboard.model".
--
-- A click on the grip starts a move: the service spreads the layer over the whole monitor,
-- an outline of the keyboard follows the pointer, and a click puts it there. The dock
-- button puts it back at the bottom.

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

local PADDING, GAP, GRIP = 8, 5, 20

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
  local docked = model == nil or model.oskPlace == nil or model.oskPlace.docked == true
  keyHeight = math.max(20, math.floor((height - 2 * PADDING - GRIP - 5 * GAP) / 5))
  local rows = {
    -- The grip moves the keyboard, the first button docks it, the last hides it. They are
    -- buttons, as a layer's rows take no clicks.
    ui.row({ gap = GAP, align = "center", height = GRIP }, {
      docked and ui.box({ width = 28 }) or ui.button({
        glyph = "layout-bottombar",
        variant = "ghost",
        controlSize = "sm",
        width = 28,
        height = GRIP,
        onClick = function() send({ action = "osk_place", docked = true }) end,
      }),
      ui.button({
        glyph = "grip-horizontal",
        variant = "ghost",
        controlSize = "sm",
        flexGrow = 1,
        height = GRIP,
        onClick = function() send({ action = "osk_move" }) end,
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

-- While moving, the monitor is a grid of cells that never move, so the pointer is always
-- read right. The cells draw nothing: the cell under the pointer is where the keyboard's
-- middle goes, the service shows the keyboard's outline there, and a click puts it there.
local CELL = 40

local hovered = nil -- { column, row } of the cell under the pointer
-- The layer grows to the whole monitor just after a move starts; a hover before that comes
-- from the small layer and names the wrong cell.
local SETTLE_MS = 250
local movingSince = 0

local function moving()
  local width, height = size()
  local outWidth, outHeight = outputSize()
  local columns = math.max(1, math.floor(outWidth / CELL))
  local rows = math.max(1, math.floor(outHeight / CELL))
  local cellWidth, cellHeight = outWidth / columns, outHeight / rows
  -- The keyboard's top left with its middle on the cell <column, row>.
  local function placeAt(column, row)
    local cx, cy = (column - 0.5) * cellWidth, (row - 0.5) * cellHeight
    return math.clamp(math.floor(cx - width / 2), 0, math.max(0, outWidth - width)),
      math.clamp(math.floor(cy - height / 2), 0, math.max(0, outHeight - height))
  end
  local lines = {}
  for row = 1, rows do
    local cells = {}
    for column = 1, columns do
      -- A button, as a layer's boxes take no pointer; it is drawn fully clear.
      table.insert(cells, ui.button({
        variant = "ghost",
        opacity = 0,
        flexGrow = 1,
        height = math.floor(cellHeight),
        -- "true" when the pointer enters the cell. A leave is not used: it can come after
        -- the next cell's enter.
        onHover = function(state)
          local settled = noctalia.nowMs() - movingSince >= SETTLE_MS
          if settled and tostring(state) == "true" and (hovered == nil or hovered[1] ~= column or hovered[2] ~= row) then
            hovered = { column, row }
            local x, y = placeAt(column, row)
            send({ action = "osk_outline", x = x, y = y })
          end
        end,
        onClick = function()
          local x, y = placeAt(column, row)
          send({ action = "osk_place", docked = false, x = x, y = y })
        end,
      }))
    end
    table.insert(lines, ui.row({}, cells))
  end
  return ui.column({ flexGrow = 1, fill = "surface/0.4" }, lines)
end

render = function()
  local isMoving = model ~= nil and model.oskMoving == true
  if isMoving ~= wasMoving then
    hovered = nil
    movingSince = noctalia.nowMs()
    wasMoving = isMoving
  end
  layer.render(isMoving and moving() or keys())
end

-- What the keyboard shows of the model. The service publishes every second; the keyboard
-- draws again only when this changes, so it does not flicker.
local function shown(value)
  if value == nil then
    return ""
  end
  local place = value.oskPlace or {}
  local size = value.oskSize or {}
  local current = nil
  for _, entry in ipairs(value.entries or {}) do
    if entry.key == value.current then
      current = entry.short
    end
  end
  return table.concat({
    tostring(current), tostring(value.oskMoving), tostring(place.docked), tostring(place.x), tostring(place.y),
    tostring(size.width), tostring(size.height),
  }, " ")
end

local lastShown = nil
noctalia.state.watch("keyboard.model", function(value)
  model = value
  local now = shown(value)
  if now ~= lastShown then
    lastShown = now
    render()
  end
end)
model = noctalia.state.get("keyboard.model")
render()
