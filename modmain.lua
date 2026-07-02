-- Better Inventory
-- Clean-core merged foundation.
--
-- Goals for this build:
--   1. Keep the inventory expansion logic small and readable.
--   2. Register extra equipment slots without global namespace pollution.
--   3. Use vanilla-only item rules first; mod compatibility can be added later.
--   4. Remove Quick Draw entirely. Vanilla quick equip/swap already covers that role.

local GLOBAL = GLOBAL
local require = GLOBAL.require
local net_entity = GLOBAL.net_entity

local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local HUD_ATLAS = GLOBAL.HUD_ATLAS
local TheNet = GLOBAL.TheNet

local INVENTORY_BG_ATLAS = "images/inventory_bg.xml"
local INVENTORY_BG_IMAGE = "images/inventory_bg.tex"
local EQUIP_SLOT_ATLAS = "images/equip_slots.xml"
local EQUIP_SLOT_IMAGE = "images/equip_slots.tex"

Assets = {
    Asset("IMAGE", INVENTORY_BG_IMAGE),
    Asset("ATLAS", INVENTORY_BG_ATLAS),
    Asset("IMAGE", EQUIP_SLOT_IMAGE),
    Asset("ATLAS", EQUIP_SLOT_ATLAS),
}

--------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------

local CONFIG = {
    inventory_size = GetModConfigData("inventory_size") or 24,
    inventory_layout = GetModConfigData("inventory_layout") or "2x12",
    slot_bag = GetModConfigData("slot_bag") ~= false,
    slot_armor = GetModConfigData("slot_armor") ~= false,
    slot_accessory = GetModConfigData("slot_accessory") ~= false,
    sort_enabled = GetModConfigData("sort_enabled") ~= false,
    sort_mode = GetModConfigData("sort_mode") or "category",
    sort_merge_stacks = GetModConfigData("sort_merge_stacks") ~= false,
    sort_key = GetModConfigData("sort_key") or "KEY_F5",
    debug_mode = GetModConfigData("debug_mode") or "off",
}

local MAX_ITEM_SLOTS = CONFIG.inventory_size == 24 and 24 or 15
local USE_EXPANDED_INVENTORY = MAX_ITEM_SLOTS > 15
local USE_2X12_LAYOUT = USE_EXPANDED_INVENTORY and CONFIG.inventory_layout == "2x12"

--------------------------------------------------------------------------
-- Debug helper
--------------------------------------------------------------------------

local function DebugLog(message)
    if CONFIG.debug_mode == "off" then
        return
    end

    local line = "[Better Inventory] " .. tostring(message)
    print(line)

    if CONFIG.debug_mode == "chatlog" and GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        if GLOBAL.TheNet ~= nil then
            GLOBAL.TheNet:Announce(line)
        end
    end
end

--------------------------------------------------------------------------
-- Extra equipment slot definitions
--------------------------------------------------------------------------

local SLOT_DEFS = {
    BAG = {
        enabled = CONFIG.slot_bag,
        eslot = "extrabody1",
        global_key = "EXTRABODY1",
        image = "backpack.tex",
        tag = "betterinventory_bag",
        label = "Bag",
    },
    ARMOR = {
        enabled = CONFIG.slot_armor,
        eslot = "extrabody2",
        global_key = "EXTRABODY2",
        image = "armor.tex",
        tag = "betterinventory_armor",
        label = "Armor",
    },
    ACCESSORY = {
        enabled = CONFIG.slot_accessory,
        eslot = "extrabody3",
        global_key = "EXTRABODY3",
        image = "amulet.tex",
        tag = "betterinventory_accessory",
        label = "Accessory",
    },
}

local ENABLED_EXTRA_SLOTS = {}

for _, key in ipairs({"BAG", "ARMOR", "ACCESSORY"}) do
    local def = SLOT_DEFS[key]
    if def.enabled then
        EQUIPSLOTS[def.global_key] = def.eslot
        table.insert(ENABLED_EXTRA_SLOTS, def)
        DebugLog("Registered extra equip slot: " .. def.label .. " -> " .. def.eslot)
    end
