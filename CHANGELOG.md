# Changelog

## v0.2.2 - Metatable Hotfix

- Fixed startup crash: `attempt to call global 'getmetatable' (a nil value)`.
- InventoryBar patch now uses `GLOBAL.getmetatable`.
- Removed the class-table marker flag for the InventoryBar rebuild patch; the patch flag is now a local upvalue to avoid readonly/class-table issues.
- Re-applies the 2 x 12 positioning pass after InventoryBar construction and rebuild.

## v0.2.1 - Readonly Hotfix

- Removed direct writes to readonly inventory component properties.
- Slot expansion now relies on `GetNumSlots` overrides and classified netvars.

# Changelog

## v0.2.1-readonly-hotfix

- Fixed a server-start crash: `Cannot change read only property` at `modmain.lua:204`.
- Removed the custom `self.maxslots` write from the inventory component post-init.
- Kept slot expansion through `Inventory:GetNumSlots()` / `inventory_replica:GetNumSlots()` overrides and `inventory_classified` netvar expansion.
- Changed internal widget/class patch flags to use `rawget` / `rawset` to avoid the same readonly issue later.
- Removed the non-essential `inst.wet_prefix` write from item prefab post-init for safer startup.


## 0.2.0-sort-core

- Added configurable inventory sorting.
- Added Sort Hotkey config: F5 / F6 / F7 / F8 / R / C / V.
- Added Sort Mode config:
  - Compact Only: preserves existing item order and closes empty gaps.
  - Category Sort: groups similar items, then sorts by prefab name.
- Added Merge Stacks on Sort config.
- Sort requests now run through a Mod RPC so item movement happens server-side.
- Quick Draw remains intentionally excluded.

## 0.1.0-clean-core

- Replaced the large extra-slot mod structure with a small local registry.
- Removed Quick Draw from the design.
- Added optional 24-slot inventory foundation.
- Added a conservative 2 x 12 inventory bar repositioning pass.
- Added optional Bag, Armor and Accessory equipment slots.
- Kept item compatibility vanilla-only for safer testing.
- Added Debug Mode: Off / Log Only / Chat + Log.
- Removed the huge modded prefab compatibility table from the active code.
- Removed experimental multi-equipment render logic from the active code.
- Reworked mannequin and punching bag compatibility to use the enabled slot list instead of hardcoded extra slots.

## Planned next

- Sort UI button near the inventory bar.
- Better final UI positioning/polish after in-game testing.
- Optional compatibility table for selected modded items.
