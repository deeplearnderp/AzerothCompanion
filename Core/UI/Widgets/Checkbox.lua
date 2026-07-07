-------------------------------------------------------------------------------
-- Azeroth Companion
-- Checkbox Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local Checkbox = BaseWidget:Extend({ Type = "Checkbox" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Checkbox:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    local frame = CreateFrame("Frame", "AzerothCompanionWidgetCheckbox" .. id, parent)
    frame:SetHeight(opts.height or style.Height)

    local check = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    check:SetSize(style.CheckboxSize, style.CheckboxSize)
    check:SetPoint("LEFT", frame, "LEFT", 0, 0)

    local label = frame:CreateFontString(nil, "OVERLAY", style.Font)
    label:SetPoint("LEFT", check, "RIGHT", style.Spacing, 0)
    label:SetText(opts.text or "")

    self:ApplyFontColor(label, style.Color)

    self.Value = opts.checked == true
    self.OnChanged = opts.onChanged

    check:SetChecked(self.Value)

    check:SetScript("OnClick", function(button)

        if not self.Enabled then
            button:SetChecked(self.Value)
            return
        end

        self.Value = button:GetChecked() == true

        if self.OnChanged then
            self.OnChanged(self, self.Value)
        end

    end)

    self.Frame = frame
    self.CheckButton = check
    self.Label = label

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function Checkbox:SetTooltip(text)

    self.Tooltip = text

    if not self.Frame or not text or text == "" then
        return
    end

    local function ShowTooltip(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end

    self.Frame:EnableMouse(true)
    self.Frame:SetScript("OnEnter", ShowTooltip)
    self.CheckButton:SetScript("OnEnter", ShowTooltip)

    local function HideTooltip()
        GameTooltip:Hide()
    end

    self.Frame:SetScript("OnLeave", HideTooltip)
    self.CheckButton:SetScript("OnLeave", HideTooltip)

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function Checkbox:SetValue(checked)

    self.Value = checked == true

    if self.CheckButton then
        self.CheckButton:SetChecked(self.Value)
    end

end

function Checkbox:GetValue()

    return self.Value == true

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function Checkbox:SetOnChanged(callback)

    self.OnChanged = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function Checkbox:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.CheckButton then
        self.CheckButton:SetEnabled(self.Enabled)
    end

    local color = self.Enabled and BaseWidget.Style.Color or BaseWidget.Style.ColorDisabled

    self:ApplyFontColor(self.Label, color)

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("Checkbox", Checkbox)

return Checkbox
