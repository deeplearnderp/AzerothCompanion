-------------------------------------------------------------------------------
-- Azeroth Companion
-- Weekly Module
--
-- Reports Great Vault reward-slot progress. Deliberately narrow, per
-- docs/GameplayModuleArchitecture.md Section 2.1: "Weekly" as a blanket
-- concept (all weekly-reset content) is not one Blizzard system, so this
-- module exists only for the one aggregate API Blizzard already
-- provides -- C_WeeklyRewards. The established profile remains the Dungeon
-- category consumed by MythicPlusModule/RecommendationEngine; category
-- projections additionally expose Delves/World and Raid when Blizzard
-- returns those categories. PvP remains outside the current product surface.
--
-- VERIFICATION STATUS (Blizzard API Verification pass): `threshold`,
-- `progress`, `level`, `index` on `WeeklyRewardActivityInfo` are now
-- confirmed via two independent sources: Warcraft Wiki's structured API
-- documentation (field names/types/added-patch) and Blizzard's own
-- Blizzard_WeeklyRewards.lua FrameXML source (`self.unlocked =
-- activityInfo.progress >= activityInfo.threshold`, exactly matching
-- this module's own unlock comparison below; `level` documented there as
-- "dungeon level (e.g., Mythic+10)" for the Activities/Mythic+ category,
-- i.e. the KEY level, not an item level -- see GetActivityReward
-- below for where the real reward item level actually comes from, and
-- why `level` alone was previously mislabeled as one on Home's "Highest
-- Reward" card). `Enum.WeeklyRewardChestThresholdType.Activities` is
-- likewise confirmed as the correct member for the Mythic+ category
-- (cross-referenced against a real community addon reading the same
-- API). Not yet confirmed by an actual live client: whether `progress`
-- for the Activities category increments in whole-dungeon-completed
-- units on THIS specific client build (every source agrees it does
-- conceptually -- "completed dungeon run count" per Blizzard's own
-- source comment -- but no source shown here is a live debug print).
-- Every call remains pcall-wrapped and every field nil-guarded regardless.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local tonumber = tonumber
local pairs = pairs

local WeeklyModule =
{
    Name = "Weekly",
}

-------------------------------------------------------------------------------
-- Reward Item Level (Blizzard API Verification pass)
--
-- `activity.level` (used for `slot.level` below) is the Mythic+ KEY level
-- (e.g. 15 for a +15) -- confirmed directly against Blizzard's own
-- Blizzard_WeeklyRewards.lua (WeeklyRewardActivityItemMixin:OnEnter's
-- sibling SetDisplayedItem), not an item level. That file resolves actual
-- reward item information through a completely different path:
-- `activity.rewards` (an array of reward entries, each with `.type`,
-- `.id`, `.itemDBID`) -> pick the best-quality/then-highest-base-level
-- Item-type reward via C_Item.GetItemInfo(rewardInfo.id) -> resolve its
-- precise level via C_WeeklyRewards.GetItemHyperlink(itemDBID) then
-- C_Item.GetDetailedItemLevelInfo(hyperlink). This mirrors that exact
-- sequence rather than treating `level` as an item level, which a prior
-- pass had wrongly assumed (see docs/DEVELOPMENT_BACKLOG.md).
--
-- Both C_Item.GetItemInfo and C_Item.GetDetailedItemLevelInfo can return
-- nil the first time an item is seen this session. Calls are pcall-wrapped
-- and nil-guarded; GET_ITEM_INFO_RECEIVED triggers a later refresh rather
-- than guessing. The overview also falls back to Blizzard's
-- GetExampleRewardItemHyperlinks preview when generated reward data is not
-- populated yet. Still needs an in-game spot check to confirm this
-- resolves reliably rather than intermittently missing -- see the Live
-- Verification checklist in docs/DEVELOPMENT_BACKLOG.md.
-------------------------------------------------------------------------------

local function GetItemDetails(hyperlink)

    if not hyperlink or not C_Item or not C_Item.GetItemInfo or not C_Item.GetDetailedItemLevelInfo then
        return nil
    end

    local okInfo, name, resolvedLink, quality = pcall(C_Item.GetItemInfo, hyperlink)
    local okLevel, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, hyperlink)

    if (not okInfo and not okLevel) or (not name and not resolvedLink and not quality and not itemLevel) then
        return nil
    end

    return
    {
        name = okInfo and name or nil,
        hyperlink = (okInfo and resolvedLink) or hyperlink,
        quality = okInfo and quality or nil,
        itemLevel = okLevel and itemLevel or nil,
    }

end

