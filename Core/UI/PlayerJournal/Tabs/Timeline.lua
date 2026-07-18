-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Timeline Tab
--
-- A unified, reverse-chronological view of record.timelineEvents --
-- PlayerJournalModule's own bounded (last 200) event log, pushed to
-- whenever a run finalizes, a note is added, a tag is toggled, or the
-- player is met for the first time (PlayerJournalModule:PushTimelineEvent).
-- This tab renders that log; it never merges/re-sorts separate
-- structures itself.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

local function FormatTimelineEvent(event)

    -- Presentation System v2 -- was a hand-rolled "%b %d, %Y %H:%M" (single
    -- space before the time), a third variant of the same format. Migrated
    -- to the addon's canonical "shortTime" style -- a real, minor visual
    -- change (single space becomes the canonical double space).
    local when = AC.Presentation.FormatDate(event.timestamp, "shortTime")

    if event.type == "met" then
        return AC.L:Format("PlayerJournal.TimelineMetFormat", when)
    elseif event.type == "run" then

        local data = event.data or {}
        local outcome

        if data.leftEarly then
            outcome = AC.L:Get("PlayerJournal.RunLeftEarly")
        elseif data.timed then
            outcome = AC.L:Get("Common.Timed")
        else
            outcome = AC.L:Get("Common.Failed")
        end

        return AC.L:Format("PlayerJournal.TimelineRunFormat", when, data.level or 0, data.dungeonName ~= "" and data.dungeonName or AC.L:Get("Common.Unknown"), outcome)

    elseif event.type == "note" then
        return AC.L:Format("PlayerJournal.TimelineNoteFormat", when)
    elseif event.type == "tag" then

        local data = event.data or {}
        local labelKey = AC.PlayerJournalTags:GetLabelKey(data.tagID)
        local tagLabel = labelKey and AC.L:Get(labelKey) or (data.tagID or "")

        if data.added then
            return AC.L:Format("PlayerJournal.TimelineTagAddedFormat", when, tagLabel)
        else
            return AC.L:Format("PlayerJournal.TimelineTagRemovedFormat", when, tagLabel)
        end

    end

    return AC.L:Format("PlayerJournal.TimelineUnknownFormat", when)

end

-- No "not record" branch here -- PlayerJournalWindow:ShowTab() already
-- guarantees a valid record before ever calling this (see
-- PLAYER_SCOPED_TABS/BuildNoPlayerSelectedTab in PlayerJournalWindow.lua).
function PlayerJournalWindow:BuildTimelineTab()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    local lines = {}

    if #record.timelineEvents == 0 then

        table.insert(lines, AC.L:Get("PlayerJournal.NoTimelineEvents"))

        local yOffset = self:LayoutLines("Timeline", lines, -4, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    for i = #record.timelineEvents, 1, -1 do
        table.insert(lines, FormatTimelineEvent(record.timelineEvents[i]))
    end

    local yOffset = self:LayoutLines("Timeline", lines, -4, self.CONTENT_WIDTH)

    return (-yOffset) + 16

end
