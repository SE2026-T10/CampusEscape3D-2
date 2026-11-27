#!/usr/bin/env python3
"""Rebuilds the Expanded Library's level scene and navmesh from source, in order:

  1. maps/library/tools/build_expanded_graybox.gd   the v4 level from expanded_layout.gd
  2. the expansion's text patches of that scene, in the order they were made:
       cut_doorways.py (Phase 2), add_expansion_instance.py (Phase 2),
       enable_items.py (Phase 3), mission_x3.py (Phase 4), security_x4.py (Phase 5),
       escape_x5.py (Phase 6), then fixes_x7 ... in number order (.gd or .py)
  3. bake_navmesh.gd                               the navmesh of the level and the expansion
  4. keep_ids.py                                   node and resource ids as in the saved scene

The expansion sub-scene (expanded_library_expansion.tscn) is an input here: build it
first with maps/library/tools/expansion/build_expansion.gd when its source changed.

  python3 maps/library/tools/rebuild_level.py            rebuild in place (the saved scene
                                                          and navmesh are overwritten)
  python3 maps/library/tools/rebuild_level.py --check    rebuild, compare with the saved
                                                          files, put the saved files back;
                                                          exit 1 if they differ (CI)
  ... --check --out=DIR                                  also keep the rebuilt files in DIR

Needs $GODOT (the Godot 4.7.2 executable). Run from the project folder.
Builder cleanup, approved by the owner on 2026-10-31: before this script the level
could only be changed by hand-run patches, and two of its steps (the Expansion
instance and the door-frame fix) were not scripted at all.
"""
import difflib, glob, os, re, shutil, subprocess, sys, tempfile

SCENE = "maps/library/scenes/expanded_library.tscn"
NAVMESH = "maps/library/resources/expanded_library_navmesh.tres"
TOOLS = "maps/library/tools"
PY_PATCHES = ["cut_doorways.py", "add_expansion_instance.py", "enable_items.py", "mission_x3.py",
              "security_x4.py", "escape_x5.py"]
# The builder writes an empty leaf_open_angles on doors without leaves; the saved scene,
# made before that property existed, has none. Both mean the same (it is the default).
DEFAULT_LINES = re.compile(r"^leaf_open_angles = PackedFloat32Array\(\)\n", re.M)


def run(cmd):
    out = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    last = [l for l in out.stdout.splitlines() if l.strip()][-1:] or [""]
    print("  %s: exit %d  %s" % (os.path.basename(cmd[1] if cmd[0] == "python3" else cmd[-1]), out.returncode, last[0][:120]))
    if out.returncode != 0 or "SCRIPT ERROR" in out.stdout or "Parse Error" in out.stdout:
        print(out.stdout[-3000:])
        sys.exit("rebuild_level: step failed: %s" % " ".join(cmd))
    return out.stdout


FLOATS = re.compile(r"^(\w+ = PackedFloat32Array\()(.*)\)$")


def same_line(x, y):
    """Equal, or float arrays equal to within 0.1 mm: the door-frame fix was typed into
    the saved scene by hand (-4.06), the builder computes it in float32 (-4.0600004)."""
    if x == y:
        return True
    mx, my = FLOATS.match(x), FLOATS.match(y)
    if not (mx and my and mx.group(1) == my.group(1)):
        return False
    vx, vy = mx.group(2).split(", "), my.group(2).split(", ")
    return len(vx) == len(vy) and all(abs(float(u) - float(v)) <= 1e-4 for u, v in zip(vx, vy))


def same(a, b):
    return len(a) == len(b) and all(same_line(x, y) for x, y in zip(a, b))


def fix_number(path):
    return int(re.search(r"fixes_x(\d+)\.(gd|py)$", path).group(1))


def rebuild(godot, old_scene):
    gd = lambda script: run([godot, "--headless", "--path", ".", "--script", "res://" + script])
    print("rebuild_level: builder")
    gd(TOOLS + "/build_expanded_graybox.gd")
    print("rebuild_level: patches")
    for p in PY_PATCHES:
        run(["python3", TOOLS + "/expansion/" + p])
    fixes = glob.glob(TOOLS + "/expansion/fixes_x*.gd") + glob.glob(TOOLS + "/expansion/fixes_x*.py")
    for f in sorted(fixes, key=fix_number):
        if f.endswith(".py"):
            run(["python3", f])
        else:
            gd(f)
    print("rebuild_level: navmesh")
    gd(TOOLS + "/expansion/bake_navmesh.gd")
    text = open(SCENE, encoding="utf-8").read()
    open(SCENE, "w", encoding="utf-8").write(DEFAULT_LINES.sub("", text))
    run(["python3", TOOLS + "/expansion/keep_ids.py", old_scene, SCENE])


def main():
    godot = os.environ.get("GODOT")
    if not godot:
        sys.exit("rebuild_level: set GODOT to the Godot executable")
    check = "--check" in sys.argv
    keep = tempfile.mkdtemp(prefix="rebuild_level_")
    saved = {p: os.path.join(keep, os.path.basename(p)) for p in (SCENE, NAVMESH)}
    for p, copy in saved.items():
        shutil.copyfile(p, copy)
    try:
        rebuild(godot, saved[SCENE])
        if not check:
            print("rebuild_level: wrote %s and %s" % (SCENE, NAVMESH))
            return
        out = next((a[len("--out="):] for a in sys.argv if a.startswith("--out=")), "")
        if out:
            os.makedirs(out, exist_ok=True)
            for p in saved:
                shutil.copyfile(p, os.path.join(out, os.path.basename(p)))
        bad = []
        for p, copy in saved.items():
            a = open(copy, encoding="utf-8").read().splitlines()
            b = open(p, encoding="utf-8").read().splitlines()
            if not same(a, b):
                diff = list(difflib.unified_diff(a, b, "saved/" + p, "rebuilt/" + p, n=0, lineterm=""))
                bad.append(p)
                print("\n".join(diff[:40]))
                print("  ... %d changed lines in %s" % (sum(1 for l in diff if l[:1] in "+-") - 2, p))
        if bad:
            print("rebuild_level: DRIFT. The saved files differ from a rebuild from source: %s" % ", ".join(bad))
            print("Change the level through its source (layout, builder, a new patch script), not by hand.")
            sys.exit(1)
        print("rebuild_level: CHECK PASSED (the saved scene and navmesh equal a rebuild from source)")
    finally:
        if check:
            for p, copy in saved.items():
                shutil.copyfile(copy, p)
        shutil.rmtree(keep, ignore_errors=True)


if __name__ == "__main__":
    main()
