-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Progress (the flagship analytics page)
--
-- Answers "How am I improving?" -- every number on this page comes from
-- ProgressSummaryService (window stats + trend directions), MilestoneService
-- (recently achieved milestones), or MythicPlusModule/StorageModule's own
-- public getters (current season, rating, live preparation readiness).
-- This page computes nothing itself: no averages, no trend comparisons, no
-- aggregation -- it only formats and lays out numbers those services/
-- modules already produced, the same "Dashboard is presentation only"
-- discipline every other page follows. Fully dynamic, same
-- measure-at-full-width-then-narrow-if-needed shape as MythicPlus.lua.
--
-- "Preparation" is shown once, near Overview, as a live current-value fact
-- (StorageModule:GetPreparationStatus) rather than once per day-window with
-- a trend arrow -- StorageModule never records readiness historically, so
-- there is nothing to compare a "Preparation improving" trend against (see
-- ProgressSummaryService's own header comment for the same reasoning).
-- Vaults Completed is omitted entirely for the same reason: WeeklyModule
-- only reports the current week's live vault progress, never a historical
-- per-week record.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat

-------------------------------------------------------------------------------
-- Formatting Helpers
-------------------------------------------------------------------------------

-- Appends a trend arrow to an already-formatted value string -- "Unknown"
-- (not enough historical data) and "Stable" both still show real
-- information (Stable gets its own flat-line glyph), only a missing
-- direction renders with no arrow at all.
local function ValueWithTrend(valueText, direction)

    local arrow = direction and Format.GetTrendArrow(direction) or ""

    if arrow == "" then
        return valueText
    end

    return valueText .. " " .. arrow

end

local function FormatDungeonWithRate(name, rate)

    if not name then
        return AC.L:Get("Common.Unknown")
    end

    return AC.L:Format("Progress.DungeonRateFormat", name, rate or 0)

end

function Dashboard:UpdateProgressPage(frame)

    local page = frame.Pages and frame.Pages.Progress

    if not page then
        return
    end

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local mpProfile = mythicPlusModule and mythicPlusModule:GetProfile()

    if not mpProfile then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    local summary = AC.ProgressSummaryService and AC.ProgressSummaryService:GetSummary()
    local trends = AC.ProgressSummaryService and AC.ProgressSummaryService:GetTrends()

    if not summary then
        return
    end

    local season = summary.season or {}
    local lifetime = summary.lifetime or {}
    local last7 = summary.last7Days or {}
    local last30 = summary.last30Days or {}

    local trends7 = trends and trends.last7Days
    local trends30 = trends and trends.last30Days

    local recentMilestones = AC.MilestoneService and AC.MilestoneService:GetRecent(5) or {}

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local preparation = storageModule and storageModule.GetPreparationStatus and storageModule:GetPreparationStatus("MythicPlus")

    -- One line per trend metric with a real (non-"Unknown") direction --
    -- "only display trends supported by real data" means a metric with
    -- insufficient history to compare simply isn't in this list at all,
    -- not shown blank or guessed.
    local trendLines = {}

    local TREND_ORDER =
    {
        { key = "runs", label = "Progress.TrendRuns" },
        { key = "ratingGain", label = "Progress.TrendRatingGain" },
        { key = "keyLevel", label = "Progress.TrendAverageKey" },
        { key = "timedRate", label = "Progress.TrendTimedPercent" },
        { key = "deaths", label = "Progress.TrendDeaths" },
        { key = "consumables", label = "Progress.TrendConsumables" },
        { key = "interrupts", label = "Progress.TrendInterrupts" },
    }

    if trends7 then

        for _, entry in ipairs(TREND_ORDER) do

            local direction = trends7[entry.key]

            if direction and direction ~= "Unknown" then
                table.insert(trendLines, { label = entry.label, direction = direction })
            end

        end

    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Hero -- current rating, with the most recent Timed % trend as a
        -- single headline indicator ("Current Trend").
        -----------------------------------------------------------------------

        local heroCaption = ""

        if trends7 and trends7.timedRate and trends7.timedRate ~= "Unknown" then
            heroCaption = Format.GetTrendArrow(trends7.timedRate) .. " " .. AC.L:Get("Progress.TrendDirection" .. trends7.timedRate)
        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("Progress.HeroHeadline"), AC.Presentation.FormatRating(mpProfile.rating), heroCaption)

        yOffset = heroEndOffset

        -----------------------------------------------------------------------
        -- Overview
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Progress.SectionOverview", yOffset)

        local overviewStats =
        {
            { label = "Progress.StatCurrentSeason", value = (mpProfile.currentSeason and mpProfile.currentSeason >= 0) and tostring(mpProfile.currentSeason) or AC.L:Get("Common.Unknown") },
            { label = "Progress.StatHighestKey", value = tostring(season.highestCompletedLevel or 0) },
            { label = "Progress.StatTimedPercent", value = AC.Presentation.FormatPercent(season.successRate) },
            { label = "Progress.StatRunsCompleted", value = tostring(season.runsCompleted or 0) },
        }

        yOffset = self:LayoutStatisticsGrid(page, "Overview", scrollChild, yOffset, width, overviewStats)

        -- Preparation -- a live current-value fact, not a per-window
        -- statistic (see header comment for why).
        if preparation then

            if not page.PreparationFootnote then

                local footnote = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                footnote:SetJustifyH("LEFT")

                page.PreparationFootnote = footnote

            end

            local prepText

            if preparation.ready then
                prepText = AC.L:Get("Progress.PreparationReady")
            else
                prepText = AC.L:Format("Progress.PreparationPercentFormat", preparation.readinessPercent or 0)
            end

            page.PreparationFootnote:ClearAllPoints()
            page.PreparationFootnote:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
            page.PreparationFootnote:SetWidth(width - Layout.ROW_INDENT)
            page.PreparationFootnote:SetText(prepText)
            page.PreparationFootnote:Show()

            yOffset = yOffset - Layout.ROW_HEIGHT

        elseif page.PreparationFootnote then
            page.PreparationFootnote:Hide()
        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Last 7 Days
        -----------------------------------------------------------------------

        local last7Stats = {}

        if last7.runsCompleted ~= 0 then

            last7Stats =
            {
                { label = "Progress.StatRunsCompleted", value = ValueWithTrend(tostring(last7.runsCompleted), trends7 and trends7.runs) },
                { label = "Progress.StatRatingGain", value = ValueWithTrend(string.format("%.1f", last7.ratingGained), trends7 and trends7.ratingGain) },
                { label = "Progress.StatAverageKey", value = ValueWithTrend(string.format("%.1f", last7.averageKeyLevel), trends7 and trends7.keyLevel) },
                { label = "Progress.StatDeaths", value = ValueWithTrend(string.format("%.1f", last7.averageDeaths), trends7 and trends7.deaths) },
                { label = "Progress.StatTimedPercent", value = ValueWithTrend(AC.Presentation.FormatPercent(last7.successRate), trends7 and trends7.timedRate) },
                { label = "Progress.StatInterrupts", value = ValueWithTrend(tostring(last7.totalInterrupts), trends7 and trends7.interrupts) },
                { label = "Progress.StatConsumables", value = ValueWithTrend(tostring(last7.totalConsumables), trends7 and trends7.consumables) },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "Last7Days", "Progress.SectionLast7Days", yOffset, last7Stats, "Progress.NoRecentData")

        -----------------------------------------------------------------------
        -- Last 30 Days
        -----------------------------------------------------------------------

        local last30Stats = {}

        if last30.runsCompleted ~= 0 then

            last30Stats =
            {
                { label = "Progress.StatRunsCompleted", value = ValueWithTrend(tostring(last30.runsCompleted), trends30 and trends30.runs) },
                { label = "Progress.StatRatingGain", value = ValueWithTrend(string.format("%.1f", last30.ratingGained), trends30 and trends30.ratingGain) },
                { label = "Progress.StatAverageKey", value = ValueWithTrend(string.format("%.1f", last30.averageKeyLevel), trends30 and trends30.keyLevel) },
                { label = "Progress.StatDeaths", value = ValueWithTrend(string.format("%.1f", last30.averageDeaths), trends30 and trends30.deaths) },
                { label = "Progress.StatTimedPercent", value = ValueWithTrend(AC.Presentation.FormatPercent(last30.successRate), trends30 and trends30.timedRate) },
                { label = "Progress.StatInterrupts", value = ValueWithTrend(tostring(last30.totalInterrupts), trends30 and trends30.interrupts) },
                { label = "Progress.StatConsumables", value = ValueWithTrend(tostring(last30.totalConsumables), trends30 and trends30.consumables) },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "Last30Days", "Progress.SectionLast30Days", yOffset, last30Stats, "Progress.NoRecentData")

        -----------------------------------------------------------------------
        -- Lifetime
        -----------------------------------------------------------------------

        local lifetimeStats = {}

        if lifetime.runsCompleted ~= 0 then

            lifetimeStats =
            {
                { label = "Progress.StatHighestKey", value = tostring(lifetime.highestCompletedLevel or 0) },
                { label = "Progress.StatLargestRatingGain", value = string.format("%.1f", lifetime.largestRatingGain or 0) },
                { label = "Progress.StatBestDungeon", value = lifetime.mostRunDungeon or AC.L:Get("Common.Unknown") },
                { label = "Progress.StatStrongestDungeon", value = FormatDungeonWithRate(lifetime.strongestDungeon, lifetime.strongestDungeonRate) },
                { label = "Progress.StatTotalRuns", value = tostring(lifetime.runsCompleted or 0) },
                { label = "Progress.StatTotalTimedRuns", value = tostring(lifetime.timedRuns or 0) },
                { label = "Progress.StatTotalDeaths", value = tostring(lifetime.totalDeaths or 0) },
                { label = "Progress.StatTotalConsumables", value = tostring(lifetime.totalConsumables or 0) },
                { label = "Progress.StatTotalInterrupts", value = tostring(lifetime.totalInterrupts or 0) },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "Lifetime", "Progress.SectionLifetime", yOffset, lifetimeStats, "Progress.NoLifetimeData")

        -----------------------------------------------------------------------
        -- Personal Records
        -----------------------------------------------------------------------

        local recordsStats = {}

        if lifetime.runsCompleted ~= 0 then

            local fastestText = AC.L:Get("Common.Unknown")

            if lifetime.fastestRun then
                fastestText = AC.L:Format("Progress.FastestCompletionFormat", lifetime.fastestRun.dungeonName or AC.L:Get("Common.Unknown"), lifetime.fastestRun.level or 0, Format.FormatClock(lifetime.fastestRun.time))
            end

            recordsStats =
            {
                { label = "Progress.StatHighestKey", value = tostring(lifetime.highestCompletedLevel or 0) },
                { label = "Progress.StatFastestCompletion", value = fastestText },
                { label = "Progress.StatLargestRatingGain", value = string.format("%.1f", lifetime.largestRatingGain or 0) },
                { label = "Progress.StatLongestWinStreak", value = tostring(lifetime.longestWinStreak or 0) },
                { label = "Progress.StatMostSuccessfulDungeon", value = FormatDungeonWithRate(lifetime.strongestDungeon, lifetime.strongestDungeonRate) },
                { label = "Progress.StatFewestDeaths", value = lifetime.minDeaths and tostring(lifetime.minDeaths) or AC.L:Get("Common.Unknown") },
                { label = "Progress.StatBestTimedPercent", value = AC.Presentation.FormatPercent(lifetime.successRate) },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "PersonalRecords", "Progress.SectionPersonalRecords", yOffset, recordsStats, "Progress.NoPersonalRecords")

        -----------------------------------------------------------------------
        -- Recent Milestones
        -----------------------------------------------------------------------

        yOffset = self:AppendTextSection(page, "RecentMilestones", "Progress.SectionRecentMilestones", yOffset, recentMilestones, "Progress.NoRecentMilestones", function(milestone)
            return AC.L:Format("Progress.MilestoneLineFormat", AC.Presentation.FormatDate(milestone.achievedAt, "short"), AC.L:Get(milestone.titleKey), AC.L:Get(milestone.descriptionKey))
        end)

        -----------------------------------------------------------------------
        -- Current Trends
        -----------------------------------------------------------------------

        yOffset = self:AppendTextSection(page, "CurrentTrends", "Progress.SectionCurrentTrends", yOffset, trendLines, "Progress.NoTrendsAvailable", function(metric)
            return Format.GetTrendArrow(metric.direction) .. " " .. AC.L:Get(metric.label)
        end)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
