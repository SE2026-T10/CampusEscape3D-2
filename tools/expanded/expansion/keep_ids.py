#!/usr/bin/env python3
"""Keeps a rebuilt expansion sub-scene's ids stable.

Godot gives every node a new random unique_id, and every script reference a
new random ext_resource id, each time build_expansion.gd saves the sub-scene,
so a rebuild would rewrite nearly every line even where nothing changed. This
copies the ids of the previous version (same node path, same resource path)
into the rebuilt file, so the diff shows only real changes. Nodes and
resources that are new keep their fresh ids.

Usage (from the project folder):
  git show HEAD:scenes/level/expanded_library_expansion.tscn > /tmp/old.tscn
  python3 tools/expanded/expansion/keep_ids.py /tmp/old.tscn scenes/level/expanded_library_expansion.tscn
"""
import re, sys

EXT = re.compile(r'^\[ext_resource type="[^"]+"(?: uid="[^"]+")? path="([^"]+)" id="([^"]+)"\]')
NODE = re.compile(r'^\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]+)")?.*? unique_id=(\d+)')


def ids(text):
    ext, nodes = {}, {}
    for line in text.split("\n"):
        m = EXT.match(line)
        if m:
            ext[m.group(1)] = m.group(2)
        m = NODE.match(line)
        if m:
            nodes[(m.group(2) or "", m.group(1))] = m.group(3)
    return ext, nodes


def main():
    old_path, new_path = sys.argv[1], sys.argv[2]
    old_ext, old_nodes = ids(open(old_path, encoding="utf-8").read())
    text = open(new_path, encoding="utf-8").read()
    new_ext, new_nodes = ids(text)
    kept_ext = kept_nodes = 0
    for path, new_id in new_ext.items():
        old_id = old_ext.get(path)
        if old_id and old_id != new_id:
            text = text.replace('id="%s"]' % new_id, 'id="%s"]' % old_id)
            text = text.replace('ExtResource("%s")' % new_id, 'ExtResource("%s")' % old_id)
            kept_ext += 1
    lines = text.split("\n")
    for i, line in enumerate(lines):
        m = NODE.match(line)
        if m:
            old_id = old_nodes.get((m.group(2) or "", m.group(1)))
            if old_id:
                lines[i] = line.replace("unique_id=%s" % m.group(3), "unique_id=%s" % old_id)
                kept_nodes += 1
    open(new_path, "w", encoding="utf-8").write("\n".join(lines))
    print("Kept %d resource ids and %d node ids from %s" % (kept_ext, kept_nodes, old_path))


if __name__ == "__main__":
    main()
