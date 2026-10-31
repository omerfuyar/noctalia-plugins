"""Shares Noctalia's settings.toml between devices, one setting at a time.

snapshot.sh runs it from the repository's folder:
    python3 settings.py <settings.toml> <theirs> <base>
<theirs> is the other devices' shared settings, <base> the shared settings this device last
agreed on; either may be a missing file. The script writes:
- shared/noctalia/settings.toml, the shared settings;
- <base>, the same, for the next save;
- <settings.toml>, when other devices changed something, in one step.

Each setting is compared in three versions: this device's, theirs and the base. One that
only another device changed is taken; otherwise this device's value stays. The list of
enabled plugins is merged item by item. Settings tied to the hardware are never shared:
brightness and battery, any table named after a monitor or placed on one (except the
wallpaper's), and Resurrect's share and device_files. Plugin sources that are folders on
this device stay too. A setting shared for the first time, with no agreed version yet,
takes the value already shared, so the device that shared it first wins.

Prints "settings applied <count>" and "count settings <number>".
"""

import math
import os
import re
import sys
import tomllib

LOCAL_SECTIONS = {"brightness", "battery"}
# Resurrect's settings that belong to this device; the rest, such as its file list, is shared.
LOCAL_RESURRECT = {"share", "device_files"}
LOCAL_PLUGIN = "omerfuyar/resurrect"
MONITOR = re.compile(r"^(eDP|DP|HDMI|DVI|VGA|LVDS|DSI|Virtual|HEADLESS|USB)(-[A-Z])?-\d+$")
NAMES_MONITOR = re.compile(r"(^|[@:_.-])(eDP|DP|HDMI|DVI|VGA|LVDS|DSI)(-[A-Z])?-\d+($|[@:_.-])")
MISSING = object()


def load(path):
    try:
        with open(path, "rb") as file:
            return tomllib.load(file)
    except FileNotFoundError:
        return {}


def is_local(path, table):
    """True for a table that holds settings of this device only."""
    if len(path) == 1 and path[0] in LOCAL_SECTIONS:
        return True
    if path[:1] == ("wallpaper",):
        return False
    if path and NAMES_MONITOR.search(path[-1]):
        return True
    return any(isinstance(v, str) and MONITOR.match(v) for v in table.values())


def is_folder_source(source):
    return isinstance(source, dict) and source.get("kind") == "path"


def split(table, path=()):
    """(shared, local) leaves of a table, as {path: value}."""
    shared, local = {}, {}
    if is_local(path, table):
        for key, value in table.items():
            local.update(flatten(value, path + (key,)))
        return shared, local
    for key, value in table.items():
        here = path + (key,)
        if isinstance(value, dict):
            s, l = split(value, here)
            shared.update(s)
            local.update(l)
        elif path == ("plugin_settings", LOCAL_PLUGIN) and key in LOCAL_RESURRECT:
            local[here] = value
        elif here == ("plugins", "source") and isinstance(value, list):
            shared[here] = [v for v in value if not is_folder_source(v)]
            folders = [v for v in value if is_folder_source(v)]
            if folders:
                local[here] = folders
        else:
            shared[here] = value
    return shared, local


def flatten(value, path):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            out.update(flatten(item, path + (key,)))
        return out
    return {path: value}


def same(a, b):
    """Equal, with floats compared closely: Noctalia stores widget positions as floats."""
    if isinstance(a, float) and isinstance(b, float):
        return math.isclose(a, b, rel_tol=1e-6)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    return type(a) is type(b) and a == b


def merge_list(mine, theirs, base):
    """Items either side added are in, items either side removed are out."""
    base = base if isinstance(base, list) else []
    mine = mine if isinstance(mine, list) else []
    theirs = theirs if isinstance(theirs, list) else []
    removed = [i for i in base if i not in mine or i not in theirs]
    out = [i for i in theirs if i not in removed]
    out += [i for i in mine if i not in out and i not in removed]
    return out


