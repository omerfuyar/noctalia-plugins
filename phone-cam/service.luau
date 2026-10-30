--!nonstrict
-- Phone Cam service: finds Android phones with adb and the virtual camera, and runs scrcpy
-- to send a phone's camera to the virtual camera, or to show the phone's screen.
--
-- scrcpy runs detached, so it outlives the 60 s limit of runAsync callbacks and survives a
-- reload of this script. RUNNER writes its output, process id and exit code to the data
-- directory; update() reads them back.
--
-- Publishes "phone-cam.model" and takes commands on "phone-cam.command".

local REQUIRED = { "scrcpy", "adb" }

local INSTALLERS = {
  { manager = "pacman", command = "sudo pacman -S --needed scrcpy android-tools" },
  { manager = "apt", command = "sudo apt install scrcpy adb" },
  { manager = "dnf", command = "sudo dnf install scrcpy android-tools" },
  { manager = "zypper", command = "sudo zypper install scrcpy android-tools" },
}

-- Loads v4l2loopback now and at every boot, with a camera named "Phone Cam".
local LOOPBACK_SETUP = "echo v4l2loopback | sudo tee /etc/modules-load.d/phone-cam.conf"
  .. " && echo 'options v4l2loopback exclusive_caps=1 card_label=\"Phone Cam\"'"
  .. " | sudo tee /etc/modprobe.d/phone-cam.conf"
  .. " && sudo modprobe v4l2loopback exclusive_caps=1 card_label=\"Phone Cam\""

-- $1 is the path prefix of the job's files, the rest is the scrcpy command.
local RUNNER = [[
prefix=$1
shift
rm -f "$prefix.exit"
"$@" >"$prefix.log" 2>&1 &
echo $! >"$prefix.pid"
wait $!
echo $? >"$prefix.exit"
]]

-- Prints "/dev/videoN<TAB>name" for each virtual camera: those with no real device behind.
local FIND_LOOPBACK = [[
for d in /sys/class/video4linux/video*; do
  case "$(readlink -f "$d/device")" in
    */virtual/*) printf '/dev/%s\t%s\n' "${d##*/}" "$(cat "$d/name")" ;;
  esac
done
]]

local QUALITY = { ["720"] = "1280", ["1080"] = "1920", ["1440"] = "2560" }

local dataDir = noctalia.pluginDataDir() or ""
local stateFile = dataDir .. "/state.json"

local missing = {}
local install = nil
local devices = {} -- { serial, name, state }
local loopback = nil -- { path, name }
local jobs: { [string]: any } = {} -- by kind, "webcam" or "mirror": { serial, name, status, error }
local facing = "back"
local selected = nil
local watching = false -- the panel is open
local reading = {}

local function prefix(kind)
  return dataDir .. "/" .. kind
end

local function save()
  local text = noctalia.json.encode({ facing = facing, selected = selected, jobs = jobs })
  if text then
    noctalia.writeFile(stateFile, text)
  end
end

local function checkDependencies()
  missing = {}
  for _, command in ipairs(REQUIRED) do
    if not noctalia.commandExists(command) then
      table.insert(missing, command)
    end
  end
  install = nil
  for _, installer in ipairs(INSTALLERS) do
    if noctalia.commandExists(installer.manager) then
      install = installer.command
      break
    end
  end
end

local function publish()
  noctalia.state.set("phone-cam.model", {
    ready = #missing == 0,
    missing = missing,
    installCommand = install,
    loopbackCommand = LOOPBACK_SETUP,
    devices = devices,
    selected = selected,
    loopback = loopback,
    facing = facing,
    webcam = jobs["webcam"],
    mirror = jobs["mirror"],
  })
end

local function deviceName(serial)
  for _, device in ipairs(devices) do
    if device.serial == serial then
      return device.name
    end
  end
  return serial
end

