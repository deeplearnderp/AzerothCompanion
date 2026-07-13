-------------------------------------------------------------------------------
-- Azeroth Companion
-- Weekly Module
--
-- Reports Great Vault reward-slot progress. Deliberately narrow, per
-- docs/GameplayModuleArchitecture.md Section 2.1: "Weekly" as a blanket
-- concept (all weekly-reset content) is not one Blizzard system, so this
-- module exists only for the one aggregate API Blizzard already
-- provides -- C_WeeklyRewards -- and only for the Mythic+ activity
-- category, since that is the category the rest of this addon currently
-- has a consumer for (MythicPlusModule/RecommendationEngine). Raid and
-- PvP vault categories are read by the same Blizzard API but have no
-- module of their own yet (see the planned Raids/PvP modules) -- adding
-- them here would mean this module silently doing another module's
-- future job, so they are left untouched rather than guessed at.
--
-- VERIFICATION STATUS (Blizzard API Verification pass): `threshold`,
-- `progress`, `level`, `index` on `WeeklyRewardActivityInfo` are now
-- confirmed via two independent sources: Warcraft Wiki's structured API
-- documentation (field names/types/added-patch) and Blizzard's own
-- Blizzard_WeeklyRewards.lua FrameXML source (`self.unlocked =
-- activityInfo.progress >= activityInfo.threshold`, exactly matching
-- this module's own unlock comparison below; `level` documented there as
-- "dungeon level (e.g., Mythic+10)" for the Activities/Mythic+ category,
-- i.e. the KEY level, not an item level -- see GetActivityRewardItemLevel
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
-- sibling SetDisplayedItem), not an item level. That file resolves the
-- actual reward item level through a completely different path:
-- `activity.rewards` (an array of reward entries, each with `.type`,
-- `.id`, `.itemDBID`) -> pick the best-quality/then-highest-base-level
-- Item-type reward via C_Item.GetItemInfo(rewardInfo.id) -> resolve its
-- precise level via C_WeeklyRewards.GetItemHyperlink(itemDBID) then
-- C_Item.GetDetailedItemLevelInfo(hyperlink). This mirrors that exact
-- sequence rather than treating `level` as an item level, which a prior
-- pass had wrongly assumed (see docs/DEVELOPMENT_BACKLOG.md).
--
-- Both C_Item.GetItemInfo and C_Item.GetDetailedItemLevelInfo can return
-- nil the first time an item is seen this session (Blizzard's own item
-- cache not yet populated -- MayReturnNothing, per Warcraft Wiki) --
-- pcall-wrapped and nil-guarded throughout; a cache miss simply means no
-- item level is available THIS refresh, resolved on a later one, never a
-- guessed number. Still needs an in-game spot check to confirm this
-- resolves reliably rather than intermittently missing -- see the Live
-- Verification checklist in docs/DEVELOPMENT_BACKLOG.md.
-------------------------------------------------------------------------------

local function GetActivityRewardItemLevel(activity)

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

    local okLevel, actualItemLevel = pcall(C_Item.GetDetailedItemLevelInfo, hyperlink)

    if okLevel and actualItemLevel and actualItemLevel > 0 then
        return actualItemLevel
    end

    return nil

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
        tooltip = "Track Great Vault (Mythic+ activity) reward-slot progress.",
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

function WeeklyModule:OnPlayerEnteringWorld()

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()
    self.Session.initialUnlockedSlots = self.Profile.unlockedSlots

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
-- Reads C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
-- -- the Mythic+ vault category. Both the namespace lookup and the call
-- itself are pcall-wrapped; if either the enum or the function is
-- missing/renamed, the profile simply reports zero slots rather than
-- fabricating a count. "Unlocked" means Blizzard's own progress has
-- reached its own threshold for that slot -- not a judgment this module
-- makes.
-------------------------------------------------------------------------------

function WeeklyModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    local slots = {}
    local unlockedSlots = 0

    local activityType = Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Activities

    if activityType and C_WeeklyRewards and C_WeeklyRewards.GetActivities then

        local ok, activities = pcall(C_WeeklyRewards.GetActivities, activityType)

        if ok and type(activities) == "table" then

            for _, activity in pairs(activities) do

                local threshold = tonumber(activity.threshold) or 0
                local progress = tonumber(activity.progress) or 0
                local level = tonumber(activity.level) or 0
                local index = tonumber(activity.index) or (#slots + 1)

                local unlocked = threshold > 0 and progress >= threshold

                if unlocked then
                    unlockedSlots = unlockedSlots + 1
                end

                -- Only resolved for unlocked slots -- a locked slot has
                -- nothing to preview for this addon's purposes (unlike
                -- Blizzard's own Great Vault UI, which previews every
                -- slot; this module only needs the best REAL, currently-
                -- earned reward for Home's "Highest Reward" fact).
                local rewardItemLevel = unlocked and GetActivityRewardItemLevel(activity) or nil

                table.insert(slots,
                {
                    index = index,
                    threshold = threshold,
                    progress = progress,
                    level = level,
                    unlocked = unlocked,
                    rewardItemLevel = rewardItemLevel,
                })

            end

        end

    end

    table.sort(slots, function(a, b)
        return a.index < b.index
    end)

    self.Profile.slots = slots
    self.Profile.totalSlots = #slots
    self.Profile.unlockedSlots = unlockedSlots

    local hasAvailableRewards = false

    if C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards then

        local ok, result = pcall(C_WeeklyRewards.HasAvailableRewards)

        if ok then
            hasAvailableRewards = result == true
        end

    end

    self.Profile.hasAvailableRewards = hasAvailableRewards

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
