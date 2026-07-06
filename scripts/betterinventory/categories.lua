local Categories = {}

Categories.ORDER = {
    "tool",
    "weapon",
    "armor",
    "bag",
    "accessory",
    "clothing",
    "food",
    "healing",
    "light",
    "fuel",
    "magic",
    "trinket",
    "material",
}

Categories.LABELS = {
    tool = "Tools, Fishing & Seafaring",
    weapon = "Weapons",
    armor = "Armor",
    bag = "Storage",
    accessory = "Riding & Accessories",
    clothing = "Clothing & Weather",
    food = "Food & Cooking",
    healing = "Healing",
    light = "Light",
    fuel = "Fuel",
    magic = "Magic",
    trinket = "Decor & Event",
    material = "Refined & Materials",
}

Categories.DEFAULT_PRIORITIES = {}
for index, category in ipairs(Categories.ORDER) do
    Categories.DEFAULT_PRIORITIES[category] = index
end

Categories.PRESETS = {
    combat = {
        label = "Combat",
        order = {
            "weapon", "armor", "healing", "food", "light", "magic", "accessory",
            "tool", "clothing", "bag", "fuel", "material", "trinket",
        },
    },
    building = {
        label = "Building",
        order = {
            "material", "tool", "fuel", "light", "food", "healing", "weapon",
            "armor", "bag", "clothing", "accessory", "magic", "trinket",
        },
    },
    survivor = {
        label = "Survivor",
        order = {
            "food", "healing", "light", "tool", "weapon", "armor", "clothing",
            "bag", "fuel", "material", "magic", "accessory", "trinket",
        },
    },
    anti_drop = {
        label = "Anti Drop",
        order = {
            "material", "fuel", "food", "tool", "light", "clothing", "bag",
            "accessory", "magic", "healing", "armor", "weapon", "trinket",
        },
    },
}

Categories.PRESET_ORDER = { "combat", "building", "survivor", "anti_drop" }
Categories.PRESET_KEYS = { "default", "combat", "building", "survivor", "anti_drop" }

function Categories.CopyOrder(order)
    local copy = {}
    for index, category in ipairs(order or {}) do
        copy[index] = category
    end
    return copy
end

function Categories.GetBasePresetOrder(key, default_priorities)
    if key == "default" then
        return Categories.PrioritiesToOrder(default_priorities or Categories.DEFAULT_PRIORITIES)
    end
    local preset = Categories.PRESETS[key]
    return preset ~= nil and Categories.CopyOrder(preset.order) or nil
end

function Categories.SerializePresetState(active_preset, orders)
    local valid_active = false
    local parts = { "active:" .. tostring(active_preset or "") }
    for _, key in ipairs(Categories.PRESET_KEYS) do
        if key == active_preset then
            valid_active = true
        end
        local serialized = Categories.SerializeOrder(orders ~= nil and orders[key] or nil)
        if serialized == nil then
            return nil
        end
        table.insert(parts, key .. ":" .. serialized)
    end
    return valid_active and table.concat(parts, "|") or nil
end

function Categories.DeserializePresetState(serialized)
    local active_preset = nil
    local orders = {}
    for part in string.gmatch(tostring(serialized or ""), "[^|]+") do
        local key, value = string.match(part, "^([a-z_]+):(.*)$")
        if key == "active" then
            active_preset = value
        elseif key ~= nil then
            local order = Categories.DeserializeOrder(value)
            if order == nil or orders[key] ~= nil then
                return nil
            end
            orders[key] = order
        end
    end

    local active_valid = false
    for _, key in ipairs(Categories.PRESET_KEYS) do
        if orders[key] == nil then
            return nil
        end
        if key == active_preset then
            active_valid = true
        end
    end
    return active_valid and active_preset or nil, active_valid and orders or nil
end

function Categories.CopyPriorities(priorities)
    local copy = {}
    for _, category in ipairs(Categories.ORDER) do
        copy[category] = priorities ~= nil and tonumber(priorities[category])
            or Categories.DEFAULT_PRIORITIES[category]
    end
    return copy
end

function Categories.OrderToPriorities(order)
    if type(order) ~= "table" or #order ~= #Categories.ORDER then
        return nil
    end

    local priorities = {}
    for index, category in ipairs(order) do
        if Categories.DEFAULT_PRIORITIES[category] == nil or priorities[category] ~= nil then
            return nil
        end
        priorities[category] = index
    end
    return priorities
end

function Categories.PrioritiesToOrder(priorities)
    local entries = {}
    for default_index, category in ipairs(Categories.ORDER) do
        local priority = priorities ~= nil and tonumber(priorities[category]) or nil
        if priority == nil or priority < 1 or priority > #Categories.ORDER
            or priority % 1 ~= 0 then
            priority = default_index
        end
        table.insert(entries, {
            category = category,
            priority = priority,
            default_index = default_index,
        })
    end

    table.sort(entries, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.default_index < b.default_index
    end)

    local order = {}
    for _, entry in ipairs(entries) do
        table.insert(order, entry.category)
    end
    return order
end

function Categories.SerializeOrder(order)
    if Categories.OrderToPriorities(order) == nil then
        return nil
    end
    return table.concat(order, ",")
end

function Categories.DeserializeOrder(serialized)
    local order = {}
    for category in string.gmatch(tostring(serialized or ""), "[a-z]+") do
        table.insert(order, category)
    end
    if Categories.OrderToPriorities(order) == nil then
        return nil
    end
    return order
end

return Categories
