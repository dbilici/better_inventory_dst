package.path = "scripts/?.lua;" .. package.path

local Sorting = require("betterinventory/sorting")

local function NewItem(prefab, options)
    options = options or {}
    local item = {
        prefab = prefab,
        components = options.components or {},
        _tags = options.tags or {},
    }

    function item:HasTag(tag)
        return self._tags[tag] == true
    end

    return item
end

local function NewConditionComponent(percent)
    return {
        GetPercent = function()
            return percent
        end,
    }
end

local function NewStackComponent(size)
    return {
        StackSize = function()
            return size
        end,
    }
end

local function NewSortingApi(mode)
    return Sorting.Setup({
        GLOBAL = {
            setmetatable = setmetatable,
        },
        config = {
            sort_mode = mode or "category",
            sort_merge_stacks = true,
        },
        max_item_slots = 24,
        slot_defs = {
            ARMOR = { tag = "betterinventory_armor" },
            BAG = { tag = "betterinventory_bag" },
            ACCESSORY = { tag = "betterinventory_accessory" },
        },
        install_handlers = false,
    })
end

local function AssertOrder(items, expected, label)
    assert(#items == #expected, label .. ": item count changed")
    for index, item in ipairs(items) do
        assert(item == expected[index], label .. ": unexpected item at index " .. tostring(index))
    end
end

local category_api = NewSortingApi("category")

do
    local rocks = NewItem("rocks")
    local torch = NewItem("torch", {
        components = { fueled = NewConditionComponent(1) },
    })
    local spear = NewItem("spear", {
        components = { weapon = {} },
    })
    local axe = NewItem("axe", {
        components = { tool = {} },
    })
    local items = { rocks, torch, spear, axe }

    category_api.SortItemsForInventory(items)
    AssertOrder(items, { axe, spear, torch, rocks }, "category order")
end

do
    local low = NewItem("torch", {
        components = { fueled = NewConditionComponent(0.25) },
    })
    local full_a = NewItem("torch", {
        components = { fueled = NewConditionComponent(1) },
    })
    local full_b = NewItem("torch", {
        components = { fueled = NewConditionComponent(1) },
    })
    local items = { low, full_a, full_b }

    category_api.SortItemsForInventory(items)
    AssertOrder(items, { full_a, full_b, low }, "condition and stable tie order")

    category_api.SortItemsForInventory(items)
    AssertOrder(items, { full_a, full_b, low }, "repeated stable sort")
end

do
    local small = NewItem("cutgrass", {
        components = { stackable = NewStackComponent(5) },
    })
    local large = NewItem("cutgrass", {
        components = { stackable = NewStackComponent(20) },
    })
    local items = { small, large }

    category_api.SortItemsForInventory(items)
    AssertOrder(items, { large, small }, "stack size order")
end

do
    local compact_api = NewSortingApi("compact")
    local rocks = NewItem("rocks")
    local axe = NewItem("axe", {
        components = { tool = {} },
    })
    local items = { rocks, axe }

    compact_api.SortItemsForInventory(items)
    AssertOrder(items, { rocks, axe }, "compact mode")
end

print("sorting_spec: OK")