local function readDevices()
  if #missing > 0 then
    return
  end
  noctalia.runAsync({ "adb", "devices", "-l" }, function(result)
    local list = {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local serial, state = line:match("^(%S+)%s+(%S+)")
      if serial and state and serial ~= "List" and serial ~= "*" then
        local model = line:match("model:(%S+)")
        table.insert(list, { serial = serial, state = state, name = model and model:gsub("_", " ") or serial })
      end
    end
    devices = list
    local found = false
    for _, device in ipairs(devices) do
      found = found or device.serial == selected
    end
    if not found then
      selected = devices[1] and devices[1].serial or nil
    end
    publish()
  end, 10000)
end

local function findLoopback()
  noctalia.runAsync({ "sh", "-c", FIND_LOOPBACK }, function(result)
    local first, named = nil, nil
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local path, name = line:match("^(%S+)\t(.*)$")
      if path then
        first = first or { path = path, name = name }
        if name == "Phone Cam" then
          named = named or { path = path, name = name }
        end
      end
    end
    loopback = named or first
    publish()
  end)
end

local function start(kind, args)
  if selected == nil then
    return
  end
  noctalia.mkdirAll(dataDir)
  local argv = { "sh", "-c", RUNNER, "phone-cam", prefix(kind), "scrcpy", "--serial", selected }
  table.move(args, 1, #args, #argv + 1, argv)
  jobs[kind] = { serial = selected, name = deviceName(selected), status = "running" }
  noctalia.runAsync(argv)
  save()
end

local function startWebcam()
  if loopback == nil then
    return
  end
  local size = QUALITY[noctalia.getConfig("quality")] or "1920"
  start("webcam", {
    "--video-source=camera", "--camera-facing=" .. facing, "--camera-ar=16:9", "--max-size=" .. size,
    "--no-audio", "--no-window", "--v4l2-sink=" .. loopback.path,
  })
end

local function startMirror()
  start("mirror", { "--window-title=" .. deviceName(selected), "--stay-awake" })
end

local function stop(kind)
  local job = jobs[kind]
  if job == nil or job.status ~= "running" then
    return
  end
  job.stopping = true
  noctalia.readFileAsync(prefix(kind) .. ".pid", function(pid)
    pid = pid and noctalia.string.trim(pid)
    if pid and pid:match("^%d+$") then
      noctalia.runAsync({ "kill", pid })
    end
  end)
end

-- The last error scrcpy printed, without its "ERROR: " prefix.
local function lastError(text)
  local found = nil
  for line in (text or ""):gmatch("[^\n]+") do
    found = line:match("^ERROR: (.*)") or found
  end
  return found
end

local function poll(kind)
  local job = jobs[kind]
  if job == nil or job.status ~= "running" or reading[kind] then
    return
  end
  reading[kind] = true
  noctalia.readFileAsync(prefix(kind) .. ".exit", function(exitText)
    local code = tonumber(exitText and noctalia.string.trim(exitText) or "")
    if code == nil then
      reading[kind] = false
      return
    end
    noctalia.readFileAsync(prefix(kind) .. ".log", function(log)
      reading[kind] = false
      -- Stopped on purpose, or closed by the user: not an error.
      if job.stopping or code == 0 then
        jobs[kind] = nil
      else
        job.status = "failed"
        job.error = lastError(log) or noctalia.tr("error.exited")
      end
      save()
      publish()
    end)
  end)
end

noctalia.state.watch("phone-cam.command", function(command)
  if type(command) ~= "table" then
    return
  end
  local action = command.action
  if action == "open" then
    watching = true
    checkDependencies()
    readDevices()
    findLoopback()
  elseif action == "close" then
    watching = false
  elseif action == "select" and type(command.serial) == "string" then
    selected = command.serial
    save()
  elseif action == "facing" and (command.facing == "back" or command.facing == "front") then
    facing = command.facing
    save()
  elseif action == "webcam" then
    if jobs.webcam and jobs.webcam.status == "running" then
      stop("webcam")
    else
      startWebcam()
    end
  elseif action == "mirror" then
    if jobs.mirror and jobs.mirror.status == "running" then
      stop("mirror")
    else
      startMirror()
    end
  elseif action == "dismiss" and type(command.kind) == "string" then
    jobs[command.kind] = nil
    save()
  end
  publish()
end)

-- noctalia msg plugin omerfuyar/phone-cam:service all webcam
-- Starts the webcam with the chosen phone, or stops it.
function onIpc(event)
  if event == "webcam" or event == "mirror" then
    noctalia.state.set("phone-cam.command", { action = event, n = noctalia.nowMs() })
  end
end

-- A job that was running when Noctalia stopped either finished meanwhile (its exit file
-- exists, and poll() picks it up) or died with Noctalia.
local function recover(kind)
  local job = jobs[kind]
  if job == nil or job.status ~= "running" or noctalia.fileExists(prefix(kind) .. ".exit") then
    return
  end
  noctalia.readFileAsync(prefix(kind) .. ".pid", function(pid)
    pid = pid and noctalia.string.trim(pid)
    local function gone()
      jobs[kind] = nil
      save()
      publish()
    end
    if pid == nil or not pid:match("^%d+$") then
      gone()
      return
    end
    noctalia.runAsync({ "kill", "-0", pid }, function(result)
      if result.exitCode ~= 0 and not noctalia.fileExists(prefix(kind) .. ".exit") then
        gone()
      end
    end)
  end)
end

local ticks = 0

function update()
  poll("webcam")
  poll("mirror")
  -- Phones come and go; while the panel is open, look every 2 seconds.
  ticks += 1
  if watching and ticks % 2 == 0 then
    readDevices()
  end
end

checkDependencies()
publish()
noctalia.readFileAsync(stateFile, function(text)
  local saved = text and noctalia.json.decode(text)
  if type(saved) == "table" then
    facing = saved.facing == "front" and "front" or "back"
    selected = type(saved.selected) == "string" and saved.selected or nil
    jobs = type(saved.jobs) == "table" and saved.jobs or {}
  end
  recover("webcam")
  recover("mirror")
  findLoopback()
  readDevices()
  publish()
  noctalia.setUpdateInterval(1000)
end)
