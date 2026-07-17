-- Pack & Sort
-- Post-v0.5.0 development.
--
-- Main goals:
--   - 24-slot inventory foundation.
--   - Compact 2 x 12 UI that grows upward from the bottom HUD instead of
--     extending below the screen.
--   - Optional Bag / Armor / Accessory equip slots.
--   - Inventory sort through server RPC.
--   - Equipped-bag sort and Quick Stack through server RPC.
--   - Persistent manual main-inventory slot locks.
--   - No Quick Draw.

local GLOBAL = GLOBAL
local require = GLOBAL.require
local MOD_NAME = modname

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
    inventory_layout = GetModConfigData("inventory_layout", true) or "2x12",
    ui_scale = GetModConfigData("ui_scale", true) or 0.85,
    slot_bag = GetModConfigData("slot_bag") ~= false,
    slot_armor = GetModConfigData("slot_armor") ~= false,
    slot_accessory = GetModConfigData("slot_accessory") ~= false,
    sort_enabled = GetModConfigData("sort_enabled") ~= false,
    bag_sort_enabled = GetModConfigData("bag_sort_enabled") ~= false,
    sort_mode = GetModConfigData("sort_mode") or "category",
    sort_merge_stacks = GetModConfigData("sort_merge_stacks") ~= false,
    sort_key = GetModConfigData("sort_key") or "KEY_F5",
    sort_order_key = GetModConfigData("sort_order_key") or "KEY_F8",
    bag_sort_key = GetModConfigData("bag_sort_key") or "KEY_F6",
    quick_stack_enabled = GetModConfigData("quick_stack_enabled") ~= false,
    quick_stack_key = GetModConfigData("quick_stack_key") or "KEY_F7",
    slot_lock_enabled = GetModConfigData("slot_lock_enabled") ~= false,
    slot_lock_key = GetModConfigData("slot_lock_key") or "KEY_L",
    debug_mode = GetModConfigData("debug_mode") or "off",
    sort_category_priorities = {
        tool = GetModConfigData("sort_priority_tool") or 1,
        weapon = GetModConfigData("sort_priority_weapon") or 2,
        armor = GetModConfigData("sort_priority_armor") or 3,
        bag = GetModConfigData("sort_priority_bag") or 4,
        accessory = GetModConfigData("sort_priority_accessory") or 5,
        clothing = GetModConfigData("sort_priority_clothing") or 6,
        food = GetModConfigData("sort_priority_food") or 7,
        healing = GetModConfigData("sort_priority_healing") or 8,
        light = GetModConfigData("sort_priority_light") or 9,
        fuel = GetModConfigData("sort_priority_fuel") or 10,
        magic = GetModConfigData("sort_priority_magic") or 11,
        trinket = GetModConfigData("sort_priority_trinket") or 12,
        material = GetModConfigData("sort_priority_material") or 13,
    },
}

local MAX_ITEM_SLOTS = CONFIG.inventory_size == 24 and 24 or 15
local USE_EXPANDED_INVENTORY = MAX_ITEM_SLOTS > 15
local UI_SCALE = CONFIG.ui_scale or 0.85
local CORE_PROTOCOL_VERSION = 5
local CORE_RPC_NAMESPACE = "BetterInventoryCore"

--------------------------------------------------------------------------
-- Debug helper
--------------------------------------------------------------------------

local function DebugLog(message)
    if CONFIG.debug_mode == "off" then
        return
    end

    local line = "[Pack & Sort] " .. tostring(message)
    print(line)

    if CONFIG.debug_mode == "chatlog" and GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        if GLOBAL.TheNet ~= nil then
            GLOBAL.TheNet:Announce(line)
        end
    end
end

local function DebugWarn(message)
    print("[Pack & Sort][WARN] " .. tostring(message))
end

--------------------------------------------------------------------------
-- Extra equipment slot definitions
--------------------------------------------------------------------------

local SLOT_DEFS = {
    BAG = {
        enabled = CONFIG.slot_bag,
        eslot = "betterinventory_bag",
        global_key = "BETTERINVENTORY_BAG",
        image = "backpack.tex",
        tag = "betterinventory_bag",
        label = "Bag",
    },
    ARMOR = {
        enabled = CONFIG.slot_armor,
        eslot = "betterinventory_armor",
        global_key = "BETTERINVENTORY_ARMOR",
        image = "armor.tex",
        tag = "betterinventory_armor",
        label = "Armor",
    },
    ACCESSORY = {
        enabled = CONFIG.slot_accessory,
        eslot = "betterinventory_accessory",
        global_key = "BETTERINVENTORY_ACCESSORY",
        image = "amulet.tex",
        tag = "betterinventory_accessory",
        label = "Accessory",
    },
}

local ENABLED_EXTRA_SLOTS = {}

