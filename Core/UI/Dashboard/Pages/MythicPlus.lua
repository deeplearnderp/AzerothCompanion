-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: MythicPlus (the flagship page)
--
-- The only place the Dashboard reads Mythic+ data. Everything here comes
-- from MythicPlusModule's public API (GetProfile/GetBestOverallLevel/
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

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("MythicPlus")

    -- Detail lines for an expanded Recent Runs row -- only fields
    -- Blizzard's GetCompletionInfo()/this module's own live state
    -- actually captured at record time (see MythicPlusModule:
    -- RecordCompletedRun). "Party" and "Loot" are not collected anywhere
    -- in this addon and are omitted rather than fabricated.
    local function BuildRunDetailLines(record)

        local data = record.Data or {}
        local lines = {}

        table.insert(lines, AC.L:Format("MythicPlus.RunDetailLevel", data.level or 0))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailTime", Format.FormatClock(data.time or 0)))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailDeaths", data.deathCount or 0))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailStarted", AC.Presentation.FormatDate(record.Started or record.Timestamp, "shortTime")))
        table.insert(lines, AC.L:Format("MythicPlus.RunDetailFinished", AC.Presentation.FormatDate(record.Ended or record.Timestamp, "shortTime")))

        local scoreChange = data.scoreChange or 0
        local sign = scoreChange >= 0 and "+" or ""

        table.insert(lines, AC.L:Format("MythicPlus.RunDetailRatingChange", sign .. string.format("%.1f", scoreChange)))

        if data.affixIDs and #data.affixIDs > 0 then

            local affixNames = {}

            for _, affixID in ipairs(data.affixIDs) do

                local affixInfo = mythicPlusModule.GetAffixDisplayInfo and mythicPlusModule:GetAffixDisplayInfo(affixID)

                -- Falls back to the raw ID only if Blizzard's own
                -- GetAffixInfo couldn't resolve it -- never a guessed name.
                table.insert(affixNames, (affixInfo and affixInfo.name) or tostring(affixID))

            end

            table.insert(lines, AC.L:Format("MythicPlus.RunDetailAffixes", table.concat(affixNames, ", ")))

        end

        return lines

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
            bigValue = "+" .. tostring(profile.activeRun.keystoneLevel or 0)
            caption = AC.L:Get("MythicPlus.HeroRunInProgress")

        elseif profile.hasKeystone then

            headline = (profile.currentDungeonName ~= "" and profile.currentDungeonName) or ("#" .. tostring(profile.currentDungeonID or 0))
            bigValue = "+" .. tostring(profile.currentLevel or 0)
            caption = AC.L:Get("MythicPlus.HeroCurrentKeystone")

        else

            headline = AC.L:Get("MythicPlus.HeroNoKeystone")
            bigValue = ""
            caption = ""

        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, headline, bigValue, caption)

        yOffset = heroEndOffset

        -----------------------------------------------------------------------
        -- Recent Runs Chart (v1.0 Polish Sprint)
        --
        -- A visual timeline of the same records the Recent Runs table
        -- below already lists -- oldest to newest, bar height = key
        -- level, color = timed/failed. Skipped entirely when there's
        -- nothing recorded yet rather than showing an empty chart.
        -----------------------------------------------------------------------

        if #recentRuns > 0 then
            yOffset = self:LayoutRunLevelChart(page, "RunLevelChart", scrollChild, yOffset, width, recentRuns)
        end

        -----------------------------------------------------------------------
        -- Key Statistics
        -----------------------------------------------------------------------

        local bestLevel = (mythicPlusModule.GetBestOverallLevel and mythicPlusModule:GetBestOverallLevel()) or 0
        local bestTimed = seasonStats.highestTimedLevel or 0

        local keyStats =
        {
            { label = "MythicPlus.StatRating", value = AC.Presentation.FormatRating(profile.rating) },
            { label = "MythicPlus.StatSeason", value = tostring(profile.currentSeason or 0) },
            { label = "MythicPlus.StatBestTimed", value = bestTimed > 0 and tostring(bestTimed) or AC.L:Get("Common.Unknown") },
            { label = "MythicPlus.StatBestCompleted", value = bestLevel > 0 and tostring(bestLevel) or AC.L:Get("Common.Unknown") },
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

            yOffset = self:LayoutHistoryRows(page, "RecentRuns", scrollChild, yOffset, width, recentRuns, BuildRunDetailLines, function(recordID)

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

        yOffset = self:BeginSection(scrollChild, "MythicPlus.SectionSeasonStatistics", yOffset)

        if seasonStats.runsCompleted == 0 then

            yOffset = ShowEmptyLine("StatsEmptyText", yOffset, width, "MythicPlus.NoSeasonStatistics")

        else

            if page.StatsEmptyText then
                page.StatsEmptyText:Hide()
            end

            local fastestText = AC.L:Get("Common.Unknown")

            if seasonStats.fastestRun then
                fastestText = AC.L:Format("MythicPlus.FastestRunFormat", seasonStats.fastestRun.dungeonName or AC.L:Get("Common.Unknown"), seasonStats.fastestRun.level or 0, Format.FormatClock(seasonStats.fastestRun.time))
            end

            local seasonGridStats =
            {
                { label = "MythicPlus.StatRunsCompleted", value = tostring(seasonStats.runsCompleted) },
                { label = "MythicPlus.StatTimedRuns", value = tostring(seasonStats.timedRuns) },
                { label = "MythicPlus.StatFailedRuns", value = tostring(seasonStats.failedRuns) },
                { label = "MythicPlus.StatSuccessRate", value = AC.Presentation.FormatPercent(seasonStats.successRate) },
                { label = "MythicPlus.StatAverageKeyLevel", value = string.format("%.1f", seasonStats.averageKeyLevel) },
                { label = "MythicPlus.StatRatingGained", value = string.format("%.1f", seasonStats.ratingGained) },
                { label = "MythicPlus.StatFastestRun", value = fastestText },
            }

            yOffset = self:LayoutStatisticsGrid(page, "SeasonStats", scrollChild, yOffset, width, seasonGridStats)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Performance Trends
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "MythicPlus.SectionPerformanceTrends", yOffset)

        if seasonStats.runsCompleted == 0 then

            yOffset = ShowEmptyLine("TrendsEmptyText", yOffset, width, "MythicPlus.NoPerformanceTrends")

        else

            if page.TrendsEmptyText then
                page.TrendsEmptyText:Hide()
            end

            local trendGridStats =
            {
                { label = "MythicPlus.StatAverageDeaths", value = string.format("%.1f", seasonStats.averageDeaths) },
                { label = "MythicPlus.StatAverageCompletionTime", value = Format.FormatClock(seasonStats.averageCompletionTime) },
            }

            yOffset = self:LayoutStatisticsGrid(page, "PerformanceTrends", scrollChild, yOffset, width, trendGridStats)

        end

        yOffset = self:EndSection(yOffset)

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
                { label = "MythicPlus.ConsumablePotion", value = tostring(totals.potion or 0) },
                { label = "MythicPlus.ConsumableFlask", value = tostring(totals.flask or 0) },
                { label = "MythicPlus.ConsumableFood", value = tostring(totals.food or 0) },
                { label = "MythicPlus.ConsumableHealthstone", value = tostring(totals.healthstone or 0) },
                { label = "MythicPlus.ConsumableItemEnhancement", value = tostring(totals.itemEnhancement or 0) },
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