end

local function IsExtraSlotEnabled(key)
    return SLOT_DEFS[key] ~= nil and SLOT_DEFS[key].enabled
end

local function GetSlotForRule(rule)
    local def = SLOT_DEFS[rule]
    return def ~= nil and def.enabled and def.eslot or EQUIPSLOTS.BODY
end

--------------------------------------------------------------------------
-- Vanilla-only item slot rules
--
-- Keep this list intentionally small while stabilizing the merged mod.
-- Large modded compatibility tables should be added later as a separate layer.
--------------------------------------------------------------------------

local ITEM_SLOT_RULES = {
    -- Bags
    backpack = "BAG",
    piggyback = "BAG",
    krampus_sack = "BAG",
    icepack = "BAG",
    spicepack = "BAG",
    seedpouch = "BAG",
    candybag = "BAG",

    -- Armor
    armorgrass = "ARMOR",
    armorwood = "ARMOR",
    armormarble = "ARMOR",
    armorruins = "ARMOR",
    armor_sanity = "ARMOR",
    armorskeleton = "ARMOR",
    armordragonfly = "ARMOR",
    armor_bramble = "ARMOR",
    armorslurper = "ARMOR",
    armorsnurtleshell = "ARMOR",
    armor_lunarplant = "ARMOR",
    armordreadstone = "ARMOR",
    armor_voidcloth = "ARMOR",

    -- Amulets / accessories
    amulet = "ACCESSORY",
    blueamulet = "ACCESSORY",
    purpleamulet = "ACCESSORY",
    orangeamulet = "ACCESSORY",
    greenamulet = "ACCESSORY",
    yellowamulet = "ACCESSORY",
}

local function ApplyEquipSlotRule(inst, rule)
    local def = SLOT_DEFS[rule]
    if def == nil or not def.enabled then
        return
    end

    if not inst:HasTag(def.tag) then
        inst:AddTag(def.tag)
    end

    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        if inst.components ~= nil and inst.components.equippable ~= nil then
            inst.components.equippable.equipslot = def.eslot

            DebugLog("Assigned " .. tostring(inst.prefab) .. " to " .. def.label .. " slot")
        else
            DebugLog("Skipped " .. tostring(inst.prefab) .. ": missing equippable component")
        end
    end
end

for prefab, rule in pairs(ITEM_SLOT_RULES) do
    AddPrefabPostInit(prefab, function(inst)
        ApplyEquipSlotRule(inst, rule)
    end)
end

--------------------------------------------------------------------------
-- Inventory slot expansion
--------------------------------------------------------------------------

if USE_EXPANDED_INVENTORY then
    local Inventory = require("components/inventory")
    local InventoryReplica = require("components/inventory_replica")

    -- Do not write new fields onto the inventory component instance here.
    -- DST class instances can be read-only after construction, and setting a
    -- custom self.maxslots field caused a startup crash. Expanding GetNumSlots
    -- is enough for the server-side inventory logic; inventory_classified below
    -- handles client replication for slots 16-24.

    if Inventory ~= nil and Inventory.GetNumSlots ~= nil then
        local Inventory_GetNumSlots_Base = Inventory.GetNumSlots
        function Inventory:GetNumSlots(...)
            local base = Inventory_GetNumSlots_Base(self, ...)
            return math.max(base or 0, MAX_ITEM_SLOTS)
        end
    end

    if InventoryReplica ~= nil then
        local InventoryReplica_GetNumSlots_Base = InventoryReplica.GetNumSlots
        function InventoryReplica:GetNumSlots(...)
            local base = InventoryReplica_GetNumSlots_Base ~= nil and InventoryReplica_GetNumSlots_Base(self, ...) or 0
            return math.max(base or 0, MAX_ITEM_SLOTS)
        end
    end

    AddPrefabPostInit("inventory_classified", function(inst)
        -- Client inventory replication only has vanilla item netvars by default.
        -- Extra slots need their own net_entity entries or clients can desync visually.
        if inst._items ~= nil and #inst._items < MAX_ITEM_SLOTS then
            for i = #inst._items + 1, MAX_ITEM_SLOTS do
                table.insert(inst._items, net_entity(inst.GUID, "inventory._items[" .. tostring(i) .. "]", "items[" .. tostring(i) .. "]dirty"))
            end
            DebugLog("inventory_classified netvars expanded to " .. tostring(MAX_ITEM_SLOTS))
        end
    end)
