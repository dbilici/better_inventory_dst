# Changelog

## Unreleased

- Added an in-game sort-order panel on a configurable hotkey (default `F8`).
- Added Default, Combat, Building, Survivor, and best-effort Anti Drop presets.
- Presets are independent editable tabs: switching preserves drafts, Reset Tab
  affects only the active tab, and Apply All persists every tab.
- Category order is player-specific, server-validated, and persistent across
  save/reload and reconnect.
- The active preset applies to main-inventory and equipped-bag sort.
- Duplicate host-default priorities fall back to the stable category order.
- Corrected core resource and light classification where broad edible, fuel,
  burnable, or weapon components previously put items in misleading categories.
- Craftable items now use DST's native Regular crafting-filter membership as
  the primary category source, with deterministic precedence for overlapping
  filters and fallback rules for non-craftable loot/resources.
- Bumped the multiplayer core protocol to 5 for sort-preference RPCs.
- Sorting now precomputes per-item sort keys. This keeps the comparator a
  valid strict order when condition-tracked and condition-less copies of the
  same item mix (previously the sort could abort), treats a missing condition
  as pristine, and stops re-classifying items on every comparison.
- Sort, bag sort, and Quick Stack cooldowns are tracked per operation, so for
  example sorting and then quick stacking within the cooldown window no longer
  silently drops the second request. Re-entrancy is still guarded across all
  operations.
- Sort-order RPCs and the panel hotkey are now registered only when main or bag
  sorting is enabled, so Quick Stack-only configurations do not expose a dead
  panel path.
- Main-inventory and equipped-bag sort now play the same local inventory-move
  feedback sound as Quick Stack, but only when the operation actually changes
  item positions or stack sizes.
- Slot lock toggles and successful sort-order Apply actions now play a small
  local feedback sound for the requesting player.
- Added a per-player sort-order panel toggle that lets the main inventory sort
  hotkey also sort the equipped bag in the same server-authoritative request.
- Changed the default active hotkeys to `F7` for sort and `F8` for the
  sort-order panel. Separate bag-only sort and Quick Stack remain configurable
  but no longer register active default hotkeys.
- The sort-order panel's open request and Apply All are rate limited
  independently, so a fast Apply can no longer be silently dropped by the
  preceding panel-open request.
- The GARDENING crafting filter now maps to Tools instead of Food, so watering
  cans, hoes, and other farming gear sort with tools.
- Category priority validation derives its bounds from the category list
  instead of a hardcoded count.

## v0.5.0 - Stable (2026-07-05)

- Promoted the release candidate after successful three-player late-join,
  reconnect, death/revive, bag operation, and Forest/Caves validation.
- Verified the subscribed Steam Workshop build without observed errors or
  Pack & Sort replication warnings.

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

- Replaced generic `extrabody1/2/3` identifiers with namespaced Pack & Sort
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
