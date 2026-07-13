-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Tooltip
--
-- Appends Player Journal facts to Blizzard's own unit tooltip via
-- TooltipDataProcessor.AddTooltipPostCall (the current, standard
-- technique for tooltip extension -- confirmed via real published addon
-- source before use, high confidence). Gated on one master
-- "Show Journal Info in Tooltips" setting. Read-only throughout -- never
-- mutates a record, and adds only the lines that actually have real data
-- (never a placeholder for a fact that doesn't exist), the same "omit
-- rather than fabricate" discipline every other tooltip/card in this
-- addon already follows. Renders nothing at all for a player with no
-- journal record.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local function OnUnitTooltip(tooltip)

    if tooltip ~= GameTooltip then
        return
    end

    if AC.ConfigurationManager:GetValue("PlayerJournal", "enableTooltips") ~= true then
        return
    end

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    if not journalModule then
        return
    end

    local _, unit = tooltip:GetUnit()

    if not unit or not UnitIsPlayer(unit) then
        return
    end

    local name, realm = UnitFullName(unit)

    if not name or name == "" then
        return
    end

    local resolvedRealm = (realm and realm ~= "") and realm or (GetRealmName and GetRealmName()) or ""
    local playerKey = name .. "-" .. resolvedRealm

    local record = journalModule:GetPlayerRecord(playerKey)

    if not record then
        return
    end

    tooltip:AddLine(" ")

    if record.tags["FavoritePlayer"] then
        tooltip:AddLine(AC.L:Get("PlayerJournal.TooltipFavorite"), 1, 0.82, 0)
    end

    if record.stats.runsTogether > 0 then
        tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipRunsTogether"), tostring(record.stats.runsTogether), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    end

    if record.lastSeen and record.lastSeen > 0 then
        tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipLastSeen"), AC.Presentation.FormatDate(record.lastSeen, "short"), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    end

    local latestNote = record.notes[#record.notes]

    if latestNote and latestNote.text and latestNote.text ~= "" then

        local preview = latestNote.text

        if #preview > 60 then
            preview = preview:sub(1, 60) .. "..."
        end

        tooltip:AddLine(AC.L:Format("PlayerJournal.TooltipNotePreviewFormat", preview), 0.6, 0.85, 1, true)

    end

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if communityModule and communityModule:IsModuleEnabled() and not record.hideCommunityNotes then

        local communityNoteCount = #communityModule:GetNotesForPlayer(playerKey)

        if communityNoteCount > 0 then
            tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipCommunityNotes"), tostring(communityNoteCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
        end

    end

    tooltip:Show()

end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
