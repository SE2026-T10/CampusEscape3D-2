"""Flaky-risk probe: random order, repeated runs, parallel runs, thread-heavy test repeated."""
import os, random, subprocess, sys, unittest
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "src")); sys.path.insert(0, os.path.join(ROOT, "tests"))

def flat(s):
    for t in s:
        yield from flat(t) if isinstance(t, unittest.TestSuite) else [t]

def one_run(seed):
    tests = list(flat(unittest.defaultTestLoader.discover(os.path.join(ROOT, "tests"))))
    random.Random(seed).shuffle(tests)                               # order / shared-state risk
    r = unittest.TextTestRunner(stream=open(os.devnull, "w")).run(unittest.TestSuite(tests))
    return r.wasSuccessful()

fails = [s for s in range(200) if not one_run(s)]
print(f"[order] 200 random-order runs, failures: {len(fails)}")
with ThreadPoolExecutor(8) as ex:                                    # concurrency risk
    res = list(ex.map(one_run, range(1000, 1100)))
print(f"[parallel] 100 runs in 8 threads, failures: {res.count(False)}")
import test_undo_contract_v2 as v2
def load(): return unittest.defaultTestLoader.loadTestsFromName("HistoryAndInvariants.test_TC16_concurrent_drops_and_undos_are_atomic", v2)
bad = sum(not unittest.TextTestRunner(stream=open(os.devnull, "w")).run(load()).wasSuccessful() for _ in range(300))
print(f"[thread test] TC16 repeated 300x, failures: {bad}")
import re
src = open(os.path.join(ROOT, "tests", "test_undo_contract_v2.py")).read() + open(os.path.join(ROOT, "tests", "test_undo_contract_v1.py")).read()
print("[static] time/sleep/network/unseeded random in tests:", bool(re.search(r"time\.|sleep|socket|urllib|random\.random|random\.choice", src)))
