-------------------------------------------------------------------------------
-- Azeroth Companion
-- Content Panel
--
-- Scrollable settings content with automatic layout and widget reuse.
--
-- Widgets never write directly into ConfigurationManager. A widget change
-- reports into PendingValues and marks the panel Dirty; ConfigurationManager
-- is only written to by Save(), which commits only the values that
-- actually changed and fires SETTINGS_CHANGED for those. Cancel() discards
-- PendingValues and reloads every widget from ConfigurationManager using
-- the existing RefreshAllPages() path.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local tinsert = table.insert

local ContentPanel = {}
AC.ContentPanel = ContentPanel

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------

ContentPanel.Layout =
{
    Margin = 16,
    Padding = 12,
    SectionSpacing = 20,
    ControlSpacing = 8,
    HeaderHeight = 22,
    ControlIndent = 8,
    ControlWidth = 420,
}

-------------------------------------------------------------------------------
-- Value Comparison
--
-- Used by Save() to decide which pending values actually differ from what
-- is already persisted. Handles both plain values and flat tables (e.g.
-- ColorPicker's {r, g, b, a}).
-------------------------------------------------------------------------------

local function ValuesEqual(a, b)

    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end

    for k, v in pairs(b) do
        if a[k] ~= v then
            return false
        end
    end

    return true

end

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function ContentPanel:Create(parent)

    local panel =
    {
        Parent = parent,
        PageFrames = {},
        ActivePageId = nil,
        SettingsManager = nil,
        PendingValues = {},
        Dirty = false,
        OnDirtyChanged = nil,
    }

    setmetatable(panel, { __index = self })

    local scrollFrame = CreateFrame("ScrollFrame", "AzerothCompanionSettingsContentScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 8)

    local scrollChild = CreateFrame("Frame", "AzerothCompanionSettingsContentChild", scrollFrame)
    scrollChild:SetWidth(ContentPanel.Layout.ControlWidth + (ContentPanel.Layout.Margin * 2))
    scrollFrame:SetScrollChild(scrollChild)

    panel.Frame = scrollFrame
    panel.ScrollChild = scrollChild

    local emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ContentPanel.Layout.Margin, -ContentPanel.Layout.Margin)
    emptyLabel:SetText("No settings pages are registered.")
    emptyLabel:Hide()

    panel.EmptyLabel = emptyLabel

    return panel

end

-------------------------------------------------------------------------------
-- Manager
-------------------------------------------------------------------------------

function ContentPanel:SetSettingsManager(manager)

    self.SettingsManager = manager

end

-------------------------------------------------------------------------------
-- Dirty State
-------------------------------------------------------------------------------

function ContentPanel:SetOnDirtyChanged(callback)

    self.OnDirtyChanged = callback

end

function ContentPanel:IsDirty()

    return self.Dirty == true

end

function ContentPanel:MarkDirty()

    if self.Dirty then
        return
    end

    self.Dirty = true

    if self.OnDirtyChanged then
        self.OnDirtyChanged(true)
    end

end

function ContentPanel:ClearDirty()

    if not self.Dirty then
        return
    end

    self.Dirty = false

    if self.OnDirtyChanged then
        self.OnDirtyChanged(false)
    end

end

-------------------------------------------------------------------------------
-- Pending Values
--
-- The only place a widget change lands before Save. Nothing here touches
-- ConfigurationManager -- that only happens in Save().
-------------------------------------------------------------------------------

function ContentPanel:SetPendingValue(moduleName, key, value)

    if not moduleName or not key then
        return
    end

    self.PendingValues[moduleName] = self.PendingValues[moduleName] or {}
    self.PendingValues[moduleName][key] = value

    self:MarkDirty()

end

function ContentPanel:GetPendingValue(moduleName, key)

    local moduleValues = self.PendingValues[moduleName]

    if not moduleValues then
        return nil, false
    end

    local value = moduleValues[key]

    if value == nil then
        return nil, false
    end

    return value, true

end

-------------------------------------------------------------------------------
-- Save
--
-- Compares PendingValues against ConfigurationManager, writes only the
-- values that actually changed, fires SETTINGS_CHANGED only for those,
-- then clears pending/dirty state.
-------------------------------------------------------------------------------

function ContentPanel:Save()

    local configuration = AC.ConfigurationManager
    local manager = self.SettingsManager

    for moduleName, moduleValues in pairs(self.PendingValues) do

        for key, value in pairs(moduleValues) do

            local current = configuration:GetValue(moduleName, key)

            if not ValuesEqual(current, value) then

                configuration:SetValue(moduleName, key, value)

                if manager then
                    manager:NotifyChanged(moduleName, key, value)
                end

            end

        end

    end

    self.PendingValues = {}

    self:ClearDirty()

end

-------------------------------------------------------------------------------
-- Cancel
--
-- Discards PendingValues and reloads every widget from ConfigurationManager
-- via the existing RefreshAllPages() path -- no new reload logic needed.
-------------------------------------------------------------------------------

function ContentPanel:Cancel()

    self.PendingValues = {}

    self:RefreshAllPages()

    self:ClearDirty()

end

-------------------------------------------------------------------------------
-- Show Page
-------------------------------------------------------------------------------

function ContentPanel:ShowPage(pageId, page)

    if not page then
        self:ShowEmpty()
        return
    end

    if self.EmptyLabel then
        self.EmptyLabel:Hide()
    end

    if self.ActivePageId and self.ActivePageId ~= pageId then

        local previous = self.PageFrames[self.ActivePageId]

        if previous and previous.Frame then
            previous.Frame:Hide()
        end

    end

    local cached = self.PageFrames[pageId]

    if not cached then
        cached = self:BuildPage(page)
        self.PageFrames[pageId] = cached
    end

    cached.Frame:Show()
    self.ActivePageId = pageId

    self.ScrollChild:SetHeight(cached.Frame:GetHeight())
    self.Frame:SetVerticalScroll(0)

    self:RefreshPageValues(cached)

end

-------------------------------------------------------------------------------
-- Empty
-------------------------------------------------------------------------------

function ContentPanel:ShowEmpty()

    for pageId, cached in pairs(self.PageFrames) do

        if cached.Frame then
            cached.Frame:Hide()
        end

    end

    self.ActivePageId = nil

    if self.EmptyLabel then
        self.EmptyLabel:Show()
    end

end

-------------------------------------------------------------------------------
-- Build Page
-------------------------------------------------------------------------------

function ContentPanel:BuildPage(page)

    local layout = self.Layout
    local widgetManager = AC.WidgetManager
    local scrollChild = self.ScrollChild

    local pageFrame = CreateFrame("Frame", "AzerothCompanionSettingsPage" .. page.Id, scrollChild)
    pageFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    pageFrame:SetWidth(scrollChild:GetWidth())

    local title = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", layout.Margin, -layout.Margin)
    title:SetText(page.Title)

    local yOffset = -layout.Margin - layout.HeaderHeight - layout.Padding
    local bindings = {}

    for sectionIndex = 1, #page.SectionOrder do

        local section = page.SectionOrder[sectionIndex]

        local header = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", layout.Margin, yOffset)
        header:SetText(section.Title)

        yOffset = yOffset - layout.HeaderHeight - layout.ControlSpacing

        for controlIndex = 1, #section.Controls do

            local controlDef = section.Controls[controlIndex]
            local widget = self:CreateWidget(widgetManager, pageFrame, controlDef)

            if widget then

                local frame = widget:GetFrame()
                local height = self:GetWidgetHeight(controlDef.type)

                frame:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", layout.Margin + layout.ControlIndent, yOffset)
                frame:SetWidth(layout.ControlWidth - layout.ControlIndent)

                if controlDef.type == "Slider" and frame.SetWidth then
                    frame:SetWidth(layout.ControlWidth - layout.ControlIndent)
                end

                self:BindControl(page, controlDef, widget)

                tinsert(bindings,
                {
                    Control = controlDef,
                    Widget = widget,
                })

                yOffset = yOffset - height - layout.ControlSpacing

            end

        end

        yOffset = yOffset - layout.SectionSpacing

    end

    pageFrame:SetHeight(math.abs(yOffset) + layout.Margin)

    return
    {
        Frame = pageFrame,
        Bindings = bindings,
        Page = page,
    }

end

-------------------------------------------------------------------------------
-- Widget Height
-------------------------------------------------------------------------------

function ContentPanel:GetWidgetHeight(widgetType)

    local style = AC.BaseWidget.Style

    if widgetType == "Slider" then
        return style.Height
    elseif widgetType == "Button" then
        return style.ButtonHeight
    elseif widgetType == "EditBox" then
        return style.EditBoxHeight
    elseif widgetType == "ColorPicker" then
        return style.ColorPickerSize
    end

    return style.Height

end

-------------------------------------------------------------------------------
-- Widget Options
-------------------------------------------------------------------------------

function ContentPanel:GetCommonOptions(controlDef)

    return
    {
        text = controlDef.text,
        tooltip = controlDef.tooltip,
        width = controlDef.width,
        height = controlDef.height,
    }

end

function ContentPanel:BuildCheckboxOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    options.checked = controlDef.default == true

    return options

end

function ContentPanel:BuildSliderOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    options.minimum = controlDef.minimum or controlDef.min
    options.maximum = controlDef.maximum or controlDef.max
    options.step = controlDef.step
    options.value = tonumber(controlDef.default) or options.minimum or 0

    return options

end

function ContentPanel:BuildEditBoxOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    if type(controlDef.default) == "string" or type(controlDef.default) == "number" then
        options.value = tostring(controlDef.default)
    else
        options.value = ""
    end

    options.onEnterPressed = controlDef.onEnterPressed

    return options

end

function ContentPanel:BuildLabelOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    if controlDef.text then
        options.text = controlDef.text
    elseif type(controlDef.default) == "string" or type(controlDef.default) == "number" then
        options.text = tostring(controlDef.default)
    end

    options.font = controlDef.font
    options.color = controlDef.color
    options.justifyH = controlDef.justifyH

    return options

end

function ContentPanel:BuildButtonOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    options.onClick = controlDef.onClick

    return options

end

function ContentPanel:BuildDropdownOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)

    options.list = controlDef.list
    options.selection = controlDef.selection

    if not options.selection and controlDef.default ~= nil and controlDef.list then

        for i = 1, #controlDef.list do

            local option = controlDef.list[i]
            local value = type(option) == "table" and option.value or option

            if value == controlDef.default then
                options.selection = i
                break
            end

        end

    end

    return options

