-------------------------------------------------------------------------------
-- Azeroth Companion
-- Briefing Service
--
-- Companion Intelligence V4 -- "Today's Briefing" on the Home page. This
-- service owns exactly one responsibility: SELECTING and ORDERING a
-- short list of already-real facts into a briefing, never generating a
-- new one.
--
-- Home Dashboard Evolution (Today's Briefing pass) -- this no longer
-- reads AC.RecommendationEngine at all. It used to lead every briefing
-- with the single highest-priority recommendation's own reason/
-- description -- a real, confirmed duplicate of what Home's Highest
-- Priority card already shows in full, one card above this one (Product
-- Vision audit). Deleted, not reworded: Highest Priority already owns
-- "what should I do next" outright. This service's job is narrower now --
-- "what else is worth knowing today" -- built from two sources:
-- AC.InsightEngine's own output (real, module-owned noteworthy facts,
-- never this service's own judgment), and two "Companion Memory"
-- observations read directly from PlayerJournal/MythicPlus's own public
-- getters (real, recurring habits, phrased as observations, never a new
-- gameplay judgment -- the one place this service reads a gameplay
-- module directly rather than going through InsightEngine, unchanged
-- from when Companion Memory was added).
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
-- Up to MAX_INSIGHT_LINES Insight lines -- one per distinct category, so
-- a single chatty module (MythicPlus has the most Insights of any module
-- today) can't crowd out every other module's own briefing-worthy fact --
-- plus up to MAX_MEMORY_LINES Companion Memory observations (below).
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
-- Called after AC.InsightEngine has already refreshed this cycle
-- (Dashboard:RefreshEngines, Sections.lua, already orders this correctly)
-- -- this service never refreshes it itself, it only reads its
-- already-current output. No longer depends on AC.RecommendationEngine
-- at all (see this file's own header) -- the guard below only checks
-- what this function actually reads.
-------------------------------------------------------------------------------

function BriefingService:Refresh()

    self.Lines = {}

    if not AC.InsightEngine then
        return
    end

    -- Home Dashboard Evolution (Today's Briefing pass) -- the single
    -- highest-value activity this service used to lead with here is
    -- DELETED, not reworded: it was the exact same fact, in the exact
    -- same words (reason/description), that Home's own Highest Priority
    -- card already shows in full, one card above this one. That was a
    -- real duplicate, not two cards with different angles on one fact --
    -- confirmed by the Product Vision's own audit. This service's job is
    -- no longer "restate what to do next" (Highest Priority already owns
    -- that outright) -- it's "what else is worth knowing today," which is
    -- a genuinely different question. AC.RecommendationEngine is no
    -- longer read here at all as a result; only AC.InsightEngine and the
    -- Companion Memory sources below remain.
    --
    -- Companion Memory leads now (Companion Intelligence vNext -- real,
    -- recurring observations, phrased as observations, "you usually/
    -- typically...", never a new gameplay judgment) -- this is the most
    -- distinctly personal-companion content this service has, and the
    -- least available anywhere else on Home, so it earns first position
    -- now that it isn't following a restated recommendation. Both sources
    -- are already-public getters on modules that own the underlying fact
    -- (Rule 6/1) -- this service only curates/orders, same as before.
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

    -- Up to MAX_INSIGHT_LINES more, one per distinct category -- InsightEngine
    -- already sorts its list by priority, so the first insight seen for
    -- a not-yet-covered category is that category's own highest-priority
    -- one. Tracked with its own counter (insightLinesAdded), not #self.Lines
    -- -- self.Lines may already hold up to MAX_MEMORY_LINES memory lines
    -- from above, and this budget is MAX_INSIGHT_LINES on its own, not
    -- shared with memory's count. No longer seeded with a recommendation's
    -- category either, since there isn't one anymore.
    local seenCategories = {}
    local insightLinesAdded = 0

    for _, insight in ipairs(AC.InsightEngine:GetInsights()) do

        if insightLinesAdded >= MAX_INSIGHT_LINES then
            break
        end

        if not seenCategories[insight.category] and insight.description and insight.description ~= "" then

            seenCategories[insight.category] = true
            table.insert(self.Lines, { text = insight.description, category = insight.category })
            insightLinesAdded = insightLinesAdded + 1

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
