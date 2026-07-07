-------------------------------------------------------------------------------
-- Azeroth Companion
-- Insight Engine
--
-- Central intelligence layer that aggregates actionable insights from modules.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local time = time

local InsightEngine =
{
    Name = "InsightEngine",
}

AC.InsightEngine = InsightEngine

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function InsightEngine:ResetState()

    self.Insights = {}
    self.LastRefresh = 0

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function InsightEngine:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function InsightEngine:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function InsightEngine:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function InsightEngine:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function InsightEngine:Refresh()

    self.Insights = {}

    if not AC.ModuleManager then
        return
    end

    for _, module in ipairs(AC.ModuleManager.Order) do

        if module.GetInsights and type(module.GetInsights) == "function" then

            local success, insights = pcall(module.GetInsights, module)

            if success and type(insights) == "table" then

                for _, insight in ipairs(insights) do

                    if self:ValidateInsight(insight) then
                        self:AddInsight(insight)
                    end

                end

            end

        end

    end

    self:SortInsights()
    self.LastRefresh = time()

end

-------------------------------------------------------------------------------
-- Insight Validation
-------------------------------------------------------------------------------

function InsightEngine:ValidateInsight(insight)

    if type(insight) ~= "table" then
        return false
    end

    if type(insight.title) ~= "string" or insight.title == "" then
        return false
    end

    if type(insight.priority) ~= "number" or insight.priority < 1 then
        return false
    end

    if type(insight.category) ~= "string" or insight.category == "" then
        return false
    end

    return true

end

-------------------------------------------------------------------------------
-- Insight Management
-------------------------------------------------------------------------------

function InsightEngine:AddInsight(insight)

    local insightRecord =
    {
        title = insight.title,
        description = insight.description or "",
        priority = insight.priority,
        category = insight.category,
        timestamp = insight.timestamp or time(),
        expiresAt = insight.expiresAt or 0,
        dismissible = insight.dismissible or false,
        data = insight.data or {},
    }

    table.insert(self.Insights, insightRecord)

end

function InsightEngine:SortInsights()

    table_sort(self.Insights, function(a, b)
        return a.priority > b.priority
    end)

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function InsightEngine:GetInsights()

    return self.Insights

end

function InsightEngine:GetInsightsByCategory(category)

    local filtered = {}
    local index = 1

    for _, insight in ipairs(self.Insights) do

        if insight.category == category then
            filtered[index] = insight
            index = index + 1
        end

    end

    return filtered

end

function InsightEngine:GetHighestPriority()

    if #self.Insights == 0 then
        return nil
    end

    return self.Insights[1]

end

function InsightEngine:GetLastRefresh()

    return self.LastRefresh

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("InsightEngine", InsightEngine)

return InsightEngine