def merge(mine, theirs, base):
    """The merged shared leaves, and how many of them came from theirs."""
    out, taken = {}, 0
    for path in sorted(set(mine) | set(theirs) | set(base), key=str):
        m, t, b = (d.get(path, MISSING) for d in (mine, theirs, base))
        if path == ("plugins", "enabled"):
            value = merge_list(*(None if v is MISSING else v for v in (m, t, b)))
            if m is MISSING or not same(value, m):
                taken += 1
        elif b is MISSING and t is not MISSING and not same(m, t):
            # Shared for the first time here: the value another device shared first wins.
            value = t
            taken += 1
        elif same(m, t) or same(t, b) or m is not b and not same(m, b):
            value = m
        else:
            value = t
            taken += 1
        if value is not MISSING:
            out[path] = value
    return out, taken


def nest(leaves):
    root = {}
    for path, value in leaves.items():
        table = root
        for key in path[:-1]:
            table = table.setdefault(key, {})
        table[path[-1]] = value
    return root


BARE = re.compile(r"^[A-Za-z0-9_-]+$")


def key(name):
    return name if BARE.match(name) else quote(name)


def quote(text):
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    escaped = re.sub(r"[\x00-\x1f\x7f]", lambda m: "\\u%04x" % ord(m.group()), escaped)
    return '"' + escaped + '"'


def value_text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return quote(value)
    if isinstance(value, list):
        return "[" + ", ".join(value_text(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(key(k) + " = " + value_text(v) for k, v in value.items()) + " }"
    raise TypeError(type(value))


def is_table_list(value):
    return isinstance(value, list) and value and all(isinstance(v, dict) for v in value)


def dump(table, path=()):
    """TOML text for a table: plain values first, then subtables and lists of tables."""
    lines = []
    for name, value in table.items():
        if not isinstance(value, dict) and not is_table_list(value):
            lines.append(key(name) + " = " + value_text(value))
    for name, value in table.items():
        here = path + (name,)
        if isinstance(value, dict):
            lines.append("")
            lines.append("[" + ".".join(key(k) for k in here) + "]")
            lines.append(dump(value, here))
        elif is_table_list(value):
            for item in value:
                lines.append("")
                lines.append("[[" + ".".join(key(k) for k in here) + "]]")
                lines.append(dump(item, here))
    return "\n".join(line for line in lines if line is not None).strip("\n")


def write(path, data):
    """Writes data as TOML next to path, checks it, then moves it over path in one step."""
    text = dump(data) + "\n"
    if not same(tomllib.loads(text), data):
        raise ValueError("TOML round trip failed for " + path)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = os.path.join(os.path.dirname(path) or ".", "." + os.path.basename(path) + ".resurrect-tmp")
    with open(tmp, "w") as file:
        file.write(text)
    os.replace(tmp, path)


def main():
    settings_path, theirs_path, base_path = sys.argv[1:4]
    with open(settings_path, "rb") as file:
        before = file.read()
    current = tomllib.loads(before.decode())
    mine, local = split(current)
    theirs, _ = split(load(theirs_path))
    base, _ = split(load(base_path))

    merged, taken = merge(mine, theirs, base)
    write("shared/noctalia/settings.toml", nest(merged))
    write(base_path, nest(merged))

    applied = 0
    if taken:
        result = nest({**merged, **local})
        # The local list of plugin sources keeps this device's folder sources.
        if ("plugins", "source") in local:
            sources = merged.get(("plugins", "source"), []) + local[("plugins", "source")]
            result.setdefault("plugins", {})["source"] = sources
        if not same(result, current):
            # Noctalia may have written the file meanwhile; then this waits for the next save.
            with open(settings_path, "rb") as file:
                if file.read() == before:
                    write(settings_path, result)
                    applied = taken
    print("settings applied %d" % applied)
    print("count settings %d" % len(merged))


if __name__ == "__main__":
    main()
