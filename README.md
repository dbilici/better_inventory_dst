# Pack & Sort

Pack & Sort is an all-clients Don't Starve Together mod that expands and
organizes the inventory while keeping item movement server-authoritative.

## Release status

`v0.6.0-dev` adds configurable category priorities on top of the validated
`v0.5.0` multiplayer-safe sorting core. Pre-1.0 Workshop builds remain Friends
Only while features and compatibility are still evolving.

## Features

- Optional 24-slot main inventory with a compact 2 x 12 HUD layout.
- Separate optional Bag, Armor, and Accessory equipment slots.
- Deterministic category sorting with stack merging and condition ordering.
- Craftable-item classification based on DST's native crafting filters.
- In-game sort-order panel with persistent per-player category order.
- Separate sorting for the equipped bag, including while its UI is closed.
- Persistent manual main-inventory slot locks.
- Quick Stack into compatible stacks already present in the equipped bag.
- Server-side cooldowns, re-entrancy guards, and detached-item recovery.
- Multiplayer protocol and replication diagnostics.

## Default controls

| Input | Action |
|---|---|
| `F7` | Sort the main inventory; optionally also sort the equipped bag |
| `F8` | Open the in-game category order panel |
| Hover a main slot + `L` | Toggle that slot's sort lock |

All hotkeys are configurable. If two inventory actions use the same key, the
secondary action is disabled with a warning instead of dispatching both.
Quick Stack and a separate bag-only sort hotkey remain configurable, but they
are not assigned as active defaults so the mod only uses `F7` and `F8` out of
the box.

## Quick Stack behavior

Quick Stack only fills compatible stacks that already exist in the equipped
bag. It does not create a new item type in the bag, ignores locked source slots,
returns leftovers to their original main-inventory slot, and remains safe when
the bag UI is closed. Successful transfers play one local inventory-move sound;
no-op requests remain silent.

## Installation and compatibility

1. Place the mod folder under the Don't Starve Together `mods` directory.
2. Enable Pack & Sort in the world's Mods settings.
3. Install and enable the same build for every joining client.

The mod targets Don't Starve Together API version 10. Existing v0.2.6+ saves
remain compatible. Back up important worlds before changing a mod setup.

## Configuration

Press `F8` in game to choose Default, Combat, Building, Survivor, or Anti Drop;
categories can still be moved up or down before applying. The order is saved
per player and applies to both main-inventory and equipped-bag sorting. Each
preset tab keeps its own editable order; switching tabs preserves unapplied
drafts, `Reset Tab` affects only the open tab, and `Apply All` saves every tab
plus the active preset. The panel also has a per-player `Sort Bag Too` toggle:
when enabled, the main sort hotkey sorts the equipped bag in the same request;
when disabled, the bag can still be sorted separately if a separate bag-only
hotkey is configured. Anti
Drop is best effort: it places expendable materials first so frog theft is more
likely to remove one of them, but the game controls the final slot scan. The Mods
menu priority values set the host defaults.

Craftable items use DST's native Regular crafting-filter membership as the
primary classification source. Because an item may appear in multiple filters,
the first supported filter in the game's documented order becomes its primary
inventory category. Non-craftable resources and loot use component, tag, and
prefab fallbacks. Filter reference:
[Crafting/DST](https://dontstarve.wiki.gg/wiki/Crafting/DST).

## Development

Run the pure sorting and Quick Stack regression suite with any Lua 5.1+
interpreter:

```sh
lua tests/sorting_spec.lua   # or: luajit tests/sorting_spec.lua
```

The full manual matrix and expected diagnostics are documented in
[README_DEV.md](README_DEV.md). Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
