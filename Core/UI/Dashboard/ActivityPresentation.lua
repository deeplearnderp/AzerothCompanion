-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Activity Presentation
--
-- Converts ActivityHistoryService records into a consistent, display-only
-- model. This helper never queries gameplay state or persistence, sorts
-- records, or calculates statistics.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Format = AC.DashboardFormat

local ActivityPresentation = {}

local MODULE_ICONS =
{
    Dungeons = "Interface\\Icons\\achievement_challengemode_bronze",
    MythicPlus = "Interface\\Icons\\achievement_challengemode_gold",
    Delves = "Interface\\Icons\\inv_misc_map_01",
    Achievements = "Interface\\Icons\\achievement_general",
}

local function GetSpecificActivityName(record)

    local name = record.ActivityName

    if type(name) == "string" and name:match("%S") then
        return name
    end

    return nil

end

local function GetActivityNameOrUnknown(record)
    return GetSpecificActivityName(record) or AC.L:Get("Common.Unknown")
end

local function BuildMythicPlusTitle(record)

    local data = record.Data or {}
    local level = data.level or 0
    local name = GetActivityNameOrUnknown(record)

    if record.Success then
        return AC.L:Format("Dashboard.FeedMythicPlusTimedFormat", level, name)
    end

    return AC.L:Format("Dashboard.FeedMythicPlusFailedFormat", level, name)

end

local function BuildDelveTitle(record)

    local data = record.Data or {}
    local tier = tonumber(data.tier)
    local name = GetActivityNameOrUnknown(record)

    if tier and tier > 0 then
        return AC.L:Format("Dashboard.FeedDelveTierFormat", tier, name)
    end

    return AC.L:Format("Dashboard.FeedDelveFormat", name)

end

local function BuildDungeonTitle(record)

    local name = GetActivityNameOrUnknown(record)

    if record.Difficulty and record.Difficulty ~= "" then
        return AC.L:Format("Dungeons.ActivityDungeonDifficultyFormat", name, record.Difficulty)
    end

    return AC.L:Format("Dungeons.ActivityDungeonFormat", name)

end

local function BuildAchievementTitle(record)

    local name = GetActivityNameOrUnknown(record)

    return AC.L:Format("Dashboard.FeedAchievementFormat", name)

end

local function BuildGenericTitle(record)

    return GetActivityNameOrUnknown(record)

end

local function BuildTimelineContext(record, moduleLabel)

    local data = record.Data or {}

    if record.Module == "MythicPlus" then

        local level = tonumber(data.level)

        if level and level > 0 then

            local outcome = record.Success and AC.L:Get("Common.Timed") or AC.L:Get("ActivityLog.ContextNotTimed")

            return AC.L:Format("ActivityLog.ContextMythicPlusFormat", level, Format.BULLET, outcome)

        end

        return AC.L:Get("ActivityLog.ContextMythicPlus")

    elseif record.Module == "Delves" or record.ActivityType == "Delve" then

        if tonumber(data.delveSummaryVersion) then

            local parts = {}
            local tierText = type(data.tierText) == "string" and data.tierText or nil
            local tier = tonumber(data.tier)

            if tierText and tierText:match("%S") then
                table.insert(parts, tierText)
            elseif tier and tier > 0 then
                table.insert(parts, AC.L:Format("ActivityLog.ContextDelveTierSummaryFormat", tier))
            end

            for _, resource in ipairs(data.resources or {}) do

                local resourceParts = {}
                local leadingText = type(resource.leadingText) == "string" and resource.leadingText or nil
                local text = type(resource.text) == "string" and resource.text or nil
                local iconFileID = tonumber(resource.iconFileID)

                if leadingText and leadingText:match("%S") then
                    table.insert(resourceParts, leadingText)
                end

                if iconFileID then
                    table.insert(resourceParts, ("|T%d:14:14:0:0|t"):format(iconFileID))
                end

                if text and text:match("%S") then
                    table.insert(resourceParts, text)
                end

                if #resourceParts > 0 then
                    table.insert(parts, table.concat(resourceParts, " "))
                end

            end

            local durationSeconds = tonumber(data.durationSeconds)

            if durationSeconds and durationSeconds >= 0 then
                table.insert(parts, AC.L:Format("ActivityLog.ContextDelveDurationFormat", AC.Presentation.FormatClock(durationSeconds)))
            end

            return table.concat(parts, " " .. Format.BULLET .. " ")

        end

        local tier = tonumber(data.tier)

        if tier and tier > 0 then
            return AC.L:Format("ActivityLog.ContextDelveTierFormat", tier)
        end

        return AC.L:Get("ActivityLog.ContextDelve")

    elseif record.ActivityType == "Achievement" or record.Module == "Achievements" then
        return AC.L:Get("ActivityLog.ContextAchievement")
    elseif record.ActivityType == "Dungeon" and record.Difficulty == "Heroic" then
        return AC.L:Get("ActivityLog.ContextHeroic")
    elseif record.ActivityType == "Dungeon" and (record.Difficulty == "Mythic" or record.Difficulty == "Mythic 0" or record.Difficulty == "Mythic0") then
        return AC.L:Get("ActivityLog.ContextMythic0")
    elseif record.ActivityType == "Dungeon" and record.Difficulty and record.Difficulty ~= "" then
        return AC.L:Format("ActivityLog.ContextDungeonDifficultyFormat", record.Difficulty)
    elseif record.ActivityType == "Dungeon" then
        return AC.L:Get("ActivityLog.ContextDungeon")
    end

    return moduleLabel

