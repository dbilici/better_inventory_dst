package.path = "scripts/?.lua;" .. package.path

local Sorting = require("betterinventory/sorting")
local Categories = require("betterinventory/categories")

do
    local custom_order = {
        "material", "light", "weapon", "tool", "armor", "bag", "accessory",
        "clothing", "food", "healing", "fuel", "magic", "trinket",
    }
    local encoded = Categories.SerializeOrder(custom_order)
    assert(encoded ~= nil, "valid category order should serialize")
    local decoded = Categories.DeserializeOrder(encoded)
    assert(decoded ~= nil and decoded[1] == "material" and decoded[13] == "trinket",
        "category order should round-trip")
    assert(Categories.DeserializeOrder("tool,tool") == nil,
        "duplicate or incomplete category order must be rejected")
    for _, preset_key in ipairs(Categories.PRESET_ORDER) do
        local preset = Categories.PRESETS[preset_key]
        assert(preset ~= nil and Categories.SerializeOrder(preset.order) ~= nil,
            "preset should contain every category exactly once: " .. tostring(preset_key))
    end

    local preset_orders = {}
    for _, key in ipairs(Categories.PRESET_KEYS) do
        preset_orders[key] = Categories.GetBasePresetOrder(key, Categories.DEFAULT_PRIORITIES)
    end
    preset_orders.combat = Categories.CopyOrder(custom_order)
    local state = Categories.SerializePresetState("combat", preset_orders)
    local active, decoded_orders = Categories.DeserializePresetState(state)
    assert(active == "combat" and decoded_orders.combat[1] == "material",
        "preset state should preserve active tab and independent orders")
end

do
    local PreviousClass = Class
    Class = function(constructor)
        local class = {}
        class.__index = class
        return setmetatable(class, {
            __call = function(_, ...)
                local instance = setmetatable({}, class)
                constructor(instance, ...)
                return instance
            end,
        })
    end

    package.loaded["components/betterinventory_sortprefs"] = nil
    local SortPreferences = require("components/betterinventory_sortprefs")
    local custom_order = {
        "material", "light", "weapon", "tool", "armor", "bag", "accessory",
        "clothing", "food", "healing", "fuel", "magic", "trinket",
    }
    local preferences = SortPreferences({})
    local preset_orders = preferences:GetPresetOrders()
    preset_orders.combat = Categories.CopyOrder(custom_order)
    assert(preferences:SetState("combat", preset_orders),
        "valid independent preset state should be accepted")
    local saved = preferences:OnSave()
    assert(saved ~= nil and saved.preset_orders.combat ~= nil, "custom preset order should save")

    local restored = SortPreferences({})
    restored:OnLoad(saved)
    assert(restored.active_preset == "combat" and restored:GetOrder()[1] == "material",
        "saved active preset and custom order should restore")
    local default_before = restored:GetPresetOrder("default")[1]
    restored:Reset("combat")
    assert(restored:GetPresetOrder("combat")[1] == "weapon",
        "reset should restore only the selected preset")
    assert(restored:GetPresetOrder("default")[1] == default_before,
        "resetting one preset must not change another")

    Class = PreviousClass
end

local function NewItem(prefab, options)
    options = options or {}
    local item = {
        prefab = prefab,
        components = options.components or {},
        _tags = options.tags or {},
        _valid = true,
    }

    function item:HasTag(tag)
        return self._tags[tag] == true
    end

    function item:IsValid()
        return self._valid
    end

    function item:Remove()
        self._valid = false
    end

    return item
end

local function AttachStack(item, size, max_size)
    local stack = {
        size = size,
        max_size = max_size,
    }
    item.components.stackable = stack

    function stack:StackSize()
        return self.size
    end

    function stack:IsFull()
        return self.size >= self.max_size
    end

    function stack:CanStackWith(source)
        return item.prefab == source.prefab and item.skinname == source.skinname
    end

    function stack:Put(source)
        if not self:CanStackWith(source) then
            return source
        end

        local source_stack = source.components.stackable
        local moved = math.min(self.max_size - self.size, source_stack.size)
        self.size = self.size + moved
        source_stack.size = source_stack.size - moved
        if source_stack.size <= 0 then
            source:Remove()
            return nil
        end
        return source
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