for _, key in ipairs({"BAG", "ARMOR", "ACCESSORY"}) do
    local def = SLOT_DEFS[key]
    if def.enabled then
        local existing = EQUIPSLOTS[def.global_key]
        if existing ~= nil and existing ~= def.eslot then
            GLOBAL.error("Pack & Sort: equip slot collision for " .. def.global_key)
        end
        EQUIPSLOTS[def.global_key] = def.eslot
        table.insert(ENABLED_EXTRA_SLOTS, def)
        DebugLog("Registered extra equip slot: " .. def.label .. " -> " .. def.eslot)
    end
end

local function IsExtraSlotEnabled(key)
    return SLOT_DEFS[key] ~= nil and SLOT_DEFS[key].enabled
end

--------------------------------------------------------------------------
-- Vanilla-only item slot rules
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
    -- All three vanilla layers (server inventory, client replica and
    -- inventory_classified netvars) ask this function for their slot count.
    -- Patching it before prefabs are constructed keeps those layers in sync and
    -- avoids late writes to readonly component fields or post-pristine netvars.
    local GetMaxItemSlots_Base = GLOBAL.GetMaxItemSlots
    if GetMaxItemSlots_Base ~= nil then
        GLOBAL.GetMaxItemSlots = function(game_mode)
            local base = GetMaxItemSlots_Base(game_mode) or 0
            if game_mode == "quagmire" then
                return base
            end
            return math.max(base, MAX_ITEM_SLOTS)
        end
    else
        GLOBAL.error("Pack & Sort: GetMaxItemSlots is unavailable")
    end
end

--------------------------------------------------------------------------
-- Multiplayer replication contract diagnostics
--------------------------------------------------------------------------

local function ValidateClassifiedContract(classified, context)
    if classified == nil then
        return false
    end

    local valid = true
    local item_count = classified._items ~= nil and #classified._items or 0
    if item_count ~= MAX_ITEM_SLOTS then
        DebugWarn(tostring(context) .. ": classified slot count=" .. tostring(item_count)
            .. ", expected=" .. tostring(MAX_ITEM_SLOTS))
        valid = false
    end

    for _, def in ipairs(ENABLED_EXTRA_SLOTS) do
        if classified._equips == nil or classified._equips[def.eslot] == nil then
            DebugWarn(tostring(context) .. ": missing equip netvar for " .. tostring(def.eslot))
            valid = false
        end
    end

    if valid then
        DebugLog(tostring(context) .. ": replication contract OK; protocol="
            .. tostring(CORE_PROTOCOL_VERSION) .. ", slots=" .. tostring(item_count))
    end

    return valid
end

AddPrefabPostInit("inventory_classified", function(inst)
    inst:DoStaticTaskInTime(0, function()
        if inst:IsValid() then
            ValidateClassifiedContract(inst, GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim
                and "server classified" or "client classified")
        end
    end)
end)

local function ValidatePlayerInventoryContract(inst, attempt)
    if inst == nil or not inst:IsValid() then
        return
    end

    local inventory = inst.components ~= nil and inst.components.inventory or nil
    local replica = inst.replica ~= nil and inst.replica.inventory or nil
    local num_slots = inventory ~= nil and inventory:GetNumSlots()
        or replica ~= nil and replica:GetNumSlots() or 0
    local context = "player " .. tostring(inst.userid or inst.prefab or inst.GUID)

    if num_slots ~= MAX_ITEM_SLOTS then
        DebugWarn(context .. ": inventory slot count=" .. tostring(num_slots)
            .. ", expected=" .. tostring(MAX_ITEM_SLOTS))
    end

    local classified = replica ~= nil and replica.classified or nil
    if classified ~= nil then
        ValidateClassifiedContract(classified, context)
    elseif (attempt or 1) < 4 then
        inst:DoTaskInTime(0.5, function()
            ValidatePlayerInventoryContract(inst, (attempt or 1) + 1)
        end)
    else
        DebugWarn(context .. ": classified was not attached after retries")
    end
end

AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0, function()
        ValidatePlayerInventoryContract(inst, 1)
    end)
end)

--------------------------------------------------------------------------
-- Client/server core protocol handshake
--------------------------------------------------------------------------

AddClientModRPCHandler(CORE_RPC_NAMESPACE, "ProtocolStatus", function(server_protocol, compatible)
    if compatible then
        DebugLog("Core protocol handshake OK; protocol=" .. tostring(server_protocol))
    else
        DebugWarn("Core protocol mismatch: client=" .. tostring(CORE_PROTOCOL_VERSION)
            .. ", server=" .. tostring(server_protocol))
    end
end)

