-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Activity Log
--
-- Long-term chronological presentation of ActivityHistoryService's canonical
-- record stream. This page owns only filtering, sorting, grouping, and layout;
-- persistence and gameplay payloads remain with their existing owners.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local ActivityPresentation = AC.DashboardActivityPresentation

local date = date

local TOOLBAR_HEIGHT = 42
local DROPDOWN_HEIGHT = 22
local CONTROL_LABEL_GAP = 4

local FILTER_OPTIONS =
{
    { value = "All", label = "ActivityLog.FilterAll" },
    { value = "MythicPlus", label = "ActivityLog.FilterMythicPlus" },
    { value = "Delves", label = "ActivityLog.FilterDelves" },
    { value = "Heroic", label = "ActivityLog.FilterHeroic" },
    { value = "Mythic0", label = "ActivityLog.FilterMythic0" },
    { value = "Achievements", label = "ActivityLog.FilterAchievements" },
    { value = "Other", label = "ActivityLog.FilterOther" },
}

local SORT_OPTIONS =
{
    { value = "Newest", label = "ActivityLog.SortNewest" },
    { value = "Oldest", label = "ActivityLog.SortOldest" },
}

local MYTHIC_ZERO_DIFFICULTIES =
{
    ["Mythic"] = true,
    ["Mythic 0"] = true,
    ["Mythic0"] = true,
}

local function GetFilterCategory(record)

    if record.Module == "MythicPlus" or record.Difficulty == "Mythic+" then
        return "MythicPlus"
    end

    if record.Module == "Delves" or record.ActivityType == "Delve" then
        return "Delves"
    end

    if record.Module == "Achievements" or record.ActivityType == "Achievement" then
        return "Achievements"
    end

    if record.ActivityType == "Dungeon" and record.Difficulty == "Heroic" then
        return "Heroic"
    end

    if record.ActivityType == "Dungeon" and MYTHIC_ZERO_DIFFICULTIES[record.Difficulty] then
        return "Mythic0"
    end

    return "Other"

end

local function GetOptionLabel(options, selectedValue)

    for _, option in ipairs(options) do

        if option.value == selectedValue then
            return AC.L:Get(option.label)
        end

    end

    return AC.L:Get(options[1].label)

end

local function GetAllActivities()

    local history = AC.ActivityHistoryService

    if not history then
        return {}
    end

    return history:GetRecent(history:Count())

end

local function BuildSummary(records)

    local activityTypes = {}
    local characters = {}
    local oldestTimestamp
    local newestTimestamp

    for _, record in ipairs(records) do

        local activityType = record.ActivityType or "Unknown"
        activityTypes[activityType] = true

        if record.Character and record.Character ~= "" then
            local characterKey = record.Character .. "-" .. (record.Realm or "")
            characters[characterKey] = true
        end

        local timestamp = tonumber(record.Timestamp)

        if timestamp and timestamp > 0 then
            oldestTimestamp = not oldestTimestamp and timestamp or math.min(oldestTimestamp, timestamp)
            newestTimestamp = not newestTimestamp and timestamp or math.max(newestTimestamp, timestamp)
        end

    end

    local typeCount = 0

    for _ in pairs(activityTypes) do
        typeCount = typeCount + 1
    end

    local characterCount = 0

    for _ in pairs(characters) do
        characterCount = characterCount + 1
    end

    return
    {
        total = #records,
        oldestTimestamp = oldestTimestamp,
        newestTimestamp = newestTimestamp,
        typeCount = typeCount,
        characterCount = characterCount,
    }

end

local function FilterAndSortActivities(records, selectedFilter, selectedSort)

    local filtered = {}

    for _, record in ipairs(records) do

        if selectedFilter == "All" or GetFilterCategory(record) == selectedFilter then
            table.insert(filtered, record)
        end

    end

    local newestFirst = selectedSort ~= "Oldest"

    table.sort(filtered, function(a, b)

        local aTimestamp = tonumber(a.Timestamp) or 0
        local bTimestamp = tonumber(b.Timestamp) or 0

        if aTimestamp == bTimestamp then

            if newestFirst then
                return tostring(a.ID or "") > tostring(b.ID or "")
            end

            return tostring(a.ID or "") < tostring(b.ID or "")

        end

        if newestFirst then
            return aTimestamp > bTimestamp
        end

        return aTimestamp < bTimestamp

    end)

    return filtered

end

