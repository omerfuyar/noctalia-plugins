--!nonstrict
-- Resurrect service: runs snapshot.sh to save the system's setup into a git repository,
-- once a day, when Noctalia starts with sharing on, and when asked, and opens restore.sh
-- from that repository in a terminal. With sharing on, each save also takes in what other
-- devices changed; files changed on two devices wait for the owner's choice, which goes to
-- snapshot.sh in RESOLVE_FILE.
--
-- snapshot.sh runs detached, as a push can take longer than the 60 s limit of runAsync
-- callbacks. RUNNER writes its output and exit code to the data directory; update() reads
-- them back.
--
-- Publishes "resurrect.model" and takes commands on "resurrect.command".

local DAY_MS = 24 * 60 * 60 * 1000

-- $1 is the path prefix of the run's files, the rest is the snapshot command.
local RUNNER = [[
prefix=$1
shift
rm -f "$prefix.exit"
"$@" >"$prefix.log" 2>&1
echo $? >"$prefix.exit"
]]

local dataDir = noctalia.pluginDataDir() or ""
local stateFile = dataDir .. "/state.json"
local runPrefix = dataDir .. "/snapshot"
local resolveFile = dataDir .. "/resolve"

-- result: "saved", "unchanged" or "pushed"; counts: what the last save held, by kind.
-- conflicts and held: shared files that wait for the owner, by path under the home folder.
local state = { lastMs = nil, result = nil, error = nil, counts = nil, conflicts = {}, held = {} }
-- Choices not yet passed to a save: path -> "mine" or "theirs".
local choices = {}
local running = false
local again = false
local reading = false
local loaded = false

local function repo()
  return noctalia.expandPath(noctalia.getConfig("folder") or "~/resurrect")
end

local function save()
  local text = noctalia.json.encode(state)
  if text then
    noctalia.writeFile(stateFile, text)
  end
end

local function list(key)
  local items = {}
  for _, path in ipairs(noctalia.getConfig(key) or {}) do
    table.insert(items, path)
  end
  return items
end

local function sharing()
  return noctalia.getConfig("share") == true
end

local function publish()
  local files = list("files")
  noctalia.state.set("resurrect.model", {
    ready = noctalia.commandExists("git"),
    running = running,
    lastMs = state.lastMs,
    result = state.result,
    error = state.error,
    folder = noctalia.getConfig("folder") or "~/resurrect",
    remote = noctalia.getConfig("remote") or "",
    packages = noctalia.getConfig("packages") ~= false,
    services = noctalia.getConfig("services") ~= false,
    noctalia = noctalia.getConfig("noctalia") ~= false,
    files = files,
    share = sharing(),
    deviceFiles = list("device_files"),
    conflicts = state.conflicts or {},
    held = state.held or {},
    choices = choices,
    canRestore = noctalia.fileExists(repo() .. "/restore.sh"),
    counts = state.counts or {},
    hooks = repo() .. "/hooks",
    canOpen = noctalia.commandExists("xdg-open"),
  })
end

local function snapshot()
  if running or not noctalia.commandExists("git") then
    return
  end
  running = true
  again = false
  noctalia.mkdirAll(dataDir)
  -- "mine <path>" or "theirs <path>" per line; snapshot.sh removes the file once read.
  local lines = {}
  for path, choice in pairs(choices) do
    table.insert(lines, choice .. " " .. path)
  end
  choices = {}
  noctalia.writeFile(resolveFile, table.concat(lines, "\n") .. "\n")
  local argv = {
    "sh", "-c", RUNNER, "resurrect", runPrefix,
    "env", "RESURRECT_RESOLVE=" .. resolveFile,
    "sh", (noctalia.pluginDir() or "") .. "/snapshot.sh", repo(), noctalia.getConfig("remote") or "",
    tostring(noctalia.getConfig("packages") ~= false),
    tostring(noctalia.getConfig("services") ~= false),
    tostring(noctalia.getConfig("noctalia") ~= false),
    tostring(sharing()),
  }
  for _, path in ipairs(list("files")) do
    table.insert(argv, noctalia.expandPath(path))
  end
  table.insert(argv, "--")
  for _, path in ipairs(list("device_files")) do
    table.insert(argv, noctalia.expandPath(path))
  end
  noctalia.runAsync(argv)
  publish()
end

-- The last line of the run's output that is not a "skipped" note or a shared file's state,
-- as the error to show.
local function lastLine(text)
  local found = nil
  for line in (text or ""):gmatch("[^\n]+") do
    if not line:match("^skipped") and not line:match("^applied ") and not line:match("^removed ")
      and not line:match("^conflict ") and not line:match("^held ") and not line:match("^settings ") then
      found = line
    end
  end
  return found
end

