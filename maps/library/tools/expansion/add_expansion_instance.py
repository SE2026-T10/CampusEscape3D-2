#!/usr/bin/env python3
"""Expanded Library expansion, Phase 2: instance the expansion sub-scene,
maps/library/scenes/expanded_library_expansion.tscn, in the existing scene,
maps/library/scenes/expanded_library.tscn, as a minimal text patch: one ext_resource
line and one node (Expansion, a child of the root, just before Dressing).

This step was first done by hand in Phase 2; it is scripted here (builder cleanup,
approved by the owner on 2026-10-31) so maps/library/tools/rebuild_level.py can
reproduce the saved scene. The node keeps the unique_id it was given then.

Usage (from the project folder):
  python3 maps/library/tools/expansion/add_expansion_instance.py [--dry-run]
Idempotent: nothing changes when the instance is already there.
"""
import re, sys

SCENE = "maps/library/scenes/expanded_library.tscn"
SUB_SCENE = "res://maps/library/scenes/expanded_library_expansion.tscn"
EXT_ID = "28_expsn"
NODE_ID = 1530477261


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    if SUB_SCENE in text:
        print("add_expansion_instance: nothing to change")
        return
    lines = text.split("\n")
    last = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    lines.insert(last + 1, '[ext_resource type="PackedScene" path="%s" id="%s"]' % (SUB_SCENE, EXT_ID))
    text = "\n".join(lines)
    anchor = '[node name="Dressing" type="Node3D" parent="."'
    if anchor not in text:
        sys.exit("add_expansion_instance: missing %s" % anchor)
    i = text.index(anchor)
    text = text[:i] + '[node name="Expansion" parent="." unique_id=%d instance=ExtResource("%s")]\n\n' % (NODE_ID, EXT_ID) + text[i:]
    m = re.search(r"load_steps=(\d+)", text)
    if m:
        text = text.replace(m.group(0), "load_steps=%d" % (int(m.group(1)) + 1), 1)
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    print("add_expansion_instance: Expansion instanced%s" % (" (dry run)" if dry else ""))


if __name__ == "__main__":
    main()
