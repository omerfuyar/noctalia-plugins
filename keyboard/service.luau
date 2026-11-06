--!nonstrict
-- Keyboard service: one list of the languages you type in, from the compositor's keyboard
-- layouts and fcitx5's input methods, and switching between them.
--
-- A layout comes from Hyprland's main keyboard. An fcitx5 input method joins the list when
-- it is more than a plain keyboard, such as Hangul, or a keyboard layout the compositor does
-- not have. Picking a layout switches every keyboard to it and puts fcitx5 back on plain
-- typing; picking an input method switches fcitx5 to it.
--
-- The active one is read every second; the lists and their names when the service starts,
-- every 30 seconds, and when the panel asks.
--
-- The panel adds and removes layouts and input methods. Once the owner changes the layouts
-- here, the plugin keeps its own list in its data folder and sets it in Hyprland while
-- Noctalia runs, also after Hyprland reloads its config; it never writes Hyprland's config.
-- "Use Hyprland's layouts" gives the config's list back. Input methods are added to and
-- removed from fcitx5's group through fcitx5, which saves them in its own configuration.
--
-- Publishes "keyboard.model" and takes commands on "keyboard.command".

local Keybind = require("./lib/keybind.luau")

local POLL_MS = 1000
local REFRESH_MS = 30000
local NEXT = "noctalia msg plugin omerfuyar/keyboard:service all next"

-- Hyprland's keyboards, then fcitx5's input method.
local POLL = [[
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null; then
  hyprctl -j devices 2>/dev/null
fi
echo
echo "@@current $(fcitx5-remote -n 2>/dev/null)"
]]

-- The names of the compositor's layouts ($@), then fcitx5's group: its default layout and
-- input methods, each with its name, label and language.
local DETAILS = [=[
awk -v codes="$*" '
  BEGIN { n = split(codes, list, " "); for (i = 1; i <= n; i++) wanted[list[i]] = 1 }
  /^! layout/ { on = 1; next }
  /^!/ { on = 0 }
  on && ($1 in wanted) { code = $1; $1 = ""; sub(/^ +/, ""); print "@@xkb " code "\t" $0 }
' /usr/share/X11/xkb/rules/evdev.lst 2>/dev/null
command -v gdbus >/dev/null || exit 0
call() {
  gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
    --method "org.fcitx.Fcitx.Controller1.$1" ${2:+"$2"} 2>/dev/null
}
group=$(call CurrentInputMethodGroup | sed -n "s/^('\(.*\)',)$/\1/p")
[ -n "$group" ] || exit 0
info=$(call InputMethodGroupInfo "$group")
echo "@@group $group"
echo "@@info $info"
# The group's input methods, and the keyboard of each layout, for its language: only these,
# since parsing all of them takes longer than a callback may. One per line; names hold
# parentheses, such as "English (US)".
ids=$(echo "$info" | grep -o "('[^']*', '[^']*')" | sed "s/^('\([^']*\)'.*/\1/")
for code in "$@"; do
  ids="$ids keyboard-$code"
done
call AvailableInputMethods | sed 's/), (/)\n(/g' | sed 's/^[[(]*//' | while read -r line; do
  for id in $ids; do
    case $line in "'$id', "*) echo "@@im $line" ;; esac
  done
done
]=]

-- What can be added: every keyboard layout, as "@@layout <code>\t<name>", and each fcitx5
-- input method that is more than a plain keyboard, as "@@im <fields>".
local CATALOG = [=[
awk '/^! layout/ { on = 1; next } /^!/ { on = 0 } on { code = $1; $1 = ""; sub(/^ +/, ""); print "@@layout " code "\t" $0 }' \
  /usr/share/X11/xkb/rules/evdev.lst 2>/dev/null
command -v gdbus >/dev/null || exit 0
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.AvailableInputMethods 2>/dev/null |
  sed 's/), (/)\n(/g' | sed 's/^[[(]*//' | grep -v "^'keyboard-" | sed 's/^/@@im /'
]=]

local dataDir = noctalia.pluginDataDir() or ""
local layoutsFile = dataDir .. "/layouts.json"

