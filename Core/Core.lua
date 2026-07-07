-------------------------------------------------------------------------------
-- Azeroth Companion
-- Core
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Core = {}
AC.Core = Core

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Core:Initialize()

    ---------------------------------------------------------------------------
    -- Services
    ---------------------------------------------------------------------------

    AC.ServiceManager:Initialize()

    ---------------------------------------------------------------------------
    -- Modules
    ---------------------------------------------------------------------------

    if AC.ModuleManager then
        AC.ModuleManager:InitializeModules()
        AC.ModuleManager:EnableModules()
    end

    AC.ServiceManager:Enable()

    ---------------------------------------------------------------------------
    -- Ready
    ---------------------------------------------------------------------------

    if AC.Events then
        AC.Events:Fire("FRAMEWORK_INITIALIZED")
    end

    if AC.Logger then
        AC.Logger:Info("Framework ready.")
        AC.Logger:Info("Type /ac help for commands.")
    end

end

-------------------------------------------------------------------------------
-- Services
-------------------------------------------------------------------------------

function Core:RegisterService(name, service)

    AC.ServiceManager:Register(name, service)

end

function Core:GetService(name)

    return AC.ServiceManager:Get(name)

end

-------------------------------------------------------------------------------
-- Modules
-------------------------------------------------------------------------------

function Core:RegisterModule(name, module)

    AC.ModuleManager:Register(name, module)

end

function Core:GetModule(name)

    return AC.ModuleManager:Get(name)

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function Core:GetConfig(moduleName)

    return AC.ConfigurationManager:Get(moduleName)

end

return Core
