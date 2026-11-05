#!/usr/bin/env python3
"""Expanded Library, a staff-corridor guard (approved by the owner on 2026-10-31: "corridor
+ card office"): a minimal text patch of the existing scene,
maps/library/scenes/expanded_library.tscn.

Adds GuardStaff, an eighth guard, on the layout's planned loop P6 (expanded_layout.gd,
"Staff Corridor", never guarded until now) as P6_StaffCorridor: along the staff
corridor (z -11) between x 0.5 and 9.5, then into Office 2 to look over the card desk.
The loop keeps off the Office 1 door (x -3): the Staff Offices respawn is at the back of
Office 1. The guard is copied from GuardUpper (the upper floor's guard: same look,
detection tuning, expanded_security and checkpoint_snapshot), with fresh ids, and
waits 2.5 s at each point (the corridor guard's pace, as GuardService).

Usage (from the project folder):  python3 maps/library/tools/expansion/fixes_x26.py [--dry-run]
Idempotent: nothing changes when GuardStaff is already there.
"""
import random, re, sys

SCENE = "maps/library/scenes/expanded_library.tscn"
UY = 4.5
ROUTE = [(0.5, -11.0), (9.5, -11.0), (3.0, -17.5)]
WAIT = 2.5


def fmt(v):
    return "%g" % v


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    if 'name="GuardStaff"' in text:
        print("fixes_x26: nothing to change")
        return 0
    rng = random.Random(20261031)
    start = text.index('[node name="P5_UpperStacks" type="Node3D" parent="Guards"')
    end = text.index('[node name="P7_Archive" type="Node3D" parent="Guards"')
    block = text[start:end]
    block = block.replace("Guards/P5_UpperStacks", "Guards/P6_StaffCorridor").replace('"P5_UpperStacks"', '"P6_StaffCorridor"')
    block = block.replace("Guards/GuardUpper", "Guards/GuardStaff").replace('"GuardUpper"', '"GuardStaff"')
    block = block.replace('NodePath("../P5_UpperStacks")', 'NodePath("../P6_StaffCorridor")')
    block = block.replace('metadata/patrol_id = "P5"', 'metadata/patrol_id = "P6"')
    block = block.replace("debug_color = Color(0.7, 0.6, 1, 1)", "debug_color = Color(0.95, 0.75, 0.35, 1)")
    block = re.sub(r"unique_id=\d+", lambda m: "unique_id=%d" % rng.randint(10**8, 2 * 10**9), block)
    first = block.index('[node name="Point0"')
    guard = block.index('[node name="GuardStaff"')
    script = re.search(r'script = ExtResource\("([^"]+)"\)', block[first:guard]).group(1)
    points = ""
    for n, (x, z) in enumerate(ROUTE):
        points += ('[node name="Point%d" type="Marker3D" parent="Guards/P6_StaffCorridor" unique_id=%d]\n'
                   'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nscript = ExtResource("%s")\nwait_time = %s\n\n') % (
            n, rng.randint(10**8, 2 * 10**9), fmt(x), fmt(UY), fmt(z), script, fmt(WAIT))
    block = block[:first] + points + block[guard:]
    # It starts at point 0 facing east (+x), along the corridor.
    block = re.sub(r'(\[node name="GuardStaff"[^\n]*\]\n)transform = [^\n]*\n',
                   lambda m: m.group(1) + "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, %s, %s, %s)\n" % (
                       fmt(ROUTE[0][0]), fmt(UY + 0.05), fmt(ROUTE[0][1])), block)
    at = text.index('[node name="P7_Archive" type="Node3D" parent="Guards"')
    text = text[:at] + block + text[at:]
    if not dry:
        open(SCENE, "w", encoding="utf-8").write(text)
    print("fixes_x26: GuardStaff on P6_StaffCorridor %s%s" % (ROUTE, " (dry run)" if dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
