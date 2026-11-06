--!nonstrict
-- Keyboard on-screen keyboard: a key grid at the bottom of the screen, in Noctalia's theme.
-- The layer never takes the keyboard focus, so each key goes to the window you type in,
-- typed there with wtype. The keys follow the active language: Turkish for TR, English
-- otherwise. Shift, Ctrl and Alt hold for the next key. Renders "keyboard.model".

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

local function key(label, onClick, options)
  options = options or {}
  return ui.button({
    text = label,
    glyph = options.glyph,
    variant = options.on and "primary" or "default",
    flexGrow = options.grow or 1,
    height = 44,
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

render = function()
  local set = activeSet()
  local rows = {}
  for index, keys in ipairs(set) do
    local row = {}
    if index == 2 then
      table.insert(row, key("Tab", function() press(nil, "Tab") end, { grow = 1.5 }))
    elseif index == 4 then
      table.insert(row, toggle("Shift", shift, function() shift = not shift end))
    end
    for _, pair in ipairs(keys) do
      local text = shift and pair[2] or pair[1]
      table.insert(row, key(text, function() press(text) end))
    end
    if index == 1 then
      table.insert(row, key("", function() press(nil, "BackSpace") end, { glyph = "backspace", grow = 1.5 }))
    elseif index == 3 then
      table.insert(row, key("", function() press(nil, "Return") end, { glyph = "corner-down-left", grow = 1.5 }))
    end
    table.insert(rows, ui.row({ gap = 6 }, row))
  end
  table.insert(rows, ui.row({ gap = 6 }, {
    toggle("Ctrl", ctrl, function() ctrl = not ctrl end),
    toggle("Alt", alt, function() alt = not alt end),
    key("", function() press(nil, "space") end, { glyph = "space", grow = 6 }),
    key("", function() press(nil, "Left") end, { glyph = "arrow-left" }),
    key("", function() press(nil, "Right") end, { glyph = "arrow-right" }),
    key("", function() send({ action = "osk", open = false }) end, { glyph = "keyboard-hide", grow = 1.5 }),
  }))
  layer.render(ui.column({ gap = 6, padding = 10, fill = "surface_container/0.96", flexGrow = 1 }, rows))
end

noctalia.state.watch("keyboard.model", function(value)
  model = value
  render()
end)
model = noctalia.state.get("keyboard.model")
render()
