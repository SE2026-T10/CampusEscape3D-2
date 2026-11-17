#!/usr/bin/env python3
"""Expanded Library, remodelled objective items (requested by the owner on 2026-11-02): a
minimal text patch of the existing scene, maps/library/scenes/expanded_library.tscn.

The staff access card on its desk (Office 2) and the rare manuscript in its case (the
vault) were plain glowing boxes. Each AccessCard now builds an ItemCatalog model into its
"Model" at run time (access_card.gd, model_item): the card the new staff card model, the
manuscript a leather-bound volume (ItemCatalog.RARE_MANUSCRIPT_MODEL). Both keep their
glow (model_glow, each part in its own colour), their spin and their floating labels, and
rest where the boxes did (model_offset: half the old box's height down). Their parts are
on render layer 8, as the card's box was (fixes_x7.gd: upper floor props; the
8-lights-per-mesh rule). This script sets those properties, removes the two old box meshes
and their resources when nothing else uses them.

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x28.py [--dry-run]
Idempotent: nothing changes when the cards already build their models.
"""
import re, sys

SCENE = "maps/library/scenes/expanded_library.tscn"
ITEMS = [
    ("StaffAccessCard", '&"staff_card"', "Vector3(0, -0.01, 0)"),
    ("RareManuscript", '&"rare_manuscript"', "Vector3(0, -0.04, 0)"),
]
GLOW = "0.3"
LAYERS = "8"


def block_span(text, header_prefix):
    start = text.index(header_prefix)
    end = text.find("\n[", start + 1)
    return start, (len(text) if end < 0 else end + 1)


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    if 'model_item = &"staff_card"' in text:
        print("fixes_x28: nothing to change")
        return 0
    changes = []
    unused_candidates = set()
    for name, item, offset in ITEMS:
        # The AccessCard's own properties, after its header block's last line.
        start, end = block_span(text, '[node name="%s" type="Area3D" parent="Gameplay"' % name)
        block = text[start:end].rstrip("\n")
        block += "\nmodel_item = %s\nmodel_offset = %s\nmodel_glow = %s\nmodel_layers = %s\n" % (item, offset, GLOW, LAYERS)
        text = text[:start] + block + "\n" + text[end:]
        # The old box mesh under its Model.
        start, end = block_span(text, '[node name="Mesh" type="MeshInstance3D" parent="Gameplay/%s/Model"' % name)
        mesh_block = text[start:end]
        unused_candidates.update(re.findall(r'SubResource\("([^"]+)"\)', mesh_block))
        text = text[:start] + text[end:]
        changes.append("%s: builds %s, old box removed" % (name, item))
    for rid in sorted(unused_candidates):
        if ('SubResource("%s")' % rid) in text:
            continue
        m = re.search(r'\[sub_resource type="[^"]+" id="%s"\]\n' % re.escape(rid), text)
        if not m:
            continue
        end = text.find("\n[", m.start() + 1)
        text = text[:m.start()] + text[end + 1:]
        changes.append("resource %s removed (unused)" % rid)
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    for c in changes:
        print("fixes_x28: %s%s" % (c, " (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
