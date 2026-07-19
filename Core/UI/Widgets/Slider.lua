-------------------------------------------------------------------------------
-- Azeroth Companion
-- Slider Widget
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWidget = AC.BaseWidget
local Slider = BaseWidget:Extend({ Type = "Slider" })

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Slider:Initialize(manager, id, parent, options)

    BaseWidget.Initialize(self, manager, id, parent, options)

    local style = BaseWidget.Style
    local opts = self.Options

    self.Minimum = opts.minimum or opts.min or 0
    self.Maximum = opts.maximum or opts.max or 100
    self.Step = opts.step or 1
    self.Value = opts.value or self.Minimum
    self.OnChanged = opts.onChanged

    local frame = CreateFrame("Frame", "AzerothCompanionWidgetSlider" .. id, parent)
    frame:SetSize(opts.width or style.SliderWidth, opts.height or style.Height)

    local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", frame, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    slider:SetHeight(style.SliderHeight)
    slider:SetMinMaxValues(self.Minimum, self.Maximum)
    slider:SetValueStep(self.Step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(self.Value)

    if slider.Low then
        slider.Low:SetText(tostring(self.Minimum))
    end

    if slider.High then
        slider.High:SetText(tostring(self.Maximum))
    end

    if slider.Text then
        slider.Text:SetText(tostring(self.Value))
    end

    slider:SetScript("OnValueChanged", function(control, value)

        if not self.Enabled then
            return
        end

        self.Value = value

        if control.Text then
            control.Text:SetText(tostring(value))
        end

        if self.Suppress then
            return
        end

        if self.OnChanged then
            self.OnChanged(self, value)
        end

    end)

    self.Frame = frame
    self.Slider = slider
    self.TooltipTargets = { slider }

    if opts.tooltip then
        self:SetTooltip(opts.tooltip)
    end

end

-------------------------------------------------------------------------------
-- Value
-------------------------------------------------------------------------------

function Slider:SetValue(value)

    value = tonumber(value) or self.Minimum

    if value < self.Minimum then
        value = self.Minimum
    elseif value > self.Maximum then
        value = self.Maximum
    end

    self.Value = value

    if self.Slider then

        self.Suppress = true
        self.Slider:SetValue(value)
        self.Suppress = false

        if self.Slider.Text then
            self.Slider.Text:SetText(tostring(value))
        end

    end

end

function Slider:GetValue()

    if self.Slider then
        return self.Slider:GetValue()
    end

    return self.Value

end

-------------------------------------------------------------------------------
-- Range
-------------------------------------------------------------------------------

function Slider:SetRange(minimum, maximum)

    self.Minimum = minimum or 0
    self.Maximum = maximum or 100

    if self.Slider then
        self.Slider:SetMinMaxValues(self.Minimum, self.Maximum)

        if self.Slider.Low then
            self.Slider.Low:SetText(tostring(self.Minimum))
        end

        if self.Slider.High then
            self.Slider.High:SetText(tostring(self.Maximum))
        end

    end

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function Slider:SetOnChanged(callback)

    self.OnChanged = callback

end

-------------------------------------------------------------------------------
-- Enabled
-------------------------------------------------------------------------------

function Slider:SetEnabled(enabled)

    self.Enabled = enabled ~= false

    if self.Slider then
        self.Slider:SetEnabled(self.Enabled)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.WidgetManager:RegisterWidgetType("Slider", Slider)

return Slider
