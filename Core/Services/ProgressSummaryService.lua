-------------------------------------------------------------------------------
-- Azeroth Companion
-- Progress Summary Service
--
-- Companion Intelligence V4. Long-term progress across four windows
-- (Last 7 Days, Last 30 Days, Season, Lifetime) and simple trend
-- direction between adjacent windows. This service computes NOTHING
-- itself beyond picking date-range boundaries and comparing two already-
-- computed numbers -- every real statistic (average key, deaths,
-- consumables, ...) is MythicPlusModule's own GetStatisticsForRange()/
-- GetSeasonStatistics(), the same shared aggregation core Season
-- Statistics and GetMilestoneStats() already use (Rule 1: this service
-- doesn't duplicate that aggregation, it only calls it four times with
-- different boundaries).
--
-- Explicitly NOT included, both evaluated and declined for the same
-- reason -- no real historical record exists anywhere in this addon to
-- build them from honestly:
--   - "Vaults Completed" -- WeeklyModule reports only the CURRENT week's
--     live vault progress; it never writes to ActivityHistoryService, so
--     there is no record of any past week's vault outcome to sum.
--   - "Preparation improving" trend -- StorageModule's readiness is a
--     live snapshot (GetPreparationStatus), also never recorded
--     historically, so there is nothing to compare "improving" against
--     over time.
-- Building either honestly would mean adding real historical recording
-- to WeeklyModule/StorageModule first -- logged in the backlog as its
-- own follow-up, not silently faked here with a fabricated number.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time

local ProgressSummaryService =
{
    Name = "ProgressSummaryService",
}

AC.ProgressSummaryService = ProgressSummaryService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local SECONDS_PER_DAY = 86400

-- A window must move by at least this fraction to be called a real
-- trend rather than noise -- deterministic, documented, the same
-- "named, fixed threshold" discipline as RecommendationEngine's own
-- ComputeScore.
local TREND_THRESHOLD = 0.10

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function ProgressSummaryService:Initialize()

end

function ProgressSummaryService:Enable()

end

function ProgressSummaryService:Disable()

end

function ProgressSummaryService:Shutdown()

end

-------------------------------------------------------------------------------
-- Get Summary
--
-- The four windows named in the design brief. "Season" reuses
-- GetSeasonStatistics() as-is (already the right scope -- no date range
-- needed, since MythicPlusModule already tracks the current season
-- number directly). Returns nil only when MythicPlusModule itself isn't
-- available (module disabled/not yet loaded) -- never a partially-
-- fabricated summary.
-------------------------------------------------------------------------------

function ProgressSummaryService:GetSummary()

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")

    if not mythicPlusModule then
        return nil
    end

    local now = time()

    return
    {
        last7Days = mythicPlusModule:GetStatisticsForRange(now - (7 * SECONDS_PER_DAY), now),
        last30Days = mythicPlusModule:GetStatisticsForRange(now - (30 * SECONDS_PER_DAY), now),
        season = mythicPlusModule:GetSeasonStatistics(),
        lifetime = mythicPlusModule:GetStatisticsForRange(0, now),
    }

end

-------------------------------------------------------------------------------
-- Trend Direction
--
-- "Improving"/"Declining"/"Stable"/"Unknown" -- deterministic, a fixed
-- percentage-change threshold, never a guess. "Unknown" when either
-- window has no recorded runs at all (nothing real to compare).
-- higherIsBetter distinguishes metrics where more is good (timed rate,
-- key level) from ones where less is good (deaths).
-------------------------------------------------------------------------------

local function TrendDirection(current, previous, higherIsBetter)

    if not previous or previous == 0 then
        return "Unknown"
    end

    local change = (current - previous) / previous

    if change < 0 then
        change = -change
    end

    if change < TREND_THRESHOLD then
        return "Stable"
    end

    local rawChange = current - previous
    local improving = higherIsBetter and rawChange > 0 or (not higherIsBetter and rawChange < 0)

    if improving then
        return "Improving"
    end

    return "Declining"

end

-------------------------------------------------------------------------------
-- Build Trend Set
--
-- One window pair (e.g. Last 7 Days vs. the 7 days before that) reduced
-- to real trend directions -- every metric the Progress page's "Last 7
-- Days"/"Last 30 Days" blocks show an arrow for. Shared by GetTrends()'s
-- two window pairs (7-day, 30-day) so these comparisons are written
-- once, not twice. "Preparation" is deliberately absent -- see this
-- file's header for why (no historical record exists to compare
-- against).
-------------------------------------------------------------------------------

local function BuildTrendSet(recent, prior)

    local hasData = recent.runsCompleted > 0 and prior.runsCompleted > 0

    -- Consumables/interrupts averages are MythicPlusModule's own
    -- trackedRunCount-gated fields (BuildStatisticsFromRecords) -- gated
    -- here the same way, since both default to 0 rather than nil when
    -- neither window has any recordVersion 2+ runs to average, and 0
    -- would otherwise read as a real (mis)trend instead of "Unknown".
    local hasTrackedData = recent.trackedRunCount > 0 and prior.trackedRunCount > 0

    return
    {
        runs = hasData and TrendDirection(recent.runsCompleted, prior.runsCompleted, true) or "Unknown",
        ratingGain = hasData and TrendDirection(recent.ratingGained, prior.ratingGained, true) or "Unknown",
        deaths = hasData and TrendDirection(recent.averageDeaths, prior.averageDeaths, false) or "Unknown",
        timedRate = hasData and TrendDirection(recent.successRate, prior.successRate, true) or "Unknown",
        keyLevel = hasData and TrendDirection(recent.averageKeyLevel, prior.averageKeyLevel, true) or "Unknown",
        consumables = hasTrackedData and TrendDirection(recent.averageConsumablesPerRun, prior.averageConsumablesPerRun, true) or "Unknown",
        interrupts = hasTrackedData and TrendDirection(recent.averageInterruptsPerRun, prior.averageInterruptsPerRun, true) or "Unknown",
    }

end

-------------------------------------------------------------------------------
-- Get Trends
--
-- Last 7 Days compared against the 7 days before that; Last 30 Days
-- compared against the 30 days before that. "Only use historical
-- recorded data" -- every input here is ActivityHistoryService-backed,
-- via MythicPlusModule:GetStatisticsForRange().
-------------------------------------------------------------------------------

function ProgressSummaryService:GetTrends()

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")

    if not mythicPlusModule then
        return nil
    end

    local now = time()

    local recent7 = mythicPlusModule:GetStatisticsForRange(now - (7 * SECONDS_PER_DAY), now)
    local prior7 = mythicPlusModule:GetStatisticsForRange(now - (14 * SECONDS_PER_DAY), now - (7 * SECONDS_PER_DAY))

    local recent30 = mythicPlusModule:GetStatisticsForRange(now - (30 * SECONDS_PER_DAY), now)
    local prior30 = mythicPlusModule:GetStatisticsForRange(now - (60 * SECONDS_PER_DAY), now - (30 * SECONDS_PER_DAY))

    return
    {
        last7Days = BuildTrendSet(recent7, prior7),
        last30Days = BuildTrendSet(recent30, prior30),
    }

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("ProgressSummaryService", ProgressSummaryService)

return ProgressSummaryService
