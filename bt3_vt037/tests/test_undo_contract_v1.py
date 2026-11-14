"""Suite v1 (test-first, written BEFORE the patch): happy path + one negative + empty history.
Intentionally lacks a failure-path test; used later to show a surviving mutant."""
import unittest
from campus.inventory import InventoryStore
from campus.undo import UndoManager, ValidationError, NothingToUndo


def make(items=None, **kw):
    return UndoManager(InventoryStore(items or {"key_card": 3, "flashlight": 1}), **kw)


class ContractV1(unittest.TestCase):
    def test_TC01_drop_then_undo_restores_exact_state(self):
        m = make(); before = m.store.snapshot()
        m.drop_item("key_card", 2)
        self.assertEqual(m.store.items["key_card"], 1)
        self.assertEqual(m.undo(), before)

    def test_TC02_drop_whole_stack_then_undo(self):
        m = make(); before = m.store.snapshot()
        m.drop_item("flashlight", 1)          # boundary qty == owned
        self.assertNotIn("flashlight", m.store.items)
        self.assertEqual(m.undo(), before)

    def test_TC03_empty_name_rejected_state_unchanged(self):
        m = make(); before = m.store.snapshot()
        with self.assertRaises(ValidationError):
            m.drop_item("", 1)
        self.assertEqual(m.store.snapshot(), before)

    def test_TC09_min_qty_one_accepted(self):
        m = make(); m.drop_item("key_card", 1)
        self.assertEqual(m.store.items["key_card"], 2)

    def test_TC11_undo_with_empty_history(self):
        m = make(); before = m.store.snapshot()
        with self.assertRaises(NothingToUndo):
            m.undo()
        self.assertEqual(m.store.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
