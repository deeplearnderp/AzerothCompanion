-------------------------------------------------------------------------------
-- Azeroth Companion
-- Observation Dialog
--
-- The one way to write a Community Observation -- a small, focused popup,
-- not the Player Journal's own tab. Reachable directly from the player
-- context menu (Core/UI/PlayerJournalContextMenu.lua) without opening the
-- Journal at all, and from the Community Observations tab's own "Add
-- Observation" button (Core/UI/PlayerJournal/Tabs/CommunityObservations.lua)
-- -- one dialog, multiple entry points. Observation creation belongs
-- here; the tab only browses.
--
-- Built on AC.BaseWindow (the same shell every standalone window in this
-- addon uses) rather than StaticPopupDialogs -- Blizzard's stock
-- StaticPopup templates only support a single-line EditBox
-- (StaticPopupEditBoxTemplate); a multi-line observation with a live
-- character count needs the same InputScrollFrameTemplate technique the
-- former embedded composer already used, which the stock popup template
-- has no slot for. A small fixed-size BaseWindow is the closest fit this
-- addon's existing toolkit offers to "feels like a Blizzard popup"
-- without inventing unverified StaticPopup internals.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ObservationDialog = {}
AC.ObservationDialog = ObservationDialog

-- Navigation System -- registered at file-load time rather than inside
-- Create() (this dialog has no Initialize() lifecycle -- Create() only
-- runs lazily, on first Show()): RegisterWindow just needs a reference to
-- this table, which already exists the moment this file loads, well
-- before anything could plausibly navigate here.
AC.NavigationService:RegisterWindow(AC.NavigationService.Windows.ObservationDialog, ObservationDialog)

local DIALOG_WIDTH = 360
local DIALOG_HEIGHT = 236
local MAX_LETTERS = 500

-------------------------------------------------------------------------------
-- Code of Conduct Gate
--
-- Shown once per account (CommunityModule:HasAcceptedCodeOfConduct/
-- AcceptCodeOfConduct), before the very first Community Observation
-- submission -- never shown again afterward. Disallowed-content bullets
-- match the feature's own brief verbatim.
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

local function ShowCodeOfConductThenSave(onAccept)

    local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_CODEOFCONDUCT", nil, nil, { onAccept = onAccept })

    if dialog then
        dialog.text:SetText(AC.L:Get("Community.CodeOfConductText"))
    end

end

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

local function UpdateCharacterCount(frame)

    local length = frame.EditBox:GetText():len()
    frame.CharacterCount:SetText(AC.L:Format("Community.CharacterCountFormat", length, MAX_LETTERS))

end

function ObservationDialog:Create()

    local frame = AC.BaseWindow:Create("AzerothCompanionObservationDialog", AC.L:Get("Community.AddObservationTitle"), DIALOG_WIDTH, DIALOG_HEIGHT)

    AC.BaseWindow:AddCloseButton(frame, self)
    AC.BaseWindow:AddBackButton(frame, self)

    local playerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", 16, -36)
    playerLabel:SetJustifyH("LEFT")

    frame.PlayerLabel = playerLabel

    -- InputScrollFrameTemplate is applied to a ScrollFrame (not an
    -- EditBox) -- it exposes the real multi-line EditBox as box.EditBox.
    -- Standard Blizzard template (guild MOTD editor, macro editor use the
    -- same one), confirmed via multiple real addon sources before use --
    -- the same technique the former embedded composer already used.
    local box = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
    box:SetSize(DIALOG_WIDTH - 32 - 12, 100)
    box:SetPoint("TOPLEFT", 16, -60)

    local editBox = box.EditBox
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(MAX_LETTERS)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetAutoFocus(false)

    frame.EditBox = editBox

    local characterCount = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    characterCount:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    characterCount:SetJustifyH("LEFT")

    frame.CharacterCount = characterCount

    editBox:SetScript("OnTextChanged", function()
        UpdateCharacterCount(frame)
    end)

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(90, 22)
    saveButton:SetText(_G.SAVE or "Save")
    saveButton:SetPoint("BOTTOMRIGHT", -16, 16)

    saveButton:SetScript("OnClick", function()
        self:Save()
    end)

    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelButton:SetSize(90, 22)
    cancelButton:SetText(_G.CANCEL or "Cancel")
    cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)

    cancelButton:SetScript("OnClick", function()
        self:Hide()
    end)

    self.Frame = frame

    return frame

end

-------------------------------------------------------------------------------
-- Show / Hide / Save
-------------------------------------------------------------------------------

function ObservationDialog:Show(playerKey, name, realm)

    AC.NavigationService:Push(AC.NavigationService.Windows.ObservationDialog, AC.NavigationService.Views.ObservationDialog.AddObservation,
        { playerKey = playerKey, name = name, realm = realm })

end

function ObservationDialog:RestoreNavigation(entry)

    if not self.Frame then
        self:Create()
    end

    local context = entry.Context or {}
    self.PlayerKey = context.playerKey
    self.PlayerName = context.name
    self.PlayerRealm = context.realm

    local displayName = (context.realm and context.realm ~= "") and (context.name .. "-" .. context.realm) or (context.name or "")

    self.Frame.PlayerLabel:SetText(AC.L:Format("Community.FieldPlayerFormat", displayName))
    self.Frame.EditBox:SetText("")
    UpdateCharacterCount(self.Frame)

    self.Frame:Show()
    self.Frame.EditBox:SetFocus()

end

function ObservationDialog:Hide()

    if not AC.NavigationService:GoBackIfCurrent(self) and self.Frame then
        self.Frame:Hide()
    end

end

function ObservationDialog:Save()

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if not communityModule or not communityModule:IsModuleEnabled() or not self.PlayerKey then
        return
    end

    local text = self.Frame.EditBox:GetText()

    if not text or text:match("^%s*$") then
        return
    end

    local function DoSave()

        local observation = communityModule:AddObservation(self.PlayerKey, text)

        if not observation then
            return
        end

        local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

        if journalModule then
            journalModule:RecordRelationship(
                { key = self.PlayerKey, name = self.PlayerName, realm = self.PlayerRealm, classFile = "" },
                journalModule.RelationshipTypes.CommunityObservation)
        end

        self:Hide()

        -- Refresh the Community Observations tab in place if it's already
        -- open on this same player, so the new observation appears
        -- immediately without requiring the Journal to be reopened.
        local journalWindow = AC.Core and AC.Core:GetModule("PlayerJournalWindow")

        if journalWindow and journalWindow.Frame and journalWindow.Frame:IsShown()
        and journalWindow.CurrentTab == "CommunityObservations"
        and journalWindow.CurrentPlayerKey == self.PlayerKey then
            journalWindow:ShowTab("CommunityObservations")
        end

    end

    if communityModule:HasAcceptedCodeOfConduct() then
        DoSave()
    else
        ShowCodeOfConductThenSave(DoSave)
    end

end

return ObservationDialog
