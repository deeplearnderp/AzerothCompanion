-------------------------------------------------------------------------------
-- Azeroth Companion
-- Service Manager
--
-- Central lifecycle manager for framework services.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ServiceManager = {}
AC.ServiceManager = ServiceManager

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

ServiceManager.Services = {}
ServiceManager.Order = {}

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

function ServiceManager:Register(name, service)

    assert(type(name) == "string", "Service name must be a string.")
    assert(type(service) == "table", "Service must be a table.")

    if self.Services[name] then
        error(("Service '%s' is already registered."):format(name))
    end

    service.Name = name

    self.Services[name] = service
    table.insert(self.Order, service)

end

-------------------------------------------------------------------------------
-- Get
-------------------------------------------------------------------------------

function ServiceManager:Get(name)

    return self.Services[name]

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function ServiceManager:Initialize()

    for _, service in ipairs(self.Order) do

        if service.Initialize then
            service:Initialize()
        end

    end

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function ServiceManager:Enable()

    for _, service in ipairs(self.Order) do

        if service.Enable then
            service:Enable()
        end

    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function ServiceManager:Disable()

    for i = #self.Order, 1, -1 do

        local service = self.Order[i]

        if service.Disable then
            service:Disable()
        end

    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function ServiceManager:Shutdown()

    for i = #self.Order, 1, -1 do

        local service = self.Order[i]

        if service.Shutdown then
            service:Shutdown()
        end

    end

end

return ServiceManager
