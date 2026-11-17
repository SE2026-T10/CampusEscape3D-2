#!/usr/bin/env python3
"""Expanded Library, a "!" over every item (requested by the owner on 2026-11-02): a minimal
text patch of the existing scene, maps/library/scenes/expanded_library.tscn.

The carried items' pickups show their "!" by default (ItemPickup.show_marker, built by the
expansion). The staff access card on its desk and the rare manuscript (AccessCard; off by
default, as in the tutorial) get theirs here: show_marker = true, the "!" floating above
their name labels (AccessCard.marker_offset, 0.8 m up; the labels are at 0.45 m).

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x29.py [--dry-run]
Idempotent: nothing changes when both already show it.
"""
import sys

SCENE = "maps/library/scenes/expanded_library.tscn"
NAMES = ["StaffAccessCard", "RareManuscript"]


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    changes = []
    for name in NAMES:
        start = text.index('[node name="%s" type="Area3D" parent="Gameplay"' % name)
        end = text.find("\n[", start + 1)
        block = text[start:end]
        if "\nshow_marker = true" in block:
            continue
        block = block.rstrip("\n") + "\nshow_marker = true\n"
        text = text[:start] + block + text[end:]
        changes.append("%s: shows its \"!\"" % name)
    if not changes:
        print("fixes_x29: nothing to change")
        return 0
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    for c in changes:
        print("fixes_x29: %s%s" % (c, " (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