local model = { ready = false, entries = {}, current = nil, fcitx = false }
-- The plugin's own layouts, once the owner changed them here: { layouts = { { code, variant } },
-- original = { layout, variant } }, the config's list to give back. nil follows Hyprland's config.
local stored = nil
local mainLayout, mainVariant = nil, nil -- the main keyboard's layouts as Hyprland has them now
local lastApplyMs = 0
local groupName = nil -- fcitx5's current group
local groupItems = {} -- its input methods with their layouts: { id, layout }
local wantCatalog = false -- read the catalog once the running refresh is done
local catalog = nil -- what the panel can add: { layouts = { { code, name } }, ims = { { id, name } } }
local layouts = {} -- { code, variant } of the compositor, in order
local activeLayout = 0 -- index into layouts, from 0 as Hyprland counts
local layoutNames = {} -- code -> "Turkish"
local layoutLangs = {} -- code -> "en", from fcitx5's keyboard input methods
local groupLayout = nil -- the layout fcitx5's group types its input methods on, such as "us"
local inputMethods = {} -- in the group's order: { id, name, label, lang, layout }
local currentIm = nil
local lastPollMs = 0
local lastRefreshMs = nil
local polling = false
local refreshing = false

local function publish()
  noctalia.state.set("keyboard.model", model)
end

local function upper(text)
  return (text or ""):upper()
end

-- fcitx5's keyboard input methods are "keyboard-<layout>" or "keyboard-<layout>-<variant>".
local function keyboardLayout(id)
  return id:match("^keyboard%-([%a]+)")
end

