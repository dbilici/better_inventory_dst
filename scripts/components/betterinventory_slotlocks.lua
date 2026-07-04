local SlotLocks = Class(function(self, inst)
    self.inst = inst
    self.locked_slots = {}
end)

local function IsValidSlot(self, slot)
    slot = tonumber(slot)
    if slot == nil or slot < 1 or slot ~= math.floor(slot) then
        return false
    end

    local inventory = self.inst.components ~= nil and self.inst.components.inventory or nil
    local num_slots = inventory ~= nil and inventory.GetNumSlots ~= nil and inventory:GetNumSlots() or 0
    return slot <= num_slots
end

function SlotLocks:IsLocked(slot)
    return self.locked_slots[slot] == true
end

function SlotLocks:SetLocked(slot, locked)
    slot = tonumber(slot)
    if not IsValidSlot(self, slot) then
        return false
    end

    if locked then
        self.locked_slots[slot] = true
    else
        self.locked_slots[slot] = nil
    end

    self.inst:PushEvent("betterinventory_slotlocksdirty", {
        slot = slot,
        locked = locked == true,
    })
    return true
end

function SlotLocks:Toggle(slot)
    slot = tonumber(slot)
    if not IsValidSlot(self, slot) then
        return nil
    end

    local locked = not self:IsLocked(slot)
    self:SetLocked(slot, locked)
    return locked
end

function SlotLocks:GetSerialized()
    local slots = {}
    for slot, locked in pairs(self.locked_slots) do
        if locked and IsValidSlot(self, slot) then
            table.insert(slots, slot)
        end
    end
    table.sort(slots)

    local encoded = {}
    for _, slot in ipairs(slots) do
        table.insert(encoded, tostring(slot))
    end
    return table.concat(encoded, ",")
end

function SlotLocks:OnSave()
    local slots = {}
    for slot, locked in pairs(self.locked_slots) do
        if locked and IsValidSlot(self, slot) then
            table.insert(slots, slot)
        end
    end

    if #slots > 0 then
        table.sort(slots)
        return { slots = slots }
    end
end

function SlotLocks:OnLoad(data)
    self.locked_slots = {}
    if data == nil or type(data.slots) ~= "table" then
        return
    end

    for _, slot in ipairs(data.slots) do
        slot = tonumber(slot)
        if IsValidSlot(self, slot) then
            self.locked_slots[slot] = true
        end
    end
end

return SlotLocks
