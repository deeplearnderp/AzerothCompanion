-------------------------------------------------------------------------------
-- Azeroth Companion
-- Configuration Manager
--
-- Provides profile-backed configuration access for all modules.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ConfigurationManager = {}
AC.ConfigurationManager = ConfigurationManager

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

ConfigurationManager.Defaults = {}

-------------------------------------------------------------------------------
-- Register Defaults
-------------------------------------------------------------------------------

function ConfigurationManager:Register(moduleName, defaults)

    assert(type(moduleName) == "string", "Module name must be a string.")
    assert(type(defaults) == "table", "Defaults must be a table.")

    self.Defaults[moduleName] = defaults

    local profile = AC.DatabaseService:GetProfile()

    if type(profile[moduleName]) ~= "table" then
        profile[moduleName] = {}
    end

    self:Merge(defaults, profile[moduleName])

end

-------------------------------------------------------------------------------
-- Recursive Merge
-------------------------------------------------------------------------------

function ConfigurationManager:Merge(defaults, destination)

    for key, value in pairs(defaults) do

        if type(value) == "table" then

            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end

            self:Merge(value, destination[key])

        elseif destination[key] == nil then

            destination[key] = value

        end

    end

end

-------------------------------------------------------------------------------
-- Get Module Config
-------------------------------------------------------------------------------

function ConfigurationManager:Get(moduleName)

    local profile = AC.DatabaseService:GetProfile()

    if not profile[moduleName] then
        profile[moduleName] = {}
    end

    return profile[moduleName]

end

-------------------------------------------------------------------------------
-- Get Value
-------------------------------------------------------------------------------

function ConfigurationManager:GetValue(moduleName, key)

    local config = self:Get(moduleName)

    return config[key]

end

-------------------------------------------------------------------------------
-- Set Value
-------------------------------------------------------------------------------

function ConfigurationManager:SetValue(moduleName, key, value)

    local config = self:Get(moduleName)

    config[key] = value

end

return ConfigurationManager