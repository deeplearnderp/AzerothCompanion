-------------------------------------------------------------------------------
-- Azeroth Companion
-- Achievements Module
--
-- Authoritative achievement data service.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local pairs = pairs
local tonumber = tonumber

local GetAchievementInfo = GetAchievementInfo

local AchievementsModule =
{
    Name = "Achievements",
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
-------------------------------------------------------------------------------

function AchievementsModule:ResetCache()

    self.LastUpdated = 0
    self.TotalPoints = 0
    self.Achievements = {}

    self.Session =
    {
        initialPoints = 0,
        achievementsEarnedThisSession = {},
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function AchievementsModule:Initialize()

    self:ResetCache()

    AC.ConfigurationManager:Register("Achievements", Defaults)

    AC.Settings:RegisterPage("Achievements",
    {
        title = "Achievements",
        module = "Achievements",
        order = 50,
    })

    AC.Settings:RegisterSection("Achievements", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Achievements", "General",
    {
        key = "enabled",
        text = "Enable Achievements Module",
        default = true,
        tooltip = "Maintain an authoritative cache of completed achievements and achievement points.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function AchievementsModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("ACHIEVEMENT_EARNED", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then
        self:Refresh()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function AchievementsModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function AchievementsModule:Shutdown()

    self:Disable()
    self:ResetCache()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function AchievementsModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Achievements", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function AchievementsModule:OnPlayerEnteringWorld()

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()
    self.Session.initialPoints = self.TotalPoints

end

function AchievementsModule:OnAchievementEarned(achievementID)

    if not self:IsModuleEnabled() then
        return
    end

    achievementID = tonumber(achievementID)

    if not achievementID then
        return
    end

    self:RefreshAchievement(achievementID)

    -- Track achievement earned this session
    self.Session.achievementsEarnedThisSession[achievementID] = time()

end

function AchievementsModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Achievements" then
        return
    end

    if key ~= "enabled" then
        return
    end

    if value then
        self:Refresh()
    else
        self:ResetCache()
    end

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function AchievementsModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshCompletedAchievements()
    self:RefreshTotalPoints()
    self.LastUpdated = time()

end

function AchievementsModule:RefreshCompletedAchievements()

    self.Achievements = {}

    local totalPoints = 0

    for achievementID = 1, 20000 do

        local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic =
            GetAchievementInfo(achievementID)

        if id and completed and not isStatistic then

            self.Achievements[achievementID] =
            {
                id = achievementID,
                name = name or "",
                description = description or "",
                points = points or 0,
                completed = true,
                month = month or 0,
                day = day or 0,
                year = year or 0,
                icon = icon or 0,
            }

            totalPoints = totalPoints + (points or 0)

        end

    end

    self.TotalPoints = totalPoints

end

function AchievementsModule:RefreshAchievement(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return nil
    end

    local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic =
        GetAchievementInfo(achievementID)

    if not id then
        self.Achievements[achievementID] = nil
        return nil
    end

    if completed and not isStatistic then

        self.Achievements[achievementID] =
        {
            id = achievementID,
            name = name or "",
            description = description or "",
            points = points or 0,
            completed = true,
            month = month or 0,
            day = day or 0,
            year = year or 0,
            icon = icon or 0,
        }

        self:RefreshTotalPoints()
        self.LastUpdated = time()

    else

        self.Achievements[achievementID] = nil
        self:RefreshTotalPoints()
        self.LastUpdated = time()

    end

    return self.Achievements[achievementID]

end

function AchievementsModule:RefreshTotalPoints()

    local totalPoints = 0

    for _, achievement in pairs(self.Achievements) do
        totalPoints = totalPoints + (achievement.points or 0)
    end

    self.TotalPoints = totalPoints

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function AchievementsModule:GetAchievement(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return nil
    end

    return self.Achievements[achievementID]

end

function AchievementsModule:GetAchievements()

    local achievements = {}
    local index = 1

    for _, achievement in pairs(self.Achievements) do
        achievements[index] = achievement
        index = index + 1
    end

    return achievements

end

function AchievementsModule:IsCompleted(achievementID)

    achievementID = tonumber(achievementID)

    if not achievementID then
        return false
    end

    local achievement = self.Achievements[achievementID]

    if achievement then
        return achievement.completed == true
    end

    local _, _, _, completed = GetAchievementInfo(achievementID)

    return completed == true

end

function AchievementsModule:GetPoints()

    return self.TotalPoints or 0

end

function AchievementsModule:GetAchievementCount()

    local count = 0

    for _ in pairs(self.Achievements) do
        count = count + 1
    end

    return count

end

function AchievementsModule:GetMostRecentAchievement()

    local mostRecent = nil
    local mostRecentValue = -1

    for _, achievement in pairs(self.Achievements) do

        local year = achievement.year or 0
        local month = achievement.month or 0
        local day = achievement.day or 0

        -- Blizzard's year/month/day fields are only meaningful relative
        -- to each other, but that's enough to sort for "most recent".
        local value = (year * 10000) + (month * 100) + day

        if value > mostRecentValue then
            mostRecentValue = value
            mostRecent = achievement
        end

    end

    return mostRecent

end

function AchievementsModule:GetSessionSummary()

    local session = self.Session

    local achievementsEarnedThisSession = 0

    for _ in pairs(session.achievementsEarnedThisSession) do
        achievementsEarnedThisSession = achievementsEarnedThisSession + 1
    end

    local pointsEarnedThisSession = (self.TotalPoints or 0) - (session.initialPoints or 0)

    if pointsEarnedThisSession < 0 then
        pointsEarnedThisSession = 0
    end

    return
    {
        achievementsEarnedThisSession = achievementsEarnedThisSession,
        pointsEarnedThisSession = pointsEarnedThisSession,
    }

end

-------------------------------------------------------------------------------
-- Insights
-------------------------------------------------------------------------------

function AchievementsModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    local session = self.Session

    if not session then
        return insights
    end

    -- Achievement earned this session
    for achievementID, timestamp in pairs(session.achievementsEarnedThisSession) do
        local achievement = self.Achievements[achievementID]
        if achievement then
            table.insert(insights,
            {
                title = "Achievement Earned",
                description = string.format("You earned: %s", achievement.name or "Unknown"),
                priority = 60,
                category = "Achievements",
                timestamp = timestamp,
                expiresAt = 0,
                dismissible = false,
                data = { achievementID = achievementID },
            })
        end
    end

    -- Achievement point milestone reached (every 1000 points)
    local pointsGained = self.TotalPoints - session.initialPoints
    if pointsGained >= 1000 then
        table.insert(insights,
        {
            title = "Achievement Milestone",
            description = string.format("You gained %d achievement points this session!", pointsGained),
            priority = 45,
            category = "Achievements",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { pointsGained = pointsGained },
        })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Achievements", AchievementsModule)

return AchievementsModule
