-------------------------------------------------------------------------------
-- Azeroth Companion
-- Button Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local Button = BaseWidget:Extend({ Type = "Button" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Button:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    local frame = CreateFrame("Button", "AzerothCompanionWidgetButton" .. id, parent, "UIPanelButtonTemplate")
    frame:SetHeight(opts.height or style.ButtonHeight)
    frame:SetWidth(opts.width or style.ButtonMinWidth)
    frame:SetText(opts.text or "")

    self.OnClick = opts.onClick

    frame:SetScript("OnClick", function()
        if self.Enabled and self.OnClick then
            self.OnClick(self)
        end
    end)

    self.Frame = frame

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function Button:SetTooltip(text)

    self.Tooltip = text

    if not self.Frame or not text or text == "" then
        return
    end

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

function Button:SetValue(text)

    if self.Frame then
        self.Frame:SetText(tostring(text or ""))
    end

end

function Button:GetValue()

    if self.Frame then
        return self.Frame:GetText()
    end

    return ""

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function Button:SetOnClick(callback)

    self.OnClick = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function Button:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.Frame then
        self.Frame:SetEnabled(self.Enabled)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("Button", Button)

return Button
