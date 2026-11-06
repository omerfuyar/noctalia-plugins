--!nonstrict
-- The key binding from the "keybind" setting, such as "SUPER + Space". It is added to
-- Hyprland while Noctalia runs, never written to its config. A key that is already bound is
-- left alone, and Hyprland drops added bindings when it reloads, so check() runs again from
-- the service's update tick (DESIGN.md, section 10.7).

local Keybind = {}

local MODIFIERS = { SHIFT = 1, CAPS = 2, CTRL = 4, CONTROL = 4, ALT = 8, MOD2 = 16, MOD3 = 32, SUPER = 64, MOD5 = 128 }

local bound = nil -- the key this plugin bound, as written in the setting
local warned = nil

local function onHyprland()
  return noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE") ~= nil and noctalia.commandExists("hyprctl")
end

local function quoted(value)
  return string.format("%q", tostring(value))
end

-- "SUPER + SHIFT + Space" -> modmask 65, key "Space", and the older form "SUPER SHIFT,Space".
local function parseKey(text)
  local parts = {}
  for part in text:gmatch("[^+]+") do
    table.insert(parts, noctalia.string.trim(part))
  end
  local key = table.remove(parts)
  if key == nil or key == "" then
    return nil
  end
  local mask = 0
  for _, modifier in ipairs(parts) do
    local value = MODIFIERS[modifier:upper()]
    if value == nil then
      return nil
    end
    mask += value
  end
  return mask, key, table.concat(parts, " ") .. "," .. key
end

local function unbind(key)
  local _, _, legacy = parseKey(key)
  noctalia.runAsync({ "hyprctl", "eval", `hl.unbind({quoted(key)})` }, function(result)
    if noctalia.string.trim(result.stdout or "") ~= "ok" then
      noctalia.runAsync({ "hyprctl", "keyword", "unbind", legacy or key })
    end
  end)
end

-- Binds the setting's key to shell command <command>, once, unless the key is taken.
function Keybind.check(command)
  if not onHyprland() then
    return
  end
  local wanted = noctalia.string.trim(noctalia.getConfig("keybind") or "")
  if bound and bound ~= wanted then
    unbind(bound)
    bound = nil
  end
  if wanted == "" then
    return
  end
  local mask, key, legacy = parseKey(wanted)
  if mask == nil then
    if warned ~= wanted then
      warned = wanted
      noctalia.notifyError(noctalia.tr("keybind.invalid_title"), noctalia.tr("keybind.invalid", { key = wanted }))
    end
    return
  end
  noctalia.runAsync({ "hyprctl", "-j", "binds" }, function(result)
    local binds = result.exitCode == 0 and noctalia.json.decode(result.stdout or "") or {}
    for _, bind in ipairs(type(binds) == "table" and binds or {}) do
      if bind.modmask == mask and tostring(bind.key):lower() == key:lower() then
        if bound ~= wanted and warned ~= wanted then
          warned = wanted
          noctalia.notifyError(noctalia.tr("keybind.taken_title"), noctalia.tr("keybind.taken", { key = wanted }))
        end
        return
      end
    end
    -- Not bound: either never added, or dropped by a Hyprland reload.
    bound = wanted
    noctalia.runAsync({ "hyprctl", "eval", `hl.bind({quoted(wanted)}, hl.dsp.exec_cmd({quoted(command)}))` },
      function(lua)
        if noctalia.string.trim(lua.stdout or "") ~= "ok" then
          noctalia.runAsync({ "hyprctl", "keyword", "bind", `{legacy},exec,{command}` })
        end
      end)
  end)
end

-- Takes the binding out again, when the plugin stops.
function Keybind.release()
  if bound then
    unbind(bound)
    bound = nil
  end
end

return Keybind
