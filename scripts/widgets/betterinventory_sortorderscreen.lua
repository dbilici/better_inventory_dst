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

local PRESET_DESCRIPTIONS = {
    default = "Balanced host default",
    combat = "Weapons, armor, healing",
    building = "Materials and tools first",
    survivor = "Food, light, survival",
    anti_drop = "Cheap items first",
}

local SortOrderScreen = Class(Screen, function(self, current_serialized, default_serialized,
        on_apply, on_close, hud_settings, on_hud_change, hud_scale_options)
    Screen._ctor(self, "BetterInventorySortOrderScreen")

    self.on_apply = on_apply
    self.on_close = on_close
    self.on_hud_change = on_hud_change

    local active_tab, current_orders, current_settings = Categories.DeserializePresetState(current_serialized)
    local _, base_orders = Categories.DeserializePresetState(default_serialized)
    self.active_tab = active_tab or "default"
    self.draft_orders = current_orders or BuildFallbackOrders(Categories.DEFAULT_PRIORITIES)
    self.base_orders = base_orders or BuildFallbackOrders(Categories.DEFAULT_PRIORITIES)
    self.order = Categories.CopyOrder(self.draft_orders[self.active_tab])
    self.sort_bag_with_inventory = current_settings ~= nil
        and current_settings.sort_bag_with_inventory == true
    self.bag_sort_available = current_settings == nil
        or current_settings.bag_sort_available ~= false
    self.selected_index = 1
    self.drag_source_index = nil
    self.drag_target_index = nil
    self.hud_settings = {
        layout = hud_settings ~= nil and hud_settings.layout or "2x12",
        scale = hud_settings ~= nil and hud_settings.scale or 0.85,
    }
    self.hud_scale_options = hud_scale_options or {
        { label = "Small", value = 0.78 },
        { label = "Compact", value = 0.85 },
        { label = "Large", value = 0.92 },
    }

    self.root = self:AddChild(TEMPLATES.ScreenRoot("betterinventory_sort_order_root"))
    self.bg = self.root:AddChild(TEMPLATES.BackgroundTint(0.82))

    self.dialog = self.root:AddChild(TEMPLATES.RectangleWindow(980, 820))
    local r, g, b = unpack(UICOLOURS.BROWN_DARK)
    self.dialog:SetBackgroundTint(r, g, b, 0.93)

    self.title = self.root:AddChild(Text(BUTTONFONT, 38, "PACK & SORT"))
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)
    self.title:SetPosition(0, 330)

    self.heading = self.root:AddChild(Text(CHATFONT, 27, "CATEGORY ORDER"))
    self.heading:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.heading:SetPosition(0, 296)

    self.top_divider = self.root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    self.top_divider:SetSize(900, 5)
    self.top_divider:SetPosition(0, 272)

    self.presets_label = self.root:AddChild(Text(CHATFONT, 23, "PRESETS"))
    self.presets_label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.presets_label:SetPosition(-355, 242)

    self.categories_label = self.root:AddChild(Text(CHATFONT, 23, "CATEGORY ORDER"))
    self.categories_label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.categories_label:SetPosition(145, 242)

    self.preset_buttons = {}
    self.preset_descriptions = {}
    for index, key in ipairs(Categories.PRESET_KEYS) do
        local selected_key = key
        local label = key == "default" and "DEFAULT" or Categories.PRESETS[key].label:upper()
        local button = self.root:AddChild(TEMPLATES.StandardButton(function()
            self:SwitchTab(selected_key)
        end, label, {220, 42}))
        local y = 196 - (index - 1) * 62
        button:SetPosition(-355, y)
        self.preset_buttons[key] = button

        local description = self.root:AddChild(Text(CHATFONT, 16,
            PRESET_DESCRIPTIONS[key] or ""))
        description:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
        description:SetPosition(-355, y - 30)
        description:SetRegionSize(230, 24)
        self.preset_descriptions[key] = description
    end

    self.preset_note = self.root:AddChild(Text(CHATFONT, 19, ""))
    self.preset_note:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.preset_note:SetPosition(-355, -150)
    self.preset_note:SetRegionSize(250, 68)
    self.preset_note:EnableWordWrap(true)
    self.preset_note:SetHAlign(ANCHOR_LEFT)

    self.bag_sort_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        if not self.bag_sort_available then
            return
        end
        self.sort_bag_with_inventory = not self.sort_bag_with_inventory
        self:RefreshBagSortButton()
        self:RefreshNote()
    end, "", {250, 42}))
    self.bag_sort_button:SetPosition(-355, -210)

    self.hud_label = self.root:AddChild(Text(CHATFONT, 18, "HUD VIEW"))
    self.hud_label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.hud_label:SetPosition(-355, -250)

    self.hud_layout_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:ToggleHudLayout()
    end, "", {132, 34}))
    self.hud_layout_button:SetPosition(-426, -278)

    self.hud_scale_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:CycleHudScale()
    end, "", {132, 34}))
    self.hud_scale_button:SetPosition(-284, -278)

    self.move_up_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:MoveSelectedCategory(-1)
    end, "MOVE UP", {116, 36}))
    self.move_up_button:SetPosition(332, 240)

    self.move_down_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:MoveSelectedCategory(1)
    end, "MOVE DOWN", {126, 36}))
    self.move_down_button:SetPosition(455, 240)

    self.selected_help = self.root:AddChild(Text(CHATFONT, 17,
        "Drag a row onto another row, or select it and use Move buttons."))
    self.selected_help:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    self.selected_help:SetPosition(158, -270)
    self.selected_help:SetRegionSize(560, 28)

    self.rows = {}
    for index = 1, #Categories.ORDER do
        local row_index = index
        local y = 204 - (index - 1) * 34
        local row = {}
        row.backing = self.root:AddChild(TEMPLATES.ListItemBackground(610, 31, function()
            self:ReleaseRowDrag(row_index)
        end))
        row.backing.AllowOnControlWhenSelected = true
        row.backing:SetPosition(155, y)
        row.backing:SetOnDown(function()
            self:BeginRowDrag(row_index)
        end)
        row.backing:SetWhileDown(function()
            self:UpdateRowDrag()
        end)

        row.marker = self.root:AddChild(Text(CHATFONT, 20, ""))
        row.marker:SetColour(UICOLOURS.GOLD_SELECTED)
        row.marker:SetPosition(-146, y)
        row.marker:SetRegionSize(24, 28)

        row.number = self.root:AddChild(Text(CHATFONT, 21, tostring(index)))
        row.number:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
        row.number:SetPosition(-116, y)
        row.number:SetRegionSize(34, 28)

        row.label = self.root:AddChild(Text(CHATFONT, 20, ""))
        row.label:SetColour(UICOLOURS.GOLD_CLICKABLE)
        row.label:SetPosition(126, y)
        row.label:SetRegionSize(460, 28)
        row.label:SetHAlign(ANCHOR_LEFT)

        self.rows[index] = row
    end

    self.bottom_divider = self.root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    self.bottom_divider:SetSize(900, 5)
    self.bottom_divider:SetPosition(0, -296)

    self.apply_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:SaveCurrentDraft()
        local serialized = Categories.SerializePresetState(self.active_tab, self.draft_orders, {
            sort_bag_with_inventory = self.sort_bag_with_inventory,
            bag_sort_available = self.bag_sort_available,
        })
        if serialized ~= nil and self.on_apply ~= nil then
            self.on_apply(serialized)
        end
        TheFrontEnd:PopScreen(self)
    end, "APPLY", {160, 48}))
    self.apply_button:SetPosition(0, -342)

    self.reset_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        self:ResetCurrentTab()
    end, "RESET THIS PRESET", {220, 48}))
    self.reset_button:SetPosition(230, -342)

    self.cancel_button = self.root:AddChild(TEMPLATES.StandardButton(function()
        TheFrontEnd:PopScreen(self)
    end, "CANCEL", {160, 48}))
    self.cancel_button:SetPosition(-210, -342)

    self.default_focus = self.apply_button
    self:RefreshRows()
    self:RefreshPresetButtons()
    self:RefreshBagSortButton()
    self:RefreshHudButtons()
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
    self.selected_index = math.min(self.selected_index or 1, #self.order)
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
    self.selected_index = math.min(self.selected_index or 1, #self.order)
    self:RefreshRows()
    self.preset_note:SetString(self:GetActiveTabLabel()
        .. " was reset. Apply saves the change.")
end

function SortOrderScreen:GetActiveTabLabel()
    return self.active_tab == "default" and "Default"
        or Categories.PRESETS[self.active_tab].label
end

function SortOrderScreen:RefreshNote()
    local bag_note = self.sort_bag_with_inventory
        and " F7 sorts inventory + bag."
        or " F7 sorts inventory only."
    if not self.bag_sort_available then
        bag_note = " Bag sort is disabled in mod settings."
    end
    if self.active_tab == "anti_drop" then
        self.preset_note:SetString(
            "Best effort: cheap items first for frog theft. " .. bag_note)
    else
        self.preset_note:SetString(self:GetActiveTabLabel()
            .. " keeps drafts while switching. Apply saves every preset. "
            .. bag_note)
    end
end

function SortOrderScreen:RefreshBagSortButton()
    if not self.bag_sort_available then
        self.bag_sort_button:SetText("BAG WITH F7: DISABLED")
        self.bag_sort_button:Disable()
        return
    end

    self.bag_sort_button:Enable()
    self.bag_sort_button:SetText(self.sort_bag_with_inventory
        and "BAG WITH F7: ON"
        or "BAG WITH F7: OFF")
    self.bag_sort_button:SetTextColour(0.12, 0.09, 0.04, 1)
    self.bag_sort_button:SetTextFocusColour(0, 0, 0, 1)
    if self.sort_bag_with_inventory then
        self.bag_sort_button:SetImageNormalColour(1, 1, 1, 1)
        self.bag_sort_button:SetImageFocusColour(1, 1, 1, 1)
    else
        self.bag_sort_button:SetImageNormalColour(0.58, 0.52, 0.42, 0.92)
        self.bag_sort_button:SetImageFocusColour(0.82, 0.75, 0.62, 1)
    end
end

function SortOrderScreen:GetHudLayoutLabel()
    return self.hud_settings.layout == "vanilla" and "SINGLE ROW" or "2 x 12"
end

function SortOrderScreen:GetHudScaleLabel()
    local current = tonumber(self.hud_settings.scale) or 0.85
    for _, option in ipairs(self.hud_scale_options) do
        if math.abs((tonumber(option.value) or 0) - current) < 0.001 then
            return option.label
        end
    end
    return tostring(current)
end

function SortOrderScreen:RefreshHudButtons()
    self.hud_layout_button:SetText("HUD: " .. self:GetHudLayoutLabel())
    self.hud_scale_button:SetText("SCALE: " .. self:GetHudScaleLabel():upper())

    for _, button in ipairs({ self.hud_layout_button, self.hud_scale_button }) do
        button:SetTextColour(0.12, 0.09, 0.04, 1)
        button:SetTextFocusColour(0, 0, 0, 1)
        button:SetImageNormalColour(0.74, 0.66, 0.48, 0.95)
        button:SetImageFocusColour(0.95, 0.84, 0.56, 1)
    end
end

function SortOrderScreen:ApplyHudSettings()
    self:RefreshHudButtons()
    if self.on_hud_change ~= nil then
        self.on_hud_change({
            layout = self.hud_settings.layout,
            scale = self.hud_settings.scale,
        })
    end
end

function SortOrderScreen:ToggleHudLayout()
    self.hud_settings.layout = self.hud_settings.layout == "vanilla" and "2x12"
        or "vanilla"
    self:ApplyHudSettings()
end

function SortOrderScreen:CycleHudScale()
    local current = tonumber(self.hud_settings.scale) or 0.85
    local next_index = 1

    for index, option in ipairs(self.hud_scale_options) do
        if math.abs((tonumber(option.value) or 0) - current) < 0.001 then
            next_index = index + 1
            break
        end
    end

    if next_index > #self.hud_scale_options then
        next_index = 1
    end

    self.hud_settings.scale = self.hud_scale_options[next_index].value
    self:ApplyHudSettings()
end

function SortOrderScreen:SelectRow(index)
    if index < 1 or index > #self.order then
        return
    end
    self.selected_index = index
    self:RefreshRows()
end

function SortOrderScreen:GetRowIndexUnderMouse()
    if TheInput == nil or TheInput.GetScreenPosition == nil then
        return nil
    end

    local mouse_pos = TheInput:GetScreenPosition()
    if mouse_pos == nil then
        return nil
    end

    for index, row in ipairs(self.rows) do
        local row_pos = row.backing:GetWorldPosition()
        if row_pos ~= nil
            and math.abs(mouse_pos.x - row_pos.x) <= 305
            and math.abs(mouse_pos.y - row_pos.y) <= 18 then
            return index
        end
    end

    return nil
end

function SortOrderScreen:BeginRowDrag(index)
    self.drag_source_index = index
    self.drag_target_index = index
    self.selected_index = index
    self:RefreshRows()
end

function SortOrderScreen:UpdateRowDrag()
    if self.drag_source_index == nil then
        return
    end

    local target = self:GetRowIndexUnderMouse()
    if target ~= nil and target ~= self.drag_target_index then
        self.drag_target_index = target
        self.selected_index = target
        self:RefreshRows()
    end
end

function SortOrderScreen:ReleaseRowDrag(fallback_index)
    if self.drag_source_index == nil then
        self:SelectRow(fallback_index)
        return
    end

    local source = self.drag_source_index
    local target = self:GetRowIndexUnderMouse() or self.drag_target_index or source
    self.drag_source_index = nil
    self.drag_target_index = nil

    if target ~= source then
        self:MoveCategoryToIndex(source, target)
    else
        self:SelectRow(source)
    end
end

function SortOrderScreen:MoveCategoryToIndex(source, target)
    if source < 1 or source > #self.order or target < 1 or target > #self.order then
        return
    end

    local category = table.remove(self.order, source)
    table.insert(self.order, target, category)
    self.selected_index = target
    self.draft_orders[self.active_tab] = Categories.CopyOrder(self.order)
    self:RefreshRows()
end

function SortOrderScreen:MoveSelectedCategory(direction)
    self:MoveCategory(self.selected_index or 1, direction)
end

function SortOrderScreen:MoveCategory(index, direction)
    local target = index + direction
    if target < 1 or target > #self.order then
        return
    end
    self.order[index], self.order[target] = self.order[target], self.order[index]
    self.selected_index = target
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

    for key, description in pairs(self.preset_descriptions) do
        if key == self.active_tab then
            description:SetColour(UICOLOURS.GOLD_SELECTED)
        else
            description:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
        end
    end
end

function SortOrderScreen:RefreshRows()
    for index, row in ipairs(self.rows) do
        local category = self.order[index]
        local selected = index == self.selected_index
        row.number:SetString(tostring(index))
        row.label:SetString(tostring(Categories.LABELS[category] or category))

        if selected then
            row.marker:SetString(">")
            row.number:SetColour(UICOLOURS.GOLD_SELECTED)
            row.label:SetColour(UICOLOURS.GOLD_SELECTED)
            row.backing:Select()
            row.backing:SetImageSelectedColour(0.95, 0.78, 0.36, 0.52)
        else
            row.marker:SetString("")
            row.number:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
            row.label:SetColour(UICOLOURS.GOLD_CLICKABLE)
            row.backing:Unselect()
            if index % 2 == 0 then
                row.backing:SetImageNormalColour(0.75, 0.68, 0.55, 0.28)
            else
                row.backing:SetImageNormalColour(0.55, 0.48, 0.38, 0.24)
            end
        end
    end

    if self.selected_index == 1 then
        self.move_up_button:Disable()
    else
        self.move_up_button:Enable()
    end
    if self.selected_index == #self.order then
        self.move_down_button:Disable()
    else
        self.move_down_button:Enable()
    end
end

function SortOrderScreen:OnControl(control, down)
    if not down then
        if control == CONTROL_MOVE_UP or control == CONTROL_FOCUS_UP then
            self:SelectRow((self.selected_index or 1) - 1)
            return true
        elseif control == CONTROL_MOVE_DOWN or control == CONTROL_FOCUS_DOWN then
            self:SelectRow((self.selected_index or 1) + 1)
            return true
        elseif control == CONTROL_MOVE_LEFT or control == CONTROL_PREVVALUE
            or control == CONTROL_SCROLLBACK then
            self:MoveSelectedCategory(-1)
            return true
        elseif control == CONTROL_MOVE_RIGHT or control == CONTROL_NEXTVALUE
            or control == CONTROL_SCROLLFWD then
            self:MoveSelectedCategory(1)
            return true
        end
    end
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
