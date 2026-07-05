# Changelog

## v0.5.0 - Stable (2026-07-05)

- Promoted the release candidate after successful three-player late-join,
  reconnect, death/revive, bag operation, and Forest/Caves validation.
- Verified the subscribed Steam Workshop build without observed errors or
  Better Inventory replication warnings.

- Added server-authoritative Quick Stack to Bag on a separate configurable
  hotkey (default `F7`). It only fills compatible stacks already present in the
  equipped bag and never starts a new item type there.
- Quick Stack skips manually and natively locked main-inventory slots, rejects
  active cursor items, works with a closed bag UI, and restores stack leftovers
  to their original slots.
- Successful Quick Stack operations play one local inventory-move sound; safe
  no-op requests remain silent.
- Refactored the inventory and bag sorting engine, RPC guards, and hotkey
  registration into a dedicated module without changing player-facing behavior.
- Added pure-Lua regression coverage for category, stack-size, condition,
  stable-tie, repeated-sort, and compact-mode ordering.
- Added server-authoritative sorting for the equipped bag on a separate,
  configurable hotkey (default `F6`). Bag sorting never intentionally moves
  items between the bag and main inventory.
- Bag sorting preserves container item restrictions, built-in locked items,
  deterministic condition ordering, stack merging, and transaction recovery.
- Added server-authoritative manual slot locks. Hover a main inventory slot and
  press the configurable lock key (default `L`) to reserve that slot during
  sorting; locks are saved with the player and restored after reload.
- Added a lock overlay and client/server lock-state synchronization.
- Made category sorting deterministic for otherwise equal items. Identical
  finite-use, fueled, armor, and perishable items sort from highest to lowest
  condition; equal-condition items preserve their original relative slot order.

## v0.2.7 - Multiplayer Core

- Replaced generic `extrabody1/2/3` identifiers with namespaced Better Inventory
  slot IDs to avoid collisions with other equipment-slot mods.
- Added replication contract checks for main inventory netvars, equipment netvars,
  player replicas, and late-attached classified entities.
- Added a client/server core protocol handshake that reports mismatched local mod
  builds during join.
- Added dedicated Bag-slot support to client-side `Has`, `HasItemWithTag`, and
  `FindItem` reads so remote clients see backpack contents consistently.
- Added a server-side sort RPC cooldown and per-player re-entrancy lock.
- Sort now rejects requests while loading or holding an active cursor item.
- Sort operations track removed items and restore any valid ownerless item after
  an error or failed placement.
- Existing v0.2.6 saves remain compatible because DST reloads equipment from each
  item's current `equippable.equipslot` instead of trusting the old save key.

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
