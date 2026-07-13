-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Community Notes Tab
--
-- Only ever renders real content when CommunityModule exists AND is
-- enabled -- otherwise a clean, honest empty state, never an error and
-- never a silent blank tab. Community Notes are their own section, never
-- merged with or replacing Personal Notes. Helpful/Not Helpful/Report/
-- Hide buttons are present (per the feature's own "moderation hooks
-- should exist" requirement) but disabled with a "Coming soon" tooltip --
-- there is no shared backend yet, so a real vote/report from anyone but
-- the note's own author is impossible; a clickable button implying
-- otherwise would misrepresent the feature.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

-------------------------------------------------------------------------------
-- Code of Conduct Gate
--
-- Shown once per account (CommunityModule:HasAcceptedCodeOfConduct/
-- AcceptCodeOfConduct), before the very first Community Note submission
-- -- never shown again afterward. Disallowed-content bullets match the
-- feature's own brief verbatim.
-------------------------------------------------------------------------------

StaticPopupDialogs["AZEROTHCOMPANION_PLAYERJOURNAL_CODEOFCONDUCT"] =
{
    text = "",
    button1 = _G.ACCEPT or "Accept",
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function(self)

        local communityModule = AC.Core and AC.Core:GetModule("Community")

        if communityModule then
            communityModule:AcceptCodeOfConduct()
        end

        if self.data and self.data.onAccept then
            self.data.onAccept()
        end

    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ShowCodeOfConductThenSubmit(onAccept)

    local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_CODEOFCONDUCT", nil, nil, { onAccept = onAccept })

    if dialog then
        dialog.text:SetText(AC.L:Get("Community.CodeOfConductText"))
    end

end

-------------------------------------------------------------------------------
-- Composer
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildCommunityComposer(yOffset)

    if not self.CommunityComposer then

        local box = CreateFrame("ScrollFrame", nil, self.ScrollChild, "InputScrollFrameTemplate")
        box:SetSize(self.CONTENT_WIDTH - 12, 50)

        local editBox = box.EditBox
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(500)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetAutoFocus(false)

        self.CommunityComposer = box
        self.CommunityComposerEditBox = editBox

        local submitButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        submitButton:SetSize(120, 20)
        submitButton:SetText(AC.L:Get("Community.SubmitNote"))

        submitButton:SetScript("OnClick", function()
            self:SubmitCommunityNote()
        end)

        self.CommunitySubmitButton = submitButton

    end

    self.CommunityComposer:ClearAllPoints()
    self.CommunityComposer:SetPoint("TOPLEFT", 6, yOffset)
    self.CommunityComposer:Show()

    yOffset = yOffset - 50 - 6

    self.CommunitySubmitButton:ClearAllPoints()
    self.CommunitySubmitButton:SetPoint("TOPLEFT", 0, yOffset)
    self.CommunitySubmitButton:Show()

    return yOffset - 26

end

function PlayerJournalWindow:SubmitCommunityNote()

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if not communityModule or not communityModule:IsModuleEnabled() or not self.CurrentPlayerKey or not self.CommunityComposerEditBox then
        return
    end

    local text = self.CommunityComposerEditBox:GetText()

    if not text or text:match("^%s*$") then
        return
    end

    local function DoSubmit()

        communityModule:AddCommunityNote(self.CurrentPlayerKey, text)
        self.CommunityComposerEditBox:SetText("")
        self:ShowTab("CommunityNotes")

    end

    if communityModule:HasAcceptedCodeOfConduct() then
        DoSubmit()
    else
        ShowCodeOfConductThenSubmit(DoSubmit)
    end

end

-------------------------------------------------------------------------------
-- Note Rows
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildCommunityNoteRow()

    local row = CreateFrame("Frame", nil, self.ScrollChild)

    local textLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textLine:SetPoint("TOPLEFT", 6, 0)
    textLine:SetJustifyH("LEFT")
    textLine:SetWordWrap(true)

    local metaLine = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaLine:SetPoint("TOPLEFT", textLine, "BOTTOMLEFT", 0, -2)
    metaLine:SetJustifyH("LEFT")

    local buttons = {}

    for _, key in ipairs({ "Helpful", "NotHelpful", "Report", "Hide" }) do

        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(64, 18)
        button:SetText(AC.L:Get("Community.Button" .. key))
        button:SetEnabled(false)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(AC.L:Get("Community.ComingSoonTooltip"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        buttons[key] = button

    end

    row.TextLine = textLine
    row.MetaLine = metaLine
    row.Buttons = buttons

    return row

end

-------------------------------------------------------------------------------
-- Build Tab
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildCommunityNotesTab()

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if not self.CommunityNoteRowPool then
        self.CommunityNoteRowPool = {}
    end

    if not communityModule or not communityModule:IsModuleEnabled() then

        if self.CommunityComposer then
            self.CommunityComposer:Hide()
            self.CommunitySubmitButton:Hide()
        end

        for _, row in ipairs(self.CommunityNoteRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("Community.Disabled") }
        local yOffset = self:LayoutLines("CommunityNotes", lines, -4, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    local yOffset = self:BuildCommunityComposer(-4)

    yOffset = yOffset - 8

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    -- A per-viewer preference set via the context menu's "Hide Community
    -- Notes" checkbox (Core/UI/PlayerJournalContextMenu.lua) -- checked
    -- here rather than in CommunityModule itself, since it's about what
    -- THIS window shows you, not a moderation action against the notes
    -- themselves.
    if record and record.hideCommunityNotes then

        for _, row in ipairs(self.CommunityNoteRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("Community.HiddenForPlayer") }
        yOffset = self:LayoutLines("CommunityNotes", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    local notes = self.CurrentPlayerKey and communityModule:GetNotesForPlayer(self.CurrentPlayerKey) or {}

    if #notes == 0 then

        for _, row in ipairs(self.CommunityNoteRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("Community.NoNotes") }
        yOffset = self:LayoutLines("CommunityNotes", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    for i = #notes, 1, -1 do

        local note = notes[i]
        local poolIndex = (#notes - i) + 1

        local row = self.CommunityNoteRowPool[poolIndex]

        if not row then
            row = self:BuildCommunityNoteRow()
            self.CommunityNoteRowPool[poolIndex] = row
        end

        row:SetWidth(self.CONTENT_WIDTH)
        row.TextLine:SetWidth(self.CONTENT_WIDTH - 12)
        row.TextLine:SetText(note.text)
        row.MetaLine:SetText(AC.L:Format("Community.NoteMetaFormat", AC.Presentation.FormatDate(note.timestamp, "short"), AC.L:Get("Community.Visibility" .. note.visibility)))

        local textHeight = row.TextLine:GetStringHeight() or 14
        local metaHeight = row.MetaLine:GetStringHeight() or 12

        local previousButton

        for _, key in ipairs({ "Helpful", "NotHelpful", "Report", "Hide" }) do

            local button = row.Buttons[key]
            button:ClearAllPoints()

            if previousButton then
                button:SetPoint("LEFT", previousButton, "RIGHT", 4, 0)
            else
                button:SetPoint("TOPLEFT", row.MetaLine, "BOTTOMLEFT", 0, -4)
            end

            previousButton = button

        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetHeight(textHeight + metaHeight + 26)
        row:Show()

        yOffset = yOffset - (textHeight + metaHeight + 26) - 8

    end

    for index = #notes + 1, #self.CommunityNoteRowPool do
        self.CommunityNoteRowPool[index]:Hide()
    end

    return (-yOffset) + 16

end
