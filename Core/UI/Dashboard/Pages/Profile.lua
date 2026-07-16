-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Profile
--
-- The only place the Dashboard reads character data. Everything here
-- comes from the Character module's public API.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Format = AC.DashboardFormat

function Dashboard:GetProfileFieldValues()

    local values = {}

    local characterModule = AC.Core and AC.Core:GetModule("Character")

    if not characterModule then
        return values
    end

    local profile = characterModule:GetProfile()

    if profile then

        if profile.name and profile.name ~= "" then
            values.name = profile.name
        end

        if profile.level and profile.level > 0 then
            values.level = tostring(profile.level)
        end

        if profile.race and profile.race ~= "" then
            values.race = profile.race
        end

        if profile.class and profile.class ~= "" then
            values.class = profile.class
        end

        if profile.specName and profile.specName ~= "" then
            values.spec = profile.specName
        end

        if profile.equippedItemLevel and profile.equippedItemLevel > 0 then
            values.equippedItemLevel = AC.Presentation.FormatItemLevel(profile.equippedItemLevel)
        end

        if profile.averageItemLevel and profile.averageItemLevel > 0 then
            values.averageItemLevel = AC.Presentation.FormatItemLevel(profile.averageItemLevel)
        end

        if profile.zone and profile.zone ~= "" then
            values.zone = profile.zone
        end

        if profile.subZone and profile.subZone ~= "" then
            values.subZone = profile.subZone
        end

        if profile.bindLocation and profile.bindLocation ~= "" then
            values.bindLocation = profile.bindLocation
        end

        if profile.guildName and profile.guildName ~= "" then

            values.guild = profile.guildName

            if profile.guildRank and profile.guildRank ~= "" then
                values.guildRank = profile.guildRank
            end

        end

        if profile.faction and profile.faction ~= "" then
            values.faction = profile.faction
        end

        if profile.money then
            values.money = Format.FormatMoney(profile.money)
        end

        if profile.playedTimeAvailable and profile.playedTimeTotal and profile.playedTimeTotal > 0 then
            values.playedTime = Format.FormatDuration(profile.playedTimeTotal)
        end

        if profile.maxLevel and profile.maxLevel > 0 then
            values.maxLevel = tostring(profile.maxLevel)
        end

        if profile.restedXP and profile.restedXP > 0 then
            values.restedXP = Format.FormatNumberWithCommas(profile.restedXP)
        else
            values.restedXP = "0"
        end

        if profile.playedTimeAvailable and profile.playedTimeLevel and profile.playedTimeLevel > 0 then
            values.timeAtCurrentLevel = Format.FormatDuration(profile.playedTimeLevel)
        end

    end

    if characterModule.GetSessionInfo then

        local session = characterModule:GetSessionInfo()

        if session then

            if session.loginTimestamp and session.loginTimestamp > 0 then
                values.loginTime = AC.Presentation.FormatDate(session.loginTimestamp, "shortTime")
                values.sessionDuration = Format.FormatDuration(session.sessionDuration)
            end

            if session.itemLevelGained then
                -- Home Dashboard Evolution -- now shares AC.Presentation.FormatSignedNumber
                -- with Home's own Profile card instead of a second inline copy of this
                -- same +/- rule.
                values.itemLevelGained = AC.Presentation.FormatSignedNumber(session.itemLevelGained, 1)
            end

            if session.levelsGained then
                values.levelsGained = tostring(session.levelsGained)
            end

        end

    end

    return values

end

function Dashboard:UpdateProfilePage(frame)

    local page = frame.Pages and frame.Pages.Profile

    if not page or not page.Fields then
        return
    end

    local values = self:GetProfileFieldValues()
    local unknown = AC.L:Get("Common.Unknown")

    for key, fontString in pairs(page.Fields) do
        fontString:SetText(values[key] or unknown)
    end

end

return Dashboard
