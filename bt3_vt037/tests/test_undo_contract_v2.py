"""Suite v2: adds boundary/negative, failure-path, history, invariant and concurrency contracts."""
import random, threading, unittest
from concurrent.futures import ThreadPoolExecutor
from campus.inventory import InventoryStore
from campus.undo import UndoManager, ValidationError, NothingToUndo, UndoFailed, MAX_NAME_LEN


def make(items=None, **kw):
    return UndoManager(InventoryStore(items if items is not None else {"key_card": 3, "flashlight": 1}), **kw)


class RejectedDropKeepsStateAndHistory(unittest.TestCase):
    """(I1) every rejected input leaves state AND history untouched, and raises (never returns a default)."""

    def assert_rejected(self, name, qty, items=None):
        m = make(items); before = m.store.snapshot()
        with self.assertRaises(ValidationError):
            m.drop_item(name, qty)
        self.assertEqual(m.store.snapshot(), before)
        with self.assertRaises(NothingToUndo):          # nothing was pushed to history
            m.undo()

    def test_TC04_blank_or_none_name(self):
        for bad in ("   ", None, 123):
            with self.subTest(name=bad):
                self.assert_rejected(bad, 1)

    def test_TC04b_blank_name_must_not_alias_another_item(self):
        self.assert_rejected("", 1, {"unnamed": 1, "key_card": 3})   # kills 'default name' mutant

    def test_TC05_qty_zero(self):
        self.assert_rejected("key_card", 0)

    def test_TC06_qty_negative(self):
        self.assert_rejected("key_card", -1)

    def test_TC07_qty_exceeds_owned(self):
        self.assert_rejected("key_card", 4)                          # owned+1 boundary

    def test_TC08_qty_wrong_type(self):
        for bad in (True, 1.0, "1", None):
            with self.subTest(qty=bad):
                self.assert_rejected("key_card", bad)

    def test_TC08b_qty_above_max(self):
        self.assert_rejected("coin", 100, {"coin": 500})              # MAX_QTY+1 even if owned

    def test_TC10_name_length_boundary(self):
        ok = "a" * MAX_NAME_LEN
        m = make({ok: 2}); m.drop_item(ok, 1)
        self.assertEqual(m.store.items[ok], 1)
        self.assert_rejected("a" * (MAX_NAME_LEN + 1), 1, {"a" * (MAX_NAME_LEN + 1): 2})

    def test_TC09b_max_qty_accepted(self):
        m = make({"coin": 99}); m.drop_item("coin", 99)
        self.assertEqual(m.store.items, {})
        self.assertEqual(m.undo(), {"coin": 99})


class FailingStore(InventoryStore):
    def restore(self, snap):
        raise IOError("disk error")


class FailurePath(unittest.TestCase):
    def test_TC12_restore_failure_is_reported_not_swallowed(self):
        m = UndoManager(FailingStore({"key_card": 3}))
        m.drop_item("key_card", 2); after_drop = m.store.snapshot()
        with self.assertRaises(UndoFailed) as cm:
            m.undo()
        self.assertIsInstance(cm.exception.__cause__, IOError)       # root cause preserved
        self.assertEqual(m.store.snapshot(), after_drop)             # (I2) state unchanged
        with self.assertRaises(UndoFailed):                          # history kept -> retry possible
            m.undo()


class HistoryAndInvariants(unittest.TestCase):
    def test_TC14_history_is_bounded(self):
        m = make({"coin": 50}, max_history=3)
        for _ in range(4):
            m.drop_item("coin", 1)
        for _ in range(3):
            m.undo()
        with self.assertRaises(NothingToUndo):
            m.undo()
        self.assertEqual(m.store.items["coin"], 49)                  # oldest drop was evicted

    def test_TC15_random_sequence_keeps_invariants_and_fully_undoes(self):
        rng = random.Random(1879)                                    # fixed seed -> deterministic
        init = {"coin": 99, "key_card": 5, "map": 1}
        m = make(dict(init), max_history=500); pushed = 0
        for _ in range(300):
            try:
                m.drop_item(rng.choice(["coin", "key_card", "map", "", "x"]), rng.choice([-1, 0, 1, 2, 5, 99, 100]))
                pushed += 1
            except ValidationError:
                pass
            self.assertTrue(all(1 <= q <= 99 for q in m.store.items.values()))   # (I3)
        for _ in range(pushed):
            m.undo()
        self.assertEqual(m.store.items, init)

    def test_TC16_concurrent_drops_and_undos_are_atomic(self):
        m = make({"coin": 99}, max_history=100)
        with ThreadPoolExecutor(50) as ex:
            list(ex.map(lambda _: m.drop_item("coin", 1), range(50)))
        self.assertEqual(m.store.items["coin"], 49)
        with ThreadPoolExecutor(50) as ex:
            list(ex.map(lambda _: m.undo(), range(50)))
        self.assertEqual(m.store.items["coin"], 99)


if __name__ == "__main__":
    unittest.main()
