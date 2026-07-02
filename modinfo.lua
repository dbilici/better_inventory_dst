name = "Better Inventory"
description = [[
Expanded inventory + utility equipment slots + inventory sort for Don't Starve Together.

Current debug baseline build:
- Optional 24-slot inventory foundation
- Unified server/client/classified slot count for usable slots 16-24
- Compact 2 x 12 inventory bar layout
- Fitted custom background for the 2-row layout
- Separate optional Bag / Armor / Accessory equip slots
- Dedicated bag slot keeps vanilla overflow-container behavior
- Vanilla-only item slot rules for safer testing
- Inventory sort hotkey with optional stack merging
- Locked-slot items remain fixed during sorting
- Debug mode for log/chat diagnostics

Quick Draw is intentionally removed because vanilla quick equip/swap already covers that use case.
]]
author = "Dogan Bilici"
version = "0.2.6-debug-baseline"
api_version = 10
priority = 100

all_clients_require_mod = true
client_only_mod = false

dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true

server_filter_tags = {
    "inventory",
    "expanded inventory",
    "equipment slots",
    "inventory sort",
}

icon_atlas = "images/modicon.xml"
icon = "modicon.tex"

local boolean_options = {
    {description = "Disabled", data = false},
    {description = "Enabled", data = true},
}

configuration_options = {
    {
        name = "inventory_size",
        label = "Inventory Size",
        hover = "Choose the base inventory size.",
        options = {
            {description = "Vanilla 15", data = 15},
            {description = "Expanded 24", data = 24},
        },
        default = 24,
    },
    {
        name = "inventory_layout",
        label = "Inventory Layout",
        hover = "Layout for the expanded inventory bar.",
        options = {
            {description = "Vanilla", data = "vanilla"},
            {description = "Compact 2 x 12", data = "2x12"},
        },
        default = "2x12",
    },
    {
        name = "ui_scale",
        label = "Inventory UI Scale",
        hover = "Smaller values keep the 2-row inventory from stretching across the screen.",
        options = {
            {description = "Small", data = 0.78},
            {description = "Compact", data = 0.85},
            {description = "Large", data = 0.92},
        },
        default = 0.85,
    },
    {
        name = "slot_bag",
        label = "Separate Bag Slot",
        hover = "Backpacks and bag-like equipment use their own slot instead of the body slot.",
        options = boolean_options,
        default = true,
    },
    {
        name = "slot_armor",
        label = "Separate Armor Slot",
        hover = "Armor uses its own slot instead of sharing the body slot.",
        options = boolean_options,
        default = true,
    },
    {
        name = "slot_accessory",
        label = "Accessory Slot",
        hover = "Amulets use a separate accessory slot.",
        options = boolean_options,
        default = true,
    },
    {
        name = "sort_enabled",
        label = "Inventory Sort",
        hover = "Enable the inventory sort hotkey.",
        options = boolean_options,
        default = true,
    },
    {
        name = "sort_mode",
        label = "Sort Mode",
        hover = "Compact keeps the current item order. Category Sort groups similar items first.",
        options = {
            {description = "Compact Only", data = "compact"},
            {description = "Category Sort", data = "category"},
        },
        default = "category",
    },
    {
        name = "sort_merge_stacks",
        label = "Merge Stacks on Sort",
        hover = "When enabled, sorting first tries to merge compatible partial stacks.",
        options = boolean_options,
        default = true,
    },
    {
        name = "sort_key",
        label = "Sort Hotkey",
        hover = "Press this key to sort the main inventory.",
        options = {
            {description = "F5", data = "KEY_F5"},
            {description = "F6", data = "KEY_F6"},
            {description = "F7", data = "KEY_F7"},
            {description = "F8", data = "KEY_F8"},
            {description = "R", data = "KEY_R"},
            {description = "C", data = "KEY_C"},
            {description = "V", data = "KEY_V"},
        },
        default = "KEY_F5",
    },
    {
        name = "debug_mode",
        label = "Debug Mode",
        hover = "Useful while testing. Chat + Log only prints chat messages on the server/host.",
        options = {
            {description = "Off", data = "off"},
            {description = "Log Only", data = "log"},
            {description = "Chat + Log", data = "chatlog"},
        },
        default = "off",
    },
}
