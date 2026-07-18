-------------------------------------------------------------------------------
-- Azeroth Companion
-- Community Module
--
-- Community Observations -- firsthand, attributed experiences with another
-- player. Optional, disabled-by-default, entirely local in this version.
-- No sync backend, no server, no addon-channel broadcast exists yet; every
-- observation is only ever visible to the account that wrote it. The data
-- model (see Observation shape below) is deliberately richer than this
-- version's own behavior requires -- imported/verified/sourceType/
-- sourcePlayer all exist so a future sharing phase can build directly on
-- this record shape rather than reshaping it again later. This phase does
-- not implement sharing, importing, exporting, or any trust/verification
-- system -- every observation stored today has imported = false and
-- author == originalAuthor, always.
--
-- Fully independent of PlayerJournalModule: its own storage namespace
-- (DatabaseService:GetGlobal().PlayerJournalCommunity, a separate
-- top-level Global key, never nested under PlayerJournal's own table),
-- its own ConfigurationManager namespace ("Community"), its own Settings
-- page. This file never references PlayerJournalModule at all -- the
-- OBSERVED player (observations are keyed by playerKey) uses the same
-- "Realm.Name" convention PlayerJournalModule's own MakePlayerKey uses,
-- but that's a shared convention, not a dependency (deliberately left
-- alone -- changing it would mean PlayerJournalModule's own record keying
-- would need to change too, since the "Hide Observations" toggle lives on
-- its record). The AUTHOR (who wrote it) is a different identity
-- entirely -- CharacterModule's own stable character GUID, never a name --
-- see AddObservation's own comment. This independence is what makes
-- "PlayerJournalModule works perfectly with CommunityModule disabled" a
-- structural fact: PlayerJournalModule never reads this module's table,
-- and this module never writes to PlayerJournalModule's. (The one
-- exception, in the other direction: PlayerJournalModule:GetDeveloperStats()
-- reads this module's GetTotalObservationCount() for a single Developer
-- Panel diagnostic line -- a read-only, guarded, stats-only reference, not
-- a real dependency either module's own behavior relies on.)
--
-- The abandoned moderation system (Helpful/Not Helpful/Report/Hide voting,
-- with real local counters nobody could ever read since there was no
-- crowd to aggregate) has been removed entirely, not just its UI --
-- GetTrustedSources() is the one forward-looking stub kept, since it maps
-- to the still-planned Trust system (accept observations from party/
-- guild/Battle.net friends/everyone) rather than the abandoned voting
-- direction.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time
local pairs = pairs
local ipairs = ipairs

local CommunityModule =
{
    Name = "Community",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = false,
}

-------------------------------------------------------------------------------
-- Storage Access
-------------------------------------------------------------------------------

local function GetCommunityData()

    return AC.DatabaseService:GetGlobal().PlayerJournalCommunity

end

-- Realm.Name -> Name only, for display. The old Note format never stored
-- anything but this key, so migrated rows have no other name to show.
local function ExtractNameFromCharacterKey(characterKey)

    if not characterKey or characterKey == "" then
        return ""
    end

    return characterKey:match("%.(.+)$") or characterKey

end