local function GroupActivitiesByDate(records)

    local groups = {}

    for _, record in ipairs(records) do

        local timestamp = tonumber(record.Timestamp) or 0
        local dateKey
        local label

        if timestamp > 0 then
            dateKey = date("%Y-%m-%d", timestamp)
            label = AC.Presentation.FormatDate(timestamp, "short")
        else
            dateKey = "Unknown"
            label = AC.L:Get("ActivityLog.UnknownDate")
        end

        local group = groups[#groups]

        if not group or group.key ~= dateKey then
            group = { key = dateKey, label = label, records = {} }
            table.insert(groups, group)
        end

        table.insert(group.records, record)

    end

    return groups

end

local function BuildToolbarControl(page, parent, key, labelKey)

    page.ActivityLogControls = page.ActivityLogControls or {}

    local control = page.ActivityLogControls[key]

    if control then
        return control
    end

    local frame = CreateFrame("Frame", nil, parent)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
    label:SetText(AC.L:Get(labelKey))

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -CONTROL_LABEL_GAP)
    dropdown:SetHeight(DROPDOWN_HEIGHT)

    frame.Label = label
    frame.Dropdown = dropdown

    page.ActivityLogControls[key] = frame

    return frame

end

local function ConfigureDropdown(control, options, selectedValue, onSelected)

    control.Dropdown:SetupMenu(function(_, rootDescription)

        for _, option in ipairs(options) do

            local value = option.value
            local label = AC.L:Get(option.label)

            rootDescription:CreateButton(label, function()
                onSelected(value)
            end)

        end

    end)

    control.Dropdown:SetDefaultText(GetOptionLabel(options, selectedValue))

end

local function BuildTimelineRow(parent)

    local row = CreateFrame("Frame", nil, parent)

    local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    timeText:SetJustifyH("LEFT")
    timeText:SetWordWrap(false)

    local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)

    local contextText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    contextText:SetJustifyH("LEFT")
    contextText:SetWordWrap(false)
    contextText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    row.TimeText = timeText
    row.TitleText = titleText
    row.ContextText = contextText

    return row

end

local function LayoutTimelineRows(scrollChild, pool, records, yOffset, contentWidth)

    local textOffset = Layout.ROW_INDENT + Layout.HISTORY_DATE_WIDTH + Layout.HISTORY_COLUMN_GAP
    local textWidth = contentWidth - textOffset

    for index, record in ipairs(records) do

        local row = pool[index]

        if not row then
            row = BuildTimelineRow(scrollChild)
            pool[index] = row
        end

        local model = ActivityPresentation:BuildTimeline(record)

        row:SetSize(contentWidth, Layout.ACTIVITY_TIMELINE_ROW_HEIGHT)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)

        row.TimeText:ClearAllPoints()
        row.TimeText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)
        row.TimeText:SetWidth(Layout.HISTORY_DATE_WIDTH)
        row.TimeText:SetText(model and model.timestampText or "")

        row.TitleText:ClearAllPoints()
        row.TitleText:SetPoint("TOPLEFT", textOffset, 0)
        row.TitleText:SetWidth(textWidth)
        row.TitleText:SetText(model and model.titleText or AC.L:Get("Common.Unknown"))

        row.ContextText:ClearAllPoints()
        row.ContextText:SetPoint("TOPLEFT", row.TitleText, "BOTTOMLEFT", 0, -Layout.STAT_LABEL_GAP)
        row.ContextText:SetWidth(textWidth)
        row.ContextText:SetText(model and model.contextText or "")

        row:Show()

        yOffset = yOffset - Layout.ACTIVITY_TIMELINE_ROW_HEIGHT

    end

    for index = #records + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

local function GetDateHeaderKey(dateKey)
    return "ActivityLog.Date." .. dateKey
end

local function HideStaleDateGroups(page, scrollChild, keepKeys)

    local datePools = page.Pools and page.Pools.ActivityLogDates

    if not datePools then
        return
    end

    for dateKey, pool in pairs(datePools) do

        if not keepKeys[dateKey] then

            for _, row in ipairs(pool) do
                row:Hide()
            end

            if pool.EmptyText then
                pool.EmptyText:Hide()
            end

            local header = scrollChild.SectionHeaders and scrollChild.SectionHeaders[GetDateHeaderKey(dateKey)]

            if header then
                header:Hide()
            end

        end

    end

end

