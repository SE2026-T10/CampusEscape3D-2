"""Undo for the risky 'drop inventory item' action (VT-037).

Contract
  pre : name is a non-blank str (<=32 chars); qty is an int (not bool) with 1 <= qty <= min(99, owned)
  post: drop applied exactly once and one snapshot pushed; undo() restores the exact pre-drop state
  inv : (I1) a rejected drop changes neither state nor history
        (I2) a failed undo changes neither state nor history and is reported, never swallowed
        (I3) every stored qty stays within 1..99
"""
import threading

MAX_NAME_LEN = 32
MAX_QTY = 99


class ValidationError(ValueError):
    pass


class NothingToUndo(Exception):
    pass


class UndoFailed(Exception):
    pass


def validate_name(name):
    if not isinstance(name, str) or not name.strip() or len(name) > MAX_NAME_LEN:
        raise ValidationError("invalid item name")
    return name


def validate_qty(qty):
    if isinstance(qty, bool) or not isinstance(qty, int) or qty < 1 or qty > MAX_QTY:
        raise ValidationError("invalid quantity")
    return qty


class UndoManager:
    def __init__(self, store, max_history=10):
        self.store = store
        self.max_history = max_history
        self._history = []
        self._lock = threading.RLock()

    def drop_item(self, name, qty):
        with self._lock:
            name = validate_name(name)
            qty = validate_qty(qty)
            owned = self.store.items.get(name, 0)
            if qty > owned:
                raise ValidationError("cannot drop more than owned")
            snap = self.store.snapshot()
            result = self.store.drop_item(name, qty)
            self._history.append(snap)
            if len(self._history) > self.max_history:
                self._history.pop(0)
            return result

    def undo(self):
        with self._lock:
            if not self._history:
                raise NothingToUndo("nothing to undo")
            snap = self._history[-1]
            try:
                self.store.restore(snap)
            except Exception as exc:
                raise UndoFailed("undo failed; state unchanged") from exc
            self._history.pop()
            return self.store.snapshot()
