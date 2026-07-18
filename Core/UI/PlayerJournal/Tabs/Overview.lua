-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Overview Tab
--
-- Identity + a quick-glance stat summary + the objective/opinion split
-- the feature's own brief requires ("objective statistics must always be
-- visually separated from opinions") -- this tab renders only the
-- objective half (via PlayerJournalModule:GetPlayerStatsSummary); tags
-- and notes each have their own dedicated tabs. Purely presentation --
-- every value already exists on PlayerJournalModule's own public API,
-- nothing computed here.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

local function FormatRelativeDate(timestamp)

    if not timestamp or timestamp == 0 then
        return AC.L:Get("Common.Unknown")
    end

    return AC.Presentation.FormatDate(timestamp, "short")

end

-- No "not record" branch here -- PlayerJournalWindow:ShowTab() already
-- guarantees a valid record before ever calling this (see
-- PLAYER_SCOPED_TABS/BuildNoPlayerSelectedTab in PlayerJournalWindow.lua).
function PlayerJournalWindow:BuildOverviewTab()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    local lines = {}

    local summary = journalModule:GetPlayerStatsSummary(self.CurrentPlayerKey)

    table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionOverview"), r = 1, g = 0.82, b = 0 })
    table.insert(lines, AC.L:Format("PlayerJournal.FieldClass", record.class ~= "" and record.class or AC.L:Get("Common.Unknown")))
    table.insert(lines, AC.L:Format("PlayerJournal.FieldGuild", record.guild ~= "" and record.guild or AC.L:Get("Common.Unknown")))
    table.insert(lines, AC.L:Format("PlayerJournal.FieldFirstSeen", FormatRelativeDate(record.firstSeen)))
    table.insert(lines, AC.L:Format("PlayerJournal.FieldLastSeen", FormatRelativeDate(record.lastSeen)))

    table.insert(lines, "")
    table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionStatistics"), r = 1, g = 0.82, b = 0 })
    table.insert(lines, AC.L:Format("PlayerJournal.StatRunsTogether", summary.runsTogether))
    table.insert(lines, AC.L:Format("PlayerJournal.StatRunsCompleted", summary.runsCompleted))
    table.insert(lines, AC.L:Format("PlayerJournal.StatRunsTimed", summary.runsTimed))
    table.insert(lines, AC.L:Format("PlayerJournal.StatRunsLeftEarly", summary.runsLeftEarly))
    table.insert(lines, AC.L:Format("PlayerJournal.StatAverageDeaths", string.format("%.1f", summary.averageDeaths)))
    table.insert(lines, AC.L:Format("PlayerJournal.StatAverageRatingGain", string.format("%.1f", summary.averageRatingGain)))
    table.insert(lines, AC.L:Format("PlayerJournal.StatFavoriteDungeon", summary.favoriteDungeonName or AC.L:Get("Common.Unknown")))
    table.insert(lines, AC.L:Format("PlayerJournal.StatFavoriteRole", summary.favoriteRole and AC.L:Get("PlayerJournal.Role" .. summary.favoriteRole) or AC.L:Get("Common.Unknown")))

    local tagCount = 0

    for _ in pairs(record.tags) do
        tagCount = tagCount + 1
    end

    if tagCount > 0 then

        -- Presentation System v2 -- was a hardcoded (0.7,0.85,1), one of
        -- three unrelated "info/link" blues found in active use across
        -- the addon for the same accent role. Migrated to the real
        -- "accent" token.
        local accentR, accentG, accentB = unpack(AC.Presentation.GetSemanticColor("accent"))

        table.insert(lines, "")
        table.insert(lines, { text = AC.L:Get("PlayerJournal.SectionTags"), r = accentR, g = accentG, b = accentB })

        local tagLabels = {}

        for tagID in pairs(record.tags) do

            local labelKey = AC.PlayerJournalTags:GetLabelKey(tagID)

            if labelKey then
                table.insert(tagLabels, AC.L:Get(labelKey))
            end

        end

        table.insert(lines, { text = table.concat(tagLabels, ", "), r = accentR, g = accentG, b = accentB })

    end

    local yOffset = self:LayoutLines("Overview", lines, -4, self.CONTENT_WIDTH)

    return (-yOffset) + 16

end