end

--------------------------------------------------------------------------
-- Inventory bar UI
--
-- Cleanup note:
-- We intentionally do not replace the full vanilla Rebuild implementation.
-- Vanilla still creates all slots; we only add extra equip slots and reposition
-- inventory/equipment slots afterward. This avoids copying old Klei internals.
--------------------------------------------------------------------------

local function AddExtraEquipSlotsToInventoryBar(self)
    if TheNet ~= nil and TheNet:GetServerGameMode() == "quagmire" then
        return
    end

    if GLOBAL.rawget(self, "_betterinventory_extra_slots_added") then
        return
    end
    GLOBAL.rawset(self, "_betterinventory_extra_slots_added", true)

    -- Keep body slot as the generic torso/clothing slot. Bags, armor and amulets
    -- receive their own optional slots.
    local sortkey_start = 1
    local sortkey_delta = 1 / (#ENABLED_EXTRA_SLOTS + 1)

    for i, def in ipairs(ENABLED_EXTRA_SLOTS) do
        self:AddEquipSlot(def.eslot, EQUIP_SLOT_ATLAS, def.image, sortkey_start + i * sortkey_delta)
    end
end

local function Reposition2x12InventoryBar(self)
    if not USE_2X12_LAYOUT or self.inv == nil then
        return
    end

    local W = 68
    local SEP = 12
    local ROW_SEP = 8
    local COLUMNS = 12
    local inventory_width = COLUMNS * W + (COLUMNS - 1) * SEP
    local row_step = W + ROW_SEP

    for slot_index, slot in pairs(self.inv) do
        if type(slot_index) == "number" and slot ~= nil and slot.SetPosition ~= nil then
            local index = slot_index - 1
            local col = index % COLUMNS
            local row = math.floor(index / COLUMNS)
            local x = -inventory_width / 2 + W / 2 + col * (W + SEP)
            local y = row == 0 and row_step / 2 or -row_step / 2
            slot:SetPosition(x, y, 0)
        end
    end

    -- Put equipment slots to the right as a compact 3-column block.
    if self.equip ~= nil and self.equipslotinfo ~= nil then
        local equip_start_x = inventory_width / 2 + 72
        local equip_start_y = row_step / 2
        local equip_columns = 3

        for i, info in ipairs(self.equipslotinfo) do
            local slot = self.equip[info.slot]
            if slot ~= nil and slot.SetPosition ~= nil then
                local index = i - 1
                local col = index % equip_columns
                local row = math.floor(index / equip_columns)
                slot:SetPosition(equip_start_x + col * (W + SEP), equip_start_y - row * row_step, 0)
            end
        end
    end

    -- Background scaling is intentionally conservative. The old mod stretched a
    -- single-row background heavily; this keeps the bar readable for testing.
    if self.bg ~= nil and self.bg.SetScale ~= nil then
        self.bg:SetScale(2.15, 1.65, 1)
    end
    if self.bgcover ~= nil and self.bgcover.SetScale ~= nil then
        self.bgcover:SetScale(2.15, 1.65, 1)
    end
end

local inventory_bar_rebuild_patched = false

AddClassPostConstruct("widgets/inventorybar", function(self)
    AddExtraEquipSlotsToInventoryBar(self)

    -- DST's mod environment does not always expose Lua's plain getmetatable
    -- in the sandbox. Use GLOBAL.getmetatable and keep the patch flag as a
    -- local upvalue instead of writing marker fields into Klei class tables.
    if not inventory_bar_rebuild_patched then
        local mt = GLOBAL.getmetatable ~= nil and GLOBAL.getmetatable(self) or nil
        local InventoryBarClass = mt ~= nil and mt.__index or nil

        if InventoryBarClass ~= nil and InventoryBarClass.Rebuild ~= nil then
            inventory_bar_rebuild_patched = true

            local Rebuild_Base = InventoryBarClass.Rebuild
            function InventoryBarClass:Rebuild(...)
                Rebuild_Base(self, ...)
                AddExtraEquipSlotsToInventoryBar(self)
                Reposition2x12InventoryBar(self)
            end
        else
            DebugLog("InventoryBar class patch skipped: metatable/index not available yet")
        end
    end

    Reposition2x12InventoryBar(self)
end)

--------------------------------------------------------------------------
-- Accessory slot compatibility fixes
--------------------------------------------------------------------------

if IsExtraSlotEnabled("ACCESSORY") then
    local ACCESSORY_SLOT = SLOT_DEFS.ACCESSORY.eslot

    AddStategraphPostInit("wilson", function(sg)
        local state = sg.states ~= nil and sg.states["amulet_rebirth"] or nil
        if state == nil then
            return
        end

        local OnEnter_Base = state.onenter
        state.onenter = function(inst, ...)
            if OnEnter_Base ~= nil then
                OnEnter_Base(inst, ...)
            end

            if inst.components ~= nil and inst.components.inventory ~= nil then
                local item = inst.components.inventory:GetEquippedItem(ACCESSORY_SLOT)
                if item ~= nil and item.prefab == "amulet" then
                    item = inst.components.inventory:RemoveItem(item)
                    if item ~= nil then
                        item:Remove()
                        inst.sg.statemem.betterinventory_usedamulet = true
                    end
                end
            end
        end

        local OnExit_Base = state.onexit
        state.onexit = function(inst, ...)
            if inst.sg ~= nil and inst.sg.statemem ~= nil and inst.sg.statemem.betterinventory_usedamulet then
                if inst.components ~= nil and inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(ACCESSORY_SLOT) == nil then
                    inst.AnimState:ClearOverrideSymbol("swap_body")
                end
            end

            if OnExit_Base ~= nil then
                OnExit_Base(inst, ...)
            end
        end
    end)

    local RecipePopup = require("widgets/recipepopup")
    if RecipePopup ~= nil and RecipePopup.Refresh ~= nil and not GLOBAL.rawget(RecipePopup, "_betterinventory_refresh_patched") then
        GLOBAL.rawset(RecipePopup, "_betterinventory_refresh_patched", true)
        local Refresh_Base = RecipePopup.Refresh
        function RecipePopup:Refresh(...)
            Refresh_Base(self, ...)

            if self.button ~= nil and self.button.IsVisible ~= nil and self.button:IsVisible()
                and self.owner ~= nil and self.owner.replica ~= nil and self.owner.replica.inventory ~= nil
                and self.amulet ~= nil then

                local equipped = self.owner.replica.inventory:GetEquippedItem(ACCESSORY_SLOT)
                if equipped ~= nil and equipped.prefab == "greenamulet" then
                    self.amulet:Show()
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- Sewing mannequin / punching bag compatibility
--------------------------------------------------------------------------

local function GetEquipmentSwapSlots()
    local slots = {
        EQUIPSLOTS.HANDS,
        EQUIPSLOTS.HEAD,
        EQUIPSLOTS.BODY,
    }

    for _, def in ipairs(ENABLED_EXTRA_SLOTS) do
        table.insert(slots, def.eslot)
    end

    return slots
end

local function InventoryHasAnyEquipment(inst, slots)
    if inst.components == nil or inst.components.inventory == nil then
        return false
    end

    for _, eslot in ipairs(slots) do
        if inst.components.inventory:GetEquippedItem(eslot) ~= nil then
            return true
        end
    end

    return false
end

local function CanSwapEquipment(inst, doer, slots)
    return InventoryHasAnyEquipment(inst, slots)
        or (doer ~= nil and InventoryHasAnyEquipment(doer, slots))
end

local function SwapEquipmentSlot(inst, doer, eslot)
    if inst.components == nil or inst.components.inventory == nil
        or doer.components == nil or doer.components.inventory == nil then
        return false
    end

    local doer_item = doer.components.inventory:Unequip(eslot)
    local inst_item = inst.components.inventory:Unequip(eslot)

    if doer_item == nil and inst_item == nil then
        return false
    end

    if inst_item ~= nil and inst_item.components ~= nil and inst_item.components.equippable ~= nil
        and not inst_item.components.equippable:IsRestricted(doer) then
        doer.components.inventory:Equip(inst_item)
    end

    if doer_item ~= nil and doer_item.components ~= nil and doer_item.components.equippable ~= nil
        and not doer_item.components.equippable:IsRestricted(inst) then
        inst.components.inventory:Equip(doer_item)
    end

    return true
end

local function ShouldAcceptEquipmentItem(inst, item, doer)
    if item == nil or item.components == nil or item.components.equippable == nil then
        return false, "GENERIC"
    end

    local item_slot = item.components.equippable.equipslot
    for _, eslot in ipairs(GetEquipmentSwapSlots()) do
        if item_slot == eslot then
            return true
        end
    end

    return false, "GENERIC"
end

if GLOBAL.TheNet ~= nil and GLOBAL.TheNet:GetIsServer() then
    AddPrefabPostInit("sewing_mannequin", function(inst)
        if inst.components == nil or inst.components.activatable == nil or inst.components.trader == nil then
            return
        end

        local slots = GetEquipmentSwapSlots()

        inst.components.activatable.OnActivate = function(target, doer)
            local function BecomeInactive()
                if target.components ~= nil and target.components.activatable ~= nil then
                    target.components.activatable.inactive = true
                end
            end
            target:DoTaskInTime(5 * GLOBAL.FRAMES, BecomeInactive)

            if CanSwapEquipment(target, doer, slots) then
                local swapped = false
                for _, eslot in ipairs(slots) do
                    swapped = SwapEquipmentSlot(target, doer, eslot) or swapped
                end

                if swapped then
                    target.AnimState:PlayAnimation("swap")
                    target.SoundEmitter:PlaySound("stageplay_set/mannequin/swap")
                    target.AnimState:PushAnimation("idle", false)
                    return true
                end

                return false, "MANNEQUIN_EQUIPSWAPFAILED"
            end

            return false
        end

        inst.components.trader:SetAbleToAcceptTest(ShouldAcceptEquipmentItem)
    end)

    AddPrefabPostInit("punchingbag", function(inst)
        if inst.components ~= nil and inst.components.trader ~= nil then
            inst.components.trader:SetAbleToAcceptTest(ShouldAcceptEquipmentItem)
        end
    end)
end



--------------------------------------------------------------------------
-- Inventory sorting
--
-- Sorting is requested from the client through a Mod RPC, then executed on
-- the server-side inventory component. This keeps item movement authoritative
-- and avoids client-only desyncs.
--------------------------------------------------------------------------

local SORT_RPC_NAMESPACE = "BetterInventory"
local SORT_RPC_NAME = "SortInventory"

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
        and target_stack.IsFull ~= nil
        and not target_stack:IsFull()
end

local function TryMergeStackInto(target, source)
    if not CanMergeStacks(target, source) then
        return false
    end

    local target_stack = target.components.stackable
    local source_stack = source.components.stackable

    if target_stack.Put ~= nil then
        target_stack:Put(source)
        return source:IsValid() == false
            or source.components == nil
            or source.components.stackable == nil
            or source.components.stackable:StackSize() <= 0
    end

    -- Conservative fallback for environments where Put is unavailable.
    if target_stack.StackSize ~= nil and target_stack.MaxSize ~= nil and target_stack.SetStackSize ~= nil
        and source_stack.StackSize ~= nil and source_stack.SetStackSize ~= nil then
        local target_size = target_stack:StackSize()
        local source_size = source_stack:StackSize()
        local room = math.max(0, target_stack:MaxSize() - target_size)
        local moved = math.min(room, source_size)

        if moved <= 0 then
            return false
        end

        target_stack:SetStackSize(target_size + moved)
        source_stack:SetStackSize(source_size - moved)

        if source_stack:StackSize() <= 0 then
            source:Remove()
            return true
        end

        return false
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

local function SortItemsForInventory(items)
    if CONFIG.sort_mode == "compact" then
        return items
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
        return sa > sb
    end)

    return items
