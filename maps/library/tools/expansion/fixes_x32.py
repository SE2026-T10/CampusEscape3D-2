#!/usr/bin/env python3
"""Expanded Library, the stamina bar on paper (requested by the owner on 2026-11-03): a
minimal text patch of the existing scene, maps/library/scenes/expanded_library.tscn.

Turns on StealthHud.paper_style for this map, as fixes_x30.py did ObjectiveHud.paper_note:
the stamina bar is drawn on a strip of paper in ink, to match the mission note, the journal
clipboard, the ways-out index card and the item tags. The tutorial is not touched.

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x32.py [--dry-run]
Idempotent: nothing changes when it is already on.
"""
import sys

SCENE = "maps/library/scenes/expanded_library.tscn"
HEADER = '[node name="StealthHud" type="CanvasLayer" parent="."'


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    start = text.index(HEADER)
    end = text.find("\n[", start + 1)
    block = text[start:end]
    if "\npaper_style = true" in block:
        print("fixes_x32: nothing to change")
        return 0
    text = text[:start] + block.rstrip("\n") + "\npaper_style = true\n" + text[end:]
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    print("fixes_x32: StealthHud draws the stamina bar on paper%s" % (" (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
