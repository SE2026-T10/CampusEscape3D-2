"""Deliberate-bug experiment: 'swallow exception and return default data'. Mutants live only in a temp copy."""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATTERN = sys.argv[1] if len(sys.argv) > 1 else "test*.py"

MUTANTS = {
    "M1 undo swallows restore error, returns current data":
        ('raise UndoFailed("undo failed; state unchanged") from exc', 'return self.store.snapshot()'),
    "M2 drop swallows over-drop error, returns current data":
        ('raise ValidationError("cannot drop more than owned")', 'return dict(self.store.items)'),
    "M3 qty validation swallows error, defaults qty=1":
        ('raise ValidationError("invalid quantity")', 'return 1'),
    "M4 name validation swallows error, defaults name":
        ('raise ValidationError("invalid item name")', 'return "unnamed"'),
}

def run(src_dir):
    env = dict(os.environ, PYTHONPATH=src_dir)
    p = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", os.path.join(ROOT, "tests"), "-p", PATTERN],
                       env=env, capture_output=True, text=True)
    return p.returncode, p.stderr

rc, _ = run(os.path.join(ROOT, "src"))
print(f"original code with {PATTERN}: {'PASS' if rc == 0 else 'FAIL'}")
killed = 0
for name, (old, new) in MUTANTS.items():
    tmp = tempfile.mkdtemp()
    shutil.copytree(os.path.join(ROOT, "src"), os.path.join(tmp, "src"))
    f = os.path.join(tmp, "src", "campus", "undo.py")
    s = open(f).read(); assert old in s, name
    open(f, "w").write(s.replace(old, new))
    rc, err = run(os.path.join(tmp, "src"))
    status = "KILLED" if rc != 0 else "SURVIVED"
    killed += rc != 0
    who = ",".join(sorted(set(re.findall(r"(?:FAIL|ERROR): (test_\w+)", err))))
    print(f"{name:62s} {status:9s} {who}")
    shutil.rmtree(tmp)
print(f"mutation score: {killed}/{len(MUTANTS)}")
