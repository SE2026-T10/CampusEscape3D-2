"""Baseline (characterization) model of the risky action: dropping an inventory item.
Stand-in for the Campus Escape 3D inventory module (real repo not accessible in sandbox)."""


class InventoryStore:
    def __init__(self, items=None):
        self.items = dict(items or {})

    def snapshot(self):
        return dict(self.items)

    def restore(self, snap):
        self.items = dict(snap)

    def drop_item(self, name, qty):
        # BASELINE BEHAVIOUR: no validation, can go negative, no undo
        self.items[name] = self.items.get(name, 0) - qty
        if self.items[name] == 0:
            del self.items[name]
        return dict(self.items)
