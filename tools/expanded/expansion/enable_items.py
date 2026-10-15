#!/usr/bin/env python3
"""Expanded Library expansion, Phase 3: switch on stamina and the inventory in
the existing scene, scenes/level/expanded_library.tscn, as a minimal text patch
(the level's builder is frozen; see cut_doorways.py).

Adds property lines only, to four existing nodes:
  - Player:               use_stamina = true, use_inventory = true
  - Gameplay/StaffAccessCard:  grants_item = &"staff_card"
    (taking the card also puts it in a carried slot)
  - Gameplay/ArchiveFrontGateG2, Gameplay/LobbyStaffDoorG4:  key_item = &"staff_card"
    (the staff doors open while the card is carried)
Approved by the owner (expansion Phase 3): stamina in the Expanded Library only;
the staff card is a carried item; card doors check the carried card.
The tutorial (library_graybox.tscn) is not touched.

Usage (from the project folder):  python3 tools/expanded/expansion/enable_items.py [--dry-run]
Idempotent: lines already present are left alone.
"""
import sys

SCENE = "scenes/level/expanded_library.tscn"

# (node header prefix, line after which to insert, lines to add)
PATCHES = [
    ('[node name="Player" parent="." ', None, ['use_stamina = true', 'use_inventory = true']),
    ('[node name="StaffAccessCard" type="Area3D" parent="Gameplay" ', 'script = ', ['grants_item = &"staff_card"']),
    ('[node name="ArchiveFrontGateG2" type="Area3D" parent="Gameplay" ', 'script = ', ['key_item = &"staff_card"']),
    ('[node name="LobbyStaffDoorG4" type="Area3D" parent="Gameplay" ', 'script = ', ['key_item = &"staff_card"']),
]


def main() -> int:
    dry = "--dry-run" in sys.argv
    lines = open(SCENE, encoding="utf-8").read().split("\n")
    added = 0
    for header, after, new in PATCHES:
        starts = [i for i, l in enumerate(lines) if l.startswith(header)]
        if len(starts) != 1:
            print("Expected one node starting %r, found %d" % (header, len(starts)))
            return 1
        start = starts[0]
        end = start + 1
        while end < len(lines) and not lines[end].startswith("["):
            end += 1
        block = lines[start:end]
        missing = [l for l in new if l not in block]
        if not missing:
            continue
        at = start + 1
        if after is not None:
            hits = [i for i in range(start + 1, end) if lines[i].startswith(after)]
            if len(hits) != 1:
                print("Expected one %r line in %r" % (after, header))
                return 1
            at = hits[0] + 1
        else:
            # Root properties of an instance: after its transform line if any.
            while at < end and lines[at].startswith("transform = "):
                at += 1
        lines[at:at] = missing
        added += len(missing)
        print("%s: + %s" % (header.split('"')[1], ", ".join(missing)))
    if dry:
        print("Dry run: %d lines would be added." % added)
        return 0
    open(SCENE, "w", encoding="utf-8").write("\n".join(lines))
    print("Added %d lines to %s." % (added, SCENE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
