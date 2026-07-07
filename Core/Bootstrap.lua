-------------------------------------------------------------------------------
-- Azeroth Companion
-- Bootstrap
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, addon)

    if addon ~= AC.Name then
        return
    end

    AC.Core:Initialize()

end)