local function GetActivityReward(activity)

    if type(activity.rewards) ~= "table" then
        return nil
    end

    if not C_Item or not C_Item.GetItemInfo or not C_WeeklyRewards or not C_WeeklyRewards.GetItemHyperlink or not C_Item.GetDetailedItemLevelInfo then
        return nil
    end

    local itemRewardType = Enum.CachedRewardType and Enum.CachedRewardType.Item

    local bestQuality = 0
    local bestBaseLevel = 0
    local bestItemDBID = nil

    for _, rewardInfo in pairs(activity.rewards) do

        if (not itemRewardType or rewardInfo.type == itemRewardType) and rewardInfo.itemDBID then

            local ok, _, _, itemQuality, itemLevel = pcall(C_Item.GetItemInfo, rewardInfo.id)

            if ok and itemQuality and itemLevel then

                if itemQuality > bestQuality or (itemQuality == bestQuality and itemLevel > bestBaseLevel) then
                    bestQuality = itemQuality
                    bestBaseLevel = itemLevel
                    bestItemDBID = rewardInfo.itemDBID
                end

            end

        end

    end

    if not bestItemDBID then
        return nil
    end

    local okLink, hyperlink = pcall(C_WeeklyRewards.GetItemHyperlink, bestItemDBID)

    if not okLink or not hyperlink then
        return nil
    end

    return GetItemDetails(hyperlink)

end

local function GetActivityPreviewRewards(activity)

    if not activity or not activity.id or not C_WeeklyRewards or not C_WeeklyRewards.GetExampleRewardItemHyperlinks or not C_Item or not C_Item.GetDetailedItemLevelInfo then
        return nil
    end

    local okLinks, hyperlink, upgradeHyperlink = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, activity.id)

    if not okLinks or not hyperlink then
        return nil
    end

    return GetItemDetails(hyperlink), GetItemDetails(upgradeHyperlink)

end

local function GetNextUpgrade(activity, categoryID)

    if not C_WeeklyRewards then
        return nil
    end

    if categoryID == "Dungeons" and C_WeeklyRewards.GetNextMythicPlusIncrease then

        local ok, hasSeasonData, nextLevel, itemLevel = pcall(C_WeeklyRewards.GetNextMythicPlusIncrease, tonumber(activity.level) or 0)

        if ok and hasSeasonData and nextLevel then
            return { level = nextLevel, itemLevel = itemLevel }
        end

    elseif C_WeeklyRewards.GetNextActivitiesIncrease and activity.activityTierID then

        local ok, hasSeasonData, nextActivityTierID, nextLevel, itemLevel = pcall(
            C_WeeklyRewards.GetNextActivitiesIncrease,
            activity.activityTierID,
            tonumber(activity.level) or 0)

        if ok and hasSeasonData and (nextActivityTierID or nextLevel or itemLevel) then
            return
            {
                activityTierID = nextActivityTierID,
                level = nextLevel,
                itemLevel = itemLevel,
            }
        end

    end

    return nil

end

