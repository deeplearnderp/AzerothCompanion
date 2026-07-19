-------------------------------------------------------------------------------
-- Azeroth Companion
-- Accomplishments Module (formerly AchievementsModule)
--
-- Owns a CURATED view of what defines this character's story -- not every
-- completed achievement (Blizzard's own Achievement UI already represents
-- that exhaustively). Only an achievement that resolves into one of the
-- categories below is ever cached: ExpansionProgress, Raiding, MythicPlus
-- (completion FACTS only -- MythicPlusModule remains the sole owner of
-- run/rating/key-level data, Rule 1), FeatsOfStrength, CharacterMilestones.
-- "Legacy Accomplishments" is a real category with no populator this pass
-- (see LEGACY note below) -- an honest empty state, not a fabricated list.
--
-- RENAME NOTE (Companion Intelligence / Accomplishments redesign): this
-- module was AchievementsModule/"Achievements" until this pass. Renamed
-- everywhere EXCEPT the literal string used to tag ActivityHistoryService
-- records (still "Achievements") and DeveloperPanel's History Inspector
-- module filter -- both stay so existing players' saved history isn't
-- orphaned by the rename. See RecordEarnedAccomplishment/
-- GetRecentAccomplishments below for the exact call sites this applies to.
--
-- CLASSIFICATION -- how "curated" is actually decided (no Blizzard flag
-- exists for this, verified this pass -- GetAchievementInfo's own `flags`
-- bitfield is documented as exactly Statistic/Hidden/ProgressBar, nothing
-- for "meta" or "signature"):
--   1. Category tree (BuildCategoryClassificationMap) -- GetCategoryList()
--      + GetCategoryInfo(categoryID) (returns title, parentCategoryID,
--      flags; parentCategoryID == -1 for top-level -- confirmed via
--      Warcraft Wiki) walks the ENTIRE category tree at runtime, no
--      hardcoded category IDs anywhere. Every achievement whose top-level
--      ancestor category is "Feats of Strength" (matched by that
--      category's own Blizzard-provided title -- same trust level
--      Pages/Accomplishments.lua's own header already grants achievement
--      names) is classified FeatsOfStrength, unconditionally. KNOWN GAP:
--      this title match is an English literal ("Feats of Strength") --
--      correct on an English client, unverified on other locales, since
--      Blizzard returns the category title already localized and this
--      module has no other signal to identify that specific category by.
--   2. Signature name-pattern table (AccomplishmentsPatterns.lua) -- for
--      every other completed achievement, matched against a curated,
--      documented list of long-standing Blizzard naming conventions
--      (Loremaster of/Pathfinder/Ahead of the Curve/Cutting Edge/Keystone
--      Master/Keystone Hero/Glory of the X/Heritage of the X). This is a
--      real pattern, not a Blizzard-guaranteed contract -- see that file's
--      own header and VerificationService's `acc.signaturePatterns` entry
--      for the ongoing-verification framing this requires.
--   3. Everything else (exploration/fishing/cooking/holiday/misc, and
--      ordinary non-signature achievements generally) is never cached.
--      This is the entire point of the redesign -- it must not silently
--      rebuild the old flat cache under a new name.
--
-- EXPANSION FIELD (Accordion Redesign) -- each accomplishment also carries
-- an `expansion` field (e.g. "Midnight"), used by the Dashboard's expanded
-- accordion view (Pages/Accomplishments.lua). Blizzard exposes no
-- expansion field anywhere in the achievement API -- inferred the same
-- "trust Blizzard's own category title" way as the Feats of Strength rule
-- above, since the category tree nests one top-level category per
-- expansion. See AccomplishmentsExpansionNames.lua's own header and
-- VerificationService's `acc.expansionNames` entry -- same living-document
-- framing as the signature-pattern table. A category whose top-level
-- title matches nothing in that list resolves `expansion` to nil, an
-- honest gap the Dashboard simply omits, never a guessed "Unknown".
--
-- CAMPAIGN / RENOWN -- deliberately NOT achievement data, kept structurally
-- separate (self.CampaignProgress/self.RenownProgress, own refresh
-- functions/getters, never merged into self.Accomplishments) so a future
-- extraction is a clean cut. Renown (`C_MajorFactions`) is owned HERE FOR
-- NOW, pending the planned Reputation module (docs/GameplayModuleArchitecture.md
-- section 2.1) -- the same "owned here for now" temporary-ownership framing
-- StorageModule.lua already established for Warband Bank item contents. A
-- deliberate, user-approved scope decision, not an oversight: Renown
-- ownership may need to move the day a Reputation module gets built.
--
-- VERIFICATION STATUS (this pass): `GetCategoryInfo` confirmed via
-- Warcraft Wiki (title, parentCategoryID, flags; -1 = top-level).
-- `C_CampaignInfo.GetAvailableCampaigns/GetState/GetChapterIDs/
-- GetCurrentChapterID` confirmed via Warcraft Wiki (`Enum.CampaignState`:
-- 0 Invalid, 1 Complete, 2 InProgress, 3 Stalled). `C_MajorFactions.
-- GetMajorFactionIDs/GetMajorFactionData/GetCurrentRenownLevel/
-- HasMaximumRenown/IsWeeklyRenownCapped` reuse this addon's OWN already-
-- confirmed function set from a prior audit cycle (see
-- docs/GameplayModuleArchitecture.md section 2.1) -- deliberately NOT
-- using `GetRenownLevels`, which surfaced in a fresh search this pass but
-- was never independently confirmed. `C_CampaignInfo.GetCampaignInfo`'s
-- exact return shape was NOT verified this pass -- read defensively
-- (pcall + nil-guarded field access) below. `MAJOR_FACTION_RENOWN_LEVEL_
-- CHANGED` (the event name) is NOT verified this pass -- registered
-- defensively (pcall). `AccomplishmentsExpansionNames.lua`'s top-level
-- category title match (the `expansion` field) is NOT independently
-- spot-checked this pass -- general addon-development knowledge, flagged
-- `acc.expansionNames` in VerificationService.lua. See VerificationService.lua
-- for the full registry.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber

