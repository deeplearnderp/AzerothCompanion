-------------------------------------------------------------------------------
-- Azeroth Companion
-- Database Service
--
-- Enterprise database service.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DatabaseService = {}
AC.DatabaseService = DatabaseService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

DatabaseService.SchemaVersion = 1

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

DatabaseService.Defaults =
{
    Metadata =
    {
        SchemaVersion = DatabaseService.SchemaVersion,
    },

    Global =
    {
        Minimap =
        {
            hide = false,
        },
    },

    Profiles =
    {
        Default =
        {
            Debug = false,
        },
    },

    Characters =
    {

    },
}

-------------------------------------------------------------------------------
-- Utilities
-------------------------------------------------------------------------------

local function DeepCopy(source)

    if type(source) ~= "table" then
        return source
    end

    local copy = {}

    for key, value in pairs(source) do
        copy[key] = DeepCopy(value)
    end

    return copy

end

local function MergeDefaults(defaults, destination)

    if type(defaults) ~= "table" then
        return
    end

    if type(destination) ~= "table" then
        return
    end

    for key, value in pairs(defaults) do

        if type(value) == "table" then

            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end

            MergeDefaults(value, destination[key])

        elseif destination[key] == nil then

            destination[key] = value

        end

    end

end

-------------------------------------------------------------------------------
-- Character Key
-------------------------------------------------------------------------------

function DatabaseService:GetCharacterKey()

    local name = UnitName("player")
    local realm = GetRealmName()

    return realm .. "." .. name

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function DatabaseService:Initialize()

    if self.Initialized then
        return
    end

    AzerothCompanionDB = AzerothCompanionDB or {}

    MergeDefaults(self.Defaults, AzerothCompanionDB)

    self.DB = AzerothCompanionDB

    local character = self:GetCharacterKey()

    if not self.DB.Characters[character] then

        self.DB.Characters[character] =
        {
            Profile = "Default",
        }

    end

    self:Migrate()

    self.Initialized = true

    if AC.Logger then
        AC.Logger:Info("Database initialized.")
    end

end

-------------------------------------------------------------------------------
-- Root
-------------------------------------------------------------------------------

function DatabaseService:GetDatabase()

    return self.DB

end

-------------------------------------------------------------------------------
-- Global
-------------------------------------------------------------------------------

function DatabaseService:GetGlobal()

    return self.DB.Global

end

-------------------------------------------------------------------------------
-- Character
-------------------------------------------------------------------------------

function DatabaseService:GetCharacter()

    return self.DB.Characters[self:GetCharacterKey()]

end

-------------------------------------------------------------------------------
-- Profile Name
-------------------------------------------------------------------------------

function DatabaseService:GetActiveProfileName()

    return self:GetCharacter().Profile

end

-------------------------------------------------------------------------------
-- Profile
-------------------------------------------------------------------------------

function DatabaseService:GetProfile()

    local profile = self:GetActiveProfileName()

    if not self.DB.Profiles[profile] then
        self.DB.Profiles[profile] = {}
    end

    MergeDefaults(self.Defaults.Profiles.Default, self.DB.Profiles[profile])

    return self.DB.Profiles[profile]

end

-------------------------------------------------------------------------------
-- Create Profile
-------------------------------------------------------------------------------

function DatabaseService:CreateProfile(name)

    if self.DB.Profiles[name] then
        return false
    end

    self.DB.Profiles[name] = DeepCopy(self.Defaults.Profiles.Default)

    return true

end

-------------------------------------------------------------------------------
-- Switch Profile
-------------------------------------------------------------------------------

function DatabaseService:SetActiveProfile(name)

    if not self.DB.Profiles[name] then
        return false
    end

    self:GetCharacter().Profile = name

    return true

end

-------------------------------------------------------------------------------
-- Delete Profile
-------------------------------------------------------------------------------

function DatabaseService:DeleteProfile(name)

    if name == "Default" then
        return false
    end

    if not self.DB.Profiles[name] then
        return false
    end

    self.DB.Profiles[name] = nil

    for _, character in pairs(self.DB.Characters) do

        if character.Profile == name then
            character.Profile = "Default"
        end

    end

    return true

end

-------------------------------------------------------------------------------
-- Reset Profile
-------------------------------------------------------------------------------

function DatabaseService:ResetProfile()

    local profile = self:GetActiveProfileName()

    self.DB.Profiles[profile] = DeepCopy(self.Defaults.Profiles.Default)

end

-------------------------------------------------------------------------------
-- Reset Character
-------------------------------------------------------------------------------

function DatabaseService:ResetCharacter()

    self.DB.Characters[self:GetCharacterKey()] =
    {
        Profile = "Default",
    }

end

-------------------------------------------------------------------------------
-- Reset Database
-------------------------------------------------------------------------------

function DatabaseService:ResetDatabase()

    AzerothCompanionDB = DeepCopy(self.Defaults)

    self.DB = AzerothCompanionDB

end

-------------------------------------------------------------------------------
-- Migration Stub
-------------------------------------------------------------------------------

function DatabaseService:Migrate()

    local version = self.DB.Metadata.SchemaVersion or 0

    if version == self.SchemaVersion then
        return
    end

    self.DB.Metadata.SchemaVersion = self.SchemaVersion

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DatabaseService", DatabaseService)

return DatabaseService