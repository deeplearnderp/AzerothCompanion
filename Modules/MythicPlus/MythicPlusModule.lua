-------------------------------------------------------------------------------
-- Azeroth Companion
-- Mythic+ Module
--
-- Authoritative Mythic+ profile service for the current character. Owns
-- current Mythic+ gameplay only -- not history, statistics, the Weekly
-- Vault, Raids, Delves, Inventory, or Character data.
--
-- Phase 1 scope: collection only. No Dashboard UI, no Settings page, no
-- Localization, no Statistics, no Recommendations, no Activity History
-- integration yet -- those are explicitly future phases.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local pairs = pairs

local GetOverallDungeonScore = C_ChallengeMode.GetOverallDungeonScore
local GetSlottedKeystoneInfo = C_ChallengeMode.GetSlottedKeystoneInfo
local HasSlottedKeystone = C_ChallengeMode.HasSlottedKeystone
local GetActiveKeystoneInfo = C_ChallengeMode.GetActiveKeystoneInfo
local IsChallengeModeActive = C_ChallengeMode.IsChallengeModeActive
local GetDeathCount = C_ChallengeMode.GetDeathCount
local GetMapScoreInfo = C_ChallengeMode.GetMapScoreInfo
local GetCompletionInfo = C_ChallengeMode.GetCompletionInfo

local GetOwnedKeystoneChallengeMapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
local GetOwnedKeystoneLevel = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
local GetCurrentAffixes = C_MythicPlus and C_MythicPlus.GetCurrentAffixes
local RequestMapInfo = C_MythicPlus and C_MythicPlus.RequestMapInfo

local MythicPlusModule =
{
    Name = "MythicPlus",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
}

-------------------------------------------------------------------------------
-- State
--
-- "Current Keystone" (hasKeystone/currentDungeonID/currentLevel) is
-- sourced from C_MythicPlus.GetOwnedKeystoneChallengeMapID()/
-- GetOwnedKeystoneLevel() -- confirmed via Blizzard's own API
-- documentation to report the keystone the player owns from anywhere,
-- not gated by location. This corrects an earlier version of this
-- module, which used C_ChallengeMode.HasSlottedKeystone()/
-- GetSlottedKeystoneInfo() as the primary source -- those only describe
-- the dungeon-entrance Font of Power receptacle and were never the
-- right function for "does the player have a keystone". They are still
-- used, but only for the narrower, genuinely receptacle-scoped
-- currentAffixIDs field.
-------------------------------------------------------------------------------

