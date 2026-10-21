#!/usr/bin/env python3
"""Check that every shipped binary asset is covered by docs/ASSET_LICENSES.md.

Default run: warn about uncovered assets and RED entries, exit 0 when coverage is
complete (so day-to-day work is not blocked by known licensing questions).
`--strict`: exit 1 if any asset is RED or uncovered — use it in a release job.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/ASSET_LICENSES.md"

SHIPPED_GLOBS = [
    "*.glb",
    "icon.png",
    "scenes/models/*.glb",
    "sounds/*.wav",
    "sounds/*.ogg",
    "sounds/*.mp3",
    "addons/gevp/sounds/*.wav",
    "data/*.osm",
]


def shipped_assets():
    assets = []
    for pattern in SHIPPED_GLOBS:
        for path in ROOT.glob(pattern):
            if path.is_file():
                assets.append(path)
    return sorted(set(assets))


def ledger_entries():
    """Return {basename: status} parsed from the markdown table."""
    entries = {}
    if not LEDGER.exists():
        return entries
    for line in LEDGER.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 6:
            continue
        name = cells[0].strip("`")
        status = cells[5].upper()
        if status in {"GREEN", "YELLOW", "RED"}:
            entries[name] = status
    return entries


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="fail on any RED or uncovered asset")
    args = parser.parse_args(argv)

    assets = shipped_assets()
    entries = ledger_entries()
    missing = [path for path in assets if path.name not in entries]
    red = sorted(name for name, status in entries.items() if status == "RED")
    yellow = sorted(name for name, status in entries.items() if status == "YELLOW")

    print(f"shipped assets: {len(assets)}; ledger entries: {len(entries)}")
    if yellow:
        print("YELLOW (needs licence confirmation before release):")
        for name in yellow:
            print(f"  - {name}")
    if red:
        print("RED (must not ship publicly until resolved):")
        for name in red:
            print(f"  - {name}")
    if missing:
        print("UNCOVERED (add to docs/ASSET_LICENSES.md):")
        for path in missing:
            print(f"  - {path.relative_to(ROOT)}")

    if missing:
        return 1
    if args.strict and red:
        print("strict mode: RED assets present", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