AddModRPCHandler(CORE_RPC_NAMESPACE, "Hello", function(player, client_protocol)
    local compatible = GLOBAL.tonumber(client_protocol) == CORE_PROTOCOL_VERSION
    if not compatible then
        DebugWarn("Core protocol mismatch for " .. tostring(player ~= nil and player.userid or "unknown")
            .. ": client=" .. tostring(client_protocol)
            .. ", server=" .. tostring(CORE_PROTOCOL_VERSION))
    end

    if player ~= nil and player.userid ~= nil then
        local rpc = GLOBAL.GetClientModRPC(CORE_RPC_NAMESPACE, "ProtocolStatus")
        GLOBAL.SendModRPCToClient(rpc, player.userid, CORE_PROTOCOL_VERSION, compatible)
    end
end)

local function SendCoreProtocolHandshake(inst, attempt)
    if inst == nil or not inst:IsValid() then
        return
    end

    if inst == GLOBAL.ThePlayer then
        local rpc = GLOBAL.GetModRPC(CORE_RPC_NAMESPACE, "Hello")
        GLOBAL.SendModRPCToServer(rpc, CORE_PROTOCOL_VERSION)
    elseif (attempt or 1) < 4 then
        inst:DoTaskInTime(0.5, function()
            SendCoreProtocolHandshake(inst, (attempt or 1) + 1)
        end)
    end
end

if not (TheNet ~= nil and TheNet.IsDedicated ~= nil and TheNet:IsDedicated()) then
    AddPlayerPostInit(function(inst)
        inst:DoTaskInTime(0.5, function()
            SendCoreProtocolHandshake(inst, 1)
        end)
    end)
end

--------------------------------------------------------------------------
-- Manual inventory slot locks
--------------------------------------------------------------------------

local SLOT_LOCK_RPC_NAMESPACE = "BetterInventorySlotLocks"
local SLOT_LOCK_TOGGLE_RPC = "Toggle"
local SLOT_LOCK_SYNC_RPC = "Sync"
local SLOT_LOCK_STATE_RPC = "State"
local SLOT_LOCK_FEEDBACK_RPC = "Feedback"
local SLOT_LOCK_REQUEST_COOLDOWN = 0.10
local SLOT_LOCK_REQUEST_STATE = GLOBAL.setmetatable({}, { __mode = "k" })
local CLIENT_LOCKED_SLOTS = {}
local ACTIVE_INVENTORY_BAR = nil

local function DecodeLockedSlots(serialized)
    local slots = {}
    for value in GLOBAL.string.gmatch(tostring(serialized or ""), "%d+") do
        local slot = GLOBAL.tonumber(value)
        if slot ~= nil and slot >= 1 and slot <= MAX_ITEM_SLOTS then
            slots[slot] = true
        end
    end
    return slots
end

local function EnsureSlotLockIndicator(slot)
    if slot == nil or slot._betterinventory_lock_indicator ~= nil then
        return slot ~= nil and slot._betterinventory_lock_indicator or nil
    end

    local Image = require("widgets/image")
    local indicator = slot:AddChild(Image(HUD_ATLAS, "craft_slot_locked.tex"))
    indicator:SetPosition(20, 20, 0)
    indicator:SetScale(0.55, 0.55, 1)
    indicator:SetClickable(false)
    indicator:Hide()
    slot._betterinventory_lock_indicator = indicator

    local OnTileChanged_Base = slot.ontilechangedfn
    slot:SetOnTileChangedFn(function(tile)
        if OnTileChanged_Base ~= nil then
            OnTileChanged_Base(tile)
        end
        indicator:MoveToFront()
    end)

    return indicator
end


local function RefreshSlotLockVisuals()
    local bar = ACTIVE_INVENTORY_BAR
    if bar == nil or bar.inv == nil then
        return
    end

    for slot_index, slot in pairs(bar.inv) do
        if type(slot_index) == "number" and slot ~= nil then
            local indicator = EnsureSlotLockIndicator(slot)
            if indicator ~= nil then
                if CLIENT_LOCKED_SLOTS[slot_index] then
                    indicator:Show()
                    indicator:MoveToFront()
                else
                    indicator:Hide()
                end
            end
        end
    end
end

local function SendSlotLockState(player)
    local component = player ~= nil and player.components ~= nil
        and player.components.betterinventory_slotlocks or nil
    if component == nil or player.userid == nil then
        return
    end

    local rpc = GLOBAL.GetClientModRPC(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_STATE_RPC)
    GLOBAL.SendModRPCToClient(rpc, player.userid, component:GetSerialized())
end

local function SendSlotLockFeedback(player, locked)
    if player == nil or player.userid == nil then
        return
    end

    local rpc = GLOBAL.GetClientModRPC(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_FEEDBACK_RPC)
    GLOBAL.SendModRPCToClient(rpc, player.userid, locked and 1 or 0)
end

