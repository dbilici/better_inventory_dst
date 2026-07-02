# Better Inventory - Developer Notes

## v0.2.2 hotfix note

DST's mod sandbox may not expose plain Lua globals such as `getmetatable`. Use `GLOBAL.getmetatable` whenever patching widget/class metatables. Also avoid writing marker fields into Klei class tables when a local upvalue flag is enough.

The InventoryBar patch now follows this pattern:

```lua
local mt = GLOBAL.getmetatable ~= nil and GLOBAL.getmetatable(self) or nil
local InventoryBarClass = mt ~= nil and mt.__index or nil
```

The rebuild patch flag is kept as:

```lua
local inventory_bar_rebuild_patched = false
```

This avoids both sandbox-global errors and potential readonly/class-table writes.

---

# Better Inventory - v0.2 Sort Core

This build merges the expanded inventory foundation with a first-pass inventory sorting system.

## Included

- 24-slot inventory foundation.
- 2 x 12 layout pass.
- Optional Bag / Armor / Accessory slots.
- Vanilla-only item slot rules.
- Configurable sort hotkey.
- Compact-only sort mode.
- Category sort mode.
- Optional stack merging during sort.
- Debug helper.

## Sort behavior

Sorting only touches the player's main inventory slots. It does not sort equipped items, backpack/container contents, chests or item bundles.

The hotkey sends a Mod RPC to the server. The actual item movement happens on the server inventory component.

## Suggested test order

1. Start a new local DST world with only this mod enabled.
2. Test inventory slots 16-24 with simple items.
3. Test backpack + armor + amulet together.
4. Put items in scattered slots and press the sort hotkey.
5. Test Compact Only mode.
6. Test Category Sort mode.
7. Test partial stack merging with items such as grass, twigs, rocks and food.
8. Test two-player multiplayer sync.
9. Test death/revival with Life Giving Amulet in the accessory slot.
10. Test Green Amulet recipe discount display.

## Known risk areas

- UI layout may need final position tuning in-game.
- Stack merging uses DST's stackable component API and should be tested with skinned items and perishables.
- Category detection is intentionally simple and may need tuning.
- Some modded bags/armors/amulets are not mapped yet.
