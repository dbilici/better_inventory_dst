# Pack & Sort — Steam Workshop Copy

This file contains ready-to-paste copy and the release checklist for `v0.5.0`.
It is not loaded by the mod.

## Title

Pack & Sort

## Short description

Expanded inventory, dedicated equipment slots, deterministic sorting, manual
slot locks, bag sorting, and Quick Stack — with server-authoritative item
movement.

## Workshop description

[h1]Pack & Sort[/h1]

Pack & Sort expands and organizes the Don't Starve Together inventory
without moving item authority away from the server.

[h2]Features[/h2]

[list]
[*]Optional 24-slot main inventory with a compact 2 x 12 layout
[*]Separate optional Bag, Armor, and Accessory equipment slots
[*]Deterministic category sorting with optional stack merging
[*]Craftable-item categories derived from DST's native crafting filters
[*]In-game category order panel with persistent per-player preferences
[*]Default, Combat, Building, Survivor, and best-effort Anti Drop presets
[*]Per-player option for F7 to sort the equipped bag together with the inventory
[*]Independent sorting for the equipped bag, even while its UI is closed
[*]Persistent manual slot locks for items you want to keep in place
[*]Quick Stack into compatible stacks already present in the equipped bag
[*]Configurable hotkeys and inventory UI scale
[*]Server-side cooldowns, transaction guards, and item recovery
[/list]

[h2]Default controls[/h2]

[table]
[tr][th]Input[/th][th]Action[/th][/tr]
[tr][td]F7[/td][td]Sort the main inventory; optionally also sort the equipped bag[/td][/tr]
[tr][td]F8[/td][td]Open the category order panel[/td][/tr]
[tr][td]Hover a main slot + L[/td][td]Toggle that slot's sort lock[/td][/tr]
[/table]

All hotkeys can be changed in the mod configuration. Conflicting inventory
hotkeys are detected and the secondary action is disabled instead of running
two operations at once. Quick Stack and a separate bag-only sort key remain
configurable, but the default setup only uses F7 and F8.

[h2]Quick Stack behavior[/h2]

Quick Stack only fills compatible stacks that already exist in the equipped
bag. It does not introduce a new item type into the bag. Locked source slots
are skipped, and leftovers return to their original main-inventory slot.

[h2]Multiplayer[/h2]

This is an all-clients mod: the server and every joining player must install and
enable the same version. Inventory movement, sorting, locks, and Quick Stack are
validated by the server.

[h2]Validation[/h2]

Version 0.5.0 has passed automated sorting regression tests plus single-player,
host, dedicated-server, and three-player validation. Multiplayer coverage
includes late join, reconnect, death/revive, bag operations, and Forest/Caves
travel.

[h2]Compatibility[/h2]

Pack & Sort targets Don't Starve Together API version 10. Existing
v0.2.6+ saves remain compatible. Mods that replace the inventory HUD, change
the base inventory size, or redefine equipment slots may conflict.

[h2]Feedback and bug reports[/h2]

Please include the host and client logs, enabled mod list, world type, and exact
steps needed to reproduce the problem.

Source and issue tracker:
https://github.com/dbilici/dst-pack-sort

## Change notes

[h1]v0.5.0[/h1]

[list]
[*]Added Quick Stack to compatible stacks already present in the equipped bag.
[*]Added independent equipped-bag sorting that works with the bag UI closed.
[*]Added persistent manual main-inventory slot locks.
[*]Made condition and equal-item sorting deterministic across repeated sorts.
[*]Added server-side cooldown, re-entrancy, recovery, and protocol diagnostics.
[*]Added automated regression coverage for sorting and Quick Stack behavior.
[/list]

Validated with three players, including late join, reconnect, death/revive,
bag operations, and Forest/Caves travel.

## Workshop visibility policy

Keep all pre-1.0 builds **Friends Only** while features and compatibility are
still evolving. Switch to **Public** with the stable `v1.0.0` release.

## Preview and screenshot plan

Use a square preview image that remains legible at thumbnail size. Recommended
screenshot order:

1. Compact 24-slot inventory plus the three dedicated equipment slots.
2. Before/after main-inventory category sort.
3. A locked slot with its overlay visible.
4. Equipped bag before/after bag sort.
5. Quick Stack before/after, showing that no new item type enters the bag.

Do not use debug chat or developer overlays in the Workshop screenshots.

## Pre-publish checklist

- [x] Subscribe/upload account owns the Workshop item.
- [x] Mod folder contains no save data, logs, `.DS_Store`, or development cache.
- [x] `modinfo.lua` reports `0.5.0` and API version 10.
- [x] Preview image and screenshots match the current 2 x 12 layout.
- [x] Workshop description and change notes are pasted from this file.
- [x] Visibility is restricted until the final release is tagged.
- [x] Host and joining clients use the same build.
- [x] Single-player/host smoke test passes after the uploaded copy is subscribed.
- [x] Dedicated server loads the subscribed Workshop copy without Lua errors.
- [x] Issue #3 multiplayer release gate is complete.

## Final-release checklist

- [x] Complete the multiplayer late-join, reconnect, death/revive, and caves matrix.
- [x] Confirm no `[Pack & Sort][WARN]` replication-contract messages.
- [x] Update version references from `0.5.0-rc1` to `0.5.0`.
- [ ] Add final change notes and tag `v0.5.0`.
- [x] Keep pre-1.0 Workshop visibility restricted to Friends Only.
- [ ] Change Workshop visibility to Public with `v1.0.0`.

## RC validation record

- 2026-07-04: Uploaded `v0.5.0-rc1` to Steam Workshop with Friends Only
  visibility. The subscribed Workshop copy loaded and passed the host smoke test
  without observed errors.
- 2026-07-05: Three players completed late-join, reconnect, death/revive, bag
  operations, and Forest/Caves tests without observed problems or replication
  warnings. GitHub issue #3 is complete.
