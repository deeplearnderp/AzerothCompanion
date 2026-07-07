-------------------------------------------------------------------------------
-- Azeroth Companion
-- Widget Manager
--
-- Central factory and lifecycle manager for framework widgets.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local tinsert = table.insert

local WidgetManager = {}
AC.WidgetManager = WidgetManager

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

WidgetManager.Types = {}
WidgetManager.Factories = {}
WidgetManager.Widgets = {}
WidgetManager.NextId = 0
WidgetManager.Enabled = false
WidgetManager.Initialized = false

-------------------------------------------------------------------------------
-- Identity
-------------------------------------------------------------------------------

function WidgetManager:AllocateId()

    self.NextId = self.NextId + 1

    return self.NextId

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

function WidgetManager:RegisterWidgetType(name, prototype)

    assert(type(name) == "string" and name ~= "", "Widget type name must be a string.")
    assert(type(prototype) == "table", "Widget prototype must be a table.")

    if self.Types[name] then
        error(("Widget type '%s' is already registered."):format(name))
    end

    prototype.Type = name
    self.Types[name] = prototype

    self:RegisterFactory(name, function(manager, parent, options)
        local id = manager:AllocateId()
        local widget = prototype:CreateInstance(manager, id, parent, options)
        widget:Initialize(manager, id, parent, options)
        manager.Widgets[id] = widget
        return widget
    end)

end

function WidgetManager:RegisterFactory(name, factory)

    assert(type(name) == "string" and name ~= "", "Widget type name must be a string.")
    assert(type(factory) == "function", "Widget factory must be a function.")

    if self.Factories[name] and not self.Types[name] then
        error(("Widget factory '%s' is already registered."):format(name))
    end

    self.Factories[name] = factory

end

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function WidgetManager:Create(widgetType, parent, options)

    if not self.Enabled then

        if AC.Logger then
            AC.Logger:Warn(("WidgetManager:Create('%s') called before enable."):format(tostring(widgetType)))
        end

    end

    local factory = self.Factories[widgetType]

    if not factory then
        error(("Unknown widget type '%s'."):format(tostring(widgetType)))
    end

    return factory(self, parent, options or {})

end

-------------------------------------------------------------------------------
-- Get
-------------------------------------------------------------------------------

function WidgetManager:Get(id)

    return self.Widgets[id]

end

function WidgetManager:GetType(widget)

    if type(widget) ~= "table" then
        return nil
    end

    return widget.Type

end

-------------------------------------------------------------------------------
-- Destroy
-------------------------------------------------------------------------------

function WidgetManager:Destroy(widget)

    local id

    if type(widget) == "table" then
        id = widget.Id
    else
        id = widget
        widget = self.Widgets[id]
    end

    if not widget then
        return false
    end

    if widget.InternalDestroy then
        widget:InternalDestroy()
    end

    self.Widgets[id] = nil

    return true

end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function WidgetManager:Initialize()

    if self.Initialized then
        return
    end

    self.Initialized = true

    if AC.Logger then
        AC.Logger:Debug("WidgetManager initialized.")
    end

end

function WidgetManager:Enable()

    self.Enabled = true

    if AC.Logger then
        AC.Logger:Debug("WidgetManager enabled.")
    end

end

function WidgetManager:Disable()

    self.Enabled = false

    for id, widget in pairs(self.Widgets) do

        if widget.Disable then
            widget:Disable()
        end

    end

    if AC.Logger then
        AC.Logger:Debug("WidgetManager disabled.")
    end

end

function WidgetManager:Shutdown()

    for id in pairs(self.Widgets) do
        self:Destroy(id)
    end

    self.Widgets = {}
    self.Enabled = false
    self.Initialized = false

    if AC.Logger then
        AC.Logger:Debug("WidgetManager shut down.")
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("WidgetManager", WidgetManager)

return WidgetManager
