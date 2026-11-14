"""Skeleton: public API exists, behaviour not implemented yet (so tests fail on behaviour, not on import)."""


class ValidationError(ValueError):
    pass


class NothingToUndo(Exception):
    pass


class UndoFailed(Exception):
    pass


class UndoManager:
    def __init__(self, store, max_history=10):
        self.store = store

    def drop_item(self, name, qty):
        return self.store.drop_item(name, qty)   # no validation, no history

    def undo(self):
        raise NotImplementedError("undo not implemented")
