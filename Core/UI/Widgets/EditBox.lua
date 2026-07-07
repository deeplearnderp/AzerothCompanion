-------------------------------------------------------------------------------
-- Azeroth Companion
-- EditBox Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local EditBox = BaseWidget:Extend({ Type = "EditBox" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function EditBox:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    local frame = CreateFrame("Frame", "AzerothCompanionWidgetEditBox" .. id, parent)
    frame:SetSize(opts.width or style.EditBoxWidth, opts.height or style.EditBoxHeight)

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetPoint("LEFT", frame, "LEFT", 6, 0)
    editBox:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    editBox:SetHeight(style.EditBoxHeight)
    editBox:SetText(tostring(opts.value or opts.text or ""))

    self.OnChanged = opts.onChanged
    self.OnEnterPressed = opts.onEnterPressed

    editBox:SetScript("OnTextChanged", function(control)

        if not self.Enabled then
            return
        end

        if self.OnChanged then
            self.OnChanged(self, control:GetText())
        end

    end)

    editBox:SetScript("OnEnterPressed", function(control)

        control:ClearFocus()

        if self.Enabled and self.OnEnterPressed then
            self.OnEnterPressed(self, control:GetText())
        end

    end)

    editBox:SetScript("OnEscapePressed", function(control)
        control:ClearFocus()
    end)

    self.Frame = frame
    self.EditBox = editBox

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function EditBox:SetTooltip(text)

    self.Tooltip = text

    if not self.EditBox or not text or text == "" then
        return
    end

    self.EditBox:SetScript("OnEnter", function(control)
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    self.EditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function EditBox:SetValue(text)

    if self.EditBox then
        self.EditBox:SetText(tostring(text or ""))
    end

end

function EditBox:GetValue()

    if self.EditBox then
        return self.EditBox:GetText()
    end

    return ""

end

-------------------------------------------------------------------------------
-- Callbacks
-------------------------------------------------------------------------------

function EditBox:SetOnChanged(callback)

    self.OnChanged = callback

end

function EditBox:SetOnEnterPressed(callback)

    self.OnEnterPressed = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function EditBox:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.EditBox then
        self.EditBox:SetEnabled(self.Enabled)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("EditBox", EditBox)

return EditBox
