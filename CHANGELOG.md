# Changelog

## v0.2.6 - Debug Baseline

- Replaced the late inventory constructor/netvar patches with one early
  `GetMaxItemSlots` wrapper so server inventory, client replica, HUD, and
  `inventory_classified` all construct with 24 slots.
- Restored backpack overflow behavior for bags equipped in the separate Bag slot.
- Emits the vanilla `setoverflow` event when a dedicated-slot bag is equipped so
  the HUD rebuilds its backpack container.
- Uses vanilla `Inventory:SwapEquipment` for mannequin swaps to prevent restricted
  equipment from becoming ownerless.
- Sorting now leaves locked-slot items in place and skips their occupied slots.
- Stack merging now checks the full vanilla `CanStackWith` contract first.
- Inventory UI Scale now scales the shared inventory root instead of individual
  slots, keeping item tiles and stack counters aligned.

## v0.2.5 - UI + Inventory Slot Hotfix

- Fixed slots 16-24 being visible but not accepting items.
- Added a constructor-time inventory max slot patch instead of post-init writes.
- Restored a fitted custom background around the compact 2 x 12 layout.
- Keeps `bgcover` hidden to avoid the long vanilla strip stretching across the screen.
- Background is now scaled from the actual slot bounds instead of a hardcoded full-screen scale.


## v0.2.4 - UI Safe Layout

- Fixed the v0.2.3 UI overlap issue by removing per-slot scaling.
- Hid the old single-row inventory background because it stretches across the screen and does not fit the 2 x 12 grid.
- Increased inventory slot spacing to vanilla-safe values.
- Moved equipment slots farther right into a separated 3 x 2 block.
- Sort and inventory item movement logic unchanged.


## v0.2.3 - UI Hotfix

- Fixed the 2 x 12 inventory layout growing downward off-screen.
- New 2-row layout now grows upward from the bottom HUD:
  - slots 1-12 on the upper row
  - slots 13-24 on the lower row
- Reduced horizontal spread by adding a configurable UI scale.
- Reduced background stretching; the background should no longer cover the full screen width.
- Kept the working sort / item movement logic from v0.2.2.

## v0.2.2 - Metatable Hotfix

- Fixed startup crash: `attempt to call global 'getmetatable' (a nil value)`.
- InventoryBar patch uses `GLOBAL.getmetatable`.
- InventoryBar rebuild patch flag is a local upvalue.

## v0.2.1 - Readonly Hotfix

- Fixed startup crash: `Cannot change read only property`.
- Removed direct writes to readonly inventory component properties.
