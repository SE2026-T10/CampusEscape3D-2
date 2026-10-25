#!/usr/bin/env python3
"""Expanded Library expansion, Phase 6: escape routes and checkpoints, as a
minimal text patch of the existing scene, maps/library/scenes/expanded_library.tscn
(the level's builder is frozen; see cut_doorways.py).

  - Every guard under Guards gets `checkpoint_snapshot = true` (checkpoints
    store and restore its position and patrol progress; tutorial guards keep
    the default).
  - Gameplay/ExitDoor (the loading dock, escape route B) becomes a walk-through
    exit: it opens once SERVICE EXIT has power and the shutter control (in
    Expansion/Gameplay/Escape) unlocks it; the player escapes by walking into
    Expansion/Gameplay/Escape/DockExitTrigger with the manuscript. Its route
    is recorded as "Loading dock".
Approved by the owner (expansion Phase 6): the three routes as proposed,
walk-through triggers, guard positions in the checkpoint snapshot.

Usage (from the project folder):  python3 maps/library/tools/expansion/escape_x5.py [--dry-run]
Idempotent: running it again changes nothing.
"""
import re, sys

SCENE = "maps/library/scenes/expanded_library.tscn"
EXIT_PROPS = [
    ("walk_through", "true"),
    ("trigger_path", 'NodePath("../../Expansion/Gameplay/Escape/DockExitTrigger")'),
    ("panel_path", 'NodePath("../../NavigationRegion3D/Ground/D_ServiceCorridor/ExitDoorPanel")'),
    ("needs_unlock", "true"),
    ("unlock_reason", '"The dock shutter is down. Free its release (tool kit), then press OPEN on the shutter control."'),
    ("route_id", '&"loading_dock"'),
    ("route_name", '"Loading dock"'),
    ("open_sign", '"DOCK · OPEN"'),
    ("locked_reason", '"You can\'t leave without the rare manuscript."'),
    ("locked_prompt", '"Loading dock exit (shutter down)"'),
]


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    original = text
    # 1. checkpoint_snapshot on every guard root block under Guards.
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if re.match(r'^\[node name="Guard\w+" parent="Guards" .*instance=ExtResource', line):
            j = i + 1
            block = []
            while j < len(lines) and not lines[j].startswith("["):
                block.append(lines[j])
                j += 1
            if "checkpoint_snapshot = true" not in block:
                k = next((n for n, l in enumerate(block) if l.startswith("expanded_security = ")), 0)
                block.insert(k + 1, "checkpoint_snapshot = true")
            out.extend(block)
            i = j
            continue
        i += 1
    text = "\n".join(out)
    # 2. The dock exit.
    start = text.index('[node name="ExitDoor" type="Area3D" parent="Gameplay"')
    end = text.index("\n[", start + 1)
    block = text[start:end]
    new = block
    for key, value in EXIT_PROPS:
        prop = "%s = %s" % (key, value)
        if re.search(r"^%s = " % key, new, flags=re.M):
            new = re.sub(r"^%s = .*$" % key, lambda m: prop, new, flags=re.M)
        else:
            new = new.replace("door_mesh = ", prop + "\ndoor_mesh = ", 1)
    text = text[:start] + new + text[end:]
    changed = text != original
    if dry:
        print("Dry run: %s" % ("would change the scene" if changed else "nothing to change"))
        return 0
    open(SCENE, "w", encoding="utf-8").write(text)
    print("%s %s" % ("Updated" if changed else "Unchanged:", SCENE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
