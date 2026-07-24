# Pack & Sort — Steam Workshop Copy

This file contains ready-to-paste copy and the release checklist for `v0.8.8`.
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

[h2]Main configuration[/h2]

[table]
[tr][th]Setting[/th][th]Choices[/th][th]Default[/th][/tr]
[tr][td]Inventory Size[/td][td]Vanilla 15 / Expanded 24[/td][td]Expanded 24[/td][/tr]
[tr][td]Inventory Layout (per player)[/td][td]Vanilla Single Row / Safe 2 x 12[/td][td]Safe 2 x 12[/td][/tr]
[tr][td]Inventory UI Scale (per player)[/td][td]Small / Compact / Large[/td][td]Compact[/td][/tr]
[tr][td]Bag / Armor / Accessory slots[/td][td]Each enabled separately[/td][td]Enabled[/td][/tr]
[tr][td]Sort Mode[/td][td]Compact Only / Category Sort[/td][td]Category Sort[/td][/tr]
[tr][td]Merge Stacks on Sort[/td][td]Disabled / Enabled[/td][td]Enabled[/td][/tr]
[tr][td]Equipped Bag Sort[/td][td]Disabled / Enabled[/td][td]Enabled[/td][/tr]
[tr][td]Quick Stack to Bag[/td][td]Disabled / Enabled[/td][td]Disabled[/td][/tr]
[tr][td]Manual Slot Locks[/td][td]Disabled / Enabled[/td][td]Enabled[/td][/tr]
[tr][td]Debug Mode[/td][td]Off / Log Only / Chat + Log[/td][td]Off[/td][/tr]
[/table]

All action hotkeys are configurable. Advanced host defaults can assign each of
the 13 sort categories a priority from 1 (first) to 13 (last); each player can
then keep separate persistent orders for the in-game preset tabs.

[h2]Quick Stack behavior[/h2]

Quick Stack only fills compatible stacks that already exist in the equipped
bag. It does not introduce a new item type into the bag. Locked source slots
are skipped, and leftovers return to their original main-inventory slot.

[h2]Multiplayer[/h2]

This is an all-clients mod: the server and every joining player must install and
enable the same version. Inventory movement, sorting, locks, and Quick Stack are
validated by the server.

[h2]Validation[/h2]

Current Workshop refresh target: [b]v0.8.8[/b]. All Lua sources and the clean
runtime package passed syntax and checksum validation on 24 July 2026.
Automated sorting regression tests passed on the preceding v0.8.7 code; v0.8.8
only adds diagnostics and aligns missing-value fallbacks with the defaults shown
in the Mods screen. The v0.5.0 multiplayer core was previously validated with
host, dedicated-server, and three-player coverage including late join,
reconnect, death/revive, bag operations, and Forest/Caves travel.

[h2]Compatibility[/h2]

Pack & Sort targets Don't Starve Together API version 10. Existing
v0.2.6+ saves remain compatible. Mods that replace the inventory HUD, change
the base inventory size, or redefine equipment slots may conflict.

[h2]Feedback and bug reports[/h2]

Please include the host and client logs, enabled mod list, world type, and exact
steps needed to reproduce the problem. Run
[code]PACK_SORT_DEBUG()[/code] on the affected runtime and include its three
status lines; it reports the effective protocol, layout, slots, actions, and
hotkeys without changing the world. [b]Chat + Log[/b] broadcasts debug lines
from the host, so prefer [b]Log Only[/b] unless everyone in the test world
expects diagnostic chat.

Source and issue tracker:
https://github.com/dbilici/dst-pack-sort

## Change notes

[h1]v0.8.8[/h1]