end

local function SortInventoryForPlayer(player)
    if not CONFIG.sort_enabled then
        return
    end

    if player == nil or not player:IsValid() or player.components == nil or player.components.inventory == nil then
        return
    end

    local inventory = player.components.inventory
    local num_slots = inventory.GetNumSlots ~= nil and inventory:GetNumSlots() or MAX_ITEM_SLOTS
    num_slots = math.min(num_slots or MAX_ITEM_SLOTS, MAX_ITEM_SLOTS)

    local items = {}

    for slot = 1, num_slots do
        local item = inventory:GetItemInSlot(slot)
        if item ~= nil then
            local removed = inventory:RemoveItem(item, true)
            if removed ~= nil then
                table.insert(items, removed)
            else
                table.insert(items, item)
            end
        end
    end

    items = MergePartialStacks(items)
    items = SortItemsForInventory(items)

    local slot = 1
    for _, item in ipairs(items) do
        if item ~= nil and item:IsValid() then
            inventory:GiveItem(item, slot)
            slot = slot + 1
        end
    end

    DebugLog("Sorted inventory for " .. tostring(player.name or player.prefab or "player")
        .. " using mode=" .. tostring(CONFIG.sort_mode)
        .. ", merge_stacks=" .. tostring(CONFIG.sort_merge_stacks))
