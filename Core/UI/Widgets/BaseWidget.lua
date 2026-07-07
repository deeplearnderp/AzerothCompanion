-------------------------------------------------------------------------------
-- Azeroth Companion
-- Base Widget
--
-- Shared lifecycle and styling for framework widgets.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = {}
AC.BaseWidget = BaseWidget

-------------------------------------------------------------------------------
-- Style
-------------------------------------------------------------------------------

BaseWidget.Style =
{
    Font = "GameFontHighlight",
    FontHeader = "GameFontNormalLarge",
    FontSmall = "GameFontHighlightSmall",

    Spacing = 8,
    Height = 26,
    CheckboxSize = 24,
    ButtonHeight = 22,
    ButtonMinWidth = 80,
    SliderHeight = 16,
    SliderWidth = 200,
    EditBoxHeight = 24,
    EditBoxWidth = 200,
    DropdownWidth = 160,
    DropdownHeight = 26,
    ColorPickerSize = 20,

    Color =
    {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },

    ColorDisabled =
    {
        r = 0.5,
        g = 0.5,
        b = 0.5,
        a = 1,
    },
}

-------------------------------------------------------------------------------
-- Extend
-------------------------------------------------------------------------------

function BaseWidget:Extend(prototype)

    prototype = prototype or {}
    setmetatable(prototype, { __index = self })

    return prototype

end

-------------------------------------------------------------------------------
-- Instance
-------------------------------------------------------------------------------

function BaseWidget:CreateInstance(manager, id, parent, options)

    local instance = setmetatable({}, { __index = self })

    instance.Manager = manager
    instance.Id = id
    instance.Parent = parent
    instance.Options = options or {}
    instance.Enabled = true
    instance.Active = true

    return instance

end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function BaseWidget:Initialize(manager, id, parent, options)

    self.Manager = manager
    self.Id = id
    self.Parent = parent
    self.Options = options or {}
    self.Enabled = true
    self.Active = true

end

function BaseWidget:Enable()

    self.Active = true

    if self.Frame then
        self.Frame:Show()
    end

end

function BaseWidget:Disable()

    self.Active = false

    if self.Frame then
        self.Frame:Hide()
    end

end

function BaseWidget:Show()

    if self.Frame then
        self.Frame:Show()
    end

end

function BaseWidget:Hide()

    if self.Frame then
        self.Frame:Hide()
    end

end

function BaseWidget:Destroy()

    if self.Manager then
        self.Manager:Destroy(self)
    end

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function BaseWidget:SetValue(value)
end

function BaseWidget:GetValue()
    return nil
end

-------------------------------------------------------------------------------
-- Enabled State
-------------------------------------------------------------------------------

function BaseWidget:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.Frame then
        self.Frame:SetEnabled(self.Enabled)
    end

end

function BaseWidget:GetEnabled()

    return self.Enabled ~= false

end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

function BaseWidget:GetFrame()

    return self.Frame

end

function BaseWidget:GetType()

    return self.Type

end

function BaseWidget:ApplyFontColor(fontString, color)

    if not fontString then
        return
    end

    color = color or self.Style.Color

    fontString:SetTextColor(color.r, color.g, color.b, color.a)

end

function BaseWidget:InternalDestroy()

    if self.Frame then
        self.Frame:SetScript("OnShow", nil)
        self.Frame:SetScript("OnHide", nil)
        self.Frame:SetScript("OnEnter", nil)
        self.Frame:SetScript("OnLeave", nil)
        self.Frame:Hide()
        self.Frame:SetParent(nil)
        self.Frame = nil
    end

    self.OnChanged = nil
    self.OnClick = nil
    self.OnEnterPressed = nil
    self.Manager = nil

end

return BaseWidget
