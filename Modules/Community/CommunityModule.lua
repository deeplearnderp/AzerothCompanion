-------------------------------------------------------------------------------
-- Azeroth Companion
-- Community Module
--
-- Optional, disabled-by-default layer of shared player notes -- entirely
-- local in this version. No sync backend, no server, no addon-channel
-- broadcast exists yet; every note is only ever visible to the account
-- that wrote it, regardless of its own `visibility` field (captured now
-- so a future sync backend has something to read, but with zero
-- rendering effect today -- see AddCommunityNote's own comment).
--
-- Fully independent of PlayerJournalModule: its own storage namespace
-- (DatabaseService:GetGlobal().PlayerJournalCommunity, a separate
-- top-level Global key, never nested under PlayerJournal's own table),
-- its own ConfigurationManager namespace ("Community"), its own Settings
-- page. This file never references PlayerJournalModule at all -- notes
-- are keyed by the same "Name-Realm" format PlayerJournalModule uses,
-- but that's a shared convention, not a dependency. This independence is
-- what makes "PlayerJournalModule works perfectly with CommunityModule
-- disabled" a structural fact: PlayerJournalModule never reads this
-- module's table, and this module never writes to PlayerJournalModule's.
--
-- Helpful/Not Helpful/Report/Hide are real functions with real local
-- counters, but nothing consumes their output yet beyond the author's
-- own client -- there is no crowd to aggregate. They exist as structural
-- moderation hooks per the feature's own brief ("Future moderation hooks
-- should exist but no backend implementation is required yet"), called
-- only from UI controls that are visually/functionally inert this
-- version (see Core/UI/PlayerJournal/Tabs/CommunityNotes.lua).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time
local ipairs = ipairs
local pairs = pairs

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
    visibility = "Disabled",
}

local VISIBILITY_LEVELS = { "Disabled", "FriendsOnly", "GuildOnly", "FriendsAndGuild", "Everyone" }

-------------------------------------------------------------------------------
-- Storage Access
-------------------------------------------------------------------------------

local function GetCommunityData()

    return AC.DatabaseService:GetGlobal().PlayerJournalCommunity

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function CommunityModule:Initialize()

    AC.ConfigurationManager:Register("Community", Defaults)

    AC.Settings:RegisterPage("Community",
    {
        title = "Community Notes",
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
        text = "Enable Community Notes",
        default = false,
        tooltip = "An optional, separate section alongside Personal Notes. Fully local this version -- there is no shared backend yet, so a Community Note is only ever visible to you.",
    })

    AC.Settings:AddDropdown("Community", "General",
    {
        key = "visibility",
        text = "Community Visibility",
        default = "Disabled",
        tooltip = "Who a future sync backend would share your Community Notes with. Has no effect yet -- captured for when that backend exists.",
        list =
        {
            { text = "Disabled", value = "Disabled" },
            { text = "Friends Only", value = "FriendsOnly" },
            { text = "Guild Only", value = "GuildOnly" },
            { text = "Friends + Guild", value = "FriendsAndGuild" },
            { text = "Everyone", value = "Everyone" },
        },
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

function CommunityModule:GetVisibility()

    return AC.ConfigurationManager:GetValue("Community", "visibility") or "Disabled"

end

-------------------------------------------------------------------------------
-- Code of Conduct
--
-- Shown once (StaticPopupDialogs, Core/UI/PlayerJournal/Tabs/
-- CommunityNotes.lua) before a player's first-ever Community Note
-- submission. Persisted so it is never shown again on this account once
-- accepted -- CodeOfConductAccepted lives in this module's own storage,
-- not a ConfigurationManager setting, since it's a one-time acknowledgment
-- record, not a toggle a player would reasonably change back and forth.
-------------------------------------------------------------------------------

function CommunityModule:HasAcceptedCodeOfConduct()

    return GetCommunityData().CodeOfConductAccepted == true

end

function CommunityModule:AcceptCodeOfConduct()

    GetCommunityData().CodeOfConductAccepted = true

end

-------------------------------------------------------------------------------
-- Notes
-------------------------------------------------------------------------------

local nextNoteID = 1

function CommunityModule:AddCommunityNote(playerKey, text)

    if not self:IsModuleEnabled() or not playerKey or not text or text == "" then
        return nil
    end

    local data = GetCommunityData()

    data.Notes[playerKey] = data.Notes[playerKey] or {}

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()
    local authorCharacterKey = (characterProfile and characterProfile.name and characterProfile.realm)
        and (characterProfile.realm .. "." .. characterProfile.name) or ""

    local note =
    {
        id = nextNoteID,
        authorCharacterKey = authorCharacterKey,
        timestamp = time(),
        editedTimestamp = nil,
        text = text,

        -- Captured for a future sync backend -- has zero effect on what
        -- is rendered today. With no backend, every note is only ever
        -- visible to the account that wrote it regardless of this value;
        -- this is not a bug, it's the honest current state of a stub.
        visibility = self:GetVisibility(),

        helpfulCount = 0,
        notHelpfulCount = 0,
        reportCount = 0,
        hidden = false,
    }

    nextNoteID = nextNoteID + 1
    table.insert(data.Notes[playerKey], note)

    return note

end

function CommunityModule:GetNotesForPlayer(playerKey)

    if not self:IsModuleEnabled() or not playerKey then
        return {}
    end

    return GetCommunityData().Notes[playerKey] or {}

end

function CommunityModule:GetTotalNoteCount()

    local total = 0

    for _, notes in pairs(GetCommunityData().Notes) do
        total = total + #notes
    end

    return total

end

-------------------------------------------------------------------------------
-- Moderation Hooks (structural stubs)
--
-- Real functions, real local counters -- but with no shared backend,
-- these only ever reflect the author's own client. Called only from UI
-- controls that are themselves disabled/inert this version (see
-- Core/UI/PlayerJournal/Tabs/CommunityNotes.lua) so nothing here
-- misrepresents itself as real crowd feedback.
-------------------------------------------------------------------------------

local function FindNote(playerKey, noteID)

    local notes = GetCommunityData().Notes[playerKey]

    if not notes then
        return nil
    end

    for _, note in ipairs(notes) do

        if note.id == noteID then
            return note
        end

    end

    return nil

end

function CommunityModule:RecordVote(playerKey, noteID, helpful)

    local note = FindNote(playerKey, noteID)

    if not note then
        return
    end

    if helpful then
        note.helpfulCount = note.helpfulCount + 1
    else
        note.notHelpfulCount = note.notHelpfulCount + 1
    end

end

function CommunityModule:RecordReport(playerKey, noteID)

    local note = FindNote(playerKey, noteID)

    if note then
        note.reportCount = note.reportCount + 1
    end

end

function CommunityModule:ToggleHide(playerKey, noteID)

    local note = FindNote(playerKey, noteID)

    if note then
        note.hidden = not note.hidden
    end

end

-------------------------------------------------------------------------------
-- Trusted Sources (structural stub -- always empty this version)
-------------------------------------------------------------------------------

function CommunityModule:GetTrustedSources()

    return GetCommunityData().TrustedSources

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Community", CommunityModule)

return CommunityModule