function MythicPlusModule:ResetProfile()

    self.Profile =
    {
        rating = 0,

        hasKeystone = false,
        currentDungeonID = 0,
        currentLevel = 0,
        currentAffixIDs = {},

        weeklyAffixIDs = {},

        bestRuns = {},

        activeRun = nil,
        lastCompletedRun = nil,

        lastUpdated = 0,
    }

    self.Session =
    {
        initialRating = 0,
        runsCompletedThisSession = 0,
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function MythicPlusModule:Initialize()

    self:ResetProfile()

    -- ConfigurationManager remains the single source of truth for the
    -- "enabled" flag even though no Settings UI is registered yet --
    -- Phase 1 scope explicitly excludes Settings. A visible toggle can
    -- be added in a later phase without touching this module's data
    -- layer at all.
    AC.ConfigurationManager:Register("MythicPlus", Defaults)

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function MythicPlusModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("CHALLENGE_MODE_START", self)
    AC.Events:Register("CHALLENGE_MODE_RESET", self)
    AC.Events:Register("CHALLENGE_MODE_COMPLETED_REWARDS", self)
    AC.Events:Register("CHALLENGE_MODE_KEYSTONE_SLOTTED", self)
    AC.Events:Register("CHALLENGE_MODE_DEATH_COUNT_UPDATED", self)
    AC.Events:Register("CHALLENGE_MODE_MAPS_UPDATE", self)
    AC.Events:Register("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then

        self:Refresh()

        if RequestMapInfo then
            RequestMapInfo()
        end

    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function MythicPlusModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function MythicPlusModule:Shutdown()

    self:Disable()
    self:ResetProfile()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function MythicPlusModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("MythicPlus", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function MythicPlusModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()

    if isInitialLogin then
        self.Session.initialRating = self.Profile.rating
    end

    if RequestMapInfo then
        RequestMapInfo()
    end

end

function MythicPlusModule:OnChallengeModeStart()

    if self:IsModuleEnabled() then
        self:RefreshActiveRun()
    end

end

function MythicPlusModule:OnChallengeModeReset()

    if self:IsModuleEnabled() then
        self.Profile.activeRun = nil
    end

end

function MythicPlusModule:OnChallengeModeCompletedRewards(mapID)

    if not self:IsModuleEnabled() then
        return
    end

    local completionInfo = GetCompletionInfo and GetCompletionInfo()

    if completionInfo then

        self.Profile.lastCompletedRun =
        {
            dungeonID = completionInfo.mapChallengeModeID or mapID or 0,
            level = completionInfo.level or 0,
            time = completionInfo.time or 0,
            onTime = completionInfo.onTime == true,
            oldScore = completionInfo.oldOverallDungeonScore or 0,
            newScore = completionInfo.newOverallDungeonScore or 0,
            isMapRecord = completionInfo.IsMapRecord == true,
        }

    end

    self.Session.runsCompletedThisSession = (self.Session.runsCompletedThisSession or 0) + 1

    self:RefreshRating()
    self:RefreshBestRuns()
    self:RefreshOwnedKeystone()

    self.Profile.activeRun = nil

    -----------------------------------------------------------------------
    -- Activity History Integration Point (NOT implemented this phase)
    --
    -- Once ActivityHistoryService integration begins, a completed run
    -- would be published here, e.g.:
    --
    -- AC.ActivityHistoryService:Append(
    -- {
    --     Character = ...,
    --     Realm = ...,
    --     Module = "MythicPlus",
    --     ActivityType = "Dungeon",
    --     ActivityName = ...,
    --     Difficulty = "Mythic+",
    --     Expansion = ...,
    --     Started = ...,
    --     Ended = time(),
    --     Completed = true,
    --     Success = self.Profile.lastCompletedRun.onTime,
    --     Data = { dungeonID = ..., level = ..., scoreChange = ... },
    -- })
    -----------------------------------------------------------------------

end

function MythicPlusModule:OnChallengeModeKeystoneSlotted()

    if self:IsModuleEnabled() then
        self:RefreshOwnedKeystone()
    end

end

function MythicPlusModule:OnChallengeModeDeathCountUpdated()

    if self:IsModuleEnabled() then
        self:RefreshActiveRun()
    end

end

function MythicPlusModule:OnChallengeModeMapsUpdate()

    if self:IsModuleEnabled() then
        self:RefreshBestRuns()
    end

end

function MythicPlusModule:OnMythicPlusCurrentAffixUpdate()

    if self:IsModuleEnabled() then
        self:RefreshWeeklyAffixes()
    end

end

function MythicPlusModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "MythicPlus" then
        return
    end

    if key ~= "enabled" then
        return
    end

    if value then
        self:Refresh()
    else
        self:ResetProfile()
    end

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function MythicPlusModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshRating()
    self:RefreshOwnedKeystone()
    self:RefreshWeeklyAffixes()
    self:RefreshBestRuns()
    self:RefreshActiveRun()

    self.Profile.lastUpdated = time()

end

function MythicPlusModule:RefreshRating()

    self.Profile.rating = GetOverallDungeonScore() or 0

end

function MythicPlusModule:RefreshOwnedKeystone()

    local profile = self.Profile

    if not GetOwnedKeystoneChallengeMapID or not GetOwnedKeystoneLevel then

        profile.hasKeystone = false
        profile.currentDungeonID = 0
        profile.currentLevel = 0

    else

        local dungeonID = GetOwnedKeystoneChallengeMapID()
        local level = GetOwnedKeystoneLevel()

        if dungeonID and dungeonID > 0 then
            profile.hasKeystone = true
            profile.currentDungeonID = dungeonID
            profile.currentLevel = level or 0
        else
            profile.hasKeystone = false
            profile.currentDungeonID = 0
            profile.currentLevel = 0
        end

    end

    -- currentAffixIDs is a narrower, genuinely receptacle-scoped bonus --
    -- only available while interacting with a Font of Power. It is
    -- deliberately decoupled from hasKeystone/currentDungeonID/
    -- currentLevel above, which are now correct from anywhere.
    if HasSlottedKeystone() then
        local _, affixIDs = GetSlottedKeystoneInfo()
        profile.currentAffixIDs = affixIDs or {}
    else
        profile.currentAffixIDs = {}
    end

end

function MythicPlusModule:RefreshWeeklyAffixes()

    if not GetCurrentAffixes then
        self.Profile.weeklyAffixIDs = {}
        return
    end

    -- Returns nil until RequestMapInfo() has been called at least once
    -- this session. Enable()/OnPlayerEnteringWorld() request it; this
    -- refresh runs again when MYTHIC_PLUS_CURRENT_AFFIX_UPDATE fires.
    local affixes = GetCurrentAffixes()

    self.Profile.weeklyAffixIDs = affixes or {}

end

function MythicPlusModule:RefreshBestRuns()

    local bestRuns = {}

    local scores = GetMapScoreInfo and GetMapScoreInfo()

    if type(scores) == "table" then

        for i = 1, #scores do

            local scoreInfo = scores[i]

            if type(scoreInfo) == "table" and scoreInfo.mapChallengeModeID then

                bestRuns[scoreInfo.mapChallengeModeID] =
                {
                    level = scoreInfo.level or 0,
                    score = scoreInfo.dungeonScore or 0,
                }

            end

        end

    end

    self.Profile.bestRuns = bestRuns

end

function MythicPlusModule:RefreshActiveRun()

    if not IsChallengeModeActive() then
        self.Profile.activeRun = nil
        return
    end

    local keystoneLevel, affixIDs, wasCharged = GetActiveKeystoneInfo()
    local numDeaths, timeLost = GetDeathCount()

    self.Profile.activeRun =
    {
        keystoneLevel = keystoneLevel or 0,
        affixIDs = affixIDs or {},
        wasCharged = wasCharged == true,
        deathCount = numDeaths or 0,
        timeLost = timeLost or 0,
    }

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function MythicPlusModule:GetProfile()

    return self.Profile

end

function MythicPlusModule:GetBestOverallLevel()

    local best = 0

    for _, run in pairs(self.Profile.bestRuns) do

        if run.level and run.level > best then
            best = run.level
        end

    end

    return best

end

function MythicPlusModule:GetDashboardSummary()

    local profile = self.Profile

    return
    {
        hasKeystone = profile.hasKeystone,
        currentDungeonID = profile.currentDungeonID,
        currentLevel = profile.currentLevel,
        rating = profile.rating,
        bestOverallLevel = self:GetBestOverallLevel(),
    }

end

-------------------------------------------------------------------------------
-- Insights
--
-- Objective only -- each of these is a direct fact (a missing keystone,
-- Blizzard's own IsMapRecord flag, a session-relative rating delta, an
-- active-run boolean), not a threshold or judgment this module invents.
-------------------------------------------------------------------------------

function MythicPlusModule:GetInsights()

    local insights = {}
    local profile = self.Profile
    local session = self.Session

    if not profile or not session then
        return insights
    end

    -- No keystone slotted (only knowable near a Font of Power -- see
    -- the note above RefreshOwnedKeystone/ResetProfile)
    if not profile.hasKeystone then
        table.insert(insights,
        {
            title = "No Keystone",
            description = "You do not have a keystone slotted.",
            priority = 30,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Personal best -- sourced directly from Blizzard's own IsMapRecord
    -- flag, not a level threshold this module invents.
    if profile.lastCompletedRun and profile.lastCompletedRun.isMapRecord then
        table.insert(insights,
        {
            title = "Personal Best",
            description = string.format("You set a new personal best at level %d.", profile.lastCompletedRun.level or 0),
            priority = 60,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Rating increased this session
    local ratingChange = profile.rating - (session.initialRating or profile.rating)

    if ratingChange > 0 then
        table.insert(insights,
        {
            title = "Rating Increased",
            description = string.format("Your Mythic+ rating increased by %.1f this session.", ratingChange),
            priority = 40,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Current run active
    if profile.activeRun then
        table.insert(insights,
        {
            title = "Current Run Active",
            description = "You are currently in an active Mythic+ run.",
            priority = 20,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("MythicPlus", MythicPlusModule)

return MythicPlusModule
