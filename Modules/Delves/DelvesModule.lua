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
local GetDelvesFactionForSeason = C_DelvesUI.GetDelvesFactionForSeason
local GetFactionForCompanion = C_DelvesUI.GetFactionForCompanion
local GetScenarioInfo = C_ScenarioInfo.GetScenarioInfo
local GetMajorFactionRenownInfo = C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo
local HasMaximumRenown = C_MajorFactions and C_MajorFactions.HasMaximumRenown
local GetFriendshipReputationRanks = C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks
local GetFriendshipReputation = C_GossipInfo and C_GossipInfo.GetFriendshipReputation
local GetFactionDataByID = C_Reputation and C_Reputation.GetFactionDataByID
local GetCreatureDisplayInfoForCompanion = C_DelvesUI.GetCreatureDisplayInfoForCompanion
local GetTraitTreeForCompanion = C_DelvesUI.GetTraitTreeForCompanion
local GetRoleNodeForCompanion = C_DelvesUI.GetRoleNodeForCompanion
local GetCurioNodeForCompanion = C_DelvesUI.GetCurioNodeForCompanion
local GetCurioRarityByTraitCondAccountElementID = C_DelvesUI.GetCurioRarityByTraitCondAccountElementID
local GetCurioLink = C_DelvesUI.GetCurioLink

local function SafeCall(fn, ...)

    if not fn then
        return nil
    end

    local ok, result = pcall(fn, ...)

    return ok and result or nil

end

local function GetCompanionSelection(configID, nodeID, includeCurioMetadata)

    if not configID or not nodeID or not C_Traits then
        return nil
    end

    local nodeInfo = SafeCall(C_Traits.GetNodeInfo, configID, nodeID)
    local entryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
    local entryInfo = entryID and SafeCall(C_Traits.GetEntryInfo, configID, entryID)

    if not entryInfo then
        return nil
    end

    if entryInfo.subTreeID and C_Traits.GetSubTreeInfo then

        local subTreeInfo = SafeCall(C_Traits.GetSubTreeInfo, configID, entryInfo.subTreeID)

        return subTreeInfo and { name = subTreeInfo.name } or nil

    end

    if entryInfo.definitionID and C_Traits.GetDefinitionInfo and C_Spell and C_Spell.GetSpellInfo then

        local definitionInfo = SafeCall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
        local spellID = definitionInfo and (definitionInfo.overriddenSpellID or definitionInfo.spellID)
        local spellInfo = spellID and SafeCall(C_Spell.GetSpellInfo, spellID)

        if not spellInfo or not spellInfo.name then
            return nil
        end

        local selection =
        {
            name = spellInfo.name,
            spellID = spellID,
            iconID = spellInfo.iconID,
        }

        if includeCurioMetadata then

            local rarity

            for _, conditionID in ipairs(entryInfo.conditionIDs or {}) do

                local conditionInfo = C_Traits.GetConditionInfo and SafeCall(C_Traits.GetConditionInfo, configID, conditionID, true)

                if conditionInfo and conditionInfo.traitCondAccountElementID then
                    rarity = tonumber(SafeCall(GetCurioRarityByTraitCondAccountElementID, conditionInfo.traitCondAccountElementID)) or rarity
                end

            end

            local maxRank = Enum.CurioRarity and tonumber(Enum.CurioRarity.Epic)

            if rarity and rarity > 0 and maxRank and maxRank >= rarity then
                selection.rank = rarity
                selection.maxRank = maxRank
                selection.link = SafeCall(GetCurioLink, spellID, rarity)
            end

        end

        return selection

    end

    return nil

end

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

-- Live progression remains Blizzard-owned. This projection gives UI consumers
-- one stable, optional-field summary while tracked completion history continues
-- to come from ActivityHistoryService through GetTrackedStatistics().
function DelvesModule:GetProgressionSummary()

    local summary =
    {
        statistics = self:GetTrackedStatistics(),
    }

    if GetMajorFactionRenownInfo and GetDelvesFactionForSeason then

        local factionID = tonumber(GetDelvesFactionForSeason())
        local info = factionID and factionID > 0 and GetMajorFactionRenownInfo(factionID)
        local rank = tonumber(info and info.renownLevel)

        if rank and rank > 0 then

            summary.journey =
            {
                rank = rank,
            }

            local earned = tonumber(info.renownReputationEarned)
            local threshold = tonumber(info.renownLevelThreshold)

            -- Blizzard's Journey UI presents a completed final rank as a
            -- full threshold even though renownReputationEarned resets to 0.
            if threshold and SafeCall(HasMaximumRenown, factionID) then
                earned = threshold
            end

            if earned and threshold and threshold > 0 then
                summary.journey.progress = earned
                summary.journey.threshold = threshold
            end

        end

    end

    if GetFactionForCompanion and GetFriendshipReputationRanks and GetFactionDataByID then

        local factionID = tonumber(GetFactionForCompanion())
        local rankInfo = factionID and factionID > 0 and GetFriendshipReputationRanks(factionID)
        local reputationInfo = factionID and factionID > 0 and SafeCall(GetFriendshipReputation, factionID)
        local factionInfo = factionID and factionID > 0 and GetFactionDataByID(factionID)
        local level = tonumber(rankInfo and rankInfo.currentLevel)
        local maxLevel = tonumber(rankInfo and rankInfo.maxLevel)
        local name = factionInfo and factionInfo.name

        if type(name) == "string" and name:match("%S") then

            summary.companion =
            {
                name = name,
            }

            if level and level > 0 then
                summary.companion.level = level
            end

            if maxLevel and maxLevel > 0 then
                summary.companion.maxLevel = maxLevel
            end

            summary.companion.isMaximumLevel = level ~= nil
                and maxLevel ~= nil
                and level >= maxLevel

            -- Blizzard uses a 1/1 sentinel when no next friendship threshold
            -- exists. Keep that implementation detail out of the projection;
            -- maximum level is represented explicitly instead.
            if not summary.companion.isMaximumLevel and reputationInfo and reputationInfo.nextThreshold then

                local standing = tonumber(reputationInfo.standing)
                local reactionThreshold = tonumber(reputationInfo.reactionThreshold)
                local nextThreshold = tonumber(reputationInfo.nextThreshold)

                if standing and reactionThreshold and nextThreshold then

                    local currentXP = standing - reactionThreshold
                    local requiredXP = nextThreshold - reactionThreshold

                    if currentXP >= 0 and requiredXP > 0 then
                        summary.companion.currentXP = currentXP
                        summary.companion.requiredXP = requiredXP
                    end

                end

            end

            local displayID = tonumber(SafeCall(GetCreatureDisplayInfoForCompanion))

            if displayID and displayID > 0 then
                summary.companion.displayID = displayID
            end

            local traitTreeID = tonumber(SafeCall(GetTraitTreeForCompanion))
            local configID = traitTreeID and C_Traits and C_Traits.GetConfigIDByTreeID and SafeCall(C_Traits.GetConfigIDByTreeID, traitTreeID)

            if configID then

                local role = GetCompanionSelection(configID, SafeCall(GetRoleNodeForCompanion))
                summary.companion.role = role and role.name or nil

                local curioTypes = Enum.CurioType or {}
                summary.companion.combatCurio = GetCompanionSelection(configID, curioTypes.Combat and SafeCall(GetCurioNodeForCompanion, curioTypes.Combat), true)
                summary.companion.utilityCurio = GetCompanionSelection(configID, curioTypes.Utility and SafeCall(GetCurioNodeForCompanion, curioTypes.Utility), true)

            end

        end

    end

    return summary

end


-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Delves", DelvesModule)

return DelvesModule
