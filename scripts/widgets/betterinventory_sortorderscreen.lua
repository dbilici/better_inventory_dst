local Screen = require("widgets/screen")
local Image = require("widgets/image")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local Categories = require("betterinventory/categories")

local function BuildFallbackOrders(default_priorities)
    local orders = {}
    for _, key in ipairs(Categories.PRESET_KEYS) do
        orders[key] = Categories.GetBasePresetOrder(key, default_priorities)
    end
    return orders
end

local SortOrderScreen = Class(Screen, function(self, current_serialized, default_serialized,
        on_apply, on_close)
    Screen._ctor(self, "BetterInventorySortOrderScreen")

    self.on_apply = on_apply
    self.on_close = on_close

    local active_tab, current_orders = Categories.DeserializePresetState(current_serialized)
    local _, base_orders = Categories.DeserializePresetState(default_serialized)
    self.active_tab = active_tab or "default"
    self.draft_orders = current_orders or BuildFallbackOrders(Categories.DEFAULT_PRIORITIES)
    self.base_orders = base_orders or BuildFallbackOrders(Categories.DEFAULT_PRIORITIES)
    self.order = Categories.CopyOrder(self.draft_orders[self.active_tab])

    self.root = self:AddChild(TEMPLATES.ScreenRoot("betterinventory_sort_order_root"))
    self.bg = self.root:AddChild(TEMPLATES.BackgroundTint(0.82))

    self.dialog = self.root:AddChild(TEMPLATES.RectangleWindow(980, 760))
    local r, g, b = unpack(UICOLOURS.BROWN_DARK)
    self.dialog:SetBackgroundTint(r, g, b, 0.93)

    self.title = self.root:AddChild(Text(BUTTONFONT, 40, "BETTER INVENTORY"))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)
    self.title:SetPosition(0, 300)

    self.heading = self.root:AddChild(Text(CHATFONT, 27, "SORT ORDER"))
    self.heading:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.heading:SetPosition(0, 266)

    self.top_divider = self.root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    self.top_divider:SetSize(900, 5)
    self.top_divider:SetPosition(0, 242)

    self.presets_label = self.root:AddChild(Text(CHATFONT, 23, "PRESETS"))
    self.presets_label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.presets_label:SetPosition(-355, 212)

    self.categories_label = self.root:AddChild(Text(CHATFONT, 23, "CATEGORY ORDER"))
    self.categories_label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.categories_label:SetPosition(145, 212)

    self.preset_buttons = {}
    for index, key in ipairs(Categories.PRESET_KEYS) do
        local selected_key = key
        local label = key == "default" and "DEFAULT" or Categories.PRESETS[key].label:upper()
        local button = self.root:AddChild(TEMPLATES.StandardButton(function()
            self:SwitchTab(selected_key)
        end, label, {220, 48}))
        button:SetPosition(-355, 164 - (index - 1) * 58)
        self.preset_buttons[key] = button
    end

    self.preset_note = self.root:AddChild(Text(CHATFONT, 19, ""))
    self.preset_note:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.preset_note:SetPosition(-355, -160)
    self.preset_note:SetRegionSize(250, 120)
    self.preset_note:EnableWordWrap(true)
    self.preset_note:SetHAlign(ANCHOR_LEFT)

    self.rows = {}
    for index = 1, #Categories.ORDER do
        local row_index = index
        local y = 174 - (index - 1) * 34
        local row = {}
        row.backing = self.root:AddChild(TEMPLATES.ListItemBackground_Static(610, 31))
        row.backing:SetPosition(155, y)
        if index % 2 == 0 then
            row.backing:SetTint(0.75, 0.68, 0.55, 0.35)
        else
            row.backing:SetTint(0.55, 0.48, 0.38, 0.30)
        end

        row.number = self.root:AddChild(Text(CHATFONT, 21, tostring(index)))
        row.number:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
        row.number:SetPosition(-125, y)
        row.number:SetRegionSize(34, 28)

        row.label = self.root:AddChild(Text(CHATFONT, 20, ""))
        row.label:SetColour(UICOLOURS.GOLD_CLICKABLE)
        row.label:SetPosition(80, y)
        row.label:SetRegionSize(350, 28)
        row.label:SetHAlign(ANCHOR_LEFT)

        row.up = self.root:AddChild(TEMPLATES.StandardButton(function()
            self:MoveCategory(row_index, -1)
        end, "UP", {72, 32}))
        row.up:SetScale(0.88)
        row.up:SetPosition(368, y)

        row.down = self.root:AddChild(TEMPLATES.StandardButton(function()
            self:MoveCategory(row_index, 1)
        end, "DOWN", {82, 32}))
        row.down:SetScale(0.88)
        row.down:SetPosition(445, y)

        self.rows[index] = row
    end

    self.bottom_divider = self.root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    self.bottom_divider:SetSize(900, 5)
    self.bottom_divider:SetPosition(0, -266)

    self.apply_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:SaveCurrentDraft()
        local serialized = Categories.SerializePresetState(self.active_tab, self.draft_orders)
        if serialized ~= nil and self.on_apply ~= nil then
            self.on_apply(serialized)
        end
        TheFrontEnd:PopScreen(self)
    end, "APPLY ALL", {180, 48}))
    self.apply_button:SetPosition(0, -312)

    self.reset_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:ResetCurrentTab()
    end, "RESET TAB", {180, 48}))
    self.reset_button:SetPosition(220, -312)

    self.cancel_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        TheFrontEnd:PopScreen(self)
    end, "CANCEL", {160, 48}))
    self.cancel_button:SetPosition(-220, -312)

    self.default_focus = self.apply_button
    self:RefreshRows()
    self:RefreshPresetButtons()
    self:RefreshNote()
