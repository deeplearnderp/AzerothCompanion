-------------------------------------------------------------------------------
-- Azeroth Companion
-- Briefing Service
--
-- Companion Intelligence V4 -- "Today's Briefing" on the Home page. This
-- service owns exactly one responsibility: SELECTING and ORDERING a
-- short list of already-real facts into a briefing, never generating a
-- new one. Every line comes verbatim from a real Insight's or
-- Recommendation's own `description`/`reason` field -- both of those are
-- already properly-worded, real, module-owned sentences (InsightEngine/
-- RecommendationEngine already require every module to supply real text,
-- never this service inventing a fabricated fact or rephrasing one).
--
-- Ownership: BriefingService reads AC.RecommendationEngine and
-- AC.InsightEngine's already-public output only -- it never reads a
-- gameplay module directly, and it never computes a new gameplay fact
-- (e.g. "your strongest dungeon"; that is MythicPlusModule's own
-- "Strongest Dungeon" Insight, added this same pass, precisely so a
-- consumer like this one never has to derive it itself). This mirrors
-- RecommendationEngine's own Rule 6 discipline: the "what's noteworthy"
-- judgment always comes from a module's Insight, this layer only curates
-- and orders what already exists.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ipairs = ipairs
local time = time

local BriefingService =
{
    Name = "BriefingService",
}

AC.BriefingService = BriefingService

-------------------------------------------------------------------------------
-- Constants
--
-- One line for the single highest-priority recommendation (the "what
-- should I do right now" headline every other page already leads with),
-- plus up to MAX_INSIGHT_LINES more -- one per distinct category, so a
-- single chatty module (MythicPlus has the most Insights of any module
-- today) can't crowd out every other module's own briefing-worthy fact.
-------------------------------------------------------------------------------

local MAX_INSIGHT_LINES = 4

-- Companion Intelligence vNext -- "Companion Memory": real, recurring
-- OBSERVATIONS about the player's own habits, never assumptions. Each of
-- the two lines below is independently omitted when the underlying
-- module has no real data yet for it -- never a fabricated placeholder.
local MAX_MEMORY_LINES = 2

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function BriefingService:ResetState()

    self.Lines = {}
    self.LastRefresh = 0

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function BriefingService:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function BriefingService:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function BriefingService:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function BriefingService:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Refresh
--
-- Called after AC.RecommendationEngine/AC.InsightEngine have already
-- refreshed this cycle (Dashboard:RefreshEngines, Sections.lua, already
-- orders this correctly) -- this service never refreshes either of them
-- itself, it only reads their already-current output.
-------------------------------------------------------------------------------

function BriefingService:Refresh()

    self.Lines = {}

    if not AC.RecommendationEngine or not AC.InsightEngine then
        return
    end

    local seenCategories = {}

    -- The single highest-value activity, exactly as the Home page's own
    -- Highest Priority card already frames it -- reason when the
    -- recommendation has one (more specific), description otherwise.
    local topRecommendation = AC.RecommendationEngine:GetHighestPriority()

    if topRecommendation then

        local text = topRecommendation.reason

        if not text or text == "" then
            text = topRecommendation.description
        end

        if text and text ~= "" then

            table.insert(self.Lines, { text = text, category = topRecommendation.category })
            seenCategories[topRecommendation.category] = true

        end

    end

    -- Up to MAX_INSIGHT_LINES more, one per distinct category not
    -- already covered above, highest priority within each -- InsightEngine
    -- already sorts its list by priority, so the first insight seen for
    -- a not-yet-covered category is that category's own highest-priority
    -- one.
    for _, insight in ipairs(AC.InsightEngine:GetInsights()) do

        if #self.Lines >= MAX_INSIGHT_LINES + 1 then
            break
        end

        if not seenCategories[insight.category] and insight.description and insight.description ~= "" then

            seenCategories[insight.category] = true
            table.insert(self.Lines, { text = insight.description, category = insight.category })

        end

    end

    -- Companion Memory (Companion Intelligence vNext) -- real, recurring
    -- observations, phrased as observations ("you usually/typically..."),
    -- never a new gameplay judgment. Both sources are already-public
    -- getters on modules that own the underlying fact (Rule 6/1) --
    -- this service only curates/orders, exactly like every line above.
    local memoryLinesAdded = 0

    if memoryLinesAdded < MAX_MEMORY_LINES then

        local playerJournalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
        local frequentCompanion = playerJournalModule and playerJournalModule.GetMostFrequentCompanion and playerJournalModule:GetMostFrequentCompanion()

        if frequentCompanion then
            table.insert(self.Lines, { text = AC.L:Format("Briefing.FrequentCompanionFormat", frequentCompanion.name, frequentCompanion.runsTogether), category = "PlayerJournal" })
            memoryLinesAdded = memoryLinesAdded + 1
        end

    end

    if memoryLinesAdded < MAX_MEMORY_LINES then

        local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
        local seasonStats = mythicPlusModule and mythicPlusModule:GetSeasonStatistics()

        if seasonStats and seasonStats.trackedRunCount and seasonStats.trackedRunCount >= 3 and seasonStats.averageConsumablesPerRun and seasonStats.averageConsumablesPerRun > 0 then
            table.insert(self.Lines, { text = AC.L:Format("Briefing.TypicalConsumablesFormat", string.format("%.1f", seasonStats.averageConsumablesPerRun)), category = "MythicPlus" })
            memoryLinesAdded = memoryLinesAdded + 1
        end

    end

    self.LastRefresh = time()

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function BriefingService:GetBriefing()

    return self.Lines

end

function BriefingService:GetLastRefresh()

    return self.LastRefresh

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("BriefingService", BriefingService)

return BriefingService