local function NewSortingApi(mode, category_priorities, crafting_filters, recipes)
    return Sorting.Setup({
        GLOBAL = {
            pcall = pcall,
            setmetatable = setmetatable,
            tonumber = tonumber,
            CRAFTING_FILTERS = crafting_filters,
            AllRecipes = recipes,
        },
        config = {
            sort_mode = mode or "category",
            sort_merge_stacks = true,
            quick_stack_enabled = true,
            sort_category_priorities = category_priorities,
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

do
    local custom_api = NewSortingApi("category", {
        material = 1,
        light = 11,
        weapon = 12,
        tool = 13,
    })
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
    local items = { axe, spear, torch, rocks }

    custom_api.SortItemsForInventory(items)
    AssertOrder(items, { rocks, torch, spear, axe }, "custom category order")
end

do
    local duplicate_api = NewSortingApi("category", {
        tool = 1,
        weapon = 1,
    })
    local spear = NewItem("spear", {
        components = { weapon = {} },
    })
    local axe = NewItem("axe", {
        components = { tool = {} },
    })
    local items = { spear, axe }

    duplicate_api.SortItemsForInventory(items)
    AssertOrder(items, { axe, spear }, "duplicate priority fallback")
end

do
    local invalid_api = NewSortingApi("category", {
        tool = 99,
        weapon = "invalid",
    })
    local spear = NewItem("spear", {
        components = { weapon = {} },
    })
    local axe = NewItem("axe", {
        components = { tool = {} },
    })
    local items = { spear, axe }

    invalid_api.SortItemsForInventory(items)
    AssertOrder(items, { axe, spear }, "invalid priority fallback")
end

local category_api = NewSortingApi("category")

do
    local filter_api = NewSortingApi("category", nil, {
        LIGHT = { default_sort_values = { wiki_lantern_recipe = 1 } },
        WEAPONS = { default_sort_values = { wiki_lantern_recipe = 1 } },
    }, {
        wiki_lantern_recipe = { product = "wiki_lantern" },
    })
    local item = NewItem("wiki_lantern")
    assert(filter_api.GetInventorySortCategoryName(item) == "light",
        "overlapping crafting filters should use documented filter precedence")
end

do
    local log = NewItem("log", {
        components = { edible = {}, fuel = {} },
    })
    local torch = NewItem("torch", {
        components = { fueled = {}, lighter = {}, weapon = {} },
    })
    assert(category_api.GetInventorySortCategoryName(log) == "material",
        "core resources must not be classified as food or fuel")
    assert(category_api.GetInventorySortCategoryName(torch) == "light",
        "light-emitting weapons must be classified as light")
end

do
    local bag_inst = {
        IsValid = function()
            return true
        end,
    }
    local bag_target = AttachStack(NewItem("twigs"), 18, 20)
    bag_target.components.inventoryitem = { owner = bag_inst }

    local bag = {
        inst = bag_inst,
        readonlycontainer = false,
        slots = { bag_target },
    }
    function bag:GetNumSlots()
        return 8
    end
    function bag:GetItemInSlot(slot)
        return self.slots[slot]
    end

    local player = { components = {} }
    function player:IsValid()
        return true
    end

    local source = AttachStack(NewItem("twigs"), 5, 20)
    source.components.inventoryitem = { owner = player }
    local unrelated = AttachStack(NewItem("cutgrass"), 7, 20)
    unrelated.components.inventoryitem = { owner = player }

    local inventory = {
        isloading = false,
        slots = { source, unrelated },
    }
    player.components.inventory = inventory

    function inventory:GetActiveItem()
        return nil
    end
    function inventory:GetOverflowContainer()
        return bag
    end
    function inventory:GetNumSlots()
        return 2
    end
    function inventory:GetItemInSlot(slot)
        return self.slots[slot]
    end
    function inventory:RemoveItem(item)
        for slot, candidate in pairs(self.slots) do
            if candidate == item then
                self.slots[slot] = nil
                item.components.inventoryitem.owner = nil
                return item
            end
        end
    end
    function inventory:GiveItem(item, slot)
        if slot ~= nil and self.slots[slot] == nil then
            self.slots[slot] = item
            item.components.inventoryitem.owner = player
            return true
        end
        return false
    end

    assert(category_api.QuickStackToBagForPlayer(player) == 2,
        "quick stack should report moved units")
    assert(bag_target.components.stackable:StackSize() == 20, "bag target should become full")
    assert(source.components.stackable:StackSize() == 3, "source leftover should be preserved")
    assert(inventory:GetItemInSlot(1) == source, "leftover should return to its original slot")
    assert(inventory:GetItemInSlot(2) == unrelated, "unrelated item type must not move")
end

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
