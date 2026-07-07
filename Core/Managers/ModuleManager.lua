-------------------------------------------------------------------------------
-- Azeroth Companion
-- Module Manager
--
-- Responsible for registering and managing addon modules.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ModuleManager = {}
AC.ModuleManager = ModuleManager

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

ModuleManager.Modules = {}
ModuleManager.Order = {}

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

function ModuleManager:Register(name, module)

    assert(type(name) == "string", "Module name must be a string.")
    assert(type(module) == "table", "Module must be a table.")

    if self.Modules[name] then
        error(("Module '%s' is already registered."):format(name))
    end

    module.Name = name

    self.Modules[name] = module
    table.insert(self.Order, module)

end

-------------------------------------------------------------------------------
-- Get
-------------------------------------------------------------------------------

function ModuleManager:Get(name)

    return self.Modules[name]

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function ModuleManager:InitializeModules()

    for _, module in ipairs(self.Order) do

        if module.Initialize then
            module:Initialize()
        end

    end

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function ModuleManager:EnableModules()

    for _, module in ipairs(self.Order) do

        if module.Enable then
            module:Enable()
        end

    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function ModuleManager:DisableModules()

    for i = #self.Order, 1, -1 do

        local module = self.Order[i]

        if module.Disable then
            module:Disable()
        end

    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function ModuleManager:ShutdownModules()

    for i = #self.Order, 1, -1 do

        local module = self.Order[i]

        if module.Shutdown then
            module:Shutdown()
        end

    end

end

return ModuleManager