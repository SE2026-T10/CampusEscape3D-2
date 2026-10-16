#!/usr/bin/env python3
"""Expanded Library expansion, Phase 4: write the mission (objective graph) into
the existing scene, scenes/level/expanded_library.tscn, as a minimal text patch
(the level's builder is frozen; see cut_doorways.py).

Changes two existing nodes only:
  - Gameplay/ObjectiveManager: its `objectives` array becomes the Phase 4
    graph (tools/expanded/expansion/expansion_layout.gd MISSION_OBJECTIVES,
    copied below): mandatory objectives with prerequisites, optional ones.
  - Gameplay/ExitDoor (the loading dock): unlocked by the manuscript instead of
    the back gate (the back gate is now an optional shortcut); its prompt and
    message say so.
Approved by the owner (expansion Phase 4): the mission as proposed, the
ObjectiveManager extended with prerequisites and optional objectives,
escape through the loading dock or the storm drain.

Usage (from the project folder):  python3 tools/expanded/expansion/mission_x3.py [--dry-run]
Idempotent: running it again changes nothing.
"""
import re, sys

SCENE = "scenes/level/expanded_library.tscn"

# Same data as MISSION_OBJECTIVES in expansion_layout.gd (the suite checks they match).
OBJECTIVES = [
    {"id": "enter_library", "title": "Enter the library", "hint": "Go in through the main entrance.",
     "done": "Inside. The main doors locked behind you (night lockdown)"},
    {"id": "take_card", "requires": ["enter_library"], "title": "Take a staff access card",
     "hint": "Staff offices, upper floor: up the main stair (or the stacks stair), through the staff wing.",
     "done": "Staff access card taken: staff doors open while you carry it"},
    {"id": "find_toolkit", "requires": ["enter_library"], "title": "Find the tool kit",
     "hint": "Somewhere in the basement maintenance areas. The west service door in the main stacks leads down.",
     "done": "Tool kit found"},
    {"id": "open_panel", "requires": ["find_toolkit"], "title": "Open the archive power panel",
     "hint": "In the electrical room (east annex). Its cover is screwed shut.",
     "done": "Panel cover off: the breakers are exposed"},
    {"id": "restore_power", "requires": ["open_panel"], "title": "Restore power to the vault",
     "hint": "Set the breakers, then engage MAIN. Facilities pinned up a wiring chart somewhere in the service wing.",
     "done": "The archive vault has power"},
    {"id": "open_vault", "requires": ["take_card", "restore_power"], "title": "Open the archive vault",
     "hint": "The vault keypad is in the archive (through the Archive Front Gate, upper floor). The head archivist left a reminder of the code.",
     "done": "Vault open"},
    {"id": "take_manuscript", "requires": ["open_vault"], "title": "Retrieve the rare manuscript",
     "hint": "On the pedestal inside the vault.",
     "done": "Manuscript retrieved. Now get out: the main entrance, the loading dock or a hidden way"},
    {"id": "escape", "requires": ["take_manuscript"], "title": "Escape with the manuscript",
     "hint": "Three ways out, each needing something different: the main entrance (locked down; security has a master badge), the loading dock (its shutter needs power) or a hidden maintenance passage in the basement.",
     "done": "Escaped"},
    {"id": "unlock_shortcut", "requires": ["take_card"], "optional": True, "title": "Unlock the archive back gate (shortcut)",
     "hint": "East side of the archive hall. It only opens from inside the archive.",
     "done": "Back gate open: the staff stair leads down to the loading dock"},
    {"id": "drain_culvert", "optional": True, "hidden": True, "title": "Drain the storm culvert",
     "hint": "Pump room, basement. The pump room log explains the valves.",
     "done": "Culvert drained: the storm drain is a way out"},
    {"id": "security_locker", "optional": True, "hidden": True, "title": "Open the security locker",
     "hint": "Office 1, upper floor. The night rota mentions the combination.",
     "done": "Security locker open"},
]

# Expansion Phase 6 updated the texts (and the objective hints above) for the
# three escape routes; escape_x5.py adds the walk-through properties.
EXIT_PROPS = {
    "key_objective_id": '&"take_manuscript"',
    "locked_reason": '"You can\'t leave without the rare manuscript."',
    "locked_prompt": '"Loading dock exit (shutter down)"',
}


def q(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def objectives_block():
    entries = []
    for o in OBJECTIVES:
        lines = ['"done": ' + q(o["done"])]
        if o.get("hidden"):
            lines.append('"hidden": true')
        lines.append('"hint": ' + q(o["hint"]))
        lines.append('"id": &' + q(o["id"]))
        if o.get("optional"):
            lines.append('"optional": true')
        if "requires" in o:
            lines.append('"requires": [' + ", ".join(q(r) for r in o["requires"]) + "]")
        lines.append('"title": ' + q(o["title"]))
        entries.append("{\n" + ",\n".join(lines) + "\n}")
    return "objectives = Array[Dictionary]([" + ", ".join(entries) + "])"


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    start = text.index('[node name="ObjectiveManager" type="Node" parent="Gameplay"')
    begin = text.index("objectives = Array[Dictionary]([", start)
    end = text.index("}])", begin) + 3
    new_block = objectives_block()
    changed = text[begin:end] != new_block
    text = text[:begin] + new_block + text[end:]
    # ExitDoor properties.
    exit_start = text.index('[node name="ExitDoor" type="Area3D" parent="Gameplay"')
    exit_end = text.index("\n[", exit_start + 1)
    block = text[exit_start:exit_end]
    new = block
    for key, value in EXIT_PROPS.items():
        new, n = re.subn(r"^%s = .*$" % key, "%s = %s" % (key, value), new, flags=re.M)
        if n != 1:
            print("ExitDoor: expected one %s line" % key)
            return 1
    changed = changed or new != block
    text = text[:exit_start] + new + text[exit_end:]
    if dry:
        print("Dry run: %s" % ("would change the scene" if changed else "nothing to change"))
        return 0
    open(SCENE, "w", encoding="utf-8").write(text)
    print("%s %s" % ("Updated" if changed else "Unchanged:", SCENE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