if CONFIG.slot_lock_enabled then
    AddPlayerPostInit(function(inst)
        if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim
            and inst.components ~= nil and inst.components.betterinventory_slotlocks == nil then
            inst:AddComponent("betterinventory_slotlocks")
        end
    end)

    AddClientModRPCHandler(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_STATE_RPC, function(serialized)
        CLIENT_LOCKED_SLOTS = DecodeLockedSlots(serialized)
        RefreshSlotLockVisuals()
    end)

    AddClientModRPCHandler(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_FEEDBACK_RPC, function()
        local sound = GLOBAL.TheFrontEnd ~= nil and GLOBAL.TheFrontEnd:GetSound() or nil
        if sound ~= nil then
            sound:PlaySound("dontstarve/HUD/click_move")
        end
    end)

    AddModRPCHandler(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_SYNC_RPC, function(player)
        SendSlotLockState(player)
    end)

    AddModRPCHandler(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_TOGGLE_RPC, function(player, requested_slot)
        local component = player ~= nil and player.components ~= nil
            and player.components.betterinventory_slotlocks or nil
        local inventory = player ~= nil and player.components ~= nil and player.components.inventory or nil
        local slot = GLOBAL.tonumber(requested_slot)
        if component == nil or inventory == nil or slot == nil then
            return
        end

        slot = GLOBAL.math.floor(slot)
        local num_slots = inventory.GetNumSlots ~= nil and inventory:GetNumSlots() or 0
        if slot < 1 or slot > num_slots or slot > MAX_ITEM_SLOTS then
            DebugWarn("Rejected invalid slot-lock request: " .. tostring(requested_slot))
            return
        end

        local now = GLOBAL.GetTime()
        local last_request = SLOT_LOCK_REQUEST_STATE[player] or -SLOT_LOCK_REQUEST_COOLDOWN
        if now - last_request < SLOT_LOCK_REQUEST_COOLDOWN then
            return
        end
        SLOT_LOCK_REQUEST_STATE[player] = now

        local locked = component:Toggle(slot)
        DebugLog("Slot " .. tostring(slot) .. (locked and " locked" or " unlocked")
            .. " for " .. tostring(player.userid or player.GUID))
        SendSlotLockState(player)
        SendSlotLockFeedback(player, locked)
    end)

    if not (TheNet ~= nil and TheNet.IsDedicated ~= nil and TheNet:IsDedicated()) then
        local function SendSlotLockSync(inst, attempt)
            if inst == nil or not inst:IsValid() then
                return
            end

            if inst == GLOBAL.ThePlayer then
                local rpc = GLOBAL.GetModRPC(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_SYNC_RPC)
                GLOBAL.SendModRPCToServer(rpc)
            elseif (attempt or 1) < 4 then
                inst:DoTaskInTime(0.5, function()
                    SendSlotLockSync(inst, (attempt or 1) + 1)
                end)
            end
        end

        AddPlayerPostInit(function(inst)
            inst:DoTaskInTime(0.75, function()
                SendSlotLockSync(inst, 1)
            end)
        end)

        local LOCK_KEY_MAP = {
            KEY_L = GLOBAL.KEY_L,
            KEY_K = GLOBAL.KEY_K,
            KEY_J = GLOBAL.KEY_J,
            KEY_N = GLOBAL.KEY_N,
        }
        local lock_key = LOCK_KEY_MAP[CONFIG.slot_lock_key] or GLOBAL.KEY_L

        if lock_key ~= nil and not GLOBAL.rawget(GLOBAL, "BETTER_INVENTORY_SLOT_LOCK_HOTKEY_ADDED") then
            GLOBAL.rawset(GLOBAL, "BETTER_INVENTORY_SLOT_LOCK_HOTKEY_ADDED", true)

            GLOBAL.TheInput:AddKeyDownHandler(lock_key, function()
                if GLOBAL.ThePlayer == nil or GLOBAL.ThePlayer.HUD == nil
                    or (GLOBAL.ThePlayer.HUD.HasInputFocus ~= nil
                        and GLOBAL.ThePlayer.HUD:HasInputFocus()) then
                    return
                end

                local bar = ACTIVE_INVENTORY_BAR
                if bar == nil or bar.owner ~= GLOBAL.ThePlayer or bar.inv == nil then
                    return
                end

                for slot_index, slot in ipairs(bar.inv) do
                    if slot ~= nil and slot.focus then
                        local rpc = GLOBAL.GetModRPC(SLOT_LOCK_RPC_NAMESPACE, SLOT_LOCK_TOGGLE_RPC)
                        GLOBAL.SendModRPCToServer(rpc, slot_index)
                        return
                    end
                end
            end)

            DebugLog("Slot lock hotkey registered: " .. tostring(CONFIG.slot_lock_key))
        end
    end
end

--------------------------------------------------------------------------
-- Separate bag slot / overflow-container compatibility
--------------------------------------------------------------------------