-------------------------------------------------------------------------------
-- Schema Migration (1 -> 2: Notes -> Observations)
--
-- Independently scoped from DatabaseService.SchemaVersion (the same
-- pattern StorageModule's own STORAGE_DATA_VERSION already uses) --
-- this stamp only ever gates the shape of this one SavedVariables record.
-- Runs once per account, here in Initialize() rather than DatabaseService's
-- own Migrations table, since only this module knows what an Observation
-- should look like. Preserves every real fact an old Note recorded (author,
-- timestamp, text) -- drops only the abandoned moderation fields
-- (helpfulCount/notHelpfulCount/reportCount/hidden), which nothing in the
-- addon ever read (confirmed by a full repo audit before this migration
-- was written). The old per-note `id` was a module-level Lua counter that
-- reset to 1 every session -- never durable, and would have collided
-- across logins the moment two sessions each wrote a "first" note.
--
-- Migrated rows keep a name-formatted author/originalAuthor forever --
-- the old Note shape only ever recorded "Realm.Name" (authorCharacterKey),
-- and a stable character GUID cannot be derived from a name after the
-- fact. Only observations written from this point forward get a real
-- GUID-based author (see AddObservation) -- authorName is populated for
-- both eras either way, so display never depends on which format author
-- happens to be.
-------------------------------------------------------------------------------

local function MigrateNotesToObservations(data)

    if data.SchemaVersion and data.SchemaVersion >= 2 then
        return
    end

    local oldNotes = data.Notes

    data.Observations = data.Observations or {}
    data.NextObservationSequence = data.NextObservationSequence or 0

    if oldNotes then

        for playerKey, notes in pairs(oldNotes) do

            local converted = {}

            for _, note in ipairs(notes) do

                data.NextObservationSequence = data.NextObservationSequence + 1

                local author = note.authorCharacterKey or ""

                table.insert(converted,
                {
                    id = author .. "#" .. data.NextObservationSequence,
                    observedPlayer = playerKey,
                    author = author,
                    authorName = ExtractNameFromCharacterKey(author),
                    createdDate = note.timestamp or time(),
                    lastModified = note.editedTimestamp or note.timestamp or time(),
                    text = note.text or "",
                    imported = false,
                    verified = false,
                    verificationDate = nil,
                    originalAuthor = author,
                    sourceType = "Firsthand",
                    sourcePlayer = nil,
                })

            end

            data.Observations[playerKey] = converted

        end

        data.Notes = nil

    end

    data.SchemaVersion = 2

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function CommunityModule:Initialize()

    MigrateNotesToObservations(GetCommunityData())

    AC.ConfigurationManager:Register("Community", Defaults)

    AC.Settings:RegisterPage("Community",
    {
        title = "Community Observations",
        module = "Community",
        order = 61,
    })

    AC.Settings:RegisterSection("Community", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Community", "General",
    {
        key = "enabled",
        text = "Enable Community Observations",
        default = false,
        tooltip = "An optional, separate section alongside Personal Notes. Fully local this version -- there is no shared backend yet, so an observation you write is only ever visible to you.",
    })

end

function CommunityModule:Enable()
end

function CommunityModule:Disable()
end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function CommunityModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Community", "enabled") == true

end

-------------------------------------------------------------------------------
-- Code of Conduct
--
-- Shown once (StaticPopupDialogs, Core/UI/PlayerJournal/ObservationDialog.lua)
-- before a player's first-ever Community Observation submission.
-- Persisted so it is never shown again on this account once accepted --
-- CodeOfConductAccepted lives in this module's own storage, not a
-- ConfigurationManager setting, since it's a one-time acknowledgment
-- record, not a toggle a player would reasonably change back and forth.
-------------------------------------------------------------------------------

function CommunityModule:HasAcceptedCodeOfConduct()

    return GetCommunityData().CodeOfConductAccepted == true

end

function CommunityModule:AcceptCodeOfConduct()

    GetCommunityData().CodeOfConductAccepted = true

end

-------------------------------------------------------------------------------
-- Observations
-------------------------------------------------------------------------------

function CommunityModule:AddObservation(playerKey, text)

    if not self:IsModuleEnabled() or not playerKey or not text or text == "" then
        return nil
    end

    local data = GetCommunityData()

    data.Observations[playerKey] = data.Observations[playerKey] or {}

    -- Author identity is the character GUID (CharacterModule:GetProfile().guid,
    -- read via UnitGUID("player") in its own ordinary refresh cycle -- not a
    -- secret value, since it never passes through a secure UI callback the
    -- way the tooltip/context-menu unit tokens this addon has already been
    -- burned by do). Stable across character rename/realm transfer, unlike
    -- the old Realm.Name key. observedPlayer intentionally still uses the
    -- Realm.Name convention -- see this module's own header for why that
    -- half was deliberately left alone. authorName is a plain display
    -- snapshot, captured once here -- never re-resolved from the GUID
    -- later (GetPlayerInfoByGUID does not reliably resolve arbitrary
    -- GUIDs, and is unnecessary when the name is already known at write
    -- time).
    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()
    local authorGUID = (characterProfile and characterProfile.guid) or ""
    local authorName = (characterProfile and characterProfile.name) or ""

    data.NextObservationSequence = (data.NextObservationSequence or 0) + 1

    local now = time()

    local observation =
    {
        id = authorGUID .. "#" .. data.NextObservationSequence,
        observedPlayer = playerKey,
        author = authorGUID,
        authorName = authorName,
        createdDate = now,
        lastModified = now,
        text = text,

        -- Always false/nil/"Firsthand" this phase -- no import path exists
        -- yet. Kept as real fields (not omitted) so Phase 2's sharing work
        -- reads/writes an already-stable shape instead of adding fields to
        -- every stored observation retroactively.
        imported = false,
        verified = false,
        verificationDate = nil,
        originalAuthor = authorGUID,
        sourceType = "Firsthand",
        sourcePlayer = nil,
    }

    table.insert(data.Observations[playerKey], observation)

    return observation

end

function CommunityModule:GetObservationsForPlayer(playerKey)

    if not self:IsModuleEnabled() or not playerKey then
        return {}
    end

    return GetCommunityData().Observations[playerKey] or {}

end

function CommunityModule:GetTotalObservationCount()

    local total = 0

    for _, observations in pairs(GetCommunityData().Observations) do
        total = total + #observations
    end

    return total

end

-------------------------------------------------------------------------------
-- Trusted Sources (structural stub -- always empty this version)
--
-- Maps to the still-planned Trust system (accept observations from party/
-- guild/Battle.net friends/everyone) -- kept, unlike the moderation stubs
-- above, because it anticipates a direction this feature is still
-- actually headed toward, not one that was abandoned.
-------------------------------------------------------------------------------

function CommunityModule:GetTrustedSources()

    return GetCommunityData().TrustedSources

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Community", CommunityModule)

return CommunityModule