local function poll()
  if not running or reading then
    return
  end
  reading = true
  noctalia.readFileAsync(runPrefix .. ".exit", function(exitText)
    local code = tonumber(exitText and noctalia.string.trim(exitText) or "")
    if code == nil then
      reading = false
      return
    end
    noctalia.readFileAsync(runPrefix .. ".log", function(log)
      reading = false
      running = false
      state.lastMs = noctalia.nowMs()
      local counts = {}
      for what, number in (log or ""):gmatch("count (%a+) (%d+)") do
        counts[what] = tonumber(number)
      end
      if next(counts) then
        state.counts = counts
      end
      -- What share.sh did with the other devices' files. A file held back was also applied
      -- first, then put back.
      local applied, conflicts, held, heldSet = {}, {}, {}, {}
      local lines = {}
      for line in (log or ""):gmatch("[^\n]+") do
        local word, path = line:match("^(%a+) (.+)$")
        if word then
          table.insert(lines, { word = word, path = path })
        end
      end
      for _, line in ipairs(lines) do
        if line.word == "held" then
          heldSet[line.path] = true
          table.insert(held, line.path)
        elseif line.word == "conflict" then
          table.insert(conflicts, line.path)
        end
      end
      for _, line in ipairs(lines) do
        if (line.word == "applied" or line.word == "removed") and not heldSet[line.path] then
          table.insert(applied, line.path)
        end
      end
      local newlyHeld = #held > #(state.held or {})
      state.conflicts, state.held = conflicts, held
      if #applied > 0 then
        noctalia.notify(noctalia.trp("notify.applied", #applied), table.concat(applied, "\n"))
      end
      local settingsTaken = tonumber((log or ""):match("settings applied (%d+)") or "0") or 0
      if settingsTaken > 0 then
        noctalia.notify(noctalia.trp("notify.settings", settingsTaken))
      end
      if newlyHeld then
        noctalia.notifyError(noctalia.tr("notify.held"), table.concat(held, "\n"))
      end
      if code == 0 then
        state.error = nil
        state.result = (log or ""):find("pushed") and "pushed"
          or (log or ""):find("unchanged") and "unchanged" or "saved"
      else
        -- Exit code 2 is a failed push: the snapshot itself is saved.
        state.result = code == 2 and "saved" or nil
        state.error = lastLine(log) or noctalia.tr("error.unknown")
        noctalia.notifyError(noctalia.tr("notify.failed"), state.error)
      end
      save()
      publish()
      if again then
        snapshot()
      end
    end)
  end)
end

local function restore()
  local script = repo() .. "/restore.sh"
  if noctalia.fileExists(script) then
    -- The path goes in single quotes, with any single quote in it closed and escaped.
    noctalia.runInTerminal("sh '" .. script:gsub("'", "'\\''") .. "'")
  end
end

noctalia.state.watch("resurrect.command", function(command)
  if type(command) ~= "table" then
    return
  end
  if command.action == "save" then
    snapshot()
  elseif command.action == "resolve" and type(command.path) == "string"
    and (command.choice == "mine" or command.choice == "theirs") then
    -- The choice goes with the next save, which starts now or after the one running.
    choices[command.path] = command.choice
    if running then
      again = true
    else
      snapshot()
    end
  elseif command.action == "restore" then
    restore()
  elseif command.action == "open" and noctalia.commandExists("xdg-open") then
    noctalia.mkdirAll(repo())
    noctalia.runAsync({ "xdg-open", repo() })
  elseif command.action == "hooks" and noctalia.commandExists("xdg-open") then
    noctalia.mkdirAll(repo() .. "/hooks/save")
    noctalia.mkdirAll(repo() .. "/hooks/restore")
    noctalia.runAsync({ "xdg-open", repo() .. "/hooks" })
  end
  publish()
end)

-- noctalia msg plugin omerfuyar/resurrect:service all save
function onIpc(event)
  if event == "save" then
    snapshot()
  end
end

function update()
  poll()
  if loaded and not running and noctalia.getConfig("daily") ~= false
    and (state.lastMs == nil or noctalia.nowMs() - state.lastMs >= DAY_MS) then
    snapshot()
  end
end

function onConfigChanged()
  publish()
end

noctalia.readFileAsync(stateFile, function(text)
  local saved = text and noctalia.json.decode(text)
  if type(saved) == "table" then
    state = saved
  end
  -- A run that was going when Noctalia stopped is read back by poll().
  running = noctalia.fileExists(runPrefix .. ".log") and not noctalia.fileExists(runPrefix .. ".exit")
  state.conflicts = state.conflicts or {}
  state.held = state.held or {}
  loaded = true
  publish()
  noctalia.setUpdateInterval(2000)
  -- With sharing on, what other devices changed comes in as soon as Noctalia starts.
  if sharing() and not running then
    snapshot()
  end
end)
