package.path = "scripts/?.lua;" .. package.path

local Sorting = require("betterinventory/sorting")

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

local function NewSortingApi(mode)
    return Sorting.Setup({
        GLOBAL = {
            pcall = pcall,
            setmetatable = setmetatable,
        },
        config = {
            sort_mode = mode or "category",
            sort_merge_stacks = true,
            quick_stack_enabled = true,
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

local category_api = NewSortingApi("category")

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

local function AssertOrder(items, expected, label)
    assert(#items == #expected, label .. ": item count changed")
    for index, item in ipairs(items) do
        assert(item == expected[index], label .. ": unexpected item at index " .. tostring(index))
    end
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
