"""Line coverage with stdlib trace (coverage.py unavailable offline). Branch coverage NOT measured."""
import os, sys, trace, unittest
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tr = trace.Trace(count=1, trace=0)
def go():
    s = unittest.defaultTestLoader.discover(os.path.join(ROOT, "tests"), pattern=(sys.argv[1] if len(sys.argv) > 1 else "test*.py"))
    unittest.TextTestRunner(stream=open(os.devnull, "w")).run(s)
tr.runfunc(go)
counts = tr.results().counts
for f in ("inventory.py", "undo.py"):
    p = os.path.join(ROOT, "src", "campus", f)
    exe = {l for l in trace._find_executable_linenos(p) if l > 0}  # line 0 = module docstring artifact
    hit = {l for (fn, l), c in counts.items() if fn == p and c}
    miss = sorted(exe - hit)
    print(f"{f:14s} lines {len(exe & hit)}/{len(exe)} = {100*len(exe & hit)/len(exe):.0f}%  missed: {miss}")
