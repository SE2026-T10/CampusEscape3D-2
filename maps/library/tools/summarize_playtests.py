#!/usr/bin/env python3
"""Summarise playtest_bot runs (runs.jsonl files) into a Markdown report.

    python3 maps/library/tools/summarize_playtests.py OUT.md runs1.jsonl [runs2.jsonl ...]

Groups runs by (route, profile, explore) and lists completion time, captures,
noticed / chased counts and waiting; then where captures and retreats happened,
by area (the layout's named areas), and which guard made the captures.
"""
import json, re, statistics, sys
from collections import Counter, defaultdict

U = 4.5
AREAS = [  # (zone, name, floor, x0, z0, x1, z1) from maps/library/tools/expanded_layout.gd
    ("A", "Lobby", "g", -12, 10, 12, 28), ("A", "Porch", "g", -5, 28, 5, 34),
    ("B", "Main Stacks", "g", -36, -28, -12, 10), ("B", "Browsing Hall", "g", -36, 10, -12, 28),
    ("C", "Reading Hall", "g", -12, -14, 12, 10), ("C", "Study rooms", "g", -12, -28, 12, -14),
    ("D", "Service Corridor", "g", 12, -28, 17, 28), ("D", "Book Processing", "g", 17, -28, 36, -6),
    ("D", "Storage", "g", 17, -6, 36, 12), ("D", "Loading Dock", "g", 17, 12, 36, 28),
    ("E", "Upper Stacks", "u", -36, -28, -6, 10), ("E", "Staff Balcony", "u", -6, -8, 12, 10),
    ("E", "Staff Corridor", "u", -6, -14, 12, -8), ("E", "Offices", "u", -6, -28, 12, -14),
    ("F", "Archive Hall", "u", 12, -18, 28, -6), ("F", "Archive Stacks", "u", 12, -28, 28, -18),
    ("F", "Vault", "u", 28, -28, 36, -18), ("F", "Alcove", "u", 28, -18, 36, -12),
    ("F", "Staff Stair Landing", "u", 30, -12, 36, -6),
]

def area(x, y, z):
    fl = "u" if y > 3.5 else "g"
    if 0.5 < y < 3.5:
        return "a stair"
    for zone, name, f, x0, z0, x1, z1 in AREAS:
        if f == fl and x0 <= x <= x1 and z0 <= z <= z1:
            return f"{zone} · {name}"
    return "?"

def parse(p):
    m = re.match(r"\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)", p)
    return tuple(float(v) for v in m.groups()) if m else None

def clock(t):
    return f"{int(t) // 60}:{int(t) % 60:02d}"

runs = []
for path in sys.argv[2:]:
    with open(path) as f:
        runs += [json.loads(l) for l in f if l.strip()]
groups = defaultdict(list)
for r in runs:
    groups[(r["route"], r["profile"], "explore" if r["explore"] else "direct")].append(r)
out = [f"{len(runs)} runs (layout {runs[0]['layout'] if runs else '?'}). Times are game time from the spawn and include a seeded 0–40 s pause at the start (the player looking around; it also varies where the guards are); 'active time' leaves that pause out. 'Noticed' counts the times the detection UI showed a guard seeing the player.", "",
       "| Route | Profile | Knowledge | Runs | Completed | Time median (min–max) | Active time median | Captures per run (total) | Noticed (median) | Chased (total) | Waiting (median) | Stalls |",
       "|---|---|---|---|---|---|---|---|---|---|---|---|"]
for key in sorted(groups):
    g = groups[key]
    done = [r for r in g if r["completed"]]
    times = [r["time_s"] for r in done]
    caps = [len(r["captures"]) for r in g]
    active = [r["time_s"] - r.get("start_delay_s", 0.0) for r in done]
    out.append("| %s | %s | %s | %d | %d | %s | %s | %.1f (%d) | %d | %d | %ds | %d |" % (key[0], key[1], key[2], len(g), len(done),
        f"{clock(statistics.median(times))} ({clock(min(times))}–{clock(max(times))})" if times else "—",
        clock(statistics.median(active)) if active else "—",
        statistics.mean(caps), sum(caps), statistics.median([r["noticed"] for r in g]), sum(r["chased"] for r in g),
        statistics.median([r["wait_s"] for r in g]), sum(1 for r in g if r["stalled"])))
cap_area, cap_guard, cap_obj, retreat_area = Counter(), Counter(), Counter(), Counter()
for r in runs:
    for c in r["captures"]:
        p = parse(c["at"])
        cap_area[area(*p) if p else "?"] += 1
        cap_guard[c["guard"]] += 1
        cap_obj[c["objective"]] += 1
    for e in r["events"]:
        if " retreat at " in e:
            p = parse(e.split(" retreat at ")[1])
            if p:
                retreat_area[area(*p)] += 1
out += ["", "**Captures by area:** " + (", ".join(f"{k} {v}" for k, v in cap_area.most_common()) or "none"),
        "", "**Captures by guard:** " + (", ".join(f"{k} {v}" for k, v in cap_guard.most_common()) or "none"),
        "", "**Captures by objective:** " + (", ".join(f"{k} {v}" for k, v in cap_obj.most_common()) or "none"),
        "", "**Where the player had to back off (noticed or in a guard's view):** " + (", ".join(f"{k} {v}" for k, v in retreat_area.most_common()) or "none"), ""]
open(sys.argv[1], "w").write("\n".join(out))
print("\n".join(out))
