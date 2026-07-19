-------------------------------------------------------------------------------
-- Azeroth Companion
-- Color Picker Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local ColorPicker = BaseWidget:Extend({ Type = "ColorPicker" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function ColorPicker:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    local color = opts.color

    if type(color) == "table" then
        self.Color =
        {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
            a = color.a or 1,
        }
    else
        self.Color =
        {
            r = opts.r or 1,
            g = opts.g or 1,
            b = opts.b or 1,
            a = opts.a or 1,
        }
    end

    self.OnChanged = opts.onChanged

    local frame = CreateFrame("Button", "AzerothCompanionWidgetColorPicker" .. id, parent)
    frame:SetSize(opts.size or style.ColorPickerSize, opts.size or style.ColorPickerSize)

    local swatch = frame:CreateTexture(nil, "BACKGROUND")
    swatch:SetAllPoints()
    swatch:SetColorTexture(self.Color.r, self.Color.g, self.Color.b, self.Color.a)

    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0.8)

    local inner = frame:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(self.Color.r, self.Color.g, self.Color.b, self.Color.a)

    -- Hover feedback -- Button's built-in highlight texture is independent
    -- of the shared BaseWidget tooltip handlers. Every other clickable
    -- swatch/card/link in this addon hover-highlights; this was the one that
    -- didn't.
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.25)
    frame:SetHighlightTexture(highlight)

    frame:SetScript("OnClick", function()
        if self.Enabled then
            self:OpenPicker()
        end
    end)

    self.Frame = frame
    self.Swatch = inner

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Color
-------------------------------------------------------------------------------

function ColorPicker:UpdateSwatch()

    if self.Swatch then
        self.Swatch:SetColorTexture(self.Color.r, self.Color.g, self.Color.b, self.Color.a)
    end

end

function ColorPicker:OpenPicker()

    local widget = self
    local previous =
    {
        r = self.Color.r,
        g = self.Color.g,
        b = self.Color.b,
        a = self.Color.a,
    }

    ColorPickerFrame:SetupColorPickerAndShow(
    {
        r = previous.r,
        g = previous.g,
        b = previous.b,
        opacity = previous.a,
        hasOpacity = true,

        swatchFunc = function()

            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()

            widget.Color.r = r
            widget.Color.g = g
            widget.Color.b = b
            widget.Color.a = a

            widget:UpdateSwatch()

            if widget.OnChanged then
                widget.OnChanged(widget, widget.Color)
            end

        end,

        cancelFunc = function()

            widget.Color.r = previous.r
            widget.Color.g = previous.g
            widget.Color.b = previous.b
            widget.Color.a = previous.a

            widget:UpdateSwatch()

        end,

        finishedFunc = function()

            if widget.OnChanged then
                widget.OnChanged(widget, widget.Color)
            end

        end,
    })

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function ColorPicker:SetValue(color)

    if type(color) ~= "table" then
        return
    end

    self.Color.r = color.r or self.Color.r
    self.Color.g = color.g or self.Color.g
    self.Color.b = color.b or self.Color.b
    self.Color.a = color.a or self.Color.a

    self:UpdateSwatch()

end

function ColorPicker:GetValue()

    return
    {
        r = self.Color.r,
        g = self.Color.g,
        b = self.Color.b,
        a = self.Color.a,
    }

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function ColorPicker:SetOnChanged(callback)

    self.OnChanged = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function ColorPicker:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.Frame then
        self.Frame:SetEnabled(self.Enabled)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("ColorPicker", ColorPicker)

return ColorPicker
