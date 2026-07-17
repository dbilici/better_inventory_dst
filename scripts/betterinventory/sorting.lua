local Sorting = {}
local Categories = require("betterinventory/categories")

function Sorting.Setup(context)
    assert(context ~= nil, "Pack & Sort sorting context is required")

    local GLOBAL = assert(context.GLOBAL, "GLOBAL is required")
    local CONFIG = assert(context.config, "sorting config is required")
    local MAX_ITEM_SLOTS = assert(context.max_item_slots, "max item slots is required")
    local SLOT_DEFS = assert(context.slot_defs, "slot definitions are required")
    local DebugLog = context.debug_log or function() end
    local DebugWarn = context.debug_warn or function() end
    local GetHudSettings = context.get_hud_settings
    local ApplyHudSettings = context.apply_hud_settings
    local HudScaleOptions = context.hud_scale_options
    local AddClientModRPCHandler = context.add_client_mod_rpc_handler
    local AddModRPCHandler = context.add_mod_rpc_handler
    local TheNet = GLOBAL.TheNet

    local SORT_RPC_NAMESPACE = "BetterInventory"
    local SORT_RPC_NAME = "SortInventory"
    local BAG_SORT_RPC_NAME = "SortBag"
    local QUICK_STACK_RPC_NAME = "QuickStackToBag"
    local QUICK_STACK_RESULT_RPC_NAME = "QuickStackResult"
    local SORT_FEEDBACK_RESULT_RPC_NAME = "SortFeedbackResult"
    local SORT_ORDER_REQUEST_RPC_NAME = "RequestSortOrder"
    local SORT_ORDER_APPLY_RPC_NAME = "ApplySortOrder"
    local SORT_ORDER_STATE_RPC_NAME = "SortOrderState"
    local SORT_RPC_COOLDOWN = 0.75
    local SORT_ORDER_RPC_COOLDOWN = 0.25
    local SORT_REQUEST_STATE = GLOBAL.setmetatable({}, { __mode = "k" })
    local SORT_ORDER_REQUEST_STATE = GLOBAL.setmetatable({}, { __mode = "k" })
    local ACTIVE_SORT_ORDER_SCREEN = nil

    local DEFAULT_CATEGORY_SORT_ORDER = Categories.DEFAULT_PRIORITIES
    local CONFIGURED_CATEGORY_SORT_ORDER = CONFIG.sort_category_priorities or {}

    local MATERIAL_PREFABS = {
        boards = true,
        charcoal = true,
        cutgrass = true,
        cutstone = true,
        gears = true,
        goldnugget = true,
        guano = true,
        houndstooth = true,
        livinglog = true,
        log = true,
        marble = true,
        moonglass = true,
        moonrocknugget = true,
        nitre = true,
        papyrus = true,
        pigskin = true,
        poop = true,
        rocks = true,
        rope = true,
        silk = true,
        stinger = true,
        thulecite = true,
        thulecite_pieces = true,
        transistor = true,
        twigs = true,
    }

    local LIGHT_PREFABS = {
        lantern = true,
        minerhat = true,
        molehat = true,
        nightstick = true,
        pumpkin_lantern = true,
        torch = true,
    }

    -- DST crafting filters are the primary classification source for craftable
    -- inventory items. The ordering follows the Regular filters documented by
    -- the official-community wiki and recipes_filter.lua. Filters may overlap;
    -- the first mapped filter becomes the item's primary inventory category.
    local CRAFTING_FILTER_CATEGORY_MAP = {
        { filter = "TOOLS", category = "tool" },
        { filter = "LIGHT", category = "light" },
        { filter = "PROTOTYPERS", category = "material" },
        { filter = "REFINE", category = "material" },
        { filter = "WEAPONS", category = "weapon" },
        { filter = "ARMOUR", category = "armor" },
        { filter = "CLOTHING", category = "clothing" },
        { filter = "RESTORATION", category = "healing" },
        { filter = "MAGIC", category = "magic" },
        { filter = "DECOR", category = "trinket" },
        { filter = "STRUCTURES", category = "material" },
        { filter = "CONTAINERS", category = "bag" },
        { filter = "COOKING", category = "food" },
        { filter = "GARDENING", category = "tool" },
        { filter = "FISHING", category = "tool" },
        { filter = "SEAFARING", category = "tool" },
        { filter = "RIDING", category = "accessory" },
        { filter = "WINTER", category = "clothing" },
        { filter = "SUMMER", category = "clothing" },
        { filter = "RAIN", category = "clothing" },
        { filter = "SPECIAL_EVENT", category = "trinket" },
    }
    local CRAFTING_CATEGORY_BY_PREFAB = nil

    local function BuildCraftingCategoryCache()
        local cache = {}
        local filters = GLOBAL.CRAFTING_FILTERS or {}
        local recipes = GLOBAL.AllRecipes or {}

        for _, mapping in ipairs(CRAFTING_FILTER_CATEGORY_MAP) do
            local filter = filters[mapping.filter]
            local values = filter ~= nil and filter.default_sort_values or nil
            if type(values) == "table" then
                for recipe_name in pairs(values) do
                    local recipe = recipes[recipe_name]
                    local product = recipe ~= nil and recipe.product or recipe_name
                    if product ~= nil and cache[product] == nil then
                        cache[product] = mapping.category
                    end
                end
            end
        end

        return cache
    end

    local function GetCraftingFilterCategory(prefab)
        if CRAFTING_CATEGORY_BY_PREFAB == nil then
            CRAFTING_CATEGORY_BY_PREFAB = BuildCraftingCategoryCache()
        end
        return prefab ~= nil and CRAFTING_CATEGORY_BY_PREFAB[prefab] or nil
    end

    local function SafeHasTag(item, tag)
        return item ~= nil and item.HasTag ~= nil and item:HasTag(tag)
    end

    local function GetInventorySortCategoryName(item)
        if item == nil then
            return "misc"
        end

        local components = item.components or {}
        local crafting_category = GetCraftingFilterCategory(item.prefab)

        if crafting_category ~= nil then
            return crafting_category
        end

        if MATERIAL_PREFABS[item.prefab] then
            return "material"
        end

        if components.tool ~= nil or SafeHasTag(item, "tool") then
            return "tool"
        end

        if LIGHT_PREFABS[item.prefab] or components.lighter ~= nil
            or SafeHasTag(item, "lighter") or SafeHasTag(item, "light") then
            return "light"
        end

        if components.weapon ~= nil or SafeHasTag(item, "weapon") then
            return "weapon"
        end

        if SafeHasTag(item, SLOT_DEFS.ARMOR.tag) or components.armor ~= nil or SafeHasTag(item, "armor") then
            return "armor"
        end

        if SafeHasTag(item, SLOT_DEFS.BAG.tag) or SafeHasTag(item, "backpack") then
            return "bag"
        end

        if SafeHasTag(item, SLOT_DEFS.ACCESSORY.tag) or SafeHasTag(item, "amulet") then
            return "accessory"
        end

        if components.equippable ~= nil then
            return "clothing"
        end

        if components.edible ~= nil or SafeHasTag(item, "preparedfood") or SafeHasTag(item, "cookable") then
            return "food"
        end

        if components.healer ~= nil then
            return "healing"
        end

        if components.fuel ~= nil or SafeHasTag(item, "fuel") then
            return "fuel"
        end

        if SafeHasTag(item, "gem") or SafeHasTag(item, "magic") then
            return "magic"
        end

        if SafeHasTag(item, "trinket") then
            return "trinket"
        end

        return "material"
    end

    local function GetInventorySortCategory(item, category_priorities)
        local category = GetInventorySortCategoryName(item)
        if category == "misc" then
            return #Categories.ORDER + 1
        end
        local priorities = category_priorities or CONFIGURED_CATEGORY_SORT_ORDER
        local configured_priority = GLOBAL.tonumber(priorities[category])
        if configured_priority == nil or configured_priority < 1
            or configured_priority > #Categories.ORDER
            or configured_priority % 1 ~= 0 then
            return DEFAULT_CATEGORY_SORT_ORDER[category]
        end
        return configured_priority
    end

    local function GetItemSortName(item)
        if item == nil then
            return ""
        end

        return tostring(item.prefab or item.name or "")
    end

    local function GetItemSkinName(item)
        if item == nil then
            return ""
        end

        if item.skinname ~= nil then
            return tostring(item.skinname)
        end

        if item.GetSkinName ~= nil then
            return tostring(item:GetSkinName() or "")
        end

        return ""
    end

    local function CanMergeStacks(target, source)
        if target == nil or source == nil or target == source then
            return false
        end

        if target.prefab ~= source.prefab then
            return false
        end

        if GetItemSkinName(target) ~= GetItemSkinName(source) then
            return false
        end

        local target_stack = target.components ~= nil and target.components.stackable or nil
        local source_stack = source.components ~= nil and source.components.stackable or nil

        return target_stack ~= nil
            and source_stack ~= nil
            and target_stack.CanStackWith ~= nil
            and target_stack:CanStackWith(source)
            and target_stack.IsFull ~= nil
            and not target_stack:IsFull()
    end

    local function TryMergeStackInto(target, source)
        if not CanMergeStacks(target, source) then
            return false
        end

        local target_stack = target.components.stackable

        if target_stack.Put ~= nil then
            target_stack:Put(source)
            return source:IsValid() == false
                or source.components == nil
                or source.components.stackable == nil
                or source.components.stackable:StackSize() <= 0
        end

        return false
    end

    local function MergePartialStacks(items)
        if not CONFIG.sort_merge_stacks then
            return items
        end

        local merged = {}

        for _, item in ipairs(items) do
            if item ~= nil and item:IsValid() then
                local absorbed = false

                for _, target in ipairs(merged) do
                    if target ~= nil and target:IsValid() and TryMergeStackInto(target, item) then
                        absorbed = true
                        break
                    end
                end

                if not absorbed and item:IsValid() then
                    table.insert(merged, item)
                end
            end
        end

        return merged
    end

    local function GetStackSize(item)
        local stackable = item ~= nil and item.components ~= nil and item.components.stackable or nil
        return stackable ~= nil and stackable.StackSize ~= nil and stackable:StackSize() or 1
    end

    local function SnapshotSlots(slot_owner, num_slots)
        local snapshot = {}
        for slot = 1, num_slots do
            local item = slot_owner:GetItemInSlot(slot)
            snapshot[slot] = {
                item = item,
                stack_size = GetStackSize(item),
            }
        end
        return snapshot
    end

    local function SlotsChanged(snapshot, slot_owner, num_slots)
        for slot = 1, num_slots do
            local item = slot_owner:GetItemInSlot(slot)
            local previous = snapshot[slot]
            if previous == nil or previous.item ~= item or previous.stack_size ~= GetStackSize(item) then
                return true
            end
        end
        return false
    end

    local ITEM_CONDITION_COMPONENTS = { "finiteuses", "fueled", "armor", "perishable" }

    local function GetItemConditionPercent(item)
        local components = item ~= nil and item.components or nil
        if components == nil then
            return nil
        end

        -- These components all expose GetPercent() as a normalized 0..1 value.
        -- Use the first applicable condition so identical items sort from most to
        -- least usable without coupling the comparator to individual prefabs.
        for _, component_name in ipairs(ITEM_CONDITION_COMPONENTS) do
            local component = components[component_name]
            if component ~= nil and component.GetPercent ~= nil then
                return component:GetPercent()
            end
        end

        return nil
    end

    local function SortItemsForInventory(items, category_priorities)
        if CONFIG.sort_mode == "compact" then
            return items
        end

        -- Precompute one immutable key per item. Comparing cached keys keeps
        -- the comparator a strict weak order: comparing live values could
        -- break transitivity when condition-tracked and condition-less items
        -- mix, and table.sort may abort on an inconsistent comparator. Items
        -- without a condition component count as pristine. The original index
        -- makes the sort stable, so equal items keep their relative order
        -- between repeated sorts.
        local sort_keys = {}
        for index, item in ipairs(items) do
            local category = GetInventorySortCategoryName(item)
            local stackable = item.components ~= nil and item.components.stackable or nil
            sort_keys[item] = {
                priority = GetInventorySortCategory(item, category_priorities),
                -- Duplicate custom priorities are valid. Resolve them with the
                -- default category order so configuration mistakes remain stable.
                default_priority = DEFAULT_CATEGORY_SORT_ORDER[category] or (#Categories.ORDER + 1),
                name = GetItemSortName(item),
                stack_size = stackable ~= nil and stackable.StackSize ~= nil
                    and stackable:StackSize() or 1,
                condition = GetItemConditionPercent(item) or 1,
                original_order = index,
            }
        end

        table.sort(items, function(a, b)
            local ka = sort_keys[a]
            local kb = sort_keys[b]
            if ka.priority ~= kb.priority then
                return ka.priority < kb.priority
            end
            if ka.default_priority ~= kb.default_priority then
                return ka.default_priority < kb.default_priority
            end
            if ka.name ~= kb.name then
                return ka.name < kb.name
            end
            if ka.stack_size ~= kb.stack_size then
                return ka.stack_size > kb.stack_size
            end
            if ka.condition ~= kb.condition then
                return ka.condition > kb.condition
            end
            return ka.original_order < kb.original_order
        end)

        return items
    end

    local function IsItemAttachedToInventory(item)
        local inventoryitem = item ~= nil and item.components ~= nil and item.components.inventoryitem or nil
        return inventoryitem ~= nil and inventoryitem.owner ~= nil
    end

    local function GetPlayerCategoryPriorities(player)
        local preferences = player ~= nil and player.components ~= nil
            and player.components.betterinventory_sortprefs or nil
        return preferences ~= nil and preferences:GetPriorities()
            or CONFIGURED_CATEGORY_SORT_ORDER
    end

    local function ShouldSortBagWithInventory(player)
        local preferences = player ~= nil and player.components ~= nil
            and player.components.betterinventory_sortprefs or nil
        return CONFIG.bag_sort_enabled and preferences ~= nil
            and preferences.sort_bag_with_inventory == true
    end

    local function RestoreDetachedSortItems(inventory, records)
        for _, record in ipairs(records) do
            local item = record.item
            if item ~= nil and item:IsValid() and not IsItemAttachedToInventory(item) then
                local preferred_slot = inventory:GetItemInSlot(record.slot) == nil and record.slot or nil
                local given = inventory:GiveItem(item, preferred_slot)
                if not given and item:IsValid() and not IsItemAttachedToInventory(item) then
                    inventory:GiveItem(item)
                end
            end
        end
    end

    local function CanContainerTakeItemInSlot(container, item, slot)
        return container.CanTakeItemInSlot == nil or container:CanTakeItemInSlot(item, slot)
    end

    local function RestoreDetachedBagSortItems(player, container, records)
        local inventory = player ~= nil and player.components ~= nil and player.components.inventory or nil

        for _, record in ipairs(records) do
            local item = record.item
            if item ~= nil and item:IsValid() and not IsItemAttachedToInventory(item) then
                local preferred_slot = container:GetItemInSlot(record.slot) == nil
                    and CanContainerTakeItemInSlot(container, item, record.slot)
                    and record.slot or nil

                container:GiveItem(item, preferred_slot, nil, false)
                if item:IsValid() and not IsItemAttachedToInventory(item) then
                    container:GiveItem(item, nil, nil, false)
                end

                -- Error recovery may cross back into the main inventory, but only
                -- as a last resort to guarantee that an ownerless item is not lost.
                if item:IsValid() and not IsItemAttachedToInventory(item) and inventory ~= nil then
                    DebugWarn("Bag sort recovered " .. tostring(item.prefab) .. " into main inventory")
                    inventory:GiveItem(item)
                end
            end
        end
    end

    local function SortInventoryForPlayer(player)
        if not CONFIG.sort_enabled then
            return false
        end

        if player == nil or not player:IsValid() or player.components == nil or player.components.inventory == nil then
            return false
        end

        local inventory = player.components.inventory
        local slot_locks = player.components.betterinventory_slotlocks
        if inventory.isloading or inventory:GetActiveItem() ~= nil then
            DebugLog("Rejected sort while inventory is loading or holding an active item")
            return false
        end

        local num_slots = inventory.GetNumSlots ~= nil and inventory:GetNumSlots() or MAX_ITEM_SLOTS
        num_slots = math.min(num_slots or MAX_ITEM_SLOTS, MAX_ITEM_SLOTS)
        local before_slots = SnapshotSlots(inventory, num_slots)

        local items = {}
        local occupied_slots = {}
        local removed_records = {}

        local ok, err = GLOBAL.pcall(function()
            for slot = 1, num_slots do
                local item = inventory:GetItemInSlot(slot)
                if slot_locks ~= nil and slot_locks:IsLocked(slot) then
                    occupied_slots[slot] = true
                elseif item ~= nil then
                    local inventoryitem = item.components ~= nil and item.components.inventoryitem or nil
                    if inventoryitem ~= nil and inventoryitem.islockedinslot then
                        occupied_slots[slot] = true
                    else
                        local removed = inventory:RemoveItem(item, true)
                        if removed ~= nil then
                            table.insert(items, removed)
                            table.insert(removed_records, { item = removed, slot = slot })
                        else
                            occupied_slots[slot] = true
                            DebugWarn("Sort kept item in slot " .. tostring(slot) .. ": removal failed")
                        end
                    end
                end
            end

            items = MergePartialStacks(items)
            items = SortItemsForInventory(items, GetPlayerCategoryPriorities(player))

            local slot = 1
            for _, item in ipairs(items) do
                if item ~= nil and item:IsValid() then
                    while slot <= num_slots and (occupied_slots[slot] or inventory:GetItemInSlot(slot) ~= nil) do
                        slot = slot + 1
                    end

                    if slot > num_slots then
                        DebugWarn("Sort ran out of slots; returning " .. tostring(item.prefab))
                        inventory:GiveItem(item)
                    else
                        local given = inventory:GiveItem(item, slot)
                        if not given then
                            DebugWarn("Sort could not place " .. tostring(item.prefab)
                                .. " in slot " .. tostring(slot))
                            inventory:GiveItem(item)
                        end
                        slot = slot + 1
                    end
                end
            end
        end)

        -- Whether the operation completed or raised, never leave a valid removed
        -- item ownerless. Merged source stacks may be invalid by design and are
        -- therefore skipped.
        RestoreDetachedSortItems(inventory, removed_records)

        if not ok then
            DebugWarn("Sort transaction recovered after error: " .. tostring(err))
            return false
        end

        DebugLog("Sorted inventory for " .. tostring(player.name or player.prefab or "player")
            .. " using mode=" .. tostring(CONFIG.sort_mode)
            .. ", merge_stacks=" .. tostring(CONFIG.sort_merge_stacks))
        return SlotsChanged(before_slots, inventory, num_slots)
    end

    local function SortBagForPlayer(player)
        if not CONFIG.bag_sort_enabled then
            return false
        end

        if player == nil or not player:IsValid() or player.components == nil
            or player.components.inventory == nil then
            return false
        end

        local inventory = player.components.inventory
        if inventory.isloading or inventory:GetActiveItem() ~= nil then
            DebugLog("Rejected bag sort while inventory is loading or holding an active item")
            return false
        end

        local container = inventory:GetOverflowContainer()
        if container == nil or container.inst == nil or not container.inst:IsValid()
            or container.readonlycontainer or container.RemoveItemBySlot == nil
            or container.GiveItem == nil then
            DebugLog("Rejected bag sort: no writable equipped bag")
            return false
        end

        local num_slots = container.GetNumSlots ~= nil and container:GetNumSlots() or 0
        if num_slots <= 0 then
            return false
        end
        local before_slots = SnapshotSlots(container, num_slots)

        local items = {}
        local occupied_slots = {}
        local removed_records = {}

        local ok, err = GLOBAL.pcall(function()
            for slot = 1, num_slots do
                local item = container:GetItemInSlot(slot)
                if item ~= nil then
                    local inventoryitem = item.components ~= nil and item.components.inventoryitem or nil
                    if inventoryitem ~= nil and inventoryitem.islockedinslot then
                        occupied_slots[slot] = true
                    else
                        local removed = container:RemoveItemBySlot(slot)
                        if removed ~= nil then
                            table.insert(items, removed)
                            table.insert(removed_records, { item = removed, slot = slot })
                        else
                            occupied_slots[slot] = true
                            DebugWarn("Bag sort kept item in slot " .. tostring(slot) .. ": removal failed")
                        end
                    end
                end
            end

            items = MergePartialStacks(items)
            items = SortItemsForInventory(items, GetPlayerCategoryPriorities(player))

            for _, item in ipairs(items) do
                if item ~= nil and item:IsValid() then
                    local target_slot = nil
                    for slot = 1, num_slots do
                        if not occupied_slots[slot] and container:GetItemInSlot(slot) == nil
                            and CanContainerTakeItemInSlot(container, item, slot) then
                            target_slot = slot
                            break
                        end
                    end

                    if target_slot == nil then
                        DebugWarn("Bag sort found no valid slot for " .. tostring(item.prefab))
                    else
                        local given = container:GiveItem(item, target_slot, nil, false)
                        if not given and item:IsValid() and not IsItemAttachedToInventory(item) then
                            DebugWarn("Bag sort could not place " .. tostring(item.prefab)
                                .. " in slot " .. tostring(target_slot))
                        end
                    end
                end
            end
        end)

        RestoreDetachedBagSortItems(player, container, removed_records)

        if not ok then
            DebugWarn("Bag sort transaction recovered after error: " .. tostring(err))
            return false
        end

        DebugLog("Sorted equipped bag for " .. tostring(player.name or player.prefab or "player")
            .. " using mode=" .. tostring(CONFIG.sort_mode)
            .. ", merge_stacks=" .. tostring(CONFIG.sort_merge_stacks))
        return SlotsChanged(before_slots, container, num_slots)
    end

    local function SortInventoryAndMaybeBagForPlayer(player)
        local inventory_changed = SortInventoryForPlayer(player)
        if not ShouldSortBagWithInventory(player) then
            return inventory_changed
        end

        local bag_changed = SortBagForPlayer(player)
        return inventory_changed or bag_changed
    end

    local function QuickStackToBagForPlayer(player)
        if not CONFIG.quick_stack_enabled then
            return false
        end

        if player == nil or not player:IsValid() or player.components == nil
            or player.components.inventory == nil then
            return false
        end

        local inventory = player.components.inventory
        local slot_locks = player.components.betterinventory_slotlocks
        if inventory.isloading or inventory:GetActiveItem() ~= nil then
            DebugLog("Rejected quick stack while inventory is loading or holding an active item")
            return false
        end

        local container = inventory:GetOverflowContainer()
        if container == nil or container.inst == nil or not container.inst:IsValid()
            or container.readonlycontainer or container.GetNumSlots == nil
            or container.GetItemInSlot == nil then
            DebugLog("Rejected quick stack: no writable equipped bag")
            return false
        end

        local bag_targets = {}
        for slot = 1, container:GetNumSlots() do
            local item = container:GetItemInSlot(slot)
            local stackable = item ~= nil and item.components ~= nil and item.components.stackable or nil
            if stackable ~= nil and stackable.IsFull ~= nil and not stackable:IsFull() then
                table.insert(bag_targets, item)
            end
        end

        if #bag_targets == 0 then
            return false
        end

        local num_slots = inventory.GetNumSlots ~= nil and inventory:GetNumSlots() or MAX_ITEM_SLOTS
        num_slots = math.min(num_slots or MAX_ITEM_SLOTS, MAX_ITEM_SLOTS)

        local removed_records = {}
        local moved_units = 0
        local ok, err = GLOBAL.pcall(function()
            for slot = 1, num_slots do
                local source = inventory:GetItemInSlot(slot)
                local inventoryitem = source ~= nil and source.components ~= nil
                    and source.components.inventoryitem or nil
                local manually_locked = slot_locks ~= nil and slot_locks:IsLocked(slot)
                local built_in_locked = inventoryitem ~= nil and inventoryitem.islockedinslot

                if source ~= nil and not manually_locked and not built_in_locked then
                    local has_compatible_target = false
                    for _, target in ipairs(bag_targets) do
                        if target ~= nil and target:IsValid() and CanMergeStacks(target, source) then
                            has_compatible_target = true
                            break
                        end
                    end

                    if has_compatible_target then
                        local removed = inventory:RemoveItem(source, true)
                        if removed ~= nil then
                            table.insert(removed_records, { item = removed, slot = slot })

                            for _, target in ipairs(bag_targets) do
                                if removed:IsValid() and target ~= nil and target:IsValid()
                                    and CanMergeStacks(target, removed) then
                                    local source_stack = removed.components.stackable
                                    local before = source_stack:StackSize()
                                    TryMergeStackInto(target, removed)
                                    local after = removed:IsValid() and removed.components ~= nil
                                        and removed.components.stackable ~= nil
                                        and removed.components.stackable:StackSize() or 0
                                    moved_units = moved_units + math.max(0, before - after)
                                end
                            end
                        else
                            DebugWarn("Quick stack kept item in slot " .. tostring(slot)
                                .. ": removal failed")
                        end
                    end
                end
            end
        end)

        RestoreDetachedSortItems(inventory, removed_records)

        if not ok then
            DebugWarn("Quick stack transaction recovered after error: " .. tostring(err))
            return false
        end

        DebugLog("Quick stacked " .. tostring(moved_units) .. " item(s) into equipped bag for "
            .. tostring(player.name or player.prefab or "player"))
        return moved_units
    end

    local function HandleInventoryRPC(player, operation, label, success_callback)
        if player == nil or not player:IsValid() then
            return
        end

        local now = GLOBAL.GetTime()
        local state = SORT_REQUEST_STATE[player]
        if state == nil then
            state = { busy = false, last_request = {} }
            SORT_REQUEST_STATE[player] = state
        end

        -- busy guards re-entrancy across every inventory operation, while the
        -- spam cooldown is tracked per operation so that for example a sort
        -- followed by a quick stack is not silently dropped.
        local last_request = state.last_request[label] or -SORT_RPC_COOLDOWN
        if state.busy or now - last_request < SORT_RPC_COOLDOWN then
            DebugLog("Rejected duplicate " .. tostring(label) .. " RPC for "
                .. tostring(player.userid or player.GUID))
            return
        end

        if player.sg ~= nil and player.sg:HasStateTag("busy") then
            DebugLog("Rejected " .. tostring(label) .. " RPC while player is busy")
            return
        end

        state.last_request[label] = now
        state.busy = true
        local ok, result = GLOBAL.pcall(operation, player)
        state.busy = false

        if not ok then
            DebugWarn("Unhandled " .. tostring(label) .. " RPC error: " .. tostring(result))
        elseif success_callback ~= nil then
            local callback_ok, callback_err = GLOBAL.pcall(success_callback, player, result)
            if not callback_ok then
                DebugWarn("Unhandled " .. tostring(label) .. " result error: "
                    .. tostring(callback_err))
            end
        end
    end

    local function SendQuickStackResult(player, moved_units)
        moved_units = GLOBAL.tonumber(moved_units) or 0
        if moved_units <= 0 or player == nil or player.userid == nil then
            return
        end

        local rpc = GLOBAL.GetClientModRPC(SORT_RPC_NAMESPACE, QUICK_STACK_RESULT_RPC_NAME)
        GLOBAL.SendModRPCToClient(rpc, player.userid, moved_units)
    end

    local function SendSortFeedbackResult(player, changed)
        if not changed or player == nil or player.userid == nil then
            return
        end

        local rpc = GLOBAL.GetClientModRPC(SORT_RPC_NAMESPACE, SORT_FEEDBACK_RESULT_RPC_NAME)
        GLOBAL.SendModRPCToClient(rpc, player.userid, 1)
    end

    local function SendSortOrderState(player)
        if player == nil or player.userid == nil then
            return
        end

        local preferences = player.components ~= nil
            and player.components.betterinventory_sortprefs or nil
        local active_preset = preferences ~= nil and preferences.active_preset or "default"
        local current_orders = {}
        local base_orders = {}
        for _, key in ipairs(Categories.PRESET_KEYS) do
            current_orders[key] = preferences ~= nil and preferences:GetPresetOrder(key)
                or Categories.GetBasePresetOrder(key, CONFIGURED_CATEGORY_SORT_ORDER)
            base_orders[key] = Categories.GetBasePresetOrder(key,
                preferences ~= nil and preferences.default_priorities
                    or CONFIGURED_CATEGORY_SORT_ORDER)
        end
        local current_settings = {
            sort_bag_with_inventory = preferences ~= nil
                and preferences.sort_bag_with_inventory == true,
            bag_sort_available = CONFIG.bag_sort_enabled == true,
        }
        local default_settings = {
            sort_bag_with_inventory = false,
            bag_sort_available = CONFIG.bag_sort_enabled == true,
        }
        local current = Categories.SerializePresetState(active_preset, current_orders,
            current_settings)
        local defaults = Categories.SerializePresetState(active_preset, base_orders,
            default_settings)
        if current == nil or defaults == nil then
            return
        end

        local rpc = GLOBAL.GetClientModRPC(SORT_RPC_NAMESPACE, SORT_ORDER_STATE_RPC_NAME)
        GLOBAL.SendModRPCToClient(rpc, player.userid, current, defaults)
    end

    -- Request (panel open) and Apply are rate limited independently: a shared
    -- timestamp could silently drop an Apply arriving right after the
    -- panel-open request, losing the player's edits with no feedback.
    local function CanUpdateSortOrder(player, action)
        if player == nil or not player:IsValid() or player.components == nil
            or player.components.betterinventory_sortprefs == nil then
            return false
        end

        local state = SORT_ORDER_REQUEST_STATE[player]
        if state == nil then
            state = {}
            SORT_ORDER_REQUEST_STATE[player] = state
        end

        local now = GLOBAL.GetTime()
        local last_request = state[action] or -SORT_ORDER_RPC_COOLDOWN
        if now - last_request < SORT_ORDER_RPC_COOLDOWN then
            return false
        end
        state[action] = now
        return true
    end

    local api = {
        CanMergeStacks = CanMergeStacks,
        GetInventorySortCategory = GetInventorySortCategory,
        GetInventorySortCategoryName = GetInventorySortCategoryName,
        QuickStackToBagForPlayer = QuickStackToBagForPlayer,
        SortItemsForInventory = SortItemsForInventory,
    }

    if context.install_handlers == false then
        return api
    end

    local sort_order_enabled = CONFIG.sort_enabled or CONFIG.bag_sort_enabled

    if sort_order_enabled or CONFIG.quick_stack_enabled then
        if AddClientModRPCHandler ~= nil then
            if sort_order_enabled then
                AddClientModRPCHandler(SORT_RPC_NAMESPACE, SORT_FEEDBACK_RESULT_RPC_NAME,
                    function(changed)
                        changed = GLOBAL.tonumber(changed) or 0
                        local sound = GLOBAL.TheFrontEnd ~= nil and GLOBAL.TheFrontEnd:GetSound() or nil
                        if changed > 0 and sound ~= nil then
                            sound:PlaySound("dontstarve/HUD/click_move")
                        end
                    end)

                AddClientModRPCHandler(SORT_RPC_NAMESPACE, SORT_ORDER_STATE_RPC_NAME,
                    function(current_serialized, default_serialized)
                        if GLOBAL.TheFrontEnd == nil then
                            return
                        end

                        if ACTIVE_SORT_ORDER_SCREEN ~= nil then
                            GLOBAL.TheFrontEnd:PopScreen(ACTIVE_SORT_ORDER_SCREEN)
                        end

                        local SortOrderScreen = require("widgets/betterinventory_sortorderscreen")
                        local screen
                        screen = SortOrderScreen(current_serialized, default_serialized,
                            function(serialized)
                                local rpc = GLOBAL.GetModRPC(SORT_RPC_NAMESPACE,
                                    SORT_ORDER_APPLY_RPC_NAME)
                                GLOBAL.SendModRPCToServer(rpc, serialized)
                            end,
                            function()
                                if ACTIVE_SORT_ORDER_SCREEN == screen then
                                    ACTIVE_SORT_ORDER_SCREEN = nil
                                end
                            end,
                            GetHudSettings ~= nil and GetHudSettings() or nil,
                            ApplyHudSettings ~= nil and function(settings)
                                ApplyHudSettings(settings, true)
                            end or nil,
                            HudScaleOptions)
                        ACTIVE_SORT_ORDER_SCREEN = screen
                        GLOBAL.TheFrontEnd:PushScreen(screen)
                    end)
            end
        end

        if sort_order_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, SORT_ORDER_REQUEST_RPC_NAME, function(player)
                if CanUpdateSortOrder(player, "request") then
                    SendSortOrderState(player)
                end
            end)

            AddModRPCHandler(SORT_RPC_NAMESPACE, SORT_ORDER_APPLY_RPC_NAME,
                function(player, serialized)
                    if not CanUpdateSortOrder(player, "apply") then
                        return
                    end

                    local preferences = player.components.betterinventory_sortprefs
                    local active_preset, orders, settings =
                        Categories.DeserializePresetState(serialized)
                    if active_preset == nil
                        or not preferences:SetState(active_preset, orders, settings) then
                        DebugWarn("Rejected invalid sort-order request for "
                            .. tostring(player.userid or player.GUID))
                        return
                    end

                    SendSortFeedbackResult(player, true)
                    DebugLog("Updated sort order for " .. tostring(player.userid or player.GUID))
                end)
        end

        if CONFIG.quick_stack_enabled and AddClientModRPCHandler ~= nil then
            AddClientModRPCHandler(SORT_RPC_NAMESPACE, QUICK_STACK_RESULT_RPC_NAME,
                function(moved_units)
                    moved_units = GLOBAL.tonumber(moved_units) or 0
                    local sound = GLOBAL.TheFrontEnd ~= nil and GLOBAL.TheFrontEnd:GetSound() or nil
                    if moved_units > 0 and sound ~= nil then
                        sound:PlaySound("dontstarve/HUD/click_move")
                    end
                end)
        end

        if CONFIG.sort_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, SORT_RPC_NAME, function(player)
                HandleInventoryRPC(player, SortInventoryAndMaybeBagForPlayer, "inventory sort",
                    SendSortFeedbackResult)
            end)
        end

        if CONFIG.bag_sort_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, BAG_SORT_RPC_NAME, function(player)
                HandleInventoryRPC(player, SortBagForPlayer, "bag sort",
                    SendSortFeedbackResult)
            end)
        end

        if CONFIG.quick_stack_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, QUICK_STACK_RPC_NAME, function(player)
                HandleInventoryRPC(player, QuickStackToBagForPlayer, "quick stack",
                    SendQuickStackResult)
            end)
        end

        if not (TheNet ~= nil and TheNet.IsDedicated ~= nil and TheNet:IsDedicated()) then
            local KEY_MAP = {
                KEY_F5 = GLOBAL.KEY_F5,
                KEY_F6 = GLOBAL.KEY_F6,
                KEY_F7 = GLOBAL.KEY_F7,
                KEY_F8 = GLOBAL.KEY_F8,
                KEY_F9 = GLOBAL.KEY_F9,
                KEY_F10 = GLOBAL.KEY_F10,
                KEY_B = GLOBAL.KEY_B,
                KEY_G = GLOBAL.KEY_G,
                KEY_R = GLOBAL.KEY_R,
                KEY_C = GLOBAL.KEY_C,
                KEY_V = GLOBAL.KEY_V,
            }

            local function ResolveKey(config_key, fallback)
                if config_key == "KEY_NONE" then
                    return nil
                end
                return KEY_MAP[config_key] or fallback
            end

            local sort_key = ResolveKey(CONFIG.sort_key, GLOBAL.KEY_F7)
            local bag_sort_key = ResolveKey(CONFIG.bag_sort_key, nil)
            local quick_stack_key = ResolveKey(CONFIG.quick_stack_key, nil)
            local sort_order_key = ResolveKey(CONFIG.sort_order_key, GLOBAL.KEY_F8)

            local function CanUseSortHotkey()
                if GLOBAL.ThePlayer == nil or GLOBAL.ThePlayer.HUD == nil then
                    return false
                end

                if GLOBAL.ThePlayer.HUD.HasInputFocus ~= nil and GLOBAL.ThePlayer.HUD:HasInputFocus() then
                    return false
                end

                if GLOBAL.ThePlayer.sg ~= nil and GLOBAL.ThePlayer.sg:HasStateTag("busy") then
                    return false
                end

                return true
            end

            local function SendSortRPC(rpc_name)
                if not CanUseSortHotkey() then
                    return
                end

                local rpc_namespace = GLOBAL.MOD_RPC ~= nil and GLOBAL.MOD_RPC[SORT_RPC_NAMESPACE] or nil
                local rpc = rpc_namespace ~= nil and rpc_namespace[rpc_name] or nil
                if rpc ~= nil then
                    GLOBAL.SendModRPCToServer(rpc)
                end
            end

            if CONFIG.sort_enabled and sort_key ~= nil
                and not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_SORT_HOTKEY_ADDED") then
                GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_SORT_HOTKEY_ADDED", true)

                GLOBAL.TheInput:AddKeyDownHandler(sort_key, function()
                    SendSortRPC(SORT_RPC_NAME)
                end)

                DebugLog("Inventory sort hotkey registered: " .. tostring(CONFIG.sort_key))
            end

            if CONFIG.bag_sort_enabled and bag_sort_key ~= nil then
                if CONFIG.sort_enabled and bag_sort_key == sort_key then
                    DebugWarn("Bag sort hotkey matches inventory sort hotkey; bag hotkey disabled")
                elseif not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_BAG_SORT_HOTKEY_ADDED") then
                    GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_BAG_SORT_HOTKEY_ADDED", true)

                    GLOBAL.TheInput:AddKeyDownHandler(bag_sort_key, function()
                        SendSortRPC(BAG_SORT_RPC_NAME)
                    end)

                    DebugLog("Bag sort hotkey registered: " .. tostring(CONFIG.bag_sort_key))
                end
            end

            if CONFIG.quick_stack_enabled and quick_stack_key ~= nil then
                local conflicts_with_sort = CONFIG.sort_enabled and quick_stack_key == sort_key
                local conflicts_with_bag_sort = CONFIG.bag_sort_enabled and quick_stack_key == bag_sort_key
                if conflicts_with_sort or conflicts_with_bag_sort then
                    DebugWarn("Quick stack hotkey matches a sort hotkey; quick stack hotkey disabled")
                elseif not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_QUICK_STACK_HOTKEY_ADDED") then
                    GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_QUICK_STACK_HOTKEY_ADDED", true)

                    GLOBAL.TheInput:AddKeyDownHandler(quick_stack_key, function()
                        SendSortRPC(QUICK_STACK_RPC_NAME)
                    end)

                    DebugLog("Quick stack hotkey registered: " .. tostring(CONFIG.quick_stack_key))
                end
            end

            if sort_order_enabled and sort_order_key ~= nil then
                local conflicts_with_sort = CONFIG.sort_enabled and sort_order_key == sort_key
                local conflicts_with_bag_sort = CONFIG.bag_sort_enabled and sort_order_key == bag_sort_key
                local conflicts_with_quick_stack = CONFIG.quick_stack_enabled
                    and sort_order_key == quick_stack_key
                if conflicts_with_sort or conflicts_with_bag_sort or conflicts_with_quick_stack then
                    DebugWarn("Sort order panel hotkey conflicts with an inventory hotkey; panel hotkey disabled")
                elseif not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_SORT_ORDER_HOTKEY_ADDED") then
                    GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_SORT_ORDER_HOTKEY_ADDED", true)

                    GLOBAL.TheInput:AddKeyDownHandler(sort_order_key, function()
                        if ACTIVE_SORT_ORDER_SCREEN ~= nil then
                            GLOBAL.TheFrontEnd:PopScreen(ACTIVE_SORT_ORDER_SCREEN)
                            return
                        end
                        SendSortRPC(SORT_ORDER_REQUEST_RPC_NAME)
                    end)

                    DebugLog("Sort order panel hotkey registered: "
                        .. tostring(CONFIG.sort_order_key))
                end
            end
        end
    end


    return api
end

return Sorting