end

function ContentPanel:BuildColorPickerOptions(controlDef)

    local options = self:GetCommonOptions(controlDef)
    local color

    if type(controlDef.default) == "table" then
        color = controlDef.default
    elseif type(controlDef.color) == "table" then
        color = controlDef.color
    end

    if color then
        options.color =
        {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
            a = color.a or 1,
        }
    else
        options.color =
        {
            r = controlDef.r or 1,
            g = controlDef.g or 1,
            b = controlDef.b or 1,
            a = controlDef.a or 1,
        }
    end

    options.size = controlDef.size

    return options

end

-------------------------------------------------------------------------------
-- Create Widget
-------------------------------------------------------------------------------

function ContentPanel:CreateWidget(widgetManager, parent, controlDef)

    local widgetType = controlDef.type

    if widgetType == "Checkbox" then
        return widgetManager:Create("Checkbox", parent, self:BuildCheckboxOptions(controlDef))
    elseif widgetType == "Slider" then
        return widgetManager:Create("Slider", parent, self:BuildSliderOptions(controlDef))
    elseif widgetType == "Dropdown" then
        return widgetManager:Create("Dropdown", parent, self:BuildDropdownOptions(controlDef))
    elseif widgetType == "Button" then
        return widgetManager:Create("Button", parent, self:BuildButtonOptions(controlDef))
    elseif widgetType == "EditBox" then
        return widgetManager:Create("EditBox", parent, self:BuildEditBoxOptions(controlDef))
    elseif widgetType == "ColorPicker" then
        return widgetManager:Create("ColorPicker", parent, self:BuildColorPickerOptions(controlDef))
    elseif widgetType == "Label" then
        return widgetManager:Create("Label", parent, self:BuildLabelOptions(controlDef))
    end

    return nil

