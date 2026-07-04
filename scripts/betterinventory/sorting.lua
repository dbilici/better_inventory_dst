local Sorting = {}

function Sorting.Setup(context)
    assert(context ~= nil, "Better Inventory sorting context is required")

    local GLOBAL = assert(context.GLOBAL, "GLOBAL is required")
    local CONFIG = assert(context.config, "sorting config is required")
    local MAX_ITEM_SLOTS = assert(context.max_item_slots, "max item slots is required")
    local SLOT_DEFS = assert(context.slot_defs, "slot definitions are required")
    local DebugLog = context.debug_log or function() end
    local DebugWarn = context.debug_warn or function() end
    local AddModRPCHandler = context.add_mod_rpc_handler
    local TheNet = GLOBAL.TheNet

    local SORT_RPC_NAMESPACE = "BetterInventory"
    local SORT_RPC_NAME = "SortInventory"
    local BAG_SORT_RPC_NAME = "SortBag"
    local SORT_RPC_COOLDOWN = 0.75
    local SORT_REQUEST_STATE = GLOBAL.setmetatable({}, { __mode = "k" })

    local CATEGORY_SORT_ORDER = {
        tool = 10,
        weapon = 20,
        armor = 30,
        bag = 35,
        accessory = 40,
        clothing = 45,
        food = 50,
        healing = 55,
        light = 60,
        fuel = 65,
        material = 70,
        magic = 80,
        trinket = 90,
        misc = 100,
    }

    local function SafeHasTag(item, tag)
        return item ~= nil and item.HasTag ~= nil and item:HasTag(tag)
    end

    local function GetInventorySortCategory(item)
        if item == nil then
            return CATEGORY_SORT_ORDER.misc
        end

        local components = item.components or {}

        if components.tool ~= nil or SafeHasTag(item, "tool") then
            return CATEGORY_SORT_ORDER.tool
        end

        if components.weapon ~= nil or SafeHasTag(item, "weapon") then
            return CATEGORY_SORT_ORDER.weapon
        end

        if SafeHasTag(item, SLOT_DEFS.ARMOR.tag) or components.armor ~= nil or SafeHasTag(item, "armor") then
            return CATEGORY_SORT_ORDER.armor
        end

        if SafeHasTag(item, SLOT_DEFS.BAG.tag) or SafeHasTag(item, "backpack") then
            return CATEGORY_SORT_ORDER.bag
        end

        if SafeHasTag(item, SLOT_DEFS.ACCESSORY.tag) or SafeHasTag(item, "amulet") then
            return CATEGORY_SORT_ORDER.accessory
        end

        if components.equippable ~= nil then
            return CATEGORY_SORT_ORDER.clothing
        end

        if components.edible ~= nil or SafeHasTag(item, "preparedfood") or SafeHasTag(item, "cookable") then
            return CATEGORY_SORT_ORDER.food
        end

        if components.healer ~= nil then
            return CATEGORY_SORT_ORDER.healing
        end

        if components.fueled ~= nil or components.burnable ~= nil or SafeHasTag(item, "light") then
            return CATEGORY_SORT_ORDER.light
        end

        if components.fuel ~= nil or SafeHasTag(item, "fuel") then
            return CATEGORY_SORT_ORDER.fuel
        end

        if SafeHasTag(item, "gem") or SafeHasTag(item, "magic") then
            return CATEGORY_SORT_ORDER.magic
        end

        if SafeHasTag(item, "trinket") then
            return CATEGORY_SORT_ORDER.trinket
        end

        return CATEGORY_SORT_ORDER.material
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

    local function SortItemsForInventory(items)
        if CONFIG.sort_mode == "compact" then
            return items
        end

        -- Lua's table.sort is not stable. Remember the current order so otherwise
        -- equal items (for example torches with different durability) do not swap
        -- positions unpredictably between repeated sorts.
        local original_order = {}
        for index, item in ipairs(items) do
            original_order[item] = index
        end

        table.sort(items, function(a, b)
            local ca = GetInventorySortCategory(a)
            local cb = GetInventorySortCategory(b)
            if ca ~= cb then
                return ca < cb
            end

            local pa = GetItemSortName(a)
            local pb = GetItemSortName(b)
            if pa ~= pb then
                return pa < pb
            end

            local sa = a.components ~= nil and a.components.stackable ~= nil and a.components.stackable.StackSize ~= nil and a.components.stackable:StackSize() or 1
            local sb = b.components ~= nil and b.components.stackable ~= nil and b.components.stackable.StackSize ~= nil and b.components.stackable:StackSize() or 1
            if sa ~= sb then
                return sa > sb
            end

            local condition_a = GetItemConditionPercent(a)
            local condition_b = GetItemConditionPercent(b)
            if condition_a ~= nil and condition_b ~= nil and condition_a ~= condition_b then
                return condition_a > condition_b
            end

            return original_order[a] < original_order[b]
        end)

        return items
    end

    local function IsItemAttachedToInventory(item)
        local inventoryitem = item ~= nil and item.components ~= nil and item.components.inventoryitem or nil
        return inventoryitem ~= nil and inventoryitem.owner ~= nil
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
            items = SortItemsForInventory(items)

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
        return true
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
            items = SortItemsForInventory(items)

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
        return true
    end

    local function HandleSortRPC(player, sort_function, label)
        if player == nil or not player:IsValid() then
            return
        end

        local now = GLOBAL.GetTime()
        local state = SORT_REQUEST_STATE[player]
        if state == nil then
            state = { busy = false, last_request = -SORT_RPC_COOLDOWN }
            SORT_REQUEST_STATE[player] = state
        end

        if state.busy or now - state.last_request < SORT_RPC_COOLDOWN then
            DebugLog("Rejected duplicate " .. tostring(label) .. " RPC for "
                .. tostring(player.userid or player.GUID))
            return
        end

        if player.sg ~= nil and player.sg:HasStateTag("busy") then
            DebugLog("Rejected " .. tostring(label) .. " RPC while player is busy")
            return
        end

        state.last_request = now
        state.busy = true
        local ok, err = GLOBAL.pcall(sort_function, player)
        state.busy = false

        if not ok then
            DebugWarn("Unhandled " .. tostring(label) .. " RPC error: " .. tostring(err))
        end
    end

    local api = {
        GetInventorySortCategory = GetInventorySortCategory,
        SortItemsForInventory = SortItemsForInventory,
    }

    if context.install_handlers == false then
        return api
    end

    if CONFIG.sort_enabled or CONFIG.bag_sort_enabled then
        if CONFIG.sort_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, SORT_RPC_NAME, function(player)
                HandleSortRPC(player, SortInventoryForPlayer, "inventory sort")
            end)
        end

        if CONFIG.bag_sort_enabled then
            AddModRPCHandler(SORT_RPC_NAMESPACE, BAG_SORT_RPC_NAME, function(player)
                HandleSortRPC(player, SortBagForPlayer, "bag sort")
            end)
        end

        if not (TheNet ~= nil and TheNet.IsDedicated ~= nil and TheNet:IsDedicated()) then
            local KEY_MAP = {
                KEY_F5 = GLOBAL.KEY_F5,
                KEY_F6 = GLOBAL.KEY_F6,
                KEY_F7 = GLOBAL.KEY_F7,
                KEY_F8 = GLOBAL.KEY_F8,
                KEY_F9 = GLOBAL.KEY_F9,
                KEY_B = GLOBAL.KEY_B,
                KEY_G = GLOBAL.KEY_G,
                KEY_R = GLOBAL.KEY_R,
                KEY_C = GLOBAL.KEY_C,
                KEY_V = GLOBAL.KEY_V,
            }

            local sort_key = KEY_MAP[CONFIG.sort_key] or GLOBAL.KEY_F5
            local bag_sort_key = KEY_MAP[CONFIG.bag_sort_key] or GLOBAL.KEY_F6

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
        end
    end


    return api
end

return Sorting

