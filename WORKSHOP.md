# Pack & Sort — Steam Workshop Copy

This file contains ready-to-paste copy and the release checklist for `v0.8.0`.
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
[*]Optional 24-slot main inventory with per-player scaled vanilla single-row or compact 2 x 12 HUD layout
[*]Separate optional Bag, Armor, and Accessory equipment slots
[*]Deterministic category sorting with optional stack merging
[*]Craftable-item categories derived from DST's native crafting filters
[*]In-game category order panel with persistent per-player preferences
[*]Default, Combat, Building, Survivor, and best-effort Anti Drop presets
[*]Per-player option for F7 to sort the equipped bag together with the inventory
[*]Independent sorting for the equipped bag, even while its UI is closed
[*]Persistent manual slot locks for items you want to keep in place
[*]Quick Stack into compatible stacks already present in the equipped bag
[*]Configurable hotkeys plus client-local inventory HUD layout and scale
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

Version 0.8.0 has passed automated sorting regression tests. The `v0.5.0`
multiplayer core was previously validated with host, dedicated-server, and
three-player coverage including late join, reconnect, death/revive, bag
operations, and Forest/Caves travel.

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

[h1]v0.8.0[/h1]

[list]
[*]Added a scaled Vanilla Single Row layout for expanded 24-slot inventories.
[*]Kept Safe 2 x 12 as the compact two-row option for players who prefer it.
[*]Made inventory HUD layout and scale client-local preferences instead of server-wide world settings.
[*]Added the in-game category order panel with Default, Combat, Building, Survivor, and Anti Drop presets.
[*]Added per-player persistent sort preferences and editable preset tabs.
[*]Added Sort Bag Too, so the main sort hotkey can also sort the equipped bag in the same request.
[*]Changed default active hotkeys to F7 for sort and F8 for the sort-order panel.
[*]Made separate bag-only sort and Quick Stack configurable but inactive by default.
[*]Improved category classification using DST's native crafting filters.
[*]Added feedback sounds for changed sorts, slot-lock toggles, and successful Apply actions.
[*]Hardened sorting stability for mixed condition-tracked and condition-less items.
[/list]

Validated with automated sorting regression coverage. Keep this pre-1.0 build
Friends Only while the subscribed Workshop copy is smoke-tested.

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
- [x] `modinfo.lua` reports `0.8.0` and API version 10.
- [x] Preview image and screenshots match the current expanded inventory layouts.
- [x] Workshop description and change notes are pasted from this file.
- [x] Visibility remains Friends Only for this pre-1.0 release.
- [x] Automated sorting regression suite passes.
- [ ] Upload `v0.8.0` as Friends Only.
- [ ] Host smoke test passes after the uploaded copy is subscribed.
- [ ] Dedicated server loads the subscribed Workshop copy without Lua errors.
- [ ] If another player is available, confirm the subscribed copy joins cleanly.

## v0.8.0 release checklist

- [x] Update version references from `0.7.0` to `0.8.0`.
- [x] Add v0.8.0 change notes.
- [ ] Upload as Friends Only.
- [ ] Smoke test the subscribed Workshop copy.
- [ ] Confirm no `[Pack & Sort][WARN]` messages or Lua errors.
- [ ] Tag `v0.8.0` after the uploaded copy is verified.
- [x] Keep pre-1.0 Workshop visibility restricted to Friends Only.
- [ ] Change Workshop visibility to Public with `v1.0.0`.

## RC validation record

- 2026-07-04: Uploaded `v0.5.0-rc1` to Steam Workshop with Friends Only
  visibility. The subscribed Workshop copy loaded and passed the host smoke test
  without observed errors.
- 2026-07-05: Three players completed late-join, reconnect, death/revive, bag
  operations, and Forest/Caves tests without observed problems or replication
  warnings. GitHub issue #3 is complete.