local GetAchievementInfo = GetAchievementInfo
local GetCategoryList = GetCategoryList
local GetCategoryNumAchievements = GetCategoryNumAchievements
local GetCategoryInfo = GetCategoryInfo

local Patterns = (AC.AccomplishmentsPatterns and AC.AccomplishmentsPatterns.SIGNATURE_PATTERNS) or {}

local AccomplishmentsModule =
{
    Name = "Accomplishments",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
    showRenown = true,
    showCampaign = true,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function AccomplishmentsModule:ResetCache()

    self.LastUpdated = 0
    self.TotalPoints = 0
    self.Accomplishments = {}
    self.CampaignProgress = {}
    self.RenownProgress = {}

    -- Cached once per full Refresh() -- see BuildCategoryClassificationMap.
    self.CategoryTopLevelTitle = {}
    self.CategoryExpansionName = {}
    self.FeatsOfStrengthTopLevelID = nil

    self.Session =
    {
        initialPoints = 0,
        accomplishmentsEarnedThisSession = {},
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function AccomplishmentsModule:Initialize()

    self:ResetCache()

    AC.ConfigurationManager:Register("Accomplishments", Defaults)

    AC.Settings:RegisterPage("Accomplishments",
    {
        title = "Accomplishments",
        module = "Accomplishments",
        order = 50,
    })

    AC.Settings:RegisterSection("Accomplishments", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Accomplishments", "General",
    {
        key = "enabled",
        text = "Enable Accomplishments Module",
        default = true,
        tooltip = "Maintain a curated cache of your character's defining accomplishments -- signature achievements, campaign progress, and Renown -- not every achievement in the game.",
    })

    AC.Settings:RegisterSection("Accomplishments", "Sections",
    {
        title = "Sections",
    })

    AC.Settings:AddCheckbox("Accomplishments", "Sections",
    {
        key = "showCampaign",
        text = "Show Campaign Progress",
        default = true,
        tooltip = "Include campaign completion state in Expansion Progress.",
    })

    AC.Settings:AddCheckbox("Accomplishments", "Sections",
    {
        key = "showRenown",
        text = "Show Renown Progress",
        default = true,
        tooltip = "Include Major Faction Renown levels in Expansion Progress. Owned here temporarily -- see this module's own header.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function AccomplishmentsModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("ACHIEVEMENT_EARNED", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    -- Unverified event name this pass (see file header) -- pcall-wrapped
    -- so a wrong/renamed event never breaks the rest of the module.
    local ok, err = pcall(AC.Events.Register, AC.Events, "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", self, "OnMajorFactionRenownLevelChanged")

    if not ok and AC.Logger then
        AC.Logger:Error(("AccomplishmentsModule failed to register MAJOR_FACTION_RENOWN_LEVEL_CHANGED: %s"):format(tostring(err)))
    end

    if self:IsModuleEnabled() then
        self:Refresh()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function AccomplishmentsModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function AccomplishmentsModule:Shutdown()

    self:Disable()
    self:ResetCache()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function AccomplishmentsModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Accomplishments", "enabled") ~= false

end

function AccomplishmentsModule:IsCampaignSectionEnabled()

    return AC.ConfigurationManager:GetValue("Accomplishments", "showCampaign") ~= false

end

function AccomplishmentsModule:IsRenownSectionEnabled()

    return AC.ConfigurationManager:GetValue("Accomplishments", "showRenown") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function AccomplishmentsModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()

    if isInitialLogin then
        self.Session.initialPoints = self.TotalPoints
    end

end

function AccomplishmentsModule:OnAchievementEarned(achievementID)

    if not self:IsModuleEnabled() then
        return
    end

    achievementID = tonumber(achievementID)

    if not achievementID then
        return
    end

    local accomplishment = self:RefreshAchievement(achievementID)

    -- Only a classified accomplishment is tracked this-session/recorded to
    -- history -- an earned achievement that doesn't classify (exploration,
    -- fishing, etc.) is exactly what this redesign exists to stop
    -- cluttering the player's view with.
    if accomplishment then

        self.Session.accomplishmentsEarnedThisSession[achievementID] = time()
        self:RecordEarnedAccomplishment(achievementID)

    end

end

-------------------------------------------------------------------------------
-- History Recording
--
-- Stored Module tag is deliberately still the literal "Achievements" --
-- see this file's header RENAME NOTE. Only ever called for a classified
-- accomplishment (see OnAchievementEarned above). No historical backfill
-- (mirroring MythicPlusModule's own run history): Blizzard exposes no
-- earn-date-ordered log to enumerate after the fact, only the live
-- ACHIEVEMENT_EARNED event.
-------------------------------------------------------------------------------

function AccomplishmentsModule:RecordEarnedAccomplishment(achievementID)

    if not AC.ActivityHistoryService then
        return
    end

    local accomplishment = self.Accomplishments[achievementID]

    if not accomplishment then
        return
    end

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()

    if not characterProfile or not characterProfile.name or characterProfile.name == "" then
        return
    end

    local now = time()

    AC.ActivityHistoryService:Append(
    {
        Character = characterProfile.name,
        Realm = characterProfile.realm or "",
        Module = "Achievements",
        ActivityType = "Achievement",
        ActivityName = accomplishment.name or "",
        Difficulty = "",
        Expansion = GetExpansionLevel and GetExpansionLevel() or 0,
        Started = now,
        Ended = now,
        Completed = true,
        Success = true,
        Data =
        {
            achievementID = achievementID,
            points = accomplishment.points or 0,
            category = accomplishment.category,
        },
    })

end

function AccomplishmentsModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Accomplishments" then
        return
    end

    if key == "enabled" then

        if value then
            self:Refresh()
        else
            self:ResetCache()
        end

    end

end

function AccomplishmentsModule:OnMajorFactionRenownLevelChanged()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshRenownProgress()

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function AccomplishmentsModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    self:BuildCategoryClassificationMap()
    self:RefreshCompletedAccomplishments()
    self:RefreshTotalPoints()
    self:RefreshCampaignProgress()
    self:RefreshRenownProgress()

    self.LastUpdated = time()

end

-------------------------------------------------------------------------------
-- Category Classification (data-driven, no hardcoded category IDs)
-------------------------------------------------------------------------------

local FEATS_OF_STRENGTH_TITLE = "Feats of Strength"

function AccomplishmentsModule:BuildCategoryClassificationMap()

    self.CategoryTopLevelTitle = {}
    self.CategoryExpansionName = {}
    self.FeatsOfStrengthTopLevelID = nil

    if not GetCategoryList or not GetCategoryInfo then
        return
    end

    local categoryIDs = GetCategoryList()
    local parentOf = {}
    local titleOf = {}

    for _, categoryID in ipairs(categoryIDs) do

        local title, parentCategoryID = GetCategoryInfo(categoryID)

        titleOf[categoryID] = title or ""
        parentOf[categoryID] = parentCategoryID

        if parentCategoryID == -1 and title == FEATS_OF_STRENGTH_TITLE then
            self.FeatsOfStrengthTopLevelID = categoryID
        end

    end

    -- Resolve every category to its top-level ancestor's title, walking
    -- the parent chain once per category (bounded -- the achievement
    -- category tree is only ever a few levels deep).
    for _, categoryID in ipairs(categoryIDs) do

        local currentID = categoryID
        local guard = 0

        while parentOf[currentID] and parentOf[currentID] ~= -1 and guard < 10 do
            currentID = parentOf[currentID]
            guard = guard + 1
        end

        self.CategoryTopLevelTitle[categoryID] = titleOf[currentID] or ""

    end

    -- Expansion inference -- see AccomplishmentsExpansionNames.lua's own
    -- header for why this is trustworthy (Blizzard's category tree nests
    -- one top-level category per expansion, its title IS the expansion
    -- name) and why it's honest to leave unmatched categories nil rather
    -- than guess.
    local expansionNames = AC.AccomplishmentsExpansionNames or {}
    local expansionLookup = {}

    for _, name in ipairs(expansionNames) do
        expansionLookup[name] = true
    end

    for categoryID, topLevelTitle in pairs(self.CategoryTopLevelTitle) do

        if expansionLookup[topLevelTitle] then
            self.CategoryExpansionName[categoryID] = topLevelTitle
        end

    end

end

-------------------------------------------------------------------------------
-- Signature Name-Pattern Matching -- see AccomplishmentsPatterns.lua
-------------------------------------------------------------------------------

local function MatchesPattern(name, entry)

    if entry.matchType == "prefix" then
        return name:sub(1, #entry.pattern) == entry.pattern
    end

    if entry.matchType == "suffix" then

        if entry.requiresPrefix and name:sub(1, #entry.requiresPrefix) ~= entry.requiresPrefix then
            return false
        end

        return name:sub(-#entry.pattern) == entry.pattern

    end

    if entry.matchType == "contains" then
        return name:find(entry.pattern, 1, true) ~= nil
    end

    return false

end

function AccomplishmentsModule:ClassifyByName(name)

    if not name or name == "" then
        return nil
    end

    for _, entry in ipairs(Patterns) do

        if MatchesPattern(name, entry) then
            return entry.category, entry.isSignature == true
        end

    end

    return nil

end

-- Category rule checked first (unambiguous, higher confidence than name
-- matching); falls back to name-pattern matching. Returns category, isSignature
-- or nil, nil if this achievement doesn't classify into anything tracked.
function AccomplishmentsModule:ClassifyAchievement(categoryID, name)

    if self.FeatsOfStrengthTopLevelID and self.CategoryTopLevelTitle[categoryID] == FEATS_OF_STRENGTH_TITLE then
        return "FeatsOfStrength", true
    end

    return self:ClassifyByName(name)

end

-------------------------------------------------------------------------------
-- Completed Accomplishments
-------------------------------------------------------------------------------

function AccomplishmentsModule:RefreshCompletedAccomplishments()

    self.Accomplishments = {}

    local categoryIDs = GetCategoryList and GetCategoryList() or {}

    for _, categoryID in ipairs(categoryIDs) do

        local numAchievements = GetCategoryNumAchievements and GetCategoryNumAchievements(categoryID, true) or 0

        for index = 1, numAchievements do

            local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic =
                GetAchievementInfo(categoryID, index)

            if id and completed and not isStatistic then

                local category, isSignature = self:ClassifyAchievement(categoryID, name or "")

                if category then

                    self.Accomplishments[id] =
                    {
                        id = id,
                        name = name or "",
                        description = description or "",
                        points = points or 0,
                        month = month or 0,
                        day = day or 0,
                        year = year or 0,
                        icon = icon or 0,
                        category = category,
                        isSignature = isSignature == true,
                        expansion = self.CategoryExpansionName[categoryID],
                    }

                end

            end

        end

    end

end

-- Single-achievement refresh (ACHIEVEMENT_EARNED). Uses the direct-by-ID
-- call form -- both forms are confirmed (Warcraft Wiki) to return the
-- identical 15-value shape as the (categoryID, index) form used above.
-- Category classification needs a real categoryID, which the direct-by-ID
-- form doesn't return -- BuildCategoryClassificationMap already ran this
-- session (Refresh()), so name-pattern classification alone is used here;
-- an achievement that only classifies via the Feats of Strength CATEGORY
-- rule (not a name pattern) will be picked up on the next full Refresh()
-- rather than instantly -- an accepted, minor lag, not a correctness gap.
-- Same gap applies to `expansion`: with no categoryID available here, a
-- freshly-earned achievement's expansion can't be resolved until the next
-- full Refresh() re-walks the category tree -- left nil in the interim
-- rather than guessed, same accepted minor lag as above.
function AccomplishmentsModule:RefreshAchievement(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return nil
    end

    local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic =
        GetAchievementInfo(achievementID)

    if not id or not completed or isStatistic then
        self.Accomplishments[achievementID] = nil
        self:RefreshTotalPoints()
        self.LastUpdated = time()
        return nil
    end

    local category, isSignature = self:ClassifyByName(name or "")

    if not category then
        self.Accomplishments[achievementID] = nil
        self:RefreshTotalPoints()
        self.LastUpdated = time()
        return nil
    end

    local accomplishment =
    {
        id = achievementID,
        name = name or "",
        description = description or "",
        points = points or 0,
        month = month or 0,
        day = day or 0,
        year = year or 0,
        icon = icon or 0,
        category = category,
        isSignature = isSignature == true,
        expansion = nil,
    }

    self.Accomplishments[achievementID] = accomplishment

    self:RefreshTotalPoints()
    self.LastUpdated = time()

    return accomplishment

end

function AccomplishmentsModule:RefreshTotalPoints()

    local totalPoints = 0

    for _, accomplishment in pairs(self.Accomplishments) do
        totalPoints = totalPoints + (accomplishment.points or 0)
    end

    self.TotalPoints = totalPoints

end

-------------------------------------------------------------------------------
-- Campaign Progress -- NOT achievement data, see file header.
-------------------------------------------------------------------------------

function AccomplishmentsModule:RefreshCampaignProgress()

    self.CampaignProgress = {}

    if not self:IsCampaignSectionEnabled() then
        return
    end

    if not C_CampaignInfo or not C_CampaignInfo.GetAvailableCampaigns then
        return
    end

    local ok, campaignIDs = pcall(C_CampaignInfo.GetAvailableCampaigns)

    if not ok or type(campaignIDs) ~= "table" then
        return
    end

    for _, campaignID in ipairs(campaignIDs) do

        local okState, state = pcall(C_CampaignInfo.GetState, campaignID)
        local okChapters, chapterIDs = pcall(C_CampaignInfo.GetChapterIDs, campaignID)
        local okCurrent, currentChapterID = pcall(C_CampaignInfo.GetCurrentChapterID, campaignID)

        -- GetCampaignInfo's exact return shape is unverified this pass
        -- (see file header) -- read defensively, a real campaign name is
        -- only used if the call succeeds and looks like the expected
        -- table shape; never fabricated otherwise.
        local name = ""
        local okInfo, info = pcall(C_CampaignInfo.GetCampaignInfo, campaignID)

        if okInfo and type(info) == "table" and info.name then
            name = info.name
        end

        self.CampaignProgress[campaignID] =
        {
            campaignID = campaignID,
            name = name,
            state = okState and state or nil,
            totalChapters = (okChapters and type(chapterIDs) == "table") and #chapterIDs or 0,
            currentChapterID = okCurrent and currentChapterID or nil,
        }

    end

end

-------------------------------------------------------------------------------
-- Renown Progress -- NOT achievement data, owned here temporarily. See
-- file header.
-------------------------------------------------------------------------------

function AccomplishmentsModule:RefreshRenownProgress()

    self.RenownProgress = {}

    if not self:IsRenownSectionEnabled() then
        return
    end

    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionIDs then
        return
    end

    local ok, majorFactionIDs = pcall(C_MajorFactions.GetMajorFactionIDs)

    if not ok or type(majorFactionIDs) ~= "table" then
        return
    end

    for _, majorFactionID in ipairs(majorFactionIDs) do

        local okData, data = pcall(C_MajorFactions.GetMajorFactionData, majorFactionID)
        local okLevel, currentRenownLevel = pcall(C_MajorFactions.GetCurrentRenownLevel, majorFactionID)
        local okMax, hasMaximumRenown = pcall(C_MajorFactions.HasMaximumRenown, majorFactionID)
        local okCapped, isWeeklyCapped = pcall(C_MajorFactions.IsWeeklyRenownCapped, majorFactionID)

        self.RenownProgress[majorFactionID] =
        {
            majorFactionID = majorFactionID,
            name = (okData and type(data) == "table" and data.name) or "",
            currentRenownLevel = okLevel and currentRenownLevel or 0,
            hasMaximumRenown = okMax and hasMaximumRenown == true,
            isWeeklyCapped = okCapped and isWeeklyCapped == true,
        }

    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function AccomplishmentsModule:GetAccomplishment(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return nil
    end

    return self.Accomplishments[achievementID]

end

function AccomplishmentsModule:GetAccomplishments()

    local results = {}
    local index = 1

    for _, accomplishment in pairs(self.Accomplishments) do
        results[index] = accomplishment
        index = index + 1
    end

    return results

end

function AccomplishmentsModule:GetAccomplishmentsByCategory(category)

    local results = {}

    for _, accomplishment in pairs(self.Accomplishments) do

        if accomplishment.category == category then
            table.insert(results, accomplishment)
        end

    end

    return results

end

function AccomplishmentsModule:IsCompleted(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return false
    end

    if self.Accomplishments[achievementID] then
        return true
    end

    local _, _, _, completed = GetAchievementInfo(achievementID)

    return completed == true

end

function AccomplishmentsModule:GetPoints()

    return self.TotalPoints or 0

end

function AccomplishmentsModule:GetAccomplishmentCount()

    local count = 0

    for _ in pairs(self.Accomplishments) do
        count = count + 1
    end

    return count

end

function AccomplishmentsModule:GetMostRecentAccomplishment()

    local mostRecent = nil
    local mostRecentValue = -1

    for _, accomplishment in pairs(self.Accomplishments) do

        local year = accomplishment.year or 0
        local month = accomplishment.month or 0
        local day = accomplishment.day or 0

        -- Blizzard's year/month/day fields are only meaningful relative
        -- to each other, but that's enough to sort for "most recent".
        local value = (year * 10000) + (month * 100) + day

        if value > mostRecentValue then
            mostRecentValue = value
            mostRecent = accomplishment
        end

    end

    return mostRecent

end

-------------------------------------------------------------------------------
-- Recent History
--
-- Reads back through ActivityHistoryService's public API using the
-- STORED "Achievements" tag -- see file header RENAME NOTE. Only ever
-- reflects classified accomplishments earned since this feature (in
-- either its old or new form) shipped -- no backfill possible.
-------------------------------------------------------------------------------

function AccomplishmentsModule:GetRecentAccomplishments(count)

    count = tonumber(count) or 10

    local results = {}

    if not AC.ActivityHistoryService then
        return results
    end

    local records = AC.ActivityHistoryService:GetByModule("Achievements")
    local total = #records

    for i = total, math.max(1, total - count + 1), -1 do
        table.insert(results, records[i])
    end

    return results

end

-------------------------------------------------------------------------------
-- Next Milestone
--
-- "Milestone" here is this addon's own presentational grouping (every
-- MILESTONE_STEP points of TRACKED accomplishments, not all-achievement
-- points as before this redesign) -- not a Blizzard-defined concept.
-------------------------------------------------------------------------------

local MILESTONE_STEP = 500

function AccomplishmentsModule:GetNextMilestone()

    local currentPoints = self.TotalPoints or 0
    local nextMilestone = (math.floor(currentPoints / MILESTONE_STEP) + 1) * MILESTONE_STEP

    return
    {
        currentPoints = currentPoints,
        nextMilestone = nextMilestone,
        pointsRemaining = nextMilestone - currentPoints,
    }

end

function AccomplishmentsModule:GetSessionSummary()

    local session = self.Session

    local accomplishmentsEarnedThisSession = 0

    for _ in pairs(session.accomplishmentsEarnedThisSession) do
        accomplishmentsEarnedThisSession = accomplishmentsEarnedThisSession + 1
    end

    local pointsEarnedThisSession = (self.TotalPoints or 0) - (session.initialPoints or 0)

    if pointsEarnedThisSession < 0 then
        pointsEarnedThisSession = 0
    end

    return
    {
        achievementsEarnedThisSession = accomplishmentsEarnedThisSession,
        pointsEarnedThisSession = pointsEarnedThisSession,
    }

end

function AccomplishmentsModule:GetCampaignProgress()

    return self.CampaignProgress

end

function AccomplishmentsModule:GetRenownProgress()

    return self.RenownProgress

end

-------------------------------------------------------------------------------
-- Insights
--
-- Insight TITLES stay "Achievement Earned"/"Achievement Milestone" --
-- purely internal matching keys (RecommendationEngine.lua,
-- NotificationService.lua's NOTIFICATION_TYPE_BY_INSIGHT_TITLE), never
-- shown to the player and still accurate descriptions of what happened.
-- Only ever fires for a classified accomplishment now (see
-- OnAchievementEarned) -- the CATEGORY field below is what actually
-- changed identity, from "Achievements" to "Accomplishments".
-------------------------------------------------------------------------------

function AccomplishmentsModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    local session = self.Session

    if not session then
        return insights
    end

    for achievementID, timestamp in pairs(session.accomplishmentsEarnedThisSession) do

        local accomplishment = self.Accomplishments[achievementID]

        if accomplishment then
            table.insert(insights,
            {
                title = "Achievement Earned",
                description = string.format("You earned: %s", accomplishment.name or "Unknown"),
                priority = 60,
                category = "Accomplishments",
                timestamp = timestamp,
                expiresAt = 0,
                dismissible = false,
                data = { achievementID = achievementID },
            })
        end

    end

    local pointsGained = self.TotalPoints - session.initialPoints

    if pointsGained >= 500 then

        local milestone = self:GetNextMilestone()

        table.insert(insights,
        {
            title = "Achievement Milestone",
            description = string.format("You gained %d accomplishment points this session! %d more to reach %d.", pointsGained, milestone.pointsRemaining, milestone.nextMilestone),
            priority = 45,
            category = "Accomplishments",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data =
            {
                pointsGained = pointsGained,
                nextMilestone = milestone.nextMilestone,
                pointsRemaining = milestone.pointsRemaining,
            },
        })

    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Accomplishments", AccomplishmentsModule)

return AccomplishmentsModule
