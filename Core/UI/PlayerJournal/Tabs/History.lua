-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: History Tab
--
-- Chronological run history with this specific player -- reverse-
-- chronological, reading record.runs (PlayerJournalModule's own
-- forward-built index, populated as each run completes; not a re-scan of
-- ActivityHistoryService, which has no player-identity field to scan by).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

function PlayerJournalWindow:BuildHistoryTab()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    local lines = {}

    if not record or #record.runs == 0 then

        table.insert(lines, AC.L:Get("PlayerJournal.NoRunHistory"))

        local yOffset = self:LayoutLines("History", lines, -4, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    for i = #record.runs, 1, -1 do

        local run = record.runs[i]

        local outcome

        if run.leftEarly then
            outcome = AC.L:Get("PlayerJournal.RunLeftEarly")
        elseif run.timed then
            outcome = AC.L:Get("Common.Timed")
        else
            outcome = AC.L:Get("Common.Failed")
        end

        local roleLabel = run.role and run.role ~= "NONE" and AC.L:Get("PlayerJournal.Role" .. run.role) or AC.L:Get("Common.Unknown")

        -- Presentation System v2 -- the leftEarly branch (0.85,0.3,0.3)
        -- already matched AC.Presentation's canonical "critical" token
        -- byte-for-byte; migrated to read from it directly (a pure
        -- refactor, zero visual change) rather than keep a second
        -- independent copy of the same value. The non-leftEarly branch
        -- (0.9,0.9,0.9) is untouched -- out of scope this pass.
        local criticalR, criticalG, criticalB = unpack(AC.Presentation.GetSemanticColor("critical"))

        table.insert(lines,
        {
            text = AC.L:Format("PlayerJournal.HistoryLineFormat",
                AC.Presentation.FormatDate(run.timestamp, "short"),
                run.dungeonName ~= "" and run.dungeonName or AC.L:Get("Common.Unknown"),
                run.level or 0,
                outcome,
                run.ratingGain and string.format("%+.1f", run.ratingGain) or "0",
                roleLabel),
            r = run.leftEarly and criticalR or 0.9,
            g = run.leftEarly and criticalG or 0.9,
            b = run.leftEarly and criticalB or 0.9,
        })

    end

    local yOffset = self:LayoutLines("History", lines, -4, self.CONTENT_WIDTH)

    return (-yOffset) + 16

end
