#!/usr/bin/env python3
"""Expanded Library expansion, Phase 5: security changes to the existing scene,
maps/library/scenes/expanded_library.tscn, as a minimal text patch (the level's
builder is frozen; see cut_doorways.py).

  - Every guard under Guards gets `expanded_security = true` (the Expanded
    Library's hiding, search and alarm rules; tutorial guards keep the default).
  - A seventh guard, GuardBasement, with its route P9_Basement (5 points along
    the service tunnel and the east basement), copied from GuardLobby's
    blocks (same look and detection tuning), added at the end of Guards.
  - Gameplay/ExitDoor (the loading dock) needs the service exit circuit:
    power_circuit, no_power_reason, no_power_sign.
Approved by the owner (expansion Phase 5): the three circuits with the service
power trade-off, the rules for the Expanded Library only, one basement guard.

Usage (from the project folder):  python3 maps/library/tools/expansion/security_x4.py [--dry-run]
Idempotent: running it again changes nothing.
"""
import re, sys, random

SCENE = "maps/library/scenes/expanded_library.tscn"
BF = -4.0
ROUTE = [(-30.0, -25.0), (-10.0, -24.8), (14.0, -25.0), (39.0, -21.0), (39.0, -10.0)]
EXIT_PROPS = [
    'power_circuit = &"service_exit"',
    'no_power_reason = "The dock shutter has no power: switch SERVICE EXIT on in the electrical room."',
    'no_power_sign = "SHUTTER · NO POWER"',
]


def fmt(v):
    return ("%g" % v)


def main():
    dry = "--dry-run" in sys.argv
    text = open(SCENE, encoding="utf-8").read()
    original = text
    rng = random.Random(20261016)
    # 1. expanded_security on every guard root block under Guards.
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
            if 'expanded_security = true' not in block:
                # after patrol_route (or first line)
                k = next((n for n, l in enumerate(block) if l.startswith("patrol_route = ")), 0)
                block.insert(k + 1, "expanded_security = true")
            out.extend(block)
            i = j
            continue
        i += 1
    text = "\n".join(out)
    # 2. The basement guard, copied from P1_Lobby + GuardLobby.
    if 'name="GuardBasement"' not in text:
        start = text.index('[node name="P1_Lobby" type="Node3D" parent="Guards"')
        end = text.index('[node name="P2_MainStacks" type="Node3D" parent="Guards"')
        block = text[start:end]
        block = block.replace("Guards/P1_Lobby", "Guards/P9_Basement").replace('"P1_Lobby"', '"P9_Basement"')
        block = block.replace("Guards/GuardLobby", "Guards/GuardBasement").replace('"GuardLobby"', '"GuardBasement"')
        block = block.replace('NodePath("../P1_Lobby")', 'NodePath("../P9_Basement")')
        block = block.replace('metadata/zone_id = "A"', 'metadata/zone_id = "G"').replace('metadata/patrol_id = "P1"', 'metadata/patrol_id = "P9"')
        # fresh unique ids
        block = re.sub(r"unique_id=\d+", lambda m: "unique_id=%d" % rng.randint(10**8, 2 * 10**9), block)
        # route points: replace the 4 point blocks with 5
        first = block.index('[node name="Point0"')
        guard = block.index('[node name="GuardBasement"')
        points = ""
        for n, (x, z) in enumerate(ROUTE):
            points += ('[node name="Point%d" type="Marker3D" parent="Guards/P9_Basement" unique_id=%d]\n'
                       'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nscript = ExtResource("%s")\n\n') % (
                n, rng.randint(10**8, 2 * 10**9), fmt(x), fmt(BF), fmt(z),
                re.search(r'script = ExtResource\("([^"]+)"\)', block[first:guard]).group(1))
        block = block[:first] + points + block[guard:]
        # the guard starts at point 0, facing east (+x)
        block = re.sub(r'(\[node name="GuardBasement"[^\n]*\]\n)transform = [^\n]*\n',
                       lambda m: m.group(1) + "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, %s, %s, %s)\n" % (
                           fmt(ROUTE[0][0]), fmt(BF + 0.05), fmt(ROUTE[0][1])), block)
        insert_at = text.index('[node name="Gameplay" type="Node3D" parent="."')
        text = text[:insert_at] + block + text[insert_at:]
    # 3. The loading dock needs service power.
    exit_start = text.index('[node name="ExitDoor" type="Area3D" parent="Gameplay"')
    exit_end = text.index("\n[", exit_start + 1)
    block = text[exit_start:exit_end]
    new = block
    for prop in EXIT_PROPS:
        key = prop.split(" = ")[0]
        if re.search(r"^%s = " % key, new, flags=re.M):
            new = re.sub(r"^%s = .*$" % key, prop, new, flags=re.M)
        else:
            new = new.replace('key_objective_id = ', prop + "\nkey_objective_id = ", 1)
    text = text[:exit_start] + new + text[exit_end:]
    changed = text != original
    if dry:
        print("Dry run: %s" % ("would change the scene" if changed else "nothing to change"))
        return 0
    open(SCENE, "w", encoding="utf-8").write(text)
    print("%s %s" % ("Updated" if changed else "Unchanged:", SCENE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