[list]
[*]Added PACK_SORT_DEBUG() for a compact protocol, layout, slot, action, hotkey, and debug-mode report.
[*]Aligned missing configuration fallbacks with the defaults shown in the Mods screen.
[*]Fixed an F8 category order panel stack overflow caused by row focus changes during panel refresh.
[*]Made F8 category drag/drop more forgiving when releasing quickly or near row edges.
[*]Added a scaled Vanilla Single Row layout for expanded 24-slot inventories.
[*]Kept Safe 2 x 12 as the compact two-row option for players who prefer it.
[*]Made inventory HUD layout and scale client-local preferences instead of server-wide world settings.
[*]Polished the F8 category order panel with drag/drop reordering and simpler Apply/Reset controls.
[*]Added F8 panel controls for switching local HUD layout and cycling inventory UI scale in game.
[*]Added the in-game category order panel with Default, Combat, Building, Survivor, and Anti Drop presets.
[*]Added per-player persistent sort preferences and editable preset tabs.
[*]Added Sort Bag Too, so the main sort hotkey can also sort the equipped bag in the same request.
[*]Changed default active hotkeys to F7 for sort and F8 for the sort-order panel.
[*]Made separate bag-only sort and Quick Stack configurable but inactive by default.
[*]Improved category classification using DST's native crafting filters.
[*]Added feedback sounds for changed sorts, slot-lock toggles, and successful Apply actions.
[*]Hardened sorting stability for mixed condition-tracked and condition-less items.
[/list]

Validated with automated sorting regression coverage. An earlier `v0.8.7` Workshop copy
was uploaded and passed a host smoke test on 2026-07-20, but the 2026-07-23
release audit found that the downloaded copy does not contain the final
drag/drop reliability changes or the `v0.8.8` diagnostics currently on `main`.
Re-upload the clean source
package and keep this pre-1.0 build Friends Only until the refreshed
subscribed-copy checks are complete.

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
- [x] `modinfo.lua` reports `0.8.8` and API version 10.
- [x] Preview image and screenshots match the current expanded inventory layouts.
- [x] Workshop description and change notes are pasted from this file.
- [x] Visibility remains Friends Only for this pre-1.0 release.
- [x] Automated sorting regression suite passes.
- [x] Upload an earlier `v0.8.7` build as Friends Only.
- [ ] Upload the clean current `v0.8.8` source package so the Workshop copy
  includes the final drag/drop reliability changes and diagnostics.
- [ ] Host smoke test passes after the refreshed copy is subscribed.
- [ ] Master and Caves load the refreshed subscribed copy without Lua errors.
- [ ] If another player is available, confirm the subscribed copy joins cleanly.
- [ ] Confirm late join, reconnect and Forest/Caves travel on `v0.8.8`.

## v0.8.8 release checklist

- [x] Update source version references to `0.8.8`.
- [x] Add v0.8.8 change notes.
- [ ] Upload as Friends Only.
- [ ] Re-upload and smoke test the current clean source package.
- [ ] Confirm no `[Pack & Sort][WARN]` messages or Lua errors after that
  refreshed upload.
- [ ] Tag `v0.8.8` after the uploaded copy is verified.
- [x] Keep pre-1.0 Workshop visibility restricted to Friends Only.
- [ ] Change Workshop visibility to Public with `v1.0.0`.

## RC validation record

- 2026-07-04: Uploaded `v0.5.0-rc1` to Steam Workshop with Friends Only
  visibility. The subscribed Workshop copy loaded and passed the host smoke test
  without observed errors.
- 2026-07-05: Three players completed late-join, reconnect, death/revive, bag
  operations, and Forest/Caves tests without observed problems or replication
  warnings. GitHub issue #3 is complete.
- 2026-07-20: Uploaded and subscribed to a `v0.8.7` copy; the owner confirmed
  the host smoke test.
- 2026-07-23: Existing Master and Caves logs were reviewed. That downloaded
  `v0.8.7` copy loaded without Pack & Sort warnings or Lua errors, but a file
  comparison showed it lacks the final drag/drop reliability changes on
  `main`. Re-upload and all refreshed-copy checks remain required.