-- The one list, and which of it is active.
local function build()
  local entries, covered = {}, {}
  for index, layout in ipairs(layouts) do
    covered[layout.code] = true
    table.insert(entries, {
      key = "layout:" .. (index - 1),
      kind = "layout",
      index = index - 1,
      code = layout.code,
      short = upper(layoutLangs[layout.code] or layout.code),
      name = layoutNames[layout.code] or layout.code,
    })
  end
  for _, im in ipairs(inputMethods) do
    local code = keyboardLayout(im.id)
    if code == nil or not covered[code] then
      table.insert(entries, {
        key = "im:" .. im.id,
        kind = "im",
        id = im.id,
        short = upper(code or (im.lang ~= "" and im.lang) or im.label),
        name = im.name,
      })
    end
  end
  local current = nil
  local imCode = currentIm and keyboardLayout(currentIm)
  for _, entry in ipairs(entries) do
    if entry.kind == "im" and entry.id == currentIm then
      current = entry.key
    end
  end
  if current == nil and (currentIm == nil or imCode ~= nil) then
    for _, entry in ipairs(entries) do
      if entry.kind == "layout" and entry.index == activeLayout then
        current = entry.key
      end
    end
  end
  local removable = #entries > 1
  for _, entry in ipairs(entries) do
    entry.removable = removable and (entry.kind == "im" or #layouts > 1)
  end
  model = {
    ready = #entries > 0,
    entries = entries,
    current = current,
    fcitx = #inputMethods > 0,
    managed = stored ~= nil,
    catalog = catalog,
  }
  publish()
end

local function readDevices(text)
  local devices = noctalia.json.decode(text or "")
  layouts = {}
  if type(devices) ~= "table" or type(devices.keyboards) ~= "table" then
    return
  end
  for _, keyboard in ipairs(devices.keyboards) do
    if keyboard.main then
      local variants = string.split(keyboard.variant or "", ",")
      for index, code in ipairs(string.split(keyboard.layout or "", ",")) do
        code = noctalia.string.trim(code)
        if code ~= "" then
          table.insert(layouts, { code = code, variant = noctalia.string.trim(variants[index] or "") })
        end
      end
      activeLayout = tonumber(keyboard.active_layout_index) or 0
      mainLayout, mainVariant = keyboard.layout or "", keyboard.variant or ""
    end
  end
end

local function layoutCodes()
  local codes = {}
  for _, layout in ipairs(layouts) do
    table.insert(codes, layout.code)
  end
  return table.concat(codes, ",")
end

local function quoted(value)
  return string.format("%q", tostring(value))
end

-- "us,tr" and ",f" for a list of { code, variant }.
local function joined(list)
  local codes, variants = {}, {}
  for _, layout in ipairs(list) do
    table.insert(codes, layout.code)
    table.insert(variants, layout.variant or "")
  end
  return table.concat(codes, ","), table.concat(variants, ",")
end

-- Sets layouts and variants in Hyprland, with Lua first, as a Lua config takes only that.
local function setInHyprland(layout, variant)
  lastApplyMs = noctalia.nowMs()
  local lua = string.format("hl.config({ input = { kb_layout = %s, kb_variant = %s } })", quoted(layout), quoted(variant))
  noctalia.runAsync({ "hyprctl", "eval", lua }, function(result)
    if noctalia.string.trim(result.stdout or "") ~= "ok" then
      noctalia.runAsync({ "hyprctl", "keyword", "input:kb_variant", variant })
      noctalia.runAsync({ "hyprctl", "keyword", "input:kb_layout", layout })
    end
  end)
end

-- Keeps Hyprland on the plugin's own list; a config reload puts the config's back.
local function ensureApplied()
  if stored == nil or mainLayout == nil or noctalia.nowMs() - lastApplyMs < 3000 then
    return
  end
  local layout, variant = joined(stored.layouts)
  if layout ~= mainLayout or variant ~= mainVariant then
    setInHyprland(layout, variant)
  end
end

local function saveStored()
  noctalia.mkdirAll(dataDir)
  if stored then
    noctalia.writeFile(layoutsFile, noctalia.json.encode(stored) or "")
  else
    noctalia.removeFile(layoutsFile)
  end
end

local function poll()
  if polling then
    return
  end
  polling = true
  lastPollMs = noctalia.nowMs()
  noctalia.runAsync({ "sh", "-c", POLL }, function(result)
    polling = false
    local out = result.stdout or ""
    local json, current = out:match("^(.-)\n@@current ([^\n]*)")
    local before = layoutCodes()
    readDevices(json)
    -- New layouts need their names.
    if layoutCodes() ~= before then
      lastRefreshMs = nil
    end
    current = noctalia.string.trim(current or "")
    currentIm = current ~= "" and current or nil
    ensureApplied()
    build()
  end, 5000)
end

-- One input method from AvailableInputMethods: id, name, native name, icon, label, language, configurable.
local function readInputMethod(line)
  local fields = {}
  for value in line:gmatch("'([^']*)'") do
    table.insert(fields, value)
  end
  return { id = fields[1], name = fields[2] or fields[1], label = fields[5] or "", lang = fields[6] or "" }
end

-- Every layout, and the input methods fcitx5 has besides plain keyboards, for the panel's pickers.
local function readCatalog()
  noctalia.runAsync({ "sh", "-c", CATALOG }, function(result)
    local found = { layouts = {}, ims = {} }
    local inGroup = {}
    for _, item in ipairs(groupItems) do
      inGroup[item.id] = true
    end
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local code, name = line:match("^@@layout (%S+)\t(.+)$")
      if code then
        table.insert(found.layouts, { code = code, name = name })
      end
      local im = line:match("^@@im (.+)$")
      if im then
        local id, imName = im:match("^'([^']*)', '([^']*)'")
        if id and not inGroup[id] then
          table.insert(found.ims, { id = id, name = imName })
        end
      end
    end
    table.sort(found.layouts, function(a, b)
      return a.name < b.name
    end)
    catalog = found
    build()
  end, 10000)
end

local function refresh()
  if refreshing then
    return
  end
  refreshing = true
  lastRefreshMs = noctalia.nowMs()
  local argv = { "sh", "-c", DETAILS, "keyboard" }
  for _, layout in ipairs(layouts) do
    table.insert(argv, layout.code)
  end
  noctalia.runAsync(argv, function(result)
    refreshing = false
    local found, order = {}, {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local code, name = line:match("^@@xkb (%S+)\t(.+)$")
      if code then
        layoutNames[code] = name
      end
      local info = line:match("^@@info (.+)$")
      local group = line:match("^@@group (.+)$")
      if group then
        groupName = group
      end
      if info then
        groupLayout = info:match("^%('([^']*)'")
        local list = info:match("%[(.*)%]") or ""
        groupItems = {}
        for id, layout in list:gmatch("%('([^']*)', '([^']*)'%)") do
          table.insert(order, id)
          table.insert(groupItems, { id = id, layout = layout })
        end
      end
      local im = line:match("^@@im (.+)$")
      if im then
        local parsed = readInputMethod(im)
        if parsed.id then
          found[parsed.id] = parsed
          local code = keyboardLayout(parsed.id)
          if code and parsed.lang ~= "" and parsed.id == "keyboard-" .. code then
            layoutLangs[code] = parsed.lang
          end
        end
      end
    end
    inputMethods = {}
    for _, id in ipairs(order) do
      table.insert(inputMethods, found[id] or { id = id, name = id, label = "", lang = "" })
    end
    build()
    if wantCatalog then
      wantCatalog = false
      readCatalog()
    end
  end, 10000)
end

-- Switches to one entry of the list.
local function choose(key)
  for _, entry in ipairs(model.entries) do
    if entry.key == key then
      if entry.kind == "layout" then
        noctalia.runAsync({ "hyprctl", "switchxkblayout", "all", tostring(entry.index) }, function()
          poll()
        end)
        if model.fcitx then
          -- fcitx5 types plainly: with its keyboard of the same layout when it has one.
          local plain = nil
          for _, im in ipairs(inputMethods) do
            if keyboardLayout(im.id) == entry.code then
              plain = im.id
            end
          end
          noctalia.runAsync(plain and { "fcitx5-remote", "-s", plain } or { "fcitx5-remote", "-c" }, function()
            poll()
          end)
        end
      else
        -- An input method types on its group's layout, such as us for Hangul.
        for index, layout in ipairs(layouts) do
          if layout.code == groupLayout and index - 1 ~= activeLayout then
            noctalia.runAsync({ "hyprctl", "switchxkblayout", "all", tostring(index - 1) })
          end
        end
        noctalia.runAsync({ "fcitx5-remote", "-s", entry.id }, function()
          poll()
        end)
      end
      model.current = key
      publish()
      return
    end
  end
end

-- The layouts as they are now: the plugin's own, or Hyprland's.
local function currentLayouts()
  local list = {}
  for _, layout in ipairs(stored and stored.layouts or layouts) do
    table.insert(list, { code = layout.code, variant = layout.variant or "" })
  end
  return list
end

-- From now on the plugin keeps this list, and remembers the config's to give it back.
local function setLayouts(list)
  if #list == 0 then
    return
  end
  stored = { layouts = list, original = stored and stored.original or { layout = mainLayout or "", variant = mainVariant or "" } }
  saveStored()
  lastApplyMs = 0
  ensureApplied()
  lastRefreshMs = nil
end

local function addLayout(code)
  local list = currentLayouts()
  for _, layout in ipairs(list) do
    if layout.code == code then
      return
    end
  end
  table.insert(list, { code = code, variant = "" })
  setLayouts(list)
end

local function removeLayout(index)
  local list = currentLayouts()
  if #list > 1 and list[index + 1] then
    table.remove(list, index + 1)
    setLayouts(list)
  end
end

-- Hyprland's config decides the layouts again.
local function resetLayouts()
  if stored == nil then
    return
  end
  local original = stored.original
  stored = nil
  saveStored()
  if original and original.layout ~= "" then
    setInHyprland(original.layout, original.variant or "")
  end
  lastRefreshMs = nil
end

-- Sets fcitx5's group to these { id, layout } items, and has fcitx5 save it.
local function setGroup(items)
  if groupName == nil or #items == 0 then
    return
  end
  local parts = {}
  for _, item in ipairs(items) do
    -- Ids and layouts are plain words, such as hangul and us, so they need no escaping.
    table.insert(parts, string.format("('%s', '%s')", item.id, item.layout))
  end
  local list = "[" .. table.concat(parts, ", ") .. "]"
  local call = { "gdbus", "call", "--session", "--dest", "org.fcitx.Fcitx5", "--object-path", "/controller", "--method" }
  local set = table.clone(call)
  table.insert(set, "org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo")
  table.insert(set, groupName)
  table.insert(set, groupLayout or "")
  table.insert(set, list)
  noctalia.runAsync(set, function()
    local save = table.clone(call)
    table.insert(save, "org.fcitx.Fcitx.Controller1.Save")
    noctalia.runAsync(save, function()
      wantCatalog = true
      refresh()
    end)
  end)
end

local function addInputMethod(id)
  local items = {}
  for _, item in ipairs(groupItems) do
    if item.id == id then
      return
    end
    table.insert(items, item)
  end
  table.insert(items, { id = id, layout = "" })
  setGroup(items)
end

local function removeInputMethod(id)
  local items = {}
  for _, item in ipairs(groupItems) do
    if item.id ~= id then
      table.insert(items, item)
    end
  end
  -- fcitx5 needs a group to start with a plain keyboard.
  if #items > 0 and #items < #groupItems then
    setGroup(items)
  end
end

-- Moves along the list by <step>, round.
local function cycle(step)
  local entries = model.entries
  if #entries == 0 then
    return
  end
  local at = 1
  for index, entry in ipairs(entries) do
    if entry.key == model.current then
      at = index
    end
  end
  choose(entries[(at - 1 + step) % #entries + 1].key)
end

noctalia.state.watch("keyboard.command", function(command)
  if type(command) ~= "table" then
    return
  end
  if command.action == "choose" and type(command.key) == "string" then
    choose(command.key)
  elseif command.action == "next" then
    cycle(1)
  elseif command.action == "previous" then
    cycle(-1)
  elseif command.action == "refresh" then
    refresh()
  elseif command.action == "open" then
    wantCatalog = true
    refresh()
  elseif command.action == "add_layout" and type(command.code) == "string" then
    addLayout(command.code)
  elseif command.action == "remove_layout" and type(command.index) == "number" then
    removeLayout(command.index)
  elseif command.action == "reset_layouts" then
    resetLayouts()
  elseif command.action == "add_im" and type(command.id) == "string" then
    addInputMethod(command.id)
  elseif command.action == "remove_im" and type(command.id) == "string" then
    removeInputMethod(command.id)
  end
end)

-- noctalia msg plugin omerfuyar/keyboard:service all next|previous
-- noctalia msg plugin omerfuyar/keyboard:service all set <short name, such as TR>
-- noctalia msg plugin omerfuyar/keyboard:service all add-layout|remove-layout <code, such as de>
-- noctalia msg plugin omerfuyar/keyboard:service all add-im|remove-im <fcitx5 id, such as mozc>
-- noctalia msg plugin omerfuyar/keyboard:service all reset-layouts
function onIpc(event, payload)
  local value = payload and noctalia.string.trim(payload) or ""
  if event == "add-layout" and value ~= "" then
    addLayout(value)
  elseif event == "remove-layout" then
    for index, layout in ipairs(currentLayouts()) do
      if layout.code == value then
        removeLayout(index - 1)
      end
    end
  elseif event == "reset-layouts" then
    resetLayouts()
  elseif event == "add-im" and value ~= "" then
    addInputMethod(value)
  elseif event == "remove-im" and value ~= "" then
    removeInputMethod(value)
  elseif event == "next" then
    cycle(1)
  elseif event == "previous" then
    cycle(-1)
  elseif event == "set" and payload then
    for _, entry in ipairs(model.entries) do
      if entry.short == upper(noctalia.string.trim(payload)) then
        choose(entry.key)
        return
      end
    end
  end
end

function update()
  local now = noctalia.nowMs()
  if now - lastPollMs >= POLL_MS then
    poll()
  end
  if lastRefreshMs == nil or now - lastRefreshMs >= REFRESH_MS then
    refresh()
    Keybind.check(NEXT)
  end
end

function onConfigChanged()
  Keybind.check(NEXT)
end

function onExit()
  Keybind.release()
end

noctalia.setUpdateInterval(250)
noctalia.readFileAsync(layoutsFile, function(text)
  local saved = text and noctalia.json.decode(text)
  if type(saved) == "table" and type(saved.layouts) == "table" and #saved.layouts > 0 then
    stored = saved
  end
  poll()
end)