if IsExtraSlotEnabled("BAG") then
    local Inventory = require("components/inventory")
    local BAG_SLOT = SLOT_DEFS.BAG.eslot

    -- Vanilla only checks EQUIPSLOTS.BODY for a backpack. Once bags move to a
    -- dedicated slot, server inventory routing and crafting must check it first.
    local Inventory_GetOverflowContainer_Base = Inventory.GetOverflowContainer
    function Inventory:GetOverflowContainer(...)
        if self.ignoreoverflow then
            return nil
        end

        local bag = self:GetEquippedItem(BAG_SLOT)
        if bag ~= nil and bag.components ~= nil and bag.components.container ~= nil
            and bag.components.container.canbeopened then
            return bag.components.container
        end

        return Inventory_GetOverflowContainer_Base(self, ...)
    end

    -- BODY equipment automatically emits setoverflow; a custom bag slot does
    -- not. Emit the same event so the HUD rebuilds when a bag is equipped.
    local Inventory_Equip_Base = Inventory.Equip
    function Inventory:Equip(item, ...)
        local eslot = item ~= nil and item.components ~= nil and item.components.equippable ~= nil
            and item.components.equippable.equipslot or nil
        local equipped = Inventory_Equip_Base(self, item, ...)

        if equipped and eslot == BAG_SLOT and item.components.container ~= nil then
            self.inst:PushEvent("setoverflow", { overflow = item })
        end

        return equipped
    end

    -- On clients InventoryReplica delegates to this classified method. Replace
    -- the exported method after prefab construction while preserving vanilla as
    -- a fallback for BODY-slot containers and unusual game modes.
    AddPrefabPostInit("inventory_classified", function(inst)
        if inst.GetOverflowContainer == nil or inst.GetEquippedItem == nil then
            return
        end

        local function GetDedicatedBagContainer(self)
            local bag = self:GetEquippedItem(BAG_SLOT)
            return bag ~= nil and bag.replica ~= nil and bag.replica.container or nil
        end

        local GetOverflowContainer_Base = inst.GetOverflowContainer
        inst.GetOverflowContainer = function(self, ...)
            if self.ignoreoverflow then
                return nil
            end

            local bag_container = GetDedicatedBagContainer(self)
            if bag_container ~= nil then
                return bag_container
            end

            return GetOverflowContainer_Base(self, ...)
        end

        -- Several classified helpers capture vanilla's BODY-only overflow
        -- lookup as a local function. Patch their exported read APIs so remote
        -- clients still count and find contents in the dedicated bag slot.
        if inst.Has ~= nil then
            local Has_Base = inst.Has
            inst.Has = function(self, prefab, amount, checkallcontainers, ...)
                local has, count = Has_Base(self, prefab, amount, checkallcontainers, ...)
                count = count or 0

                local bag_container = GetDedicatedBagContainer(self)
                local already_counted = false
                if checkallcontainers and bag_container ~= nil and bag_container.inst ~= nil
                    and self._parent ~= nil and self._parent.replica ~= nil
                    and self._parent.replica.inventory ~= nil then
                    local containers = self._parent.replica.inventory:GetOpenContainers()
                    already_counted = containers ~= nil and containers[bag_container.inst] == true
                end

                if bag_container ~= nil and not already_counted then
                    local _, bag_count = bag_container:Has(prefab, amount, checkallcontainers)
                    count = count + (bag_count or 0)
                end

                return count >= (amount or 1), count
            end
        end

        if inst.HasItemWithTag ~= nil then
            local HasItemWithTag_Base = inst.HasItemWithTag
            inst.HasItemWithTag = function(self, tag, amount, ...)
                local _, count = HasItemWithTag_Base(self, tag, amount, ...)
                count = count or 0

                local bag_container = GetDedicatedBagContainer(self)
                if bag_container ~= nil then
                    local _, bag_count = bag_container:HasItemWithTag(tag, amount)
                    count = count + (bag_count or 0)
                end

                return count >= (amount or 1), count
            end
        end

        if inst.FindItem ~= nil then
            local FindItem_Base = inst.FindItem
            inst.FindItem = function(self, fn, ...)
                local item = FindItem_Base(self, fn, ...)
                if item ~= nil then
                    return item
                end

                local bag_container = GetDedicatedBagContainer(self)
                return bag_container ~= nil and bag_container:FindItem(fn) or nil
            end
        end
    end)
end

--------------------------------------------------------------------------
-- Inventory bar UI
--------------------------------------------------------------------------

