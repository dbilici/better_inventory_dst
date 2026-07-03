# v0.2.7 multiplayer core test focus

This pass freezes feature work and focuses on server/client invariants.

Known-fix regression check: place two full torches and one partially used torch
in a deliberate relative order, sort repeatedly, and verify that their relative
order remains unchanged.

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

Expected debug success lines include `replication contract OK`, protocol `1`, and
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
