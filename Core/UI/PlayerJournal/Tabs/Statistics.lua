-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Statistics Tab
--
-- The full objective-data breakdown for this player -- deliberately
-- styled with a cool blue accent (StatColor below), visually distinct
-- from Personal Notes/Tags' own warm gold accent elsewhere in this
-- window, per the feature's own requirement that objective statistics
-- always read as visually separate from personal opinion. Every number
-- here already exists on PlayerJournalModule's own public API/record --
-- this tab only lays it out, computes nothing.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

-- Presentation System v2 -- this tab's own deliberate blue accent (see
-- file header) is now the canonical source of AC.Presentation's addon-wide
-- "accent" semantic color -- read back from there rather than a second
-- independent literal, so the two can never drift apart again.
local accentR, accentG, accentB = unpack(AC.Presentation.GetSemanticColor("accent"))
local StatColor = { r = accentR, g = accentG, b = accentB }

-- No "not record" branch here -- PlayerJournalWindow:ShowTab() already
-- guarantees a valid record before ever calling this (see
-- PLAYER_SCOPED_TABS/BuildNoPlayerSelectedTab in PlayerJournalWindow.lua).
function PlayerJournalWindow:BuildStatisticsTab()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    local lines = {}

    local summary = journalModule:GetPlayerStatsSummary(self.CurrentPlayerKey)
    local stats = record.stats

    local winRate = stats.runsTogether > 0 and ((stats.runsCompleted / stats.runsTogether) * 100) or 0

    table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionStatistics"), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatWinRate", AC.Presentation.FormatPercent(winRate)), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatRunsTogether", summary.runsTogether), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatRunsCompleted", summary.runsCompleted), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatRunsTimed", summary.runsTimed), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatRunsLeftEarly", summary.runsLeftEarly), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatAverageDeaths", string.format("%.1f", summary.averageDeaths)), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatAverageRatingGain", string.format("%.1f", summary.averageRatingGain)), r = StatColor.r, g = StatColor.g, b = StatColor.b })
    table.insert(lines, { text = AC.L:Format("PlayerJournal.StatTotalInterrupts", summary.totalInterrupts), r = StatColor.r, g = StatColor.g, b = StatColor.b })

    table.insert(lines, "")
    table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionDungeonBreakdown"), r = StatColor.r, g = StatColor.g, b = StatColor.b })

    local dungeonEntries = {}

    for dungeonID, count in pairs(stats.dungeonCounts) do
        table.insert(dungeonEntries, { dungeonID = dungeonID, count = count })
    end

    if #dungeonEntries == 0 then

        table.insert(lines, { text = AC.L:Get("PlayerJournal.NoDungeonBreakdown"), r = 0.6, g = 0.6, b = 0.6 })

    else

        table.sort(dungeonEntries, function(a, b) return a.count > b.count end)

        local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")

        for _, entry in ipairs(dungeonEntries) do

            local dungeonName = mythicPlusModule and mythicPlusModule.GetDungeonName and mythicPlusModule:GetDungeonName(entry.dungeonID)

            table.insert(lines,
            {
                text = AC.L:Format("PlayerJournal.DungeonBreakdownLineFormat", dungeonName ~= "" and dungeonName or AC.L:Get("Common.Unknown"), entry.count),
                r = StatColor.r, g = StatColor.g, b = StatColor.b,
            })

        end

    end

    table.insert(lines, "")
    table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionRoleBreakdown"), r = StatColor.r, g = StatColor.g, b = StatColor.b })

    for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do

        local count = stats.roleCounts[role] or 0

        if count > 0 then
            table.insert(lines, { text = AC.L:Format("PlayerJournal.RoleBreakdownLineFormat", AC.L:Get("PlayerJournal.Role" .. role), count), r = StatColor.r, g = StatColor.g, b = StatColor.b })
        end

    end

    local yOffset = self:LayoutLines("Statistics", lines, -4, self.CONTENT_WIDTH)

    return (-yOffset) + 16

end
