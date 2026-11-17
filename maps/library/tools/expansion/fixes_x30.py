#!/usr/bin/env python3
"""Expanded Library, the mission as a note on paper (requested by the owner on 2026-11-02):
a minimal text patch of the existing scene, maps/library/scenes/expanded_library.tscn.

Turns on ObjectiveHud.paper_note for this map: its mission panel becomes a PaperNote
(shared/scripts/ui/paper_note.gd: a taped, ruled sheet with the objectives in handwriting,
the done ones ticked and crossed out). The tutorial's HUD is not touched (paper_note off).

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x30.py [--dry-run]
Idempotent: nothing changes when the note is already on.
"""
import sys

SCENE = "maps/library/scenes/expanded_library.tscn"
HEADER = '[node name="ObjectiveHud" type="CanvasLayer" parent="."'


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    start = text.index(HEADER)
    end = text.find("\n[", start + 1)
    block = text[start:end]
    if "\npaper_note = true" in block:
        print("fixes_x30: nothing to change")
        return 0
    text = text[:start] + block.rstrip("\n") + "\npaper_note = true\n" + text[end:]
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    print("fixes_x30: ObjectiveHud shows the mission as a paper note%s" % (" (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
