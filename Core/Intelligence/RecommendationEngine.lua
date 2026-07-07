-------------------------------------------------------------------------------
-- Azeroth Companion
-- Recommendation Engine
--
-- Evaluates insights and produces prioritized recommendations.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local time = time

local RecommendationEngine =
{
    Name = "RecommendationEngine",
}

AC.RecommendationEngine = RecommendationEngine

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function RecommendationEngine:ResetState()

    self.Recommendations = {}
    self.LastRefresh = 0

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function RecommendationEngine:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function RecommendationEngine:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function RecommendationEngine:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function RecommendationEngine:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RecommendationEngine:Refresh()

    self.Recommendations = {}

    if not AC.InsightEngine then
        return
    end

    local insights = AC.InsightEngine:GetInsights()

    if not insights or #insights == 0 then
        return
    end

    for _, insight in ipairs(insights) do

        local recommendation = self:EvaluateInsight(insight)

        if recommendation then
            self:AddRecommendation(recommendation)
        end

    end

    self:SortRecommendations()
    self.LastRefresh = time()

end

-------------------------------------------------------------------------------
-- Insight Evaluation
-------------------------------------------------------------------------------

function RecommendationEngine:EvaluateInsight(insight)

    if not insight or type(insight) ~= "table" then
        return nil
    end

    local title = insight.title or ""
    local category = insight.category or ""
    local priority = insight.priority or 0

    -- Bags Almost Full
    if title == "Bags Almost Full" then
        return
        {
            title = AC.L:Get("Recommendation.VisitVendor.Title"),
            description = AC.L:Get("Recommendation.VisitVendor.Description"),
            priority = priority + 10,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Bags Filling Up
    if title == "Bags Filling Up" then
        return
        {
            title = AC.L:Get("Recommendation.ConsiderVendorSoon.Title"),
            description = AC.L:Get("Recommendation.ConsiderVendorSoon.Description"),
            priority = priority - 10,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Hearthstone Missing
    if title == "Hearthstone Missing" then
        return
        {
            title = AC.L:Get("Recommendation.AcquireHearthstone.Title"),
            description = AC.L:Get("Recommendation.AcquireHearthstone.Description"),
            priority = priority,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Rested XP Available
    if title == "Rested XP Available" then
        return
        {
            title = AC.L:Get("Recommendation.UseRestedXP.Title"),
            description = AC.L:Get("Recommendation.UseRestedXP.Description"),
            priority = priority - 5,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Level Up This Session
    if title == "Level Up This Session" then
        return
        {
            title = AC.L:Get("Recommendation.ContinueLeveling.Title"),
            description = AC.L:Get("Recommendation.ContinueLeveling.Description"),
            priority = priority - 10,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Item Level Improved
    if title == "Item Level Improved" then
        return
        {
            title = AC.L:Get("Recommendation.TryHarderContent.Title"),
            description = AC.L:Get("Recommendation.TryHarderContent.Description"),
            priority = priority - 15,
            category = "Profile",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Achievement Earned
    if title == "Achievement Earned" then
        return
        {
            title = AC.L:Get("Recommendation.ContinueAchievementHunting.Title"),
            description = AC.L:Get("Recommendation.ContinueAchievementHunting.Description"),
            priority = priority - 10,
            category = "Achievements",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    -- Achievement Milestone
    if title == "Achievement Milestone" then
        return
        {
            title = AC.L:Get("Recommendation.ReachNextMilestone.Title"),
            description = AC.L:Get("Recommendation.ReachNextMilestone.Description"),
            priority = priority - 5,
            category = "Achievements",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = insight.data or {},
        }
    end

    return nil

end

-------------------------------------------------------------------------------
-- Recommendation Management
-------------------------------------------------------------------------------

function RecommendationEngine:AddRecommendation(recommendation)

    local recommendationRecord =
    {
        title = recommendation.title,
        description = recommendation.description,
        priority = recommendation.priority,
        category = recommendation.category,
        timestamp = recommendation.timestamp or time(),
        expiresAt = recommendation.expiresAt or 0,
        dismissible = recommendation.dismissible or false,
        data = recommendation.data or {},
    }

    table.insert(self.Recommendations, recommendationRecord)

end

function RecommendationEngine:SortRecommendations()

    table_sort(self.Recommendations, function(a, b)
        return a.priority > b.priority
    end)

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function RecommendationEngine:GetRecommendations()

    return self.Recommendations

end

function RecommendationEngine:GetHighestPriority()

    if #self.Recommendations == 0 then
        return nil
    end

    return self.Recommendations[1]

end

function RecommendationEngine:GetLastRefresh()

    return self.LastRefresh

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("RecommendationEngine", RecommendationEngine)

return RecommendationEngine
