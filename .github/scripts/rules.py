"""Checks of this repository's own rules for every plugin (DESIGN.md, section 13.1).

Prints each problem as "<file>:<line>: <problem>" and exits 1 when there is one.

- A slow call, such as noctalia.appIconPath, runs only in a service: a panel's or widget's
  callback has 25 ms of CPU, and its script starts again each time it opens, so a cache
  there is lost (DESIGN.md, section 1.5). Files a non-service entry loads with require()
  count as that entry's.
- Every translation key used in Luau as a plain string exists in translations/en.json.
"""

import json
import re
import sys
import tomllib
from pathlib import Path

SLOW_CALLS = ["noctalia.appIconPath"]
UI_ENTRIES = ["panel", "widget", "launcher_provider", "layer", "desktop_widget", "lockscreen_widget", "shortcut"]
REQUIRE = re.compile(r'require\(\s*"([^"]+)"\s*\)')
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
