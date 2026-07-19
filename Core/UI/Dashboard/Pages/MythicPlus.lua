-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: MythicPlus (the flagship page)
--
-- The competitive Mythic+ page. Everything here
-- comes from MythicPlusModule's public API (GetProfile/GetBestOverallLevel/
-- GetRecentRuns/GetSeasonStatistics) plus RecommendationEngine/
-- InsightEngine filtered to the "MythicPlus" category. Unlike the static
-- pages, this page is rebuilt fresh on every show/refresh rather than
-- built once at Create() -- almost everything on it (owned keystone
-- state, run history, season stats, recommendations, insights) is
-- inherently dynamic, so there is no fixed schema to build once. The
-- measure-at-full-width-then-narrow-if-needed shape mirrors
-- Dashboard:BuildDataPageContent, just applied to this page's own
-- bespoke layout.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat

function Dashboard:UpdateMythicPlusPage(frame)

    local page = frame.Pages and frame.Pages.MythicPlus

    if not page then
        return
    end

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local profile = mythicPlusModule and mythicPlusModule:GetProfile()

    if not profile then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    local recentRuns = mythicPlusModule:GetRecentRuns(10)
    local seasonStats = mythicPlusModule:GetSeasonStatistics()
    local bestLevel = (mythicPlusModule.GetBestOverallLevel and mythicPlusModule:GetBestOverallLevel()) or 0

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("MythicPlus")

    -- Detail lines for an expanded Recent Runs row -- only fields
    -- Blizzard's GetChallengeCompletionInfo()/this module's own live state
    -- actually captured at record time (see MythicPlusModule:
    -- RecordCompletedRun). "Party" and "Loot" are not collected anywhere
    -- in this addon and are omitted rather than fabricated.
    local function BuildRunDetailLines(record)

        local data = record.Data or {}
        local lines = {}

        table.insert(lines, AC.L:Format("MythicPlus.RunDetailOutcome", AC.L:Get(record.Success and "Common.Timed" or "MythicPlus.OutcomeNotTimed")))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailTime", Format.FormatClock(data.time or 0)))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailDeaths", tonumber(data.deathCount) or 0))
        table.insert(lines, AC.L:Format(
            "MythicPlus.RunDetailRatingChange",
            AC.Presentation.FormatSignedNumberCompact(data.scoreChange, 1, true)))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailStarted", AC.Presentation.FormatDate(record.Started or record.Timestamp, "shortTime12")))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailFinished", AC.Presentation.FormatDate(record.Ended or record.Timestamp, "shortTime12")))

        return lines

    end

    local function BuildRunSummaryIcons(record)

        local icons = {}
        local data = record.Data or {}

        for _, affixEntry in ipairs(data.affixIDs or {}) do

            local affixInfo = mythicPlusModule.GetAffixDisplayInfo and mythicPlusModule:GetAffixDisplayInfo(affixEntry)

            if affixInfo then
                table.insert(icons,
                {
                    icon = affixInfo.icon,
                    tooltipTitle = affixInfo.name,
                    tooltipText = affixInfo.description,
                })
            end

        end

        return icons

    end

    -- Delegates to the shared Dashboard:ShowEmptyLine.
    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Hero
        -----------------------------------------------------------------------

        local headline, bigValue, caption

        if profile.activeRun then

            headline = (profile.currentDungeonName ~= "" and profile.currentDungeonName) or AC.L:Get("Common.Unknown")
            bigValue = "+" .. AC.Presentation.FormatNumber(profile.activeRun.keystoneLevel, 0)
            caption = AC.L:Get("MythicPlus.HeroRunInProgress")

        elseif profile.hasKeystone then

            headline = (profile.currentDungeonName ~= "" and profile.currentDungeonName) or ("#" .. tostring(profile.currentDungeonID or 0))
            bigValue = "+" .. AC.Presentation.FormatNumber(profile.currentLevel, 0)
            caption = AC.L:Get("MythicPlus.HeroCurrentKeystone")

        else

            headline = AC.L:Get("MythicPlus.HeroNoKeystone")
            bigValue = ""
            caption = ""

        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, headline, bigValue, caption)

        yOffset = heroEndOffset

        -----------------------------------------------------------------------
        -- Key Statistics
        -----------------------------------------------------------------------

        local bestTimed = seasonStats.highestTimedLevel or 0

        local keyStats =
        {
            { label = "MythicPlus.StatRating", value = AC.Presentation.FormatRating(profile.rating) },
            { label = "MythicPlus.StatSeason", value = AC.Presentation.FormatNumber(profile.currentSeason, 0) },
            { label = "MythicPlus.StatBestTimed", value = bestTimed > 0 and AC.Presentation.FormatNumber(bestTimed, 0) or AC.L:Get("Common.Unknown") },
            { label = "MythicPlus.StatBestCompleted", value = bestLevel > 0 and AC.Presentation.FormatNumber(bestLevel, 0) or AC.L:Get("Common.Unknown") },
        }

        yOffset = self:LayoutStatisticsGrid(page, "KeyStats", scrollChild, yOffset, width, keyStats)

        -----------------------------------------------------------------------
        -- Recent Runs
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "MythicPlus.SectionRecentRuns", yOffset)

        if #recentRuns == 0 then

            yOffset = ShowEmptyLine("RunsEmptyText", yOffset, width, "MythicPlus.NoRunsRecorded")

        else

            if page.RunsEmptyText then
                page.RunsEmptyText:Hide()
            end

            yOffset = self:LayoutHistoryRows(page, "RecentRuns", scrollChild, yOffset, width, recentRuns, BuildRunDetailLines, BuildRunSummaryIcons, function(recordID)

                if page.ExpandedRunID == recordID then
                    page.ExpandedRunID = nil
                else
                    page.ExpandedRunID = recordID
                end

                Dashboard:UpdateMythicPlusPage(frame)

            end)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Season Statistics
        --
        -- Includes Fastest Run, folded in from the former standalone
        -- "Personal Bests" section (Product Polish Phase 1). That
        -- section's other two fields -- Highest Timed/Completed -- were
        -- an exact duplicate (same label, same seasonStats value) of a
        -- row this same grid already rendered, so they were dropped
        -- rather than merged; nothing here changed what those two rows
        -- show. Key Statistics' own Best Timed/Best Completed (above,
        -- unconditional) are a separate case -- Best Completed reads
        -- Blizzard's live GetBestOverallLevel(), not this addon-recorded
        -- seasonStats, so it was left untouched rather than assumed
        -- identical. See docs/GameplayModuleArchitecture.md Rule 16.
        -----------------------------------------------------------------------

        local seasonGridStats = {}

        if seasonStats.runsCompleted ~= 0 then

            local fastestText = AC.L:Get("Common.Unknown")
            local ratingChange = tonumber(seasonStats.ratingGained) or 0
            local ratingChangeText = ratingChange == 0
                and AC.L:Get("MythicPlus.RatingNoChange")
                or AC.Presentation.FormatSignedNumberCompact(ratingChange, 1, false)

            if seasonStats.fastestRun then
                fastestText = AC.L:Format(
                    "MythicPlus.FastestRunFormat",
                    seasonStats.fastestRun.dungeonName or AC.L:Get("Common.Unknown"),
                    seasonStats.fastestRun.level or 0,
                    Format.BULLET,
                    Format.FormatClock(seasonStats.fastestRun.time))
            end

            seasonGridStats =
            {
                { label = "MythicPlus.StatRunsCompleted", value = AC.Presentation.FormatNumber(seasonStats.runsCompleted, 0) },
                { label = "MythicPlus.StatTimedRuns", value = AC.Presentation.FormatNumber(seasonStats.timedRuns, 0) },
                { label = "MythicPlus.StatFailedRuns", value = AC.Presentation.FormatNumber(seasonStats.failedRuns, 0) },
                { label = "MythicPlus.StatSuccessRate", value = AC.Presentation.FormatPercentCompact(seasonStats.successRate, 1) },
                { label = "MythicPlus.StatAverageKeyLevel", value = AC.Presentation.FormatNumberCompact(seasonStats.averageKeyLevel, 1) },
                { label = "MythicPlus.StatRatingChange", value = ratingChangeText },
                { label = "MythicPlus.StatFastestRun", value = fastestText },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "SeasonStats", "MythicPlus.SectionSeasonStatistics", yOffset, seasonGridStats, "MythicPlus.NoSeasonStatistics")

        -----------------------------------------------------------------------
        -- Performance Trends
        -----------------------------------------------------------------------

        local trendGridStats = {}

        if seasonStats.runsCompleted ~= 0 then

            trendGridStats =
            {
                { label = "MythicPlus.StatAverageDeaths", value = AC.Presentation.FormatNumberCompact(seasonStats.averageDeaths, 1) },
                { label = "MythicPlus.StatAverageCompletionTime", value = Format.FormatClock(seasonStats.averageCompletionTime) },
            }

        end

        yOffset = self:AppendStatisticsSection(page, "PerformanceTrends", "MythicPlus.SectionPerformanceTrends", yOffset, trendGridStats, "MythicPlus.NoPerformanceTrends")

        -----------------------------------------------------------------------
        -- Consumables
        --
        -- Only counts runs that actually tracked consumables
        -- (recordVersion 2+ -- see MythicPlusModule:GetSeasonStatistics).
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "MythicPlus.SectionConsumables", yOffset)

        if seasonStats.trackedRunCount == 0 then

            if page.ConsumablesFootnote then
                page.ConsumablesFootnote:Hide()
            end

            yOffset = ShowEmptyLine("ConsumablesEmptyText", yOffset, width, "MythicPlus.NoConsumableData")

        else

            if page.ConsumablesEmptyText then
                page.ConsumablesEmptyText:Hide()
            end

            local totals = seasonStats.consumableTotals

            local consumableGridStats =
            {
                { label = "MythicPlus.ConsumablePotion", value = AC.Presentation.FormatNumber(totals.potion, 0) },
                { label = "MythicPlus.ConsumableFlask", value = AC.Presentation.FormatNumber(totals.flask, 0) },
                { label = "MythicPlus.ConsumableFood", value = AC.Presentation.FormatNumber(totals.food, 0) },
                { label = "MythicPlus.ConsumableHealthstone", value = AC.Presentation.FormatNumber(totals.healthstone, 0) },
                { label = "MythicPlus.ConsumableItemEnhancement", value = AC.Presentation.FormatNumber(totals.itemEnhancement, 0) },
            }

            yOffset = self:LayoutStatisticsGrid(page, "Consumables", scrollChild, yOffset, width, consumableGridStats)

            if not page.ConsumablesFootnote then

                local footnote = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                footnote:SetJustifyH("LEFT")

                page.ConsumablesFootnote = footnote

            end

            page.ConsumablesFootnote:ClearAllPoints()
            page.ConsumablesFootnote:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
            page.ConsumablesFootnote:SetWidth(width - Layout.ROW_INDENT)
            page.ConsumablesFootnote:SetText(AC.L:Format("MythicPlus.ConsumablesTrackedFormat", seasonStats.trackedRunCount))
            page.ConsumablesFootnote:Show()

            yOffset = yOffset - Layout.ROW_HEIGHT

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Recommendations
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Recommendations", "MythicPlus.SectionRecommendations", yOffset, recommendations, "MythicPlus.NoRecommendations", true)

        -----------------------------------------------------------------------
        -- Insights
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Insights", "MythicPlus.SectionInsights", yOffset, insights, "MythicPlus.NoInsights")

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
