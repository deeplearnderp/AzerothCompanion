-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dropdown Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local BaseWidget = AC.BaseWidget
local Dropdown = BaseWidget:Extend({ Type = "Dropdown" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Dropdown:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    self.OptionsList = opts.list or {}
    self.SelectedIndex = opts.selection or 1
    self.OnChanged = opts.onChanged

    if self.SelectedIndex < 1 then
        self.SelectedIndex = 1
    elseif self.SelectedIndex > #self.OptionsList and #self.OptionsList > 0 then
        self.SelectedIndex = #self.OptionsList
    end

    local frame = CreateFrame("Frame", "AzerothCompanionWidgetDropdown" .. id, parent)
    frame:SetSize(opts.width or style.DropdownWidth, opts.height or style.DropdownHeight)

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", frame, "LEFT", 0, 0)
    dropdown:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    self.Frame = frame
    self.Dropdown = dropdown

    self:RefreshMenu()
    self:UpdateLabel()

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------

function Dropdown:GetOptionText(option)

    if type(option) == "table" then
        return option.text or option.value or ""
    end

    return tostring(option)

end

function Dropdown:GetOptionValue(option, index)

    if type(option) == "table" and option.value ~= nil then
        return option.value
    end

    return option or index

end

function Dropdown:RefreshMenu()

    local widget = self

    self.Dropdown:SetupMenu(function(_, rootDescription)

        for i = 1, #widget.OptionsList do

            local option = widget.OptionsList[i]
            local text = widget:GetOptionText(option)
            local index = i

            rootDescription:CreateButton(text, function()
                widget:SetSelectedIndex(index)
            end)

        end

    end)

end

function Dropdown:UpdateLabel()

    local option = self.OptionsList[self.SelectedIndex]

    if option and self.Dropdown then
        self.Dropdown:SetDefaultText(self:GetOptionText(option))
    elseif self.Dropdown then
        self.Dropdown:SetDefaultText("")
    end

end

function Dropdown:SetList(list)

    self.OptionsList = list or {}

    if self.SelectedIndex > #self.OptionsList then
        self.SelectedIndex = #self.OptionsList > 0 and #self.OptionsList or 1
    end

    self:RefreshMenu()
    self:UpdateLabel()

end

function Dropdown:SetSelectedIndex(index, silent)

    index = tonumber(index) or 1

    if index < 1 or index > #self.OptionsList then
        return
    end

    self.SelectedIndex = index
    self:UpdateLabel()

    if not silent and self.OnChanged then
        local option = self.OptionsList[index]
        self.OnChanged(self, self:GetOptionValue(option, index), index)
    end

end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function Dropdown:SetTooltip(text)

    self.Tooltip = text

    if not self.Dropdown or not text or text == "" then
        return
    end

    self.Dropdown:SetScript("OnEnter", function(control)
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    self.Dropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function Dropdown:SetValue(value)

    for i = 1, #self.OptionsList do

        local option = self.OptionsList[i]

        if self:GetOptionValue(option, i) == value then
            self:SetSelectedIndex(i, true) -- silent: syncing display, not a user action
            return
        end

    end

end

function Dropdown:GetValue()

    local option = self.OptionsList[self.SelectedIndex]

    if not option then
        return nil
    end

    return self:GetOptionValue(option, self.SelectedIndex)

end

function Dropdown:GetSelection()

    return self.SelectedIndex

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function Dropdown:SetOnChanged(callback)

    self.OnChanged = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function Dropdown:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.Dropdown then
        self.Dropdown:SetEnabled(self.Enabled)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("Dropdown", Dropdown)

return Dropdown
