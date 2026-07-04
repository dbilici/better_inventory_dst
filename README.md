# Better Inventory DST

Better Inventory is an all-clients Don't Starve Together mod that expands and
organizes the inventory while keeping item movement server-authoritative.

## Release status

`v0.5.0-rc1` is a release candidate. Single-player/host validation and
dedicated-server loading pass. Full two-client late-join and cross-shard
validation is still tracked in
[issue #3](https://github.com/dbilici/better_inventory_dst/issues/3).

## Features

- Optional 24-slot main inventory with a compact 2 x 12 HUD layout.
- Separate optional Bag, Armor, and Accessory equipment slots.
- Deterministic category sorting with stack merging and condition ordering.
- Separate sorting for the equipped bag, including while its UI is closed.
- Persistent manual main-inventory slot locks.
- Quick Stack into compatible stacks already present in the equipped bag.
- Server-side cooldowns, re-entrancy guards, and detached-item recovery.
- Multiplayer protocol and replication diagnostics.

## Default controls

| Input | Action |
|---|---|
| `F5` | Sort the main inventory |
| `F6` | Sort the equipped bag |
| `F7` | Quick Stack matching items into existing bag stacks |
| Hover a main slot + `L` | Toggle that slot's sort lock |

All hotkeys are configurable. If two inventory actions use the same key, the
secondary action is disabled with a warning instead of dispatching both.

## Quick Stack behavior

Quick Stack only fills compatible stacks that already exist in the equipped
bag. It does not create a new item type in the bag, ignores locked source slots,
returns leftovers to their original main-inventory slot, and remains safe when
the bag UI is closed. Successful transfers play one local inventory-move sound;
no-op requests remain silent.

## Installation and compatibility

1. Place the mod folder under the Don't Starve Together `mods` directory.
2. Enable Better Inventory in the world's Mods settings.
3. Install and enable the same build for every joining client.

The mod targets Don't Starve Together API version 10. Existing v0.2.6+ saves
remain compatible. Back up important worlds before adopting a release candidate.

## Configuration

The Mods menu exposes inventory size/layout, HUD scale, equipment slots, sorting
mode, stack merging, manual slot locks, Quick Stack, hotkeys, and debug logging.

## Development

Run the pure sorting and Quick Stack regression suite with:

```sh
lua tests/sorting_spec.lua
```

The full manual matrix and expected diagnostics are documented in
[README_DEV.md](README_DEV.md). Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
