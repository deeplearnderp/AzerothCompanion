-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Personal Notes Tab
--
-- Unlimited, local, unmoderated notes -- a multi-line composer (a plain
-- Blizzard multi-line EditBox; this addon has no rich-text framework, so
-- "rich text editor" from the feature's own brief is honestly scoped down
-- to plain multi-line text rather than fabricating formatting controls
-- that don't exist) plus a reverse-chronological list below it. Clicking
-- an existing note loads it back into the composer for editing --
-- Save then calls EditNote instead of AddNote (tracked via
-- self.EditingNoteID), so Add/Edit share one composer instead of two
-- separate input surfaces.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

local COMPOSER_HEIGHT = 60

function PlayerJournalWindow:BuildComposer(yOffset)

    if not self.NoteComposer then

        -- InputScrollFrameTemplate is applied to a ScrollFrame (not an
        -- EditBox) -- it exposes the real multi-line EditBox as
        -- box.EditBox. Standard Blizzard template (guild MOTD editor,
        -- macro editor use the same one), confirmed via multiple real
        -- addon sources before use.
        local box = CreateFrame("ScrollFrame", nil, self.ScrollChild, "InputScrollFrameTemplate")
        box:SetSize(self.CONTENT_WIDTH - 12, COMPOSER_HEIGHT)

        local editBox = box.EditBox
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(1000)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetAutoFocus(false)

        self.NoteComposer = box
        self.NoteComposerEditBox = editBox

        local saveButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        saveButton:SetSize(90, 20)

        saveButton:SetScript("OnClick", function()
            self:SaveComposerNote()
        end)

        self.NoteSaveButton = saveButton

        local cancelButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        cancelButton:SetSize(90, 20)
        cancelButton:SetText(AC.L:Get("PlayerJournal.CancelEdit"))

        cancelButton:SetScript("OnClick", function()
            self:ClearComposer()
            self:ShowTab("PersonalNotes")
        end)

        self.NoteCancelButton = cancelButton

    end

    self.NoteComposer:ClearAllPoints()
    self.NoteComposer:SetPoint("TOPLEFT", 6, yOffset)
    self.NoteComposer:Show()

    yOffset = yOffset - COMPOSER_HEIGHT - 6

    self.NoteSaveButton:ClearAllPoints()
    self.NoteSaveButton:SetPoint("TOPLEFT", 0, yOffset)
    self.NoteSaveButton:SetText(self.EditingNoteID and AC.L:Get("PlayerJournal.SaveEdit") or AC.L:Get("PlayerJournal.AddNote"))
    self.NoteSaveButton:Show()

    self.NoteCancelButton:ClearAllPoints()

    if self.EditingNoteID then

        self.NoteCancelButton:SetPoint("LEFT", self.NoteSaveButton, "RIGHT", 6, 0)
        self.NoteCancelButton:Show()

    else
        self.NoteCancelButton:Hide()
    end

    return yOffset - 26

end

function PlayerJournalWindow:ClearComposer()

    self.EditingNoteID = nil

    if self.NoteComposerEditBox then
        self.NoteComposerEditBox:SetText("")
    end

end

function PlayerJournalWindow:SaveComposerNote()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    if not journalModule or not self.CurrentPlayerKey or not self.NoteComposerEditBox then
        return
    end

    local text = self.NoteComposerEditBox:GetText()

    if not text or text:match("^%s*$") then
        return
    end

    if self.EditingNoteID then
        journalModule:EditNote(self.CurrentPlayerKey, self.EditingNoteID, text)
    else
        journalModule:RecordRelationship(self.CurrentIdentity, journalModule.RelationshipTypes.PersonalNote)
        journalModule:AddNote(self.CurrentPlayerKey, text)
    end

    self:ClearComposer()
    self:ShowTab("PersonalNotes")

end

-------------------------------------------------------------------------------
-- Personal Tags
--
-- No dedicated Tags tab exists (the window's own 7-tab list doesn't
-- include one) -- tags live here, alongside Personal Notes, since both
-- are subjective/personal facts, deliberately kept out of the
-- Statistics tab's objective-only section. A simple toggle-button grid
-- over AC.PlayerJournalTags:GetAllTags() -- pooled, not recreated per
-- refresh, colored gold when set (matching this window's own highlight
-- convention) and plain white otherwise.
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildTagGrid(yOffset)

    if not self.CurrentPlayerKey then
        return yOffset
    end

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    if not record then
        return yOffset
    end

    self.TagButtonPool = self.TagButtonPool or {}

    local allTags = AC.PlayerJournalTags:GetAllTags()

    local header = self.TagGridHeader

    if not header then

        header = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetJustifyH("LEFT")
        self.TagGridHeader = header

    end

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 0, yOffset)
    header:SetText(AC.L:Get("PlayerJournal.SectionTags"))
    AC.DashboardFormat.SetHighlightColor(header)
    header:Show()

    yOffset = yOffset - header:GetStringHeight() - 6

    local columnWidth = 110
    local rowHeight = 22
    local columnsPerRow = math.max(1, math.floor(self.CONTENT_WIDTH / columnWidth))

    for index, tag in ipairs(allTags) do

        local button = self.TagButtonPool[index]

        if not button then

            button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            button:SetSize(columnWidth - 6, 18)
            self.TagButtonPool[index] = button

        end

        local column = (index - 1) % columnsPerRow
        local gridRow = math.floor((index - 1) / columnsPerRow)

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", column * columnWidth, yOffset - (gridRow * rowHeight))
        button:SetText(AC.L:Get(tag.labelKey))

        local isSet = record.tags[tag.id] == true
        button:GetFontString():SetTextColor(isSet and 1 or 1, isSet and 0.82 or 1, isSet and 0 or 1)

        local tagID = tag.id

        button:SetScript("OnClick", function()
            local relationshipType = tagID == "FavoritePlayer"
                and journalModule.RelationshipTypes.Favorite
                or journalModule.RelationshipTypes.PersonalTag

            journalModule:RecordRelationship(self.CurrentIdentity, relationshipType)
            journalModule:ToggleTag(self.CurrentPlayerKey, tagID)
            self:ShowTab("PersonalNotes")
        end)

        button:Show()

    end

    for index = #allTags + 1, #self.TagButtonPool do
        self.TagButtonPool[index]:Hide()
    end

    local rowCount = math.ceil(#allTags / columnsPerRow)

    return yOffset - (rowCount * rowHeight) - 12

end

-------------------------------------------------------------------------------
-- Note Rows
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildNoteRow()

    local row = self:BuildTextMetaRow()

    local editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    editButton:SetSize(50, 18)
    editButton:SetText(AC.L:Get("PlayerJournal.EditNote"))

    local deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    deleteButton:SetSize(50, 18)
    deleteButton:SetText(AC.L:Get("PlayerJournal.DeleteNote"))

    row.EditButton = editButton
    row.DeleteButton = deleteButton

    return row

end

-- No "not record" branch here -- PlayerJournalWindow:ShowTab() already
-- guarantees a valid record before ever calling this (see
-- PLAYER_SCOPED_TABS/BuildNoPlayerSelectedTab in PlayerJournalWindow.lua).
function PlayerJournalWindow:BuildPersonalNotesTab()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    if not self.NoteRowPool then
        self.NoteRowPool = {}
    end

    local yOffset = self:BuildComposer(-4)

    yOffset = yOffset - 8

    if not record then
        local lines = { AC.L:Get("PlayerJournal.UntrackedNoteDescription") }
        yOffset = self:LayoutLines("PersonalNotes", lines, yOffset, self.CONTENT_WIDTH)
        return (-yOffset) + 16
    end

    yOffset = self:BuildTagGrid(yOffset)

    yOffset = yOffset - 8

    if #record.notes == 0 then

        for _, row in ipairs(self.NoteRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("PlayerJournal.NoNotes") }
        yOffset = self:LayoutLines("PersonalNotes", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    self:ClearPool("PersonalNotes")

    for i = #record.notes, 1, -1 do

        local note = record.notes[i]
        local poolIndex = (#record.notes - i) + 1

        local row = self.NoteRowPool[poolIndex]

        if not row then
            row = self:BuildNoteRow()
            self.NoteRowPool[poolIndex] = row
        end

        row:SetWidth(self.CONTENT_WIDTH)
        row.TextLine:SetWidth(self.CONTENT_WIDTH - 12)
        row.TextLine:SetText(note.text)

        -- Presentation System v2 -- was a hand-rolled "%b %d, %Y %H:%M"
        -- (single space before the time), a third variant of the same
        -- format. Migrated to the addon's canonical "shortTime" style -- a
        -- real, minor visual change (single space becomes the canonical
        -- double space).
        local metaText = AC.Presentation.FormatDate(note.timestamp, "shortTime")

        if note.editedTimestamp then
            metaText = metaText .. " " .. AC.L:Format("PlayerJournal.EditedSuffixFormat", AC.Presentation.FormatDate(note.editedTimestamp, "shortTime"))
        end

        row.MetaLine:SetText(metaText)

        local textHeight = row.TextLine:GetStringHeight() or 14
        local metaHeight = row.MetaLine:GetStringHeight() or 12

        row.EditButton:ClearAllPoints()
        row.EditButton:SetPoint("TOPLEFT", row.MetaLine, "BOTTOMLEFT", 0, -4)

        row.DeleteButton:ClearAllPoints()
        row.DeleteButton:SetPoint("LEFT", row.EditButton, "RIGHT", 4, 0)

        local noteID = note.id

        row.EditButton:SetScript("OnClick", function()

            self.EditingNoteID = noteID
            self.NoteComposerEditBox:SetText(note.text)
            self.NoteComposerEditBox:SetFocus()
            self:ShowTab("PersonalNotes")

        end)

        row.DeleteButton:SetScript("OnClick", function()

            journalModule:DeleteNote(self.CurrentPlayerKey, noteID)
            self:ShowTab("PersonalNotes")

        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetHeight(textHeight + metaHeight + 26)
        row:Show()

        yOffset = yOffset - (textHeight + metaHeight + 26) - 8

    end

    for index = #record.notes + 1, #self.NoteRowPool do
        self.NoteRowPool[index]:Hide()
    end

    return (-yOffset) + 16

end