end

function ActivityPresentation:Build(record, timestampStyle)

    if type(record) ~= "table" then
        return nil
    end

    local title
    local moduleLabel

    if record.Module == "MythicPlus" then
        title = BuildMythicPlusTitle(record)
        moduleLabel = AC.L:Get("Dashboard.MythicPlus")
    elseif record.Module == "Delves" then
        title = BuildDelveTitle(record)
        moduleLabel = AC.L:Get("Dashboard.Delves")
    elseif record.ActivityType == "Dungeon" then
        title = BuildDungeonTitle(record)
        moduleLabel = AC.L:Get("Dashboard.Dungeons")
    elseif record.ActivityType == "Achievement" or record.Module == "Achievements" then
        title = BuildAchievementTitle(record)
        moduleLabel = AC.L:Get("Dashboard.Accomplishments")
    else
        title = BuildGenericTitle(record)
        moduleLabel = (record.ActivityType and record.ActivityType ~= "" and record.ActivityType) or AC.L:Get("ActivityLog.FilterOther")
    end

    local timestamp = record.Timestamp or 0
    local timestampText = AC.Presentation.FormatDate(timestamp, timestampStyle or "short")
    local icon = MODULE_ICONS[record.Module] or (record.ActivityType == "Dungeon" and MODULE_ICONS.Dungeons) or "Interface\\Icons\\INV_Misc_QuestionMark"

    return
    {
        title = title,
        subtitle = AC.L:Format("Dashboard.ActivitySubtitleFormat", moduleLabel, timestampText),
        moduleLabel = moduleLabel,
        icon = icon,
        iconMarkup = icon and string.format("|T%s:14:14:0:0|t", icon) or "",
        timestamp = timestamp,
        timestampText = timestampText,
        success = record.Success == true,
    }

end

function ActivityPresentation:BuildTimeline(record)

    local model = self:Build(record, "time")

    if not model then
        return nil
    end

    local status = model.success and Format.CHECK_SUCCESS or Format.CHECK_FAILURE
    local icon = model.iconMarkup ~= "" and (model.iconMarkup .. " ") or ""
    local title = GetSpecificActivityName(record) or model.title

    return
    {
        title = title,
        titleText = AC.L:Format("Dashboard.ActivityTimelineTitleFormat", status, icon, title),
        contextText = BuildTimelineContext(record, model.moduleLabel),
        timestampText = model.timestampText,
    }

end

function ActivityPresentation:FormatLine(record, timestampStyle)

    local model = self:Build(record, timestampStyle)

    if not model then
        return nil
    end

    local status = model.success and Format.CHECK_SUCCESS or Format.CHECK_FAILURE
    local icon = model.iconMarkup ~= "" and (model.iconMarkup .. " ") or ""

    return AC.L:Format("Dashboard.ActivityLineFormat", status, icon, model.title, model.subtitle)

end

AC.DashboardActivityPresentation = ActivityPresentation

return ActivityPresentation