end

-------------------------------------------------------------------------------
-- Bind Control
--
-- Widget changes report into PendingValues (via SetPendingValue) instead
-- of writing to ConfigurationManager directly. The Button+key action path
-- is unchanged: it reads the currently PERSISTED value for a custom
-- onClick handler and isn't a settings input participating in Save/Cancel.
-------------------------------------------------------------------------------

function ContentPanel:BindControl(page, controlDef, widget)

    if controlDef.type == "Label" then
        return
    end

    if controlDef.type == "Button" and not controlDef.key then
        return
    end

    local moduleName = controlDef.module or controlDef.moduleName or page.Module
    local key = controlDef.key

    if not moduleName or not key then
        return
    end

    local manager = self.SettingsManager
    local configuration = AC.ConfigurationManager

    if not manager then
        return
    end

    manager:EnsureDefault(moduleName, key, controlDef.default)

    if controlDef.type == "Checkbox" then

        widget:SetOnChanged(function(_, value)

            local checked = value == true

            self:SetPendingValue(moduleName, key, checked)

            if controlDef.onChanged then
                controlDef.onChanged(widget, checked)
            end

        end)

    elseif controlDef.type == "Slider" then

        widget:SetOnChanged(function(_, value)

            local numberValue = tonumber(value)

            if numberValue == nil then
                return
            end

            self:SetPendingValue(moduleName, key, numberValue)

            if controlDef.onChanged then
                controlDef.onChanged(widget, numberValue)
            end

        end)

    elseif controlDef.type == "Dropdown" then

        widget:SetOnChanged(function(_, value, index)

            self:SetPendingValue(moduleName, key, value)

            if controlDef.onChanged then
                controlDef.onChanged(widget, value, index)
            end

        end)

    elseif controlDef.type == "EditBox" then

        widget:SetOnChanged(function(_, value)

            local textValue = tostring(value or "")

            self:SetPendingValue(moduleName, key, textValue)

            if controlDef.onChanged then
                controlDef.onChanged(widget, textValue)
            end

        end)

        if controlDef.onEnterPressed then
            widget:SetOnEnterPressed(controlDef.onEnterPressed)
        end

    elseif controlDef.type == "ColorPicker" then

        widget:SetOnChanged(function(_, value)

            if type(value) ~= "table" then
                return
            end

            local color =
            {
                r = value.r or 1,
                g = value.g or 1,
                b = value.b or 1,
                a = value.a or 1,
            }

            self:SetPendingValue(moduleName, key, color)

            if controlDef.onChanged then
                controlDef.onChanged(widget, color)
            end

        end)

    elseif controlDef.type == "Button" and controlDef.key then

        widget:SetOnClick(function()

            local current = configuration:GetValue(moduleName, key)

            if controlDef.onClick then
                controlDef.onClick(widget, current)
            end

        end)

    end

