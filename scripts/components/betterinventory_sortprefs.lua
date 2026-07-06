local Categories = require("betterinventory/categories")

local SortPreferences = Class(function(self, inst)
    self.inst = inst
    self.default_priorities = Categories.CopyPriorities(Categories.DEFAULT_PRIORITIES)
    self.active_preset = "default"
    self.custom_priorities = {}
end)

function SortPreferences:SetDefaultPriorities(priorities)
    self.default_priorities = Categories.CopyPriorities(priorities)
end

function SortPreferences:GetBaseOrder(key)
    return Categories.GetBasePresetOrder(key, self.default_priorities)
end

function SortPreferences:GetPresetOrder(key)
    local custom = self.custom_priorities[key]
    return custom ~= nil and Categories.PrioritiesToOrder(custom) or self:GetBaseOrder(key)
end

function SortPreferences:GetPresetOrders()
    local orders = {}
    for _, key in ipairs(Categories.PRESET_KEYS) do
        orders[key] = self:GetPresetOrder(key)
    end
    return orders
end

function SortPreferences:GetPriorities()
    return Categories.OrderToPriorities(self:GetPresetOrder(self.active_preset))
end

function SortPreferences:GetOrder()
    return self:GetPresetOrder(self.active_preset)
end

function SortPreferences:GetDefaultOrder()
    return self:GetBaseOrder("default")
end

function SortPreferences:SetPresetOrder(key, order)
    if Categories.GetBasePresetOrder(key, self.default_priorities) == nil then
        return false
    end
    local priorities = Categories.OrderToPriorities(order)
    if priorities == nil then
        return false
    end
    self.custom_priorities[key] = priorities
    return true
end

function SortPreferences:SetOrder(order)
    return self:SetPresetOrder(self.active_preset, order)
end

function SortPreferences:SetState(active_preset, orders)
    if type(orders) ~= "table" then
        return false
    end

    local updated = {}
    local active_valid = false
    for _, key in ipairs(Categories.PRESET_KEYS) do
        if key == active_preset then
            active_valid = true
        end
        local priorities = Categories.OrderToPriorities(orders[key])
        if priorities == nil then
            return false
        end
        updated[key] = priorities
    end

    if not active_valid then
        return false
    end
    self.active_preset = active_preset
    self.custom_priorities = updated
    return true
end

function SortPreferences:Reset(key)
    key = key or self.active_preset
    if Categories.GetBasePresetOrder(key, self.default_priorities) == nil then
        return false
    end
    self.custom_priorities[key] = nil
    return true
end

function SortPreferences:OnSave()
    local preset_orders = {}
    for key, priorities in pairs(self.custom_priorities) do
        local serialized = Categories.SerializeOrder(Categories.PrioritiesToOrder(priorities))
        if serialized ~= nil then
            preset_orders[key] = serialized
        end
    end

    if next(preset_orders) ~= nil or self.active_preset ~= "default" then
        return {
            active_preset = self.active_preset,
            preset_orders = preset_orders,
        }
    end
end

function SortPreferences:OnLoad(data)
    self.active_preset = "default"
    self.custom_priorities = {}
    if data == nil then
        return
    end

    -- Backward compatibility with the first single-order development build.
    if type(data.order) == "string" then
        local order = Categories.DeserializeOrder(data.order)
        if order ~= nil then
            self.custom_priorities.default = Categories.OrderToPriorities(order)
        end
        return
    end

    if type(data.preset_orders) == "table" then
        for _, key in ipairs(Categories.PRESET_KEYS) do
            local order = Categories.DeserializeOrder(data.preset_orders[key])
            if order ~= nil then
                self.custom_priorities[key] = Categories.OrderToPriorities(order)
            end
        end
    end

    for _, key in ipairs(Categories.PRESET_KEYS) do
        if data.active_preset == key then
            self.active_preset = key
            break
        end
    end
end

return SortPreferences
