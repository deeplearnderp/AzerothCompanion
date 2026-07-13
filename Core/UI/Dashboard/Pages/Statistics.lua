-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Statistics (Companion Intelligence vNext)
--
-- Answers "is the Companion actually useful?" -- every number on this page
-- is aggregated from RecommendationHistoryService's own already-real,
-- already-persisted records (Rule 2: this page computes nothing new, it
-- only sums/groups already-computed per-recommendation counters, the same
-- "presentation-layer aggregation over an already-real list" Progress.lua
-- already does for its own season/lifetime sums). Fully dynamic, same
-- measure-at-full-width-then-narrow-if-needed shape as Progress.lua/
-- MythicPlus.lua.
--
-- Honesty note (see RecommendationHistoryService.lua's own header):
-- "Completed"/"Not Acknowledged" totals here are the same INFERRED
-- signals that service already tracks -- this page does not strengthen or
-- reinterpret that certainty, it only sums it.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat

function Dashboard:UpdateStatisticsPage(frame)

    local page = frame.Pages and frame.Pages.Statistics

    if not page then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    local historyRecords = AC.RecommendationHistoryService and AC.RecommendationHistoryService:GetAllHistory() or {}

    local totalGenerated, totalCompleted, totalDismissed, totalNotAcknowledged = 0, 0, 0, 0
    local totalResolvedDuration = 0
    local categoryTotals = {}
    local hasAnyHistory = false

    for _, record in pairs(historyRecords) do

        hasAnyHistory = true

        totalGenerated = totalGenerated + (record.timesShown or 0)
        totalCompleted = totalCompleted + (record.timesCompleted or 0)
        totalDismissed = totalDismissed + (record.timesDismissed or 0)
        totalNotAcknowledged = totalNotAcknowledged + (record.timesNotAcknowledged or 0)
        totalResolvedDuration = totalResolvedDuration + (record.totalResolvedDurationSeconds or 0)

        local category = record.category or AC.L:Get("Common.Unknown")
        local catTotals = categoryTotals[category]

        if not catTotals then
            catTotals = { generated = 0, completed = 0 }
            categoryTotals[category] = catTotals
        end

        catTotals.generated = catTotals.generated + (record.timesShown or 0)
        catTotals.completed = catTotals.completed + (record.timesCompleted or 0)

    end

    local overallCompletionRate = totalGenerated > 0 and ((totalCompleted / totalGenerated) * 100) or 0
    local averageCompletionTime = totalCompleted > 0 and (totalResolvedDuration / totalCompleted) or 0

    local mostUsefulCategory, mostUsefulCount = nil, 0

    for category, totals in pairs(categoryTotals) do

        if totals.completed > mostUsefulCount then
            mostUsefulCategory, mostUsefulCount = category, totals.completed
        end

    end

    local categoryList = {}

    for category, totals in pairs(categoryTotals) do
        table.insert(categoryList, { category = category, generated = totals.generated, completed = totals.completed })
    end

    table.sort(categoryList, function(a, b)
        return a.completed > b.completed
    end)

    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Hero -- total recommendations generated, with the overall
        -- completion rate as a headline indicator.
        -----------------------------------------------------------------------

        local heroCaption = ""

        if hasAnyHistory then
            heroCaption = AC.L:Format("Statistics.HeroCaptionFormat", string.format("%.0f", overallCompletionRate))
        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("Statistics.HeroHeadline"), tostring(totalGenerated), heroCaption)

        yOffset = heroEndOffset

        -----------------------------------------------------------------------
        -- Overview
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Statistics.SectionOverview", yOffset)

        if not hasAnyHistory then

            yOffset = ShowEmptyLine("OverviewEmptyText", yOffset, width, "Statistics.NoHistoryYet")

        else

            if page.OverviewEmptyText then
                page.OverviewEmptyText:Hide()
            end

            local overviewStats =
            {
                { label = "Statistics.StatTotalGenerated", value = tostring(totalGenerated) },
                { label = "Statistics.StatTotalCompleted", value = tostring(totalCompleted) },
                { label = "Statistics.StatTotalDismissed", value = tostring(totalDismissed) },
                { label = "Statistics.StatTotalNotAcknowledged", value = tostring(totalNotAcknowledged) },
                { label = "Statistics.StatAverageCompletionTime", value = averageCompletionTime > 0 and Format.FormatClock(averageCompletionTime) or AC.L:Get("Common.Unknown") },
                { label = "Statistics.StatMostUsefulCategory", value = mostUsefulCategory or AC.L:Get("Common.Unknown") },
            }

            yOffset = self:LayoutStatisticsGrid(page, "Overview", scrollChild, yOffset, width, overviewStats)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Per-Category Breakdown
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Statistics.SectionCategoryBreakdown", yOffset)

        page.Pools = page.Pools or {}
        page.Pools.CategoryBreakdown = page.Pools.CategoryBreakdown or {}

        yOffset = self:LayoutTextLines(scrollChild, page.Pools.CategoryBreakdown, categoryList, yOffset, width, "Statistics.NoCategoryData", function(entry)
            return AC.L:Format("Statistics.CategoryLineFormat", entry.category, entry.completed, entry.generated)
        end)

        yOffset = self:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
