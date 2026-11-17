#!/usr/bin/env python3
"""Expanded Library, the Study 4 reserve shelf (approved by the owner on 2026-10-31): a
minimal text patch of the existing scene, maps/library/scenes/expanded_library.tscn.

Appends the optional, hidden objective "reserve_shelf" to Gameplay/ObjectiveManager's
`objectives` (the same data as its entry in expansion_layout.gd MISSION_OBJECTIVES; the
puzzle suite checks they match). The puzzle itself, its books, clues and reward are in the
expansion sub-scene (build_expansion.gd: _add_reserve_shelf, _reserve_bookcase).

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x27.py [--dry-run]
Idempotent: nothing changes when the objective is already there.
"""
import sys

SCENE = "maps/library/scenes/expanded_library.tscn"
ENTRY = """}, {
"done": "Reserve shelf complete: the cabinet below it is open",
"hidden": true,
"hint": "Study 4, ground floor. The reserve slip lists the three missing books; they are out on the return trolleys.",
"id": &"reserve_shelf",
"optional": true,
"title": "Complete the reserve shelf"
}])"""
AFTER = '"title": "Open the security locker"\n}])'


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    if '"id": &"reserve_shelf"' in text:
        print("fixes_x27: nothing to change")
        return 0
    if text.count(AFTER) != 1:
        sys.exit("fixes_x27: the objectives' end (after security_locker) not found once")
    text = text.replace(AFTER, '"title": "Open the security locker"\n' + ENTRY)
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    print("fixes_x27: objective reserve_shelf added%s" % (" (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