local function BuildVaultCategory(categoryID, titleKey, activityType, unitSingularKey, unitPluralKey)

    local category =
    {
        id = categoryID,
        titleKey = titleKey,
        unitSingularKey = unitSingularKey,
        unitPluralKey = unitPluralKey,
        totalSlots = 0,
        unlockedSlots = 0,
        slots = {},
    }

    if not activityType or not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        return category
    end

    local ok, activities = pcall(C_WeeklyRewards.GetActivities, activityType)

    if not ok or type(activities) ~= "table" then
        return category
    end

    for _, activity in pairs(activities) do

        local threshold = tonumber(activity.threshold) or 0
        local progress = tonumber(activity.progress) or 0
        local level = tonumber(activity.level) or 0
        local index = tonumber(activity.index) or (#category.slots + 1)
        local unlocked = threshold > 0 and progress >= threshold
        local actualReward = unlocked and GetActivityReward(activity) or nil
        local previewReward, previewUpgrade = GetActivityPreviewRewards(activity)
        local reward = actualReward or previewReward
        local nextUpgrade = GetNextUpgrade(activity, categoryID)

        if nextUpgrade and not nextUpgrade.itemLevel and previewUpgrade then
            nextUpgrade.itemLevel = previewUpgrade.itemLevel
        end

        if unlocked then
            category.unlockedSlots = category.unlockedSlots + 1
        end

        table.insert(category.slots,
        {
            index = index,
            threshold = threshold,
            progress = progress,
            remaining = math.max(0, threshold - progress),
            level = level,
            unlocked = unlocked,
            activityTierID = activity.activityTierID,
            raidString = activity.raidString,
            rewardName = reward and reward.name or nil,
            rewardHyperlink = reward and reward.hyperlink or nil,
            rewardQuality = reward and reward.quality or nil,
            rewardItemLevel = reward and reward.itemLevel or nil,
            rewardIsPreview = actualReward == nil,
            nextUpgradeLevel = nextUpgrade and nextUpgrade.level or nil,
            nextUpgradeItemLevel = nextUpgrade and nextUpgrade.itemLevel or nil,
        })

    end

    table.sort(category.slots, function(a, b)
        return a.index < b.index
    end)

    category.totalSlots = #category.slots

    return category

end

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function WeeklyModule:ResetProfile()

    self.Profile =
    {
        activityType = "MythicPlus",
        totalSlots = 0,
        unlockedSlots = 0,
        slots = {},
        categories = {},
        categoryOrder = {},
        hasAvailableRewards = false,
    }

    self.Session =
    {
        initialUnlockedSlots = 0,
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function WeeklyModule:Initialize()

    self:ResetProfile()

    AC.ConfigurationManager:Register("Weekly", Defaults)

    AC.Settings:RegisterPage("Weekly",
    {
        title = "Weekly",
        module = "Weekly",
        order = 55,
    })

    AC.Settings:RegisterSection("Weekly", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Weekly", "General",
    {
        key = "enabled",
        text = "Enable Weekly Module",
        default = true,
        tooltip = "Track Great Vault Dungeon and World reward-slot progress.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function WeeklyModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)

    -- WEEKLY_REWARDS_UPDATE confirmed directly against Blizzard's own
    -- Blizzard_WeeklyRewards.lua (WEEKLY_REWARDS_EVENTS table, handled in
    -- its own OnEvent) -- Blizzard API Verification pass. Still
    -- pcall-wrapped for defense-in-depth (a future client build could
    -- always rename/remove an event), not because the name itself is in
    -- doubt anymore.
    local ok, err = pcall(AC.Events.Register, AC.Events, "WEEKLY_REWARDS_UPDATE", self, "OnWeeklyRewardsUpdate")

    if not ok and AC.Logger then
        AC.Logger:Error(("WeeklyModule failed to register WEEKLY_REWARDS_UPDATE: %s"):format(tostring(err)))
    end

    pcall(AC.Events.Register, AC.Events, "WEEKLY_REWARDS_ITEM_CHANGED", self, "OnWeeklyRewardsUpdate")
    pcall(AC.Events.Register, AC.Events, "GET_ITEM_INFO_RECEIVED", self, "OnWeeklyRewardsUpdate")

    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then
        self:Refresh()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function WeeklyModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function WeeklyModule:Shutdown()

    self:Disable()
    self:ResetProfile()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function WeeklyModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Weekly", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function WeeklyModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()

    if isInitialLogin then
        self.Session.initialUnlockedSlots = self.Profile.unlockedSlots
    end

end

function WeeklyModule:OnWeeklyRewardsUpdate()

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()

end

function WeeklyModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Weekly" then
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
--
-- Reads C_WeeklyRewards.GetActivities for the Dungeon (Activities) and World
-- categories. Both enum lookups and calls are pcall/nil guarded; if either
-- enum or the function is missing/renamed, the relevant category
-- missing/renamed, the profile simply reports zero slots rather than
-- fabricating a count. "Unlocked" means Blizzard's own progress has
-- reached its own threshold for that slot -- not a judgment this module
-- makes.
-------------------------------------------------------------------------------

function WeeklyModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    local thresholdTypes = Enum.WeeklyRewardChestThresholdType or {}
    local categoryDefinitions =
    {
        { id = "Dungeons", titleKey = "Weekly.CategoryDungeons", activityType = thresholdTypes.Activities, unitSingularKey = "Weekly.UnitDungeon", unitPluralKey = "Weekly.UnitDungeons" },
        { id = "Delves", titleKey = "Weekly.CategoryDelves", activityType = thresholdTypes.World, unitSingularKey = "Weekly.UnitDelve", unitPluralKey = "Weekly.UnitDelves" },
        { id = "Raid", titleKey = "Weekly.CategoryRaid", activityType = thresholdTypes.Raid, unitSingularKey = "Weekly.UnitRaidBoss", unitPluralKey = "Weekly.UnitRaidBosses" },
    }
    local categories = {}
    local categoryOrder = {}

    for _, definition in ipairs(categoryDefinitions) do

        if definition.activityType then

            local category = BuildVaultCategory(
                definition.id,
                definition.titleKey,
                definition.activityType,
                definition.unitSingularKey,
                definition.unitPluralKey)

            if category.totalSlots > 0 then
                categories[definition.id] = category
                table.insert(categoryOrder, category)
            end

        end

    end

    local dungeonCategory = categories.Dungeons or { totalSlots = 0, unlockedSlots = 0, slots = {} }

    -- Preserve the established Mythic+ projection for existing consumers.
    self.Profile.slots = dungeonCategory.slots
    self.Profile.totalSlots = dungeonCategory.totalSlots
    self.Profile.unlockedSlots = dungeonCategory.unlockedSlots
    self.Profile.categories = categories
    self.Profile.categories.World = categories.Delves
    self.Profile.categoryOrder = categoryOrder

    local hasAvailableRewards = false

    if C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards then

        local ok, result = pcall(C_WeeklyRewards.HasAvailableRewards)

        if ok then
            hasAvailableRewards = result == true
        end

    end

    self.Profile.hasAvailableRewards = hasAvailableRewards

    if AC.Events then
        AC.Events:Fire("WEEKLY_DATA_UPDATED")
    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function WeeklyModule:GetProfile()

    return self.Profile

end

function WeeklyModule:GetVaultProgress()

    return self.Profile

end

function WeeklyModule:GetVaultCategoryProgress(categoryName)

    return self.Profile.categories and self.Profile.categories[categoryName]

end

function WeeklyModule:GetVaultCategories()

    return self.Profile.categoryOrder or {}

end

-- Companion Intelligence vNext -- real slots gained since this session's
-- own OnPlayerEnteringWorld snapshot (Session.initialUnlockedSlots,
-- already captured for the "Vault Slot Unlocked" Insight below). Shared
-- by that Insight and Home's new "Today's Companion Notes" card so this
-- comparison exists in exactly one place (Rule 7).
function WeeklyModule:GetSlotsGainedThisSession()

    return math.max(0, self.Profile.unlockedSlots - (self.Session.initialUnlockedSlots or 0))

end

-------------------------------------------------------------------------------
-- Next Locked Slot (Companion Intelligence V4)
--
-- The next vault slot not yet unlocked, with how much more progress it
-- needs -- real data straight from C_WeeklyRewards' own per-slot
-- threshold/progress (see this file's own verification notice above).
-- Shared by the "Vault Slot Progress" Insight below and
-- RecommendationEngine's "Complete Your Keystone" evidence-gathering, so
-- neither one re-derives this by scanning self.Profile.slots itself.
-- Slots are already sorted ascending by index (Refresh(), via
-- table.sort), so the first locked one found is genuinely the next to
-- unlock. Returns nil when every slot is already unlocked, or when
-- there's no vault data at all this session.
-------------------------------------------------------------------------------

function WeeklyModule:GetNextLockedSlot()

    for _, slot in ipairs(self.Profile.slots or {}) do

        if not slot.unlocked then

            return
            {
                index = slot.index,
                threshold = slot.threshold,
                progress = slot.progress,
                remaining = (slot.threshold or 0) - (slot.progress or 0),
            }

        end

    end

    return nil

end

-------------------------------------------------------------------------------
-- Insights
--
-- Objective only. "Slot unlocked" is session-relative (like
-- MythicPlusModule's "Rating Increased") so it fires once, the session
-- this addon actually observed the slot cross its threshold, rather than
-- every login while it stays unlocked.
-------------------------------------------------------------------------------

function WeeklyModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    local profile = self.Profile
    local session = self.Session

    if not profile or not session then
        return insights
    end

    if profile.totalSlots > 0 and self:GetSlotsGainedThisSession() > 0 then
        table.insert(insights,
        {
            title = "Vault Slot Unlocked",
            description = string.format("You unlocked Great Vault slot %d of %d this session.", profile.unlockedSlots, profile.totalSlots),
            priority = 40,
            category = "Weekly",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { unlockedSlots = profile.unlockedSlots, totalSlots = profile.totalSlots },
        })
    end

    if profile.hasAvailableRewards then
        table.insert(insights,
        {
            title = "Vault Reward Available",
            description = "You have an unclaimed Great Vault reward.",
            priority = 35,
            category = "Weekly",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Vault slot progress (Companion Intelligence V4) -- a standing fact,
    -- not session-relative like "Vault Slot Unlocked" above, so it keeps
    -- showing for as long as a slot remains locked. "How much more" is
    -- real and computable via GetNextLockedSlot() -- the same per-slot
    -- threshold/progress data (and the same general-knowledge/
    -- unverified caveat) as the rest of this module.
    local nextSlot = self:GetNextLockedSlot()

    if nextSlot and nextSlot.remaining > 0 then
        table.insert(insights,
        {
            title = "Vault Slot Progress",
            description = string.format("You need %d more toward Great Vault slot %d.", nextSlot.remaining, nextSlot.index or 0),
            priority = 25,
            category = "Weekly",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { remaining = nextSlot.remaining, slotIndex = nextSlot.index, totalSlots = profile.totalSlots },
        })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Weekly", WeeklyModule)

return WeeklyModule