end

if CONFIG.sort_enabled then
    AddModRPCHandler(SORT_RPC_NAMESPACE, SORT_RPC_NAME, function(player)
        SortInventoryForPlayer(player)
    end)

    if not (TheNet ~= nil and TheNet:IsDedicated()) then
        local KEY_MAP = {
            KEY_F5 = GLOBAL.KEY_F5,
            KEY_F6 = GLOBAL.KEY_F6,
            KEY_F7 = GLOBAL.KEY_F7,
            KEY_F8 = GLOBAL.KEY_F8,
            KEY_R = GLOBAL.KEY_R,
            KEY_C = GLOBAL.KEY_C,
            KEY_V = GLOBAL.KEY_V,
        }

        local sort_key = KEY_MAP[CONFIG.sort_key] or GLOBAL.KEY_F5

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

        if sort_key ~= nil and not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_SORT_HOTKEY_ADDED") then
            GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_SORT_HOTKEY_ADDED", true)

            GLOBAL.TheInput:AddKeyDownHandler(sort_key, function()
                if not CanUseSortHotkey() then
                    return
                end

                local rpc_namespace = GLOBAL.MOD_RPC ~= nil and GLOBAL.MOD_RPC[SORT_RPC_NAMESPACE] or nil
                local rpc = rpc_namespace ~= nil and rpc_namespace[SORT_RPC_NAME] or nil
                if rpc ~= nil then
                    GLOBAL.SendModRPCToServer(rpc)
                end
            end)

            DebugLog("Inventory sort hotkey registered: " .. tostring(CONFIG.sort_key))
        end
    end
end

DebugLog("Loaded sort core. Inventory slots=" .. tostring(MAX_ITEM_SLOTS)
    .. ", layout=" .. tostring(CONFIG.inventory_layout)
    .. ", bag=" .. tostring(CONFIG.slot_bag)
    .. ", armor=" .. tostring(CONFIG.slot_armor)
    .. ", accessory=" .. tostring(CONFIG.slot_accessory)
    .. ", sort=" .. tostring(CONFIG.sort_enabled)
    .. ", sort_mode=" .. tostring(CONFIG.sort_mode))
