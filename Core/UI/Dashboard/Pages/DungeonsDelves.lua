-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Dungeons & Delves
--
-- Presentation-only composition of MythicPlusModule, DelvesModule, and the
-- chronological record stream owned by ActivityHistoryService. Gameplay
-- ownership, calculations, and persistence remain in those existing owners.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local ActivityPresentation = AC.DashboardActivityPresentation

function Dashboard:GetRecentInstancedActivities(count)

    local records = {}
    local history = AC.ActivityHistoryService

    if not history then
        return records
    end

    -- GetRecent already returns the service's canonical newest-first order.
    -- Filtering that stream preserves chronology without merging or sorting
    -- independent module histories in the Dashboard.
    for _, record in ipairs(history:GetRecent(history:Count())) do

        if record.Module == "MythicPlus" or record.Module == "Delves" then

            table.insert(records, record)

            if #records >= count then
                break
            end

        end

    end

    return records

end

local function FormatDelveName(record)

    if not record then
        return AC.L:Get("Common.Unknown")
    end

    local name = record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown")
    local tier = tonumber(record.Data and record.Data.tier)

    if tier and tier > 0 then
        return AC.L:Format("DungeonsDelves.DelveTierFormat", name, tier)
    end

    return name

end

local function FormatActiveDelve(activeDelve)

    if not activeDelve then
        return AC.L:Get("DungeonsDelves.NoActiveDelve")
    end

    local name = activeDelve.name ~= "" and activeDelve.name or AC.L:Get("Common.Unknown")

    if activeDelve.tier then
        return AC.L:Format("DungeonsDelves.DelveTierFormat", name, activeDelve.tier)
    end

    return name

end

function Dashboard:UpdateDungeonsDelvesPage(frame)

    local page = frame.Pages and frame.Pages.DungeonsDelves

    if not page then
        return
    end

    local delvesModule = AC.Core and AC.Core:GetModule("Delves")
    local activeDelve = delvesModule and delvesModule.GetActiveDelveInfo and delvesModule:GetActiveDelveInfo()
    local trackedStatistics = delvesModule and delvesModule.GetTrackedStatistics and delvesModule:GetTrackedStatistics() or { completionCount = 0 }
    local recentDelves = delvesModule and delvesModule.GetRecentDelves and delvesModule:GetRecentDelves(10) or {}
    local recentActivity = self:GetRecentInstancedActivities(10)

    local function LayoutHero(context, yOffset, width)

        local profile = context.profile
        local headline
        local bigValue
        local caption

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

        if activeDelve then

            local activeDelveText = AC.L:Format("DungeonsDelves.ActiveDelveFormat", FormatActiveDelve(activeDelve))

            if caption ~= "" then
                caption = AC.L:Format("DungeonsDelves.HeroCaptionFormat", caption, activeDelveText)
            else
                caption = activeDelveText
            end

        end

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, context.scrollChild, yOffset, width, headline, bigValue, caption)
        local recentDelve = recentDelves[1]
        local heroStats =
        {
            { label = "DungeonsDelves.StatHighestKey", value = context.bestLevel > 0 and ("+" .. tostring(context.bestLevel)) or AC.L:Get("Common.Unknown") },
            { label = "DungeonsDelves.StatActiveDelve", value = FormatActiveDelve(activeDelve) },
            { label = "DungeonsDelves.StatHighestTrackedTier", value = trackedStatistics.highestTier and tostring(trackedStatistics.highestTier) or AC.L:Get("Common.Unknown") },
            { label = "DungeonsDelves.StatRecentDelve", value = recentDelve and FormatDelveName(recentDelve) or AC.L:Get("Common.Unknown") },
        }

        return self:LayoutStatisticsGrid(page, "InstancedHeroStats", context.scrollChild, heroEndOffset, width, heroStats)

    end

    local function LayoutBeforeMythicPlus(context, yOffset, width)

        page.Pools = page.Pools or {}
        page.Pools.RecentInstancedActivity = page.Pools.RecentInstancedActivity or {}

        yOffset = self:BeginSection(context.scrollChild, "DungeonsDelves.SectionRecentActivity", yOffset)
        yOffset = self:LayoutTextLines(context.scrollChild, page.Pools.RecentInstancedActivity, recentActivity, yOffset, width, "DungeonsDelves.NoRecentActivity", function(record)
            return ActivityPresentation:FormatLine(record)
        end)
        yOffset = self:EndSection(yOffset)

        return self:BeginSection(context.scrollChild, "DungeonsDelves.SectionMythicPlus", yOffset)

    end

    local function LayoutAfterMythicPlus(context, yOffset, width)

        page.Pools = page.Pools or {}
        page.Pools.TrackedDelves = page.Pools.TrackedDelves or {}

        yOffset = self:EndSection(yOffset)
        yOffset = self:BeginSection(context.scrollChild, "DungeonsDelves.SectionDelves", yOffset)
        yOffset = self:LayoutStatisticsGrid(page, "DelveStats", context.scrollChild, yOffset, width,
        {
            { label = "DungeonsDelves.StatTrackedCompletions", value = tostring(trackedStatistics.completionCount or 0) },
            { label = "DungeonsDelves.StatHighestTrackedTier", value = trackedStatistics.highestTier and tostring(trackedStatistics.highestTier) or AC.L:Get("Common.Unknown") },
        })
        yOffset = self:EndSection(yOffset)

        yOffset = self:BeginSection(context.scrollChild, "Delves.SectionRecentDelves", yOffset)
        yOffset = self:LayoutTextLines(context.scrollChild, page.Pools.TrackedDelves, recentDelves, yOffset, width, "Delves.NoDelvesRecorded", function(record)
            return ActivityPresentation:FormatLine(record)
        end)

        return self:EndSection(yOffset)

    end

    self:RenderMythicPlusPage(frame, page,
    {
        layoutHero = LayoutHero,
        layoutBeforeMythicPlus = LayoutBeforeMythicPlus,
        layoutAfterMythicPlus = LayoutAfterMythicPlus,
        onRefresh = function()
            Dashboard:UpdateDungeonsDelvesPage(frame)
        end,
    })

end

return Dashboard
