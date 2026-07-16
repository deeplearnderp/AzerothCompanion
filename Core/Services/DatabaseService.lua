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

        -- Blizzard API verification records (VerificationService) and
        -- guided-checklist scenario completions (DeveloperPanel's
        -- Checklist tab) -- account-wide, not character-scoped, since
        -- whether a Blizzard API behaves as expected is a fact about the
        -- game client/account, not about any one character.
        VerificationLog = {},
        ChecklistLog = {},

        -- Player Journal: who you've grouped with, account-wide rather
        -- than per-character -- recognizing a past companion is a fact
        -- about the account/person playing, not about which alt you
        -- happened to be on (same reasoning as VerificationLog above).
        -- A fully separate top-level key from PlayerJournal itself, not
        -- nested under it -- CommunityModule never gets write access to
        -- PlayerJournal's own table at all, which is what makes
        -- "PlayerJournalModule works with CommunityModule disabled" a
        -- structural fact rather than just a currently-true one. See
        -- docs/GameplayModuleArchitecture.md section 1.11.
        PlayerJournal =
        {
            SchemaVersion = 1,
            Players = {},
            TotalPruned = 0,
        },

        PlayerJournalCommunity =
        {
            SchemaVersion = 1,
            Notes = {},
            CodeOfConductAccepted = false,
            TrustedSources = {},
        },

        -- Developer Runtime capability data (distinct from
        -- profile.DeveloperRuntime.<Capability>'s settings, which stay
        -- per-profile) -- account-wide for the same reason as
        -- VerificationLog/ChecklistLog above: whether this addon's own
        -- code throws is a fact about the account running it, not about
        -- which character is logged in. Nested here (not a flat top-level
        -- Global key) so future capabilities named in
        -- GameplayModuleArchitecture.md (Warning Capture, Performance
        -- Metrics, ...) have a natural, consistent home alongside
        -- ErrorCapture rather than each claiming their own Global key.
        DeveloperRuntime =
        {
            ErrorCapture =
            {
                SchemaVersion = 1,
                Errors = {},
            },
        },
    },

    Profiles =
    {
        Default =
        {
            Debug = false,
            DeveloperMode = false,
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
-- Migrations
--
-- Each entry is keyed by the schema version it upgrades TO, and receives
-- the raw SavedVariables root table (AzerothCompanionDB, i.e. self.DB) to
-- transform in place. Empty today -- no stored shape has ever needed to
-- change -- but this is the real mechanism SchemaVersion was always meant
-- to drive, run one version at a time from whatever is currently stored,
-- not a placeholder that only stamps a number.
--
-- Example, for when one is actually needed:
--   Migrations[2] = function(db)
--       for _, character in pairs(db.Characters) do
--           character.SomeRenamedField = character.OldFieldName
--           character.OldFieldName = nil
--       end
--   end
-------------------------------------------------------------------------------

DatabaseService.Migrations = {}

-------------------------------------------------------------------------------
-- Migrate
--
-- Walks forward one version at a time from whatever is currently stored.
-- Each step is pcall-wrapped: a migration that throws stops the walk at
-- the version before it, so SchemaVersion never advances past a step that
-- didn't actually run -- a broken migration is retried on the next login
-- instead of being silently skipped or corrupting data. A stored version
-- newer than this addon understands (the addon was downgraded) is left
-- completely untouched rather than having its version stamped backward.
-------------------------------------------------------------------------------

function DatabaseService:Migrate()

    local version = self.DB.Metadata.SchemaVersion or 0

    if version == self.SchemaVersion then
        return
    end

    if version > self.SchemaVersion then

        if AC.Logger then
            AC.Logger:Warn(string.format(
                "SavedVariables schema version (%d) is newer than this addon version supports (%d) -- likely a downgrade. Data left untouched.",
                version, self.SchemaVersion
            ))
        end

        return

    end

    while version < self.SchemaVersion do

        local nextVersion = version + 1
        local migration = self.Migrations[nextVersion]

        if migration then

            local ok, err = pcall(migration, self.DB)

            if not ok then

                if AC.Logger then
                    AC.Logger:Error(string.format(
                        "SavedVariables migration to schema version %d failed: %s. Stopping at version %d; will retry next login.",
                        nextVersion, tostring(err), version
                    ))
                end

                return

            end

            if AC.Logger then
                AC.Logger:Info(string.format("SavedVariables migrated to schema version %d.", nextVersion))
            end

        end

        version = nextVersion
        self.DB.Metadata.SchemaVersion = version

    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DatabaseService", DatabaseService)

return DatabaseService