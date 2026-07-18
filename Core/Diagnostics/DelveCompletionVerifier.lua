-------------------------------------------------------------------------------
-- Azeroth Companion
-- Temporary Retail Delve completion verifier
--
-- Remove this file and its .toc entry after the live verification pass.
-------------------------------------------------------------------------------

local completionEventCount = 0

local function FormatScenarioInfo(info)

    if not info then
        return "nil"
    end

    return string.format(
        "name=%s, scenarioID=%s, currentStage=%s, numStages=%s, isComplete=%s, type=%s, area=%s",
        tostring(info.name),
        tostring(info.scenarioID),
        tostring(info.currentStage),
        tostring(info.numStages),
        tostring(info.isComplete),
        tostring(info.type),
        tostring(info.area)
    )

end

local function FormatTierInfo(info)

    if not info then
        return "nil"
    end

    return string.format(
        "tier=%s, suggestedILvl=%s, unlocked=%s, modifierUIWidgetSetID=%s, lockedReason=%s",
        tostring(info.tier),
        tostring(info.suggestedILvl),
        tostring(info.unlocked),
        tostring(info.modifierUIWidgetSetID),
        tostring(info.lockedReason)
    )

end


local frame = CreateFrame("Frame")

frame:RegisterEvent("SCENARIO_COMPLETED")

frame:SetScript("OnEvent", function(_, event, questID, xp, money)

    completionEventCount = completionEventCount + 1

    local hasActiveDelve = C_DelvesUI.HasActiveDelve()
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    local tierInfo = C_DelvesUI.GetActiveDelveTier()

    print(string.format("[D VERIFY] %s count=%d questID=%s xp=%s money=%s", event, completionEventCount, tostring(questID), tostring(xp), tostring(money)))
    print("[D VERIFY] HasActiveDelve=" .. tostring(hasActiveDelve))
    print("[D VERIFY] ScenarioInfo={" .. FormatScenarioInfo(scenarioInfo) .. "}")
    print("[D VERIFY] scenarioInfo.isComplete=" .. tostring(scenarioInfo and scenarioInfo.isComplete))
    print("[D VERIFY] ActiveDelveTier={" .. FormatTierInfo(tierInfo) .. "}")

end)