end)

function SortOrderScreen:SaveCurrentDraft()
    self.draft_orders[self.active_tab] = Categories.CopyOrder(self.order)
end

function SortOrderScreen:SwitchTab(key)
    if self.draft_orders[key] == nil then
        return
    end
    self:SaveCurrentDraft()
    self.active_tab = key
    self.order = Categories.CopyOrder(self.draft_orders[key])
    self:RefreshRows()
    self:RefreshPresetButtons()
    self:RefreshNote()
end

function SortOrderScreen:ResetCurrentTab()
    local base_order = self.base_orders[self.active_tab]
    if base_order == nil then
        return
    end
    self.order = Categories.CopyOrder(base_order)
    self.draft_orders[self.active_tab] = Categories.CopyOrder(base_order)
    self:RefreshRows()
    self.preset_note:SetString("Only " .. self:GetActiveTabLabel()
        .. " was reset. Apply All to save the change.")
end

function SortOrderScreen:GetActiveTabLabel()
    return self.active_tab == "default" and "Default"
        or Categories.PRESETS[self.active_tab].label
end

function SortOrderScreen:RefreshNote()
    if self.active_tab == "anti_drop" then
        self.preset_note:SetString(
            "Best effort: expendable items first for frog theft. The game controls slot scanning.")
    else
        self.preset_note:SetString(self:GetActiveTabLabel()
            .. " tab. Changes are kept while switching tabs; Apply All saves every tab.")
    end
end

function SortOrderScreen:MoveCategory(index, direction)
    local target = index + direction
    if target < 1 or target > #self.order then
        return
    end
    self.order[index], self.order[target] = self.order[target], self.order[index]
    self.draft_orders[self.active_tab] = Categories.CopyOrder(self.order)
    self:RefreshRows()
end

function SortOrderScreen:RefreshPresetButtons()
    for key, button in pairs(self.preset_buttons) do
        button:SetTextColour(0.12, 0.09, 0.04, 1)
        button:SetTextFocusColour(0, 0, 0, 1)
        if key == self.active_tab then
            button:SetImageNormalColour(1, 1, 1, 1)
            button:SetImageFocusColour(1, 1, 1, 1)
            button:SetImageDisabledColour(1, 1, 1, 1)
        else
            button:SetImageNormalColour(0.58, 0.52, 0.42, 0.92)
            button:SetImageFocusColour(0.82, 0.75, 0.62, 1)
            button:SetImageDisabledColour(0.58, 0.52, 0.42, 0.92)
        end
    end
end

function SortOrderScreen:RefreshRows()
    for index, row in ipairs(self.rows) do
        local category = self.order[index]
        row.number:SetString(tostring(index))
        row.label:SetString(tostring(Categories.LABELS[category] or category))
        if index == 1 then
            row.up:Disable()
        else
            row.up:Enable()
        end
        if index == #self.order then
            row.down:Disable()
        else
            row.down:Enable()
        end
    end
end

function SortOrderScreen:OnControl(control, down)
    if SortOrderScreen._base.OnControl(self, control, down) then
        return true
    end
    if not down and (control == CONTROL_MENU_BACK or control == CONTROL_CANCEL) then
        TheFrontEnd:PopScreen(self)
        return true
    end
    return false
end

function SortOrderScreen:OnDestroy()
    if self.on_close ~= nil then
        self.on_close()
    end
    SortOrderScreen._base.OnDestroy(self)
end

return SortOrderScreen
