-------------------------------------------------------------------------------
-- Azeroth Companion
-- Diagnostics Service
--
-- Investigation tooling for the Mythic+ login-refresh bug (and reusable for
-- future login/event-ordering investigations). Deliberately isolated from
-- every gameplay module: it registers its own listeners for a curated set
-- of Blizzard events and reads Blizzard's raw Mythic+ APIs directly rather
-- than routing through MythicPlusModule's cached Profile -- the entire
-- point is to observe what Blizzard itself reports at the moment each event
-- fires, independent of when any module chooses to refresh its own cache.
--
-- Emits structured Logger:Trace() calls only; it owns no storage or
-- presentation of its own (Logger owns storage, the Diagnostics window
-- owns presentation), per the framework's diagnostics architecture rule.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DiagnosticsService = {}
AC.DiagnosticsService = DiagnosticsService

-------------------------------------------------------------------------------
-- Raw Blizzard API Access
--
-- Read directly and deliberately -- see file header. Not a violation of
-- "the Dashboard never calls a Blizzard API directly" (Architecture Rule 2);
-- that rule governs the Dashboard/presentation layer. This is diagnostic
-- instrumentation, whose only purpose is to observe raw Blizzard state.
-------------------------------------------------------------------------------

local GetOwnedKeystoneChallengeMapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
local GetOwnedKeystoneLevel = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
local GetCurrentSeason = C_MythicPlus and C_MythicPlus.GetCurrentSeason
local GetOverallDungeonScore = C_ChallengeMode.GetOverallDungeonScore
local GetMapUIInfo = C_ChallengeMode.GetMapUIInfo

local function CaptureMythicPlusSnapshot()

    local mapID = GetOwnedKeystoneChallengeMapID and GetOwnedKeystoneChallengeMapID()
    local level = GetOwnedKeystoneLevel and GetOwnedKeystoneLevel()
    local rating = GetOverallDungeonScore and GetOverallDungeonScore()
    local season = GetCurrentSeason and GetCurrentSeason()
    local dungeonName

    if mapID and mapID > 0 then
        dungeonName = GetMapUIInfo(mapID)
    end

    return
    {
        MapID = mapID,
        Level = level,
        Rating = rating,
        Season = season,
        Dungeon = dungeonName,
    }

end

-------------------------------------------------------------------------------
-- Traced Events
--
-- The Part 6 event list plus every event MythicPlusModule currently
-- registers (CHALLENGE_MODE_START/RESET/COMPLETED_REWARDS/KEYSTONE_SLOTTED/
-- DEATH_COUNT_UPDATED/MAPS_UPDATE, MYTHIC_PLUS_CURRENT_AFFIX_UPDATE).
--
-- Note (updated, Blizzard API Verification Workflow pass): both
-- "CHALLENGE_MODE_COMPLETED" and "CHALLENGE_MODE_COMPLETED_REWARDS" are now
-- confirmed as real, distinct Blizzard events (Blizzard Interface Source /
-- Warcraft Wiki). This still traces only CHALLENGE_MODE_COMPLETED_REWARDS,
-- since that is the event MythicPlusModule actually registers and consumes
-- (added Patch 11.2.0; payload: mapID, medal, timeMS, money, rewards) --
-- per "prefer matching Blizzard's own implementation," there is no reason
-- to also trace an event nothing in this addon listens for. Registration
-- below is still pcall-wrapped as a safety net for any future addition to
-- this list.
-------------------------------------------------------------------------------

local TRACED_EVENTS =
{
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_ALIVE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_RESET",
    "CHALLENGE_MODE_COMPLETED_REWARDS",
    "CHALLENGE_MODE_KEYSTONE_SLOTTED",
    "CHALLENGE_MODE_DEATH_COUNT_UPDATED",
    "CHALLENGE_MODE_MAPS_UPDATE",
    "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE",
    "MYTHIC_PLUS_NEW_WEEKLY_RECORD",
}

-------------------------------------------------------------------------------
-- Trace Handler
--
-- Gate checks happen before building the snapshot (a handful of cheap API
-- calls, but no reason to pay even that when tracing is off) -- BAG_UPDATE
-- in particular can fire often, so this stays a no-op unless the "Mythic+"
-- trace category is actively selected.
-------------------------------------------------------------------------------

local function TraceHandler(eventName)

    return function(...)

        if not AC.Logger:IsDebugEnabled() then
            return
        end

        if not AC.Logger:IsTraceCategoryEnabled("Mythic+") then
            return
        end

        AC.Logger:Trace("Mythic+", eventName, CaptureMythicPlusSnapshot())

    end

end

-------------------------------------------------------------------------------
-- Enable
--
-- Must load after EventManager in the TOC so that EventManager.Enabled is
-- already true by the time this runs (both Enable() calls happen inside
-- the same ServiceManager:Enable() sweep) -- that guarantees
-- AC.Events:Register() below registers with the real Blizzard frame
-- immediately, synchronously, inside this function's own pcall, rather
-- than being deferred into EventManager's later catch-up sweep where a bad
-- event name would throw uncaught.
-------------------------------------------------------------------------------

function DiagnosticsService:Enable()

    for i = 1, #TRACED_EVENTS do

        local eventName = TRACED_EVENTS[i]
        local ok, err = pcall(AC.Events.Register, AC.Events, eventName, TraceHandler(eventName))

        if not ok and AC.Logger then
            AC.Logger:Error(("DiagnosticsService failed to register trace event '%s': %s"):format(eventName, tostring(err)))
        end

    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DiagnosticsService", DiagnosticsService)

return DiagnosticsService
