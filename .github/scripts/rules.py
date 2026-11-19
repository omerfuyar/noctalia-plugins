"""Checks of this repository's own rules for every plugin (DESIGN.md, section 13.1).

Prints each problem as "<file>:<line>: <problem>" and exits 1 when there is one.

- A slow call, such as noctalia.appIconPath, runs only in a service: a panel's or widget's
  callback has 25 ms of CPU, and its script starts again each time it opens, so a cache
  there is lost (DESIGN.md, section 1.5). Files a non-service entry loads with require()
  count as that entry's.
- Every translation key used in Luau as a plain string exists in translations/en.json.
- No shell runs a script, except those in SHELL_SCRIPTS: an argv that starts with "sh", "-c"
  or "bash", "-c" names its script, and a command given to runAsync as one string runs
  through a shell, so it is not allowed (DESIGN.md, section 10.4 and 10.8).
"""

import json
import re
import sys
import tomllib
from pathlib import Path

SLOW_CALLS = ["noctalia.appIconPath"]
UI_ENTRIES = ["panel", "widget", "launcher_provider", "layer", "desktop_widget", "lockscreen_widget", "shortcut"]
REQUIRE = re.compile(r'require\(\s*"([^"]+)"\s*\)')
# Each allowed shell script: (file, the variable that holds the script) -> why only a shell
# can do it.
SHELL_SCRIPTS = {
    ("media-downloader/service.luau", "RUNNER"):
        "a download outlives the service when it reloads, and the shell writes its exit code",
    ("resurrect/service.luau", "LONG"):
        "git's network commands may take longer than the 60 s limit of runAsync callbacks",
    ("screen-control/lib/hyprland.luau", "EVAL_ALL"):
        "the requests that put the screens back as the plugin stops run in order after it is gone",
    ("screen-control/lib/hyprland.luau", "MONITOR_ALL"):
        "the requests that put the screens back as the plugin stops run in order after it is gone",
}
SHELL = re.compile(r'"(?:sh|bash)",\s*"-c",\s*([\w.]+|"[^"]*"|\[)')
STRING_COMMAND = re.compile(r'runAsync\(\s*(?:"|\[=*\[|string\.format)')
TRANSLATE = re.compile(r'noctalia\.trp?\(\s*"([^"]+)"\s*[,)]')


def required(path, seen):
    """The file and every file it loads with require(), relative to the file."""
    if path in seen or not path.is_file():
        return
    seen.add(path)
    for name in REQUIRE.findall(path.read_text()):
        required((path.parent / name).resolve(), seen)


def has_key(translations, key):
    node = translations
    for part in key.split("."):
        if not isinstance(node, dict) or part not in node:
            return False
        node = node[part]
    return isinstance(node, str) or (isinstance(node, dict) and "other" in node)


def check(plugin):
    problems = []
    manifest = tomllib.loads((plugin / "plugin.toml").read_text())
    ui_files = set()
    for kind in UI_ENTRIES:
        for entry in manifest.get(kind, []):
            if "entry" in entry:
                required((plugin / entry["entry"]).resolve(), ui_files)

    for path in sorted(ui_files):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            code = line.split("--", 1)[0]
            for call in SLOW_CALLS:
                if call in code:
                    problems.append(f"{path.relative_to(Path.cwd())}:{number}: {call} in a panel or widget; "
                                    "call it in the service and publish the result (DESIGN.md, section 1.5)")

    en = plugin / "translations" / "en.json"
    translations = json.loads(en.read_text()) if en.is_file() else {}
    for path in sorted(plugin.rglob("*.luau")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            for key in TRANSLATE.findall(line.split("--", 1)[0]):
                if not has_key(translations, key):
                    problems.append(f"{path.relative_to(Path.cwd())}:{number}: translation key {key} "
                                    "is not in translations/en.json")

    for path in sorted(plugin.rglob("*.luau")):
        relative = path.relative_to(Path.cwd())
        for number, line in enumerate(path.read_text().splitlines(), 1):
            code = line.split("--", 1)[0]
            for script in SHELL.findall(code):
                if (str(relative), script) not in SHELL_SCRIPTS:
                    problems.append(f"{relative}:{number}: a shell script; run the command with argv, or add "
                                    "it to SHELL_SCRIPTS in rules.py with why only a shell can do it")
            if STRING_COMMAND.search(code):
                problems.append(f"{relative}:{number}: runAsync with one string runs a shell; give it argv")
    return problems


def main():
    problems = []
    for manifest in sorted(Path(".").glob("*/plugin.toml")):
        problems += check(manifest.parent.resolve())
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