end

-------------------------------------------------------------------------------
-- Refresh
--
-- Displays a control's PendingValue if one exists (so switching tabs
-- never loses an unsaved edit); otherwise falls back to the persisted
-- ConfigurationManager value, exactly as before.
-------------------------------------------------------------------------------

function ContentPanel:ApplyWidgetValue(controlDef, widget, value)

    if value == nil then
        return
    end

    if controlDef.type == "Checkbox" then
        widget:SetValue(value == true)
    elseif controlDef.type == "Slider" then
        widget:SetValue(tonumber(value))
    elseif controlDef.type == "EditBox" then
        widget:SetValue(tostring(value))
    elseif controlDef.type == "Label" then
        widget:SetValue(tostring(value))
    elseif controlDef.type == "Dropdown" then
        widget:SetValue(value)
    elseif controlDef.type == "ColorPicker" then
        if type(value) == "table" then
            widget:SetValue(value)
        end
    elseif controlDef.type == "Button" then
        widget:SetValue(tostring(value))
    end

end

function ContentPanel:RefreshPageValues(cached)

    if not cached or not cached.Bindings then
        return
    end

    local configuration = AC.ConfigurationManager
    local page = cached.Page

    for i = 1, #cached.Bindings do

        local binding = cached.Bindings[i]
        local controlDef = binding.Control
        local widget = binding.Widget

        if controlDef.type == "Button" and not controlDef.key then
            -- action button
        elseif controlDef.type == "Label" and not controlDef.key then
            -- static label
        else

            local moduleName = controlDef.module or controlDef.moduleName or page.Module
            local key = controlDef.key

            if moduleName and key then

                local pendingValue, hasPending = self:GetPendingValue(moduleName, key)
                local value

                if hasPending then
                    value = pendingValue
                else
                    value = configuration:GetValue(moduleName, key)
                end

                self:ApplyWidgetValue(controlDef, widget, value)

            end

        end

    end

end

function ContentPanel:RefreshActivePage()

    if not self.ActivePageId then
        return
    end

    local cached = self.PageFrames[self.ActivePageId]

    if cached then
        self:RefreshPageValues(cached)
    end

end

function ContentPanel:RefreshAllPages()

    for pageId, cached in pairs(self.PageFrames) do
        self:RefreshPageValues(cached)
    end

end

function ContentPanel:DestroyPage(pageId)

    local cached = self.PageFrames[pageId]

    if not cached then
        return
    end

    if cached.Bindings then

        for i = 1, #cached.Bindings do

            local widget = cached.Bindings[i].Widget

            if widget then
                AC.WidgetManager:Destroy(widget)
            end

        end

    end

    if cached.Frame then
        cached.Frame:Hide()
        cached.Frame:SetParent(nil)
    end

    self.PageFrames[pageId] = nil

    if self.ActivePageId == pageId then
        self.ActivePageId = nil
    end

end

-------------------------------------------------------------------------------
-- Destroy
-------------------------------------------------------------------------------

function ContentPanel:Destroy()

    for pageId in pairs(self.PageFrames) do
        self:DestroyPage(pageId)
    end

    self.PageFrames = {}
    self.ActivePageId = nil
    self.PendingValues = {}

    self:ClearDirty()

end

return ContentPanel
