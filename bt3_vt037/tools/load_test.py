"""Load harness: 200 concurrent drop+undo tasks. Storage latency is SIMULATED (sleep); no real game server/disk/network."""
import random, statistics, sys, threading, time
from concurrent.futures import ThreadPoolExecutor
from campus.inventory import InventoryStore
from campus.undo import UndoManager

N, TARGET_P95 = 200, 5.0

class SlowStore(InventoryStore):
    def __init__(self, items, lat): super().__init__(items); self.lat = lat
    def drop_item(self, n, q): time.sleep(self.lat()); return super().drop_item(n, q)
    def restore(self, s): time.sleep(self.lat()); return super().restore(s)

def pct(xs, p): xs = sorted(xs); return xs[min(len(xs) - 1, int(round(p / 100 * len(xs) + 0.5)) - 1)]

def scenario(name, make_mgr, lat_fn, check_state=True):
    rng = random.Random(37); start = threading.Barrier(N); lats = []; errs = []
    def task(i):
        m = make_mgr(i)
        start.wait(); t0 = time.perf_counter()
        try:
            before = m.store.snapshot(); m.drop_item("coin", 1); m.undo()
            if check_state and m.store.snapshot() != before: errs.append(i)  # only valid when store is not shared
        except Exception as e: errs.append(repr(e))
        lats.append(time.perf_counter() - t0)
    with ThreadPoolExecutor(N) as ex: list(ex.map(task, range(N)))
    p95 = pct(lats, 95)
    print(f"{name}\n  n={len(lats)} errors={len(errs)} p50={statistics.median(lats):.3f}s p95={p95:.3f}s p99={pct(lats,99):.3f}s max={max(lats):.3f}s"
          f"  -> p95 {'<=' if p95 <= TARGET_P95 else '>'} {TARGET_P95}s: {'PASS' if p95 <= TARGET_P95 else 'FAIL'}")

r = random.Random(1)
# A: one manager per player, storage latency 20-60 ms per op (realistic design: no shared lock)
scenario("A: per-player manager, 20-60ms/op", lambda i: UndoManager(SlowStore({"coin": 5}, lambda: r.uniform(.02, .06))), None)
# B: ALL players share one manager (single RLock held during I/O), 15 ms/op -> worst-case design
shared = UndoManager(SlowStore({"coin": 99}, lambda: 0.015), max_history=1000)
scenario("B: single shared manager, 15ms/op (lock held during I/O)", lambda i: shared, None, check_state=False)
