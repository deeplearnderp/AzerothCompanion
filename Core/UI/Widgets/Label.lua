-------------------------------------------------------------------------------
-- Azeroth Companion
-- Label Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local Label = BaseWidget:Extend({ Type = "Label" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Label:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    local frame = CreateFrame("Frame", "AzerothCompanionWidgetLabel" .. id, parent)
    frame:SetHeight(opts.height or style.Height)

    local fontString = frame:CreateFontString(nil, "OVERLAY", opts.font or style.Font)
    fontString:SetPoint("LEFT", frame, "LEFT", 0, 0)
    fontString:SetJustifyH(opts.justifyH or "LEFT")
    fontString:SetText(opts.text or "")

    self:ApplyFontColor(fontString, opts.color or style.Color)

    if opts.width then
        frame:SetWidth(opts.width)
        fontString:SetWidth(opts.width)
    end

    self.Frame = frame
    self.FontString = fontString

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function Label:SetTooltip(text)

    self.Tooltip = text

    if not self.Frame or not text or text == "" then
        return
    end

    self.Frame:EnableMouse(true)

    self.Frame:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    self.Frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function Label:SetValue(text)

    if self.FontString then
        self.FontString:SetText(tostring(text or ""))
    end

end

function Label:GetValue()

    if self.FontString then
        return self.FontString:GetText()
    end

    return ""

end

-------------------------------------------------------------------------------
-- Style
-------------------------------------------------------------------------------

function Label:SetFont(font)

    if self.FontString and font then
        self.FontString:SetFontObject(font)
    end

end

function Label:SetColor(color)

    self:ApplyFontColor(self.FontString, color)

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function Label:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    local color = self.Enabled and BaseWidget.Style.Color or BaseWidget.Style.ColorDisabled

    self:ApplyFontColor(self.FontString, color)

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("Label", Label)

return Label
