-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Dungeons
--
-- Goal-oriented presentation for general dungeon participation. It composes
-- authoritative facts from existing gameplay owners without adopting their
-- logic: DelvesModule supplies Delve state/statistics, MythicPlusModule may
-- supply current-run context only, and ActivityHistoryService supplies the
-- chronological record stream.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local ActivityPresentation = AC.DashboardActivityPresentation

local function IsGeneralDungeonActivity(record)

    if record.Module == "Delves" then
        return true
    end

    return record.ActivityType == "Dungeon" and record.Module ~= "MythicPlus"

end

function Dashboard:GetRecentDungeonActivities(count)

    local records = {}
    local history = AC.ActivityHistoryService

    if not history then
        return records
    end

    for _, record in ipairs(history:GetRecent(history:Count())) do

        if IsGeneralDungeonActivity(record) then

            table.insert(records, record)

            if #records >= count then
                break
            end

        end

    end

    return records

end


local function FormatActiveDelve(activeDelve)

    if not activeDelve then
        return AC.L:Get("Dungeons.NoActiveDelve")
    end

    local name = activeDelve.name ~= "" and activeDelve.name or AC.L:Get("Common.Unknown")

    if activeDelve.tier then
        return AC.L:Format("Dungeons.DelveTierFormat", name, activeDelve.tier)
    end

    return name

end

local function FormatDungeonRecord(record)

    if not record then
        return AC.L:Get("Common.Unknown")
    end

    local name = record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown")

    if record.Difficulty and record.Difficulty ~= "" then
        return AC.L:Format("Dungeons.DungeonDifficultyFormat", name, record.Difficulty)
    end

    return name

end

function Dashboard:UpdateDungeonsPage(frame)

    local page = frame.Pages and frame.Pages.Dungeons

    if not page then
        return
    end

    local delvesModule = AC.Core and AC.Core:GetModule("Delves")
    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local mythicPlusProfile = mythicPlusModule and mythicPlusModule:GetProfile()
    local activeDelve = delvesModule and delvesModule.GetActiveDelveInfo and delvesModule:GetActiveDelveInfo()
    local trackedStatistics = delvesModule and delvesModule.GetTrackedStatistics and delvesModule:GetTrackedStatistics() or { completionCount = 0 }
    local recentDelves = delvesModule and delvesModule.GetRecentDelves and delvesModule:GetRecentDelves(10) or {}
    local recentActivity = self:GetRecentDungeonActivities(10)
    local currentDungeonName
    local currentDungeonLevel
    local recentDungeon

    if mythicPlusProfile and mythicPlusProfile.activeRun then
        currentDungeonName = mythicPlusProfile.currentDungeonName ~= "" and mythicPlusProfile.currentDungeonName or AC.L:Get("Common.Unknown")
        currentDungeonLevel = mythicPlusProfile.activeRun.keystoneLevel or 0
    end

    for _, record in ipairs(recentActivity) do

        if record.ActivityType == "Dungeon" and record.Module ~= "MythicPlus" then
            recentDungeon = record
            break
        end

    end

    local scrollChild = page.ScrollChild

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4
        local headline
        local bigValue
        local caption

        if currentDungeonName then
            headline = currentDungeonName
            bigValue = currentDungeonLevel > 0 and ("+" .. tostring(currentDungeonLevel)) or ""
            caption = AC.L:Get("Dungeons.HeroCurrentDungeon")
        elseif activeDelve then
            headline = activeDelve.name ~= "" and activeDelve.name or AC.L:Get("Common.Unknown")
            bigValue = activeDelve.tier and tostring(activeDelve.tier) or ""
            caption = activeDelve.tier and AC.L:Get("Dungeons.HeroActiveDelveTier") or AC.L:Get("Dungeons.HeroActiveDelve")
        else
            headline = AC.L:Get("Dungeons.HeroNoActiveDungeon")
            bigValue = ""
            caption = ""
        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, headline, bigValue, caption)
        local heroStats = {}

        if currentDungeonName or not activeDelve then
            table.insert(heroStats, { label = "Dungeons.StatActiveDelve", value = FormatActiveDelve(activeDelve) })
        end

        table.insert(heroStats, { label = "Dungeons.StatRecentDungeon", value = FormatDungeonRecord(recentDungeon) })
        table.insert(heroStats, { label = "Dungeons.StatWeeklyProgress", value = AC.L:Get("Dungeons.WeeklyProgressUnavailable") })

        yOffset = self:LayoutStatisticsGrid(page, "DungeonHeroStats", scrollChild, heroEndOffset, width, heroStats)

        yOffset = self:AppendTextSection(page, "RecentDungeonActivity", "Dungeons.SectionRecentActivity", yOffset, recentActivity, "Dungeons.NoRecentActivity", function(record)
            return ActivityPresentation:FormatLine(record)
        end)

        yOffset = self:AppendStatisticsSection(page, "DungeonDelveStats", "Dungeons.SectionDelves", yOffset,
        {
            { label = "Dungeons.StatTrackedCompletions", value = tostring(trackedStatistics.completionCount or 0) },
            { label = "Dungeons.StatHighestTrackedTier", value = trackedStatistics.highestTier and tostring(trackedStatistics.highestTier) or AC.L:Get("Common.Unknown") },
        })

        yOffset = self:AppendTextSection(page, "RecentDelves", "Delves.SectionRecentDelves", yOffset, recentDelves, "Delves.NoDelvesRecorded", function(record)
            return ActivityPresentation:FormatLine(record)
        end)

        yOffset = self:BeginSection(scrollChild, "Dungeons.SectionOverview", yOffset)
        yOffset = self:ShowEmptyLine(page, scrollChild, "DungeonOverviewEmptyText", yOffset, width, "Dungeons.OverviewUnavailable")
        yOffset = self:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