local function AddExtraEquipSlotsToInventoryBar(self)
    if TheNet ~= nil and TheNet.GetServerGameMode ~= nil and TheNet:GetServerGameMode() == "quagmire" then
        return
    end

    if GLOBAL.rawget(self, "_betterinventory_extra_slots_added") then
        return
    end
    GLOBAL.rawset(self, "_betterinventory_extra_slots_added", true)

    local sortkey_start = 1
    local sortkey_delta = 1 / (#ENABLED_EXTRA_SLOTS + 1)

    for i, def in ipairs(ENABLED_EXTRA_SLOTS) do
        self:AddEquipSlot(def.eslot, EQUIP_SLOT_ATLAS, def.image, sortkey_start + i * sortkey_delta)
    end
end

local INVENTORY_BG_TEX = "inventory_bg.tex"
local INVENTORY_BG_WIDTH = 1352
local INVENTORY_BG_HEIGHT = 204
local RepositionExpandedInventoryBar
local UI_SCALE_OPTIONS = {
    { label = "Small", value = 0.78 },
    { label = "Compact", value = 0.85 },
    { label = "Large", value = 0.92 },
}

local function GetInventoryHudSettings()
    return {
        layout = CONFIG.inventory_layout == "vanilla" and "vanilla" or "2x12",
        scale = UI_SCALE,
    }
end

local function SaveClientInventoryHudSettings()
    if GLOBAL.KnownModIndex == nil or MOD_NAME == nil then
        return
    end

    local config_options = GLOBAL.KnownModIndex:LoadModConfigurationOptions(MOD_NAME, true)
    if type(config_options) ~= "table" then
        return
    end

    for _, option in ipairs(config_options) do
        if option.name == "inventory_layout" then
            option.saved = CONFIG.inventory_layout
        elseif option.name == "ui_scale" then
            option.saved = UI_SCALE
        end
    end

    GLOBAL.KnownModIndex:SaveConfigurationOptions(function() end, MOD_NAME,
        config_options, true)
end

local function ApplyInventoryHudSettings(settings, should_save)
    if type(settings) ~= "table" then
        return
    end

    if settings.layout == "vanilla" or settings.layout == "2x12" then
        CONFIG.inventory_layout = settings.layout
    end

    local scale = GLOBAL.tonumber(settings.scale)
    if scale ~= nil then
        UI_SCALE = math.max(0.70, math.min(1.00, scale))
        CONFIG.ui_scale = UI_SCALE
    end

    if ACTIVE_INVENTORY_BAR ~= nil then
        RepositionExpandedInventoryBar(ACTIVE_INVENTORY_BAR)
        if CONFIG.slot_lock_enabled then
            RefreshSlotLockVisuals()
        end
    end

    if should_save then
        SaveClientInventoryHudSettings()
    end
end

local function FitInventoryBarBackground(self, min_x, max_x, min_y, max_y)
    -- Keep a real background, but fit it to the active expanded layout.
    -- v0.2.4 hid the background entirely; v0.2.3 scaled it too aggressively.
    -- This uses the uploaded inventory_bg texture dimensions and positions it
    -- around the actual slot bounds instead of stretching it across the screen.
    if self.bg ~= nil then
        if self.bg.SetTexture ~= nil then
            self.bg:SetTexture(INVENTORY_BG_ATLAS, INVENTORY_BG_TEX)
        end
        if self.bg.Show ~= nil then
            self.bg:Show()
        end
        if self.bg.SetPosition ~= nil then
            self.bg:SetPosition((min_x + max_x) / 2, (min_y + max_y) / 2, 0)
        end
        if self.bg.SetScale ~= nil then
            local target_width = (max_x - min_x) + 110
            local target_height = (max_y - min_y) + 70
            self.bg:SetScale(target_width / INVENTORY_BG_WIDTH, target_height / INVENTORY_BG_HEIGHT, 1)
        end
    end

    -- bgcover is the part that tends to create the long vanilla strip. Keep it
    -- hidden while we use our fitted custom background.
    if self.bgcover ~= nil and self.bgcover.Hide ~= nil then
        self.bgcover:Hide()
    end
end

local function RepositionScaledSingleRowInventoryBar(self)
    if not (USE_EXPANDED_INVENTORY and CONFIG.inventory_layout ~= "2x12")
        or self.inv == nil then
        return
    end

    -- Keep the vanilla idea of one long row, but rebuild it inside a tighter
    -- footprint and cap the root scale so 24 inventory slots plus equipment
    -- slots do not run into the right-side HUD.
    local SLOT_STEP = 64
    local EQUIP_GAP = 78
    local single_row_scale = math.min(UI_SCALE, 0.78)
    local inventory_half_width = ((MAX_ITEM_SLOTS - 1) * SLOT_STEP) / 2
    local slot_half_size = 34
    local min_x = 999999
    local max_x = -999999
    local min_y = 999999
    local max_y = -999999

    if self.root ~= nil and self.root.SetScale ~= nil then
        self.root:SetScale(single_row_scale, single_row_scale, 1)
    end

    for slot_index, slot in pairs(self.inv) do
        if type(slot_index) == "number" and slot ~= nil and slot.SetPosition ~= nil then
            local index = slot_index - 1
            local x = -inventory_half_width + index * SLOT_STEP
            local y = 0

            slot:SetPosition(x, y, 0)
            min_x = math.min(min_x, x - slot_half_size)
            max_x = math.max(max_x, x + slot_half_size)
            min_y = math.min(min_y, y - slot_half_size)
            max_y = math.max(max_y, y + slot_half_size)
            if slot.SetScale ~= nil then
                slot:SetScale(1, 1, 1)
            end
        end
    end

    if self.equip ~= nil and self.equipslotinfo ~= nil then
        local equip_start_x = inventory_half_width + EQUIP_GAP

        for i, info in ipairs(self.equipslotinfo) do
            local slot = self.equip[info.slot]
            if slot ~= nil and slot.SetPosition ~= nil then
                local x = equip_start_x + (i - 1) * SLOT_STEP
                local y = 0

                slot:SetPosition(x, y, 0)
                min_x = math.min(min_x, x - slot_half_size)
                max_x = math.max(max_x, x + slot_half_size)
                min_y = math.min(min_y, y - slot_half_size)
                max_y = math.max(max_y, y + slot_half_size)
                if slot.SetScale ~= nil then
                    slot:SetScale(1, 1, 1)
                end
            end
        end
    end

    if min_x < max_x and min_y < max_y then
        FitInventoryBarBackground(self, min_x, max_x, min_y, max_y)
    end
end

local function Reposition2x12InventoryBar(self)
    if not (USE_EXPANDED_INVENTORY and CONFIG.inventory_layout == "2x12")
        or self.inv == nil then
        return
    end

    -- UI safe layout:
    -- Do not scale individual slots. Scaling the slot widget also scales/offsets
    -- ItemTile children in ways that can make stack counters overlap. Instead,
    -- keep vanilla-ish slot size and only move the slots into a two-row grid.
    local COLUMNS = 12
    local SLOT_STEP = 70
    local ROW_STEP = 70
    local inventory_half_width = ((COLUMNS - 1) * SLOT_STEP) / 2
    local top_row_y = ROW_STEP
    local bottom_row_y = 0
    local slot_half_size = 34
    local min_x = 999999
    local max_x = -999999
    local min_y = 999999
    local max_y = -999999

    -- Scale the common root instead of individual slot widgets. This keeps item
    -- tiles and counters aligned while making the config option effective.
    if self.root ~= nil and self.root.SetScale ~= nil then
        self.root:SetScale(UI_SCALE, UI_SCALE, 1)
    end

    for slot_index, slot in pairs(self.inv) do
        if type(slot_index) == "number" and slot ~= nil and slot.SetPosition ~= nil then
            local index = slot_index - 1
            local col = index % COLUMNS
            local row = math.floor(index / COLUMNS)
            local x = -inventory_half_width + col * SLOT_STEP
            local y = row == 0 and top_row_y or bottom_row_y

            slot:SetPosition(x, y, 0)
            min_x = math.min(min_x, x - slot_half_size)
            max_x = math.max(max_x, x + slot_half_size)
            min_y = math.min(min_y, y - slot_half_size)
            max_y = math.max(max_y, y + slot_half_size)
            if slot.SetScale ~= nil then
                slot:SetScale(1, 1, 1)
            end
        end
    end

    -- Equipment slots: a clearly separated 3 x 2 block on the right.
    -- This avoids the overlap seen in v0.2.3 where equip slots started too close
    -- to the inventory grid after UI scaling.
    if self.equip ~= nil and self.equipslotinfo ~= nil then
        local equip_start_x = inventory_half_width + 110
        local equip_top_y = top_row_y
        local equip_columns = 3

        for i, info in ipairs(self.equipslotinfo) do
            local slot = self.equip[info.slot]
            if slot ~= nil and slot.SetPosition ~= nil then
                local index = i - 1
                local col = index % equip_columns
                local row = math.floor(index / equip_columns)
                local x = equip_start_x + col * SLOT_STEP
                local y = equip_top_y - row * ROW_STEP
                slot:SetPosition(x, y, 0)
                min_x = math.min(min_x, x - slot_half_size)
                max_x = math.max(max_x, x + slot_half_size)
                min_y = math.min(min_y, y - slot_half_size)
                max_y = math.max(max_y, y + slot_half_size)
                if slot.SetScale ~= nil then
                    slot:SetScale(1, 1, 1)
                end
            end
        end
    end

    if min_x < max_x and min_y < max_y then
        FitInventoryBarBackground(self, min_x, max_x, min_y, max_y)
    end
end

function RepositionExpandedInventoryBar(self)
    RepositionScaledSingleRowInventoryBar(self)
    Reposition2x12InventoryBar(self)
end

local inventory_bar_rebuild_patched = false

AddClassPostConstruct("widgets/inventorybar", function(self)
    if CONFIG.slot_lock_enabled and self.owner == GLOBAL.ThePlayer then
        ACTIVE_INVENTORY_BAR = self
    end

    AddExtraEquipSlotsToInventoryBar(self)

    if not inventory_bar_rebuild_patched then
        local mt = GLOBAL.getmetatable ~= nil and GLOBAL.getmetatable(self) or nil
        local InventoryBarClass = mt ~= nil and mt.__index or nil

        if InventoryBarClass ~= nil and InventoryBarClass.Rebuild ~= nil then
            inventory_bar_rebuild_patched = true

            local Rebuild_Base = InventoryBarClass.Rebuild
            function InventoryBarClass:Rebuild(...)
                Rebuild_Base(self, ...)
                AddExtraEquipSlotsToInventoryBar(self)
                RepositionExpandedInventoryBar(self)
                if CONFIG.slot_lock_enabled and self.owner == GLOBAL.ThePlayer then
                    ACTIVE_INVENTORY_BAR = self
                    RefreshSlotLockVisuals()
                end
            end
        else
            DebugLog("InventoryBar class patch skipped: metatable/index not available yet")
        end
    end

    RepositionExpandedInventoryBar(self)
    if CONFIG.slot_lock_enabled then
        RefreshSlotLockVisuals()
    end
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
    local recipepopup_refresh_patched = false
    if RecipePopup ~= nil and RecipePopup.Refresh ~= nil and not recipepopup_refresh_patched then
        recipepopup_refresh_patched = true
        local Refresh_Base = RecipePopup.Refresh
        function RecipePopup:Refresh(...)
            local result = Refresh_Base(self, ...)

            if self.button ~= nil and self.button.IsVisible ~= nil and self.button:IsVisible()
                and self.owner ~= nil and self.owner.replica ~= nil and self.owner.replica.inventory ~= nil
                and self.amulet ~= nil then

                local equipped = self.owner.replica.inventory:GetEquippedItem(ACCESSORY_SLOT)
                if equipped ~= nil and equipped.prefab == "greenamulet" then
                    self.amulet:Show()
                end
            end

            return result
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

    if doer.components.inventory:GetEquippedItem(eslot) == nil
        and inst.components.inventory:GetEquippedItem(eslot) == nil then
        return false
    end

    -- Vanilla handles restricted equipment and failed equips by returning items
    -- to an inventory. The old custom swap could leave either item ownerless.
    return inst.components.inventory:SwapEquipment(doer, eslot)
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

if GLOBAL.TheNet ~= nil and GLOBAL.TheNet.GetIsServer ~= nil and GLOBAL.TheNet:GetIsServer() then
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
--------------------------------------------------------------------------

local SortCategories = require("betterinventory/categories")

local SORT_ORDER_ENABLED = CONFIG.sort_enabled or CONFIG.bag_sort_enabled

if SORT_ORDER_ENABLED then
    AddPlayerPostInit(function(inst)
        if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim and inst.components ~= nil then
            if inst.components.betterinventory_sortprefs == nil then
                inst:AddComponent("betterinventory_sortprefs")
            end
            inst.components.betterinventory_sortprefs:SetDefaultPriorities(
                CONFIG.sort_category_priorities or SortCategories.DEFAULT_PRIORITIES)
        end
    end)
end

local Sorting = require("betterinventory/sorting")
Sorting.Setup({
    GLOBAL = GLOBAL,
    config = CONFIG,
    max_item_slots = MAX_ITEM_SLOTS,
    slot_defs = SLOT_DEFS,
    debug_log = DebugLog,
    debug_warn = DebugWarn,
    get_hud_settings = GetInventoryHudSettings,
    apply_hud_settings = ApplyInventoryHudSettings,
    hud_scale_options = UI_SCALE_OPTIONS,
    add_client_mod_rpc_handler = AddClientModRPCHandler,
    add_mod_rpc_handler = AddModRPCHandler,
})
DebugLog("Loaded multiplayer core. Protocol=" .. tostring(CORE_PROTOCOL_VERSION)
    .. ", inventory slots=" .. tostring(MAX_ITEM_SLOTS)
    .. ", layout=" .. tostring(CONFIG.inventory_layout)
    .. ", ui_scale=" .. tostring(UI_SCALE)
    .. ", bag=" .. tostring(CONFIG.slot_bag)
    .. ", armor=" .. tostring(CONFIG.slot_armor)
    .. ", accessory=" .. tostring(CONFIG.slot_accessory)
    .. ", sort=" .. tostring(CONFIG.sort_enabled)
    .. ", bag_sort=" .. tostring(CONFIG.bag_sort_enabled)
    .. ", sort_mode=" .. tostring(CONFIG.sort_mode)
    .. ", sort_order_key=" .. tostring(CONFIG.sort_order_key)
    .. ", bag_sort_key=" .. tostring(CONFIG.bag_sort_key)
    .. ", quick_stack=" .. tostring(CONFIG.quick_stack_enabled)
    .. ", quick_stack_key=" .. tostring(CONFIG.quick_stack_key)
    .. ", slot_locks=" .. tostring(CONFIG.slot_lock_enabled)
    .. ", lock_key=" .. tostring(CONFIG.slot_lock_key))
