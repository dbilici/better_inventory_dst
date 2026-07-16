name = "Pack & Sort"
description = [[
Expanded inventory + utility equipment slots + inventory sort for Don't Starve Together.

Current v0.6.0 development build:
- Optional 24-slot inventory foundation
- Unified server/client/classified slot count for usable slots 16-24
- Namespaced equipment slots to avoid collisions with other mods
- Compact 2 x 12 inventory bar layout
- Fitted custom background for the 2-row layout
- Separate optional Bag / Armor / Accessory equip slots
- Dedicated bag slot keeps vanilla overflow-container behavior
- Client bag-content reads account for the dedicated Bag slot
- Vanilla-only item slot rules for safer testing
- Inventory sort hotkey with optional stack merging
- In-game sort-order panel with per-player persistent category order
- Per-player option for the main sort hotkey to also sort the equipped bag
- Default / Combat / Building / Survivor / Anti Drop sort presets
- Independent editable preset tabs with per-tab reset and Apply All
- Main sort hotkey can also sort the equipped bag when enabled per player
- Optional Quick Stack fills compatible stacks already present in the equipped bag
- Hover a main inventory slot and press a configurable key to lock it in place
- Manual slot locks persist across save/reload
- Server-side sort cooldown, re-entrancy lock, and item recovery
- Locked-slot items remain fixed during sorting
- Late-join replication contract diagnostics
- Client/server core protocol handshake
- Debug mode for log/chat diagnostics

Quick Draw is intentionally removed because vanilla quick equip/swap already covers that use case.
]]
author = "Dogan Bilici"
version = "0.6.0-dev"
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

local sort_priority_options = {
    {description = "1 - First", data = 1},
    {description = "2", data = 2},
    {description = "3", data = 3},
    {description = "4", data = 4},
    {description = "5", data = 5},
    {description = "6", data = 6},
    {description = "7", data = 7},
    {description = "8", data = 8},
    {description = "9", data = 9},
    {description = "10", data = 10},
    {description = "11", data = 11},
    {description = "12", data = 12},
    {description = "13 - Last", data = 13},
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
        default = "KEY_F7",
    },
    {
        name = "sort_order_key",
        label = "Sort Order Panel Hotkey",
        hover = "Open the in-game category order panel. Use a different key from other inventory actions.",
        options = {
            {description = "F8", data = "KEY_F8"},
            {description = "F9", data = "KEY_F9"},
            {description = "F10", data = "KEY_F10"},
            {description = "B", data = "KEY_B"},
            {description = "G", data = "KEY_G"},
            {description = "V", data = "KEY_V"},
        },
        default = "KEY_F8",
    },
    {
        name = "bag_sort_enabled",
        label = "Equipped Bag Sort",
        hover = "Sort the equipped backpack or bag internally without moving items to or from the main inventory.",
        options = boolean_options,
        default = true,
    },
    {
        name = "bag_sort_key",
        label = "Bag Sort Hotkey",
        hover = "Optional separate bag-only sort key. Leave disabled to use only the main Sort Hotkey + Sort Bag Too.",
        options = {
            {description = "Disabled", data = "KEY_NONE"},
            {description = "F6", data = "KEY_F6"},
            {description = "F7", data = "KEY_F7"},
            {description = "F8", data = "KEY_F8"},
            {description = "F9", data = "KEY_F9"},
            {description = "B", data = "KEY_B"},
            {description = "G", data = "KEY_G"},
        },
        default = "KEY_NONE",
    },
    {
        name = "quick_stack_enabled",
        label = "Quick Stack to Bag",
        hover = "Move main-inventory items only into compatible stacks already present in the equipped bag.",
        options = boolean_options,
        default = false,
    },
    {
        name = "quick_stack_key",
        label = "Quick Stack Hotkey",
        hover = "Press this key to fill matching stacks already present in the equipped bag.",
        options = {
            {description = "Disabled", data = "KEY_NONE"},
            {description = "F7", data = "KEY_F7"},
            {description = "F8", data = "KEY_F8"},
            {description = "F9", data = "KEY_F9"},
            {description = "F10", data = "KEY_F10"},
            {description = "B", data = "KEY_B"},
            {description = "G", data = "KEY_G"},
        },
        default = "KEY_NONE",
    },
    {
        name = "slot_lock_enabled",
        label = "Manual Slot Locks",
        hover = "Hover a main inventory slot and press the lock hotkey to keep that slot fixed during sorting.",
        options = boolean_options,
        default = true,
    },
    {
        name = "slot_lock_key",
        label = "Slot Lock Hotkey",
        hover = "Hover a main inventory slot and press this key to toggle its sort lock.",
        options = {
            {description = "L", data = "KEY_L"},
            {description = "K", data = "KEY_K"},
            {description = "J", data = "KEY_J"},
            {description = "N", data = "KEY_N"},
        },
        default = "KEY_L",
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
    {
        name = "sort_priority_tool",
        label = "Sort Priority: Tools/Fishing/Seafaring",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 1,
    },
    {
        name = "sort_priority_weapon",
        label = "Sort Priority: Weapons",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 2,
    },
    {
        name = "sort_priority_armor",
        label = "Sort Priority: Armor",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 3,
    },
    {
        name = "sort_priority_bag",
        label = "Sort Priority: Storage",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 4,
    },
    {
        name = "sort_priority_accessory",
        label = "Sort Priority: Riding/Accessories",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 5,
    },
    {
        name = "sort_priority_clothing",
        label = "Sort Priority: Clothing/Weather",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 6,
    },
    {
        name = "sort_priority_food",
        label = "Sort Priority: Food/Cooking",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 7,
    },
    {
        name = "sort_priority_healing",
        label = "Sort Priority: Healing",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 8,
    },
    {
        name = "sort_priority_light",
        label = "Sort Priority: Light",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 9,
    },
    {
        name = "sort_priority_fuel",
        label = "Sort Priority: Fuel",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 10,
    },
    {
        name = "sort_priority_magic",
        label = "Sort Priority: Magic",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 11,
    },
    {
        name = "sort_priority_trinket",
        label = "Sort Priority: Decor/Event",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 12,
    },
    {
        name = "sort_priority_material",
        label = "Sort Priority: Refined/Materials",
        hover = "Lower numbers sort earlier. Duplicate priorities use the default category order.",
        options = sort_priority_options,
        default = 13,
    },
}