function Dashboard:UpdateActivityLogPage(frame)

    local page = frame.Pages and frame.Pages.ActivityLog

    if not page then
        return
    end

    page.ActivityLogFilter = page.ActivityLogFilter or "All"
    page.ActivityLogSort = page.ActivityLogSort or "Newest"

    local allActivities = GetAllActivities()
    local summary = BuildSummary(allActivities)
    local filteredActivities = FilterAndSortActivities(allActivities, page.ActivityLogFilter, page.ActivityLogSort)
    local dateGroups = GroupActivitiesByDate(filteredActivities)
    local scrollChild = page.ScrollChild

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4
        local heroCaption = summary.total > 0 and AC.L:Get("ActivityLog.HeroCaption") or AC.L:Get("ActivityLog.HeroEmptyCaption")
        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("ActivityLog.HeroHeadline"), tostring(summary.total), heroCaption)
        local heroStats =
        {
            { label = "ActivityLog.StatOldest", value = summary.oldestTimestamp and AC.Presentation.FormatDate(summary.oldestTimestamp, "shortTime") or AC.L:Get("Common.Unknown") },
            { label = "ActivityLog.StatNewest", value = summary.newestTimestamp and AC.Presentation.FormatDate(summary.newestTimestamp, "shortTime") or AC.L:Get("Common.Unknown") },
            { label = "ActivityLog.StatActivityTypes", value = tostring(summary.typeCount) },
            { label = "ActivityLog.StatCharacters", value = summary.characterCount > 0 and tostring(summary.characterCount) or AC.L:Get("Common.Unknown") },
        }

        yOffset = self:LayoutStatisticsGrid(page, "ActivityLogSummary", scrollChild, heroEndOffset, width, heroStats)
        yOffset = self:BeginSection(scrollChild, "ActivityLog.SectionFilters", yOffset)

        local controlWidth = (width - Layout.ROW_INDENT - Layout.STAT_CELL_GAP) / 2
        local filterControl = BuildToolbarControl(page, scrollChild, "ActivityType", "ActivityLog.FilterActivityType")
        local sortControl = BuildToolbarControl(page, scrollChild, "Sort", "ActivityLog.FilterSort")

        filterControl:SetSize(controlWidth, TOOLBAR_HEIGHT)
        filterControl:ClearAllPoints()
        filterControl:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        filterControl.Label:SetWidth(controlWidth)
        filterControl.Dropdown:SetWidth(controlWidth)
        filterControl:Show()

        sortControl:SetSize(controlWidth, TOOLBAR_HEIGHT)
        sortControl:ClearAllPoints()
        sortControl:SetPoint("TOPLEFT", Layout.ROW_INDENT + controlWidth + Layout.STAT_CELL_GAP, yOffset)
        sortControl.Label:SetWidth(controlWidth)
        sortControl.Dropdown:SetWidth(controlWidth)
        sortControl:Show()

        ConfigureDropdown(filterControl, FILTER_OPTIONS, page.ActivityLogFilter, function(value)
            page.ActivityLogFilter = value
            Dashboard:UpdateActivityLogPage(frame)
        end)

        ConfigureDropdown(sortControl, SORT_OPTIONS, page.ActivityLogSort, function(value)
            page.ActivityLogSort = value
            Dashboard:UpdateActivityLogPage(frame)
        end)

        yOffset = self:EndSection(yOffset - TOOLBAR_HEIGHT)

        page.Pools = page.Pools or {}
        page.Pools.ActivityLogDates = page.Pools.ActivityLogDates or {}

        if #filteredActivities == 0 then

            HideStaleDateGroups(page, scrollChild, {})

            yOffset = self:BeginSection(scrollChild, "ActivityLog.SectionTimeline", yOffset)
            yOffset = self:ShowEmptyLine(page, scrollChild, "ActivityLogTimelineEmptyText", yOffset, width, summary.total == 0 and "ActivityLog.NoActivities" or "ActivityLog.NoMatchingActivities")
            yOffset = self:EndSection(yOffset)

        else

            if page.ActivityLogTimelineEmptyText then
                page.ActivityLogTimelineEmptyText:Hide()
            end

            local timelineHeader = scrollChild.SectionHeaders and scrollChild.SectionHeaders["ActivityLog.SectionTimeline"]

            if timelineHeader then
                timelineHeader:Hide()
            end

            local keepKeys = {}

            for _, group in ipairs(dateGroups) do

                keepKeys[group.key] = true

                local pool = page.Pools.ActivityLogDates[group.key]

                if not pool then
                    pool = {}
                    page.Pools.ActivityLogDates[group.key] = pool
                end

                yOffset = self:BeginSection(scrollChild, GetDateHeaderKey(group.key), yOffset, group.label)
                yOffset = LayoutTimelineRows(scrollChild, pool, group.records, yOffset, width)
                yOffset = self:EndSection(yOffset)

            end

            HideStaleDateGroups(page, scrollChild, keepKeys)

        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
