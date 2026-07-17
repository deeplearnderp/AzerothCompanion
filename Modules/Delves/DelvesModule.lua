-------------------------------------------------------------------------------
-- Azeroth Companion
-- Delves Module
--
-- Owns completed Delve detection and Delve history records. Persistence,
-- indexing, and pruning remain owned by ActivityHistoryService.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time
local tonumber = tonumber

local HasActiveDelve = C_DelvesUI.HasActiveDelve
local GetActiveDelveTier = C_DelvesUI.GetActiveDelveTier
local GetDelveEntranceMapID = C_DelvesUI.GetDelveEntranceMapID
local GetScenarioInfo = C_ScenarioInfo.GetScenarioInfo

local DelvesModule =
{
    Name = "Delves",
}

-- ScenarioInformation.name is the scenario-level label; area is the
-- specific Delve adventure shown to the player (for example, The Sinkhole).
-- Both values come from the same synchronous completion snapshot.
local function GetCompletedDelveName(scenarioInfo)

    if type(scenarioInfo.area) == "string" and scenarioInfo.area:match("%S") then
        return scenarioInfo.area
    end

    if type(scenarioInfo.name) == "string" and scenarioInfo.name:match("%S") then
        return scenarioInfo.name
    end

    return ""

end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function DelvesModule:Enable()

    AC.Events:Register("SCENARIO_COMPLETED", self)

end

function DelvesModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end


function DelvesModule:Shutdown()

    self:Disable()

end


-------------------------------------------------------------------------------
-- Completion
-------------------------------------------------------------------------------

function DelvesModule:OnScenarioCompleted(questID, xp, money)

    if not HasActiveDelve() then
        return
    end

    local scenarioInfo = GetScenarioInfo()

    if not scenarioInfo or not scenarioInfo.isComplete then
        return
    end

    local tierInfo = GetActiveDelveTier()
    local tier = tonumber(tierInfo and tierInfo.tier)
    local mapID = tonumber(GetDelveEntranceMapID())
    local activityName = GetCompletedDelveName(scenarioInfo)

    -- Retail 12.0.7 can return tier 0 at completion. Blizzard exposes no
    -- other authoritative numeric Delve-tier API at this point, so zero is
    -- not promoted into a gameplay tier and no inferred value is stored.
    if not tier or tier <= 0 then
        tier = nil
    end

    if not mapID or mapID <= 0 then
        mapID = nil
    end

    if not AC.ActivityHistoryService then
        return
    end

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()

    if not characterProfile or not characterProfile.name or characterProfile.name == "" then
        return
    end

    local now = time()
    local data =
    {
        recordVersion = 2,
        scenarioID = scenarioInfo.scenarioID,
        scenarioName = scenarioInfo.name,
        currentStage = scenarioInfo.currentStage,
        numStages = scenarioInfo.numStages,
        area = scenarioInfo.area,
        questID = questID,
        xp = xp,
        money = money,
    }

    if tier then
        data.tier = tier
    end

    if mapID then
        data.mapID = mapID
    end

    AC.ActivityHistoryService:Append(
    {
        Character = characterProfile.name,
        Realm = characterProfile.realm or "",
        Module = "Delves",
        ActivityType = "Delve",
        ActivityName = activityName,
        Difficulty = tier and ("Tier " .. tier) or "",
        Expansion = GetExpansionLevel and GetExpansionLevel() or 0,
        Started = now,
        Ended = now,
        Completed = true,
        Success = true,
        Data = data,
    })

end


-------------------------------------------------------------------------------
-- Recent History
-------------------------------------------------------------------------------

function DelvesModule:GetRecentDelves(count)

    count = tonumber(count) or 10

    local results = {}

    if not AC.ActivityHistoryService then
        return results
    end

    local records = AC.ActivityHistoryService:GetByModule("Delves")
    local total = #records

    for i = total, math.max(1, total - count + 1), -1 do
        table.insert(results, records[i])
    end

    return results

end


-------------------------------------------------------------------------------
-- Public State
-------------------------------------------------------------------------------

function DelvesModule:GetActiveDelveInfo()

    if not HasActiveDelve() then
        return nil
    end

    local scenarioInfo = GetScenarioInfo()

    if not scenarioInfo then
        return nil
    end

    local tierInfo = GetActiveDelveTier()
    local tier = tonumber(tierInfo and tierInfo.tier)

    if not tier or tier <= 0 then
        tier = nil
    end

    return
    {
        name = scenarioInfo.name or "",
        scenarioID = scenarioInfo.scenarioID,
        area = scenarioInfo.area,
        currentStage = scenarioInfo.currentStage,
        numStages = scenarioInfo.numStages,
        isComplete = scenarioInfo.isComplete == true,
        tier = tier,
    }

end

function DelvesModule:GetTrackedStatistics()

    local statistics =
    {
        completionCount = 0,
        highestTier = nil,
    }

    if not AC.ActivityHistoryService then
        return statistics
    end

    for _, record in ipairs(AC.ActivityHistoryService:GetByModule("Delves")) do

        if record.ActivityType == "Delve" and record.Completed then

            statistics.completionCount = statistics.completionCount + 1

            local tier = tonumber(record.Data and record.Data.tier)

            if tier and tier > 0 and (not statistics.highestTier or tier > statistics.highestTier) then
                statistics.highestTier = tier
            end

        end

    end

    return statistics

end


-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Delves", DelvesModule)

return DelvesModule
