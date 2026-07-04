# v0.5.0-rc1 validation

This release candidate freezes feature work and focuses on regression and
server/client invariants.

Pure sorting regression test:

```sh
lua tests/sorting_spec.lua
```

Known-fix regression check: place two full torches and one partially used torch
in a deliberate relative order, sort repeatedly, and verify that the full
torches remain ahead of the partial torch while equal-condition items retain
their relative order.

Manual slot-lock checks:

1. Hover an occupied slot and press `L`; verify the lock overlay appears and
   repeated sorts leave the item in that slot.
2. Lock an empty slot and verify sorting leaves it empty.
3. Press `L` again to unlock, then verify sorting may reuse the slot.
4. Save/reload and verify both occupied and empty slot locks are restored.
5. Confirm typing `L` in chat does not toggle a hovered slot.

Equipped bag-sort checks:

1. Equip a backpack containing mixed item categories and partial stacks, then
   press `F6`; verify only the bag contents are sorted and merged. Repeat while
   the bag UI is closed; server-side sorting should still work.
2. Confirm `F5` still sorts only the main inventory.
3. Hold an active cursor item and press `F6`; verify neither container changes.
4. Press `F6` with no equipped bag; verify there is no error or dropped item.
5. Test a restricted bag such as Seed Pack-It and verify every item remains in
   a valid bag slot.
6. Set both sort hotkeys to the same key and verify the bag hotkey is disabled
   with a warning instead of dispatching both operations.

Quick Stack to Bag checks:

1. Put a partial stack in the equipped bag and a matching stack in the main
   inventory; press `F7` and verify only the matching quantity moves and one
   inventory-move sound plays.
2. Fill the bag target nearly to capacity and verify leftovers return to the
   source inventory slot.
3. Verify an item type not already present in the bag does not move.
4. Lock a matching source slot with `L`; verify Quick Stack leaves it untouched.
5. Hold an active cursor item, remove the bag, and close the bag UI in separate
   runs; the first two cases must be safe no-ops and the closed bag must work.
6. Set `F7` as another sort hotkey and verify Quick Stack is disabled with a
   warning instead of dispatching two operations.
7. Press `F7` when nothing can move and verify no success sound plays.

Test matrix:

1. Host a world, fill slots 16-24, and connect a second client after the items
   already exist.
2. On both clients, move stacks between slots 1-24 and verify the other screen
   updates without ghost items.
3. Equip a backpack in the Bag slot and verify both clients can count, find,
   craft from, open, and close its contents.
4. Spam the sort hotkey; the server must accept at most one request per cooldown
   and must never duplicate, delete, or leave an item on the cursor.
5. Attempt sorting with an active cursor item and with a locked/cursed slot item.
6. Disconnect and reconnect the second client, then repeat inventory and bag reads.
7. Save/reload, die/revive, and travel Forest -> Caves -> Forest.
8. Search logs for `[Better Inventory][WARN]`; any replication-contract warning is
   a release blocker.

Expected debug success lines include `replication contract OK`, protocol `4`, and
slot count `24` on both server and client. Each joining client should also log
`Core protocol handshake OK`.

---

# v0.2.6 debug baseline test focus

This pass establishes a safer baseline before adding features:

1. Slot count is decided before inventory and classified prefabs are constructed.
2. A bag in the dedicated Bag slot remains the player's overflow container.
3. Sorting preserves items that are locked to a slot.
4. Mannequin swaps use DST's own restricted-item fallback behavior.

Test order:

1. Start a world with only Better Inventory enabled.
2. Fill and manually rearrange slots 16-24, then save/reload the world.
3. Equip a backpack in the Bag slot; open it, pick up items into it, craft from it,
   and unequip it while it contains items.
4. Test the Small, Compact, and Large UI scale settings after a HUD rebuild.
5. Sort a normal inventory and an inventory containing a locked/cursed item.
6. Swap normal and restricted equipment with a Sewing Mannequin.
7. Repeat slot, bag, and sort tests with a second client connected.

---

# v0.2.5 test focus

This build fixes two regressions from the UI-safe pass:

1. The second row was visible but slots 16-24 were not accepting items. The inventory component now gets `maxslots = 24` during construction through a wrapped `_ctor`, avoiding readonly post-init writes.
2. The background was hidden entirely. The mod now fits the uploaded `inventory_bg.tex` around the actual compact slot bounds.

Test order:

1. Start world.
2. Confirm the fitted background appears.
3. Put items directly into slots 16-24.
4. Move items from slots 1-15 into 16-24 manually.
5. Press sort hotkey and verify all 24 slots are still usable.

---

# Better Inventory - v0.2.4 UI Safe Layout

This build fixes the v0.2.3 UI overlap by using a conservative layout:

- 12 columns x 2 inventory rows.
- No per-slot scaling.
- Old stretched inventory background hidden.
- Equipment slots separated into a 3 x 2 block on the right.

The sort system and inventory movement logic are unchanged from v0.2.x.

## Test focus

1. Check whether stack counters overlap.
2. Check whether the bottom inventory row stays visible.
3. Check whether equipment slots overlap with inventory slots.
4. Confirm sort still works.

Next UI pass should create a real 2 x 12 background asset instead of trying to reuse the old single-row background.

---

# Better Inventory - v0.2.3 UI Hotfix

## What changed

The previous 2 x 12 UI centered both inventory rows around y=0. Since the DST inventory bar is anchored near the bottom of the screen, the lower row could fall below the visible area.

This version places the lower row at y=0 and the upper row above it. It also reduces horizontal spread with a configurable UI scale.

## Recommended test config

- Inventory Size: Expanded 24
- Inventory Layout: Compact 2 x 12
- Inventory UI Scale: Compact
- Inventory Sort: Enabled
- Sort Hotkey: F5

If the UI is still too wide, set Inventory UI Scale to Small.
