-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Community Observations Tab
--
-- Browsing/history only -- creation belongs to AC.ObservationDialog
-- (Core/UI/PlayerJournal/ObservationDialog.lua), reachable both from this
-- tab's own "Add Observation" button and directly from the player context
-- menu without opening the Journal at all. This tab never duplicates that
-- writing experience; it only lists what already exists.
--
-- Only ever renders real content when CommunityModule exists AND is
-- enabled -- otherwise a clean, honest empty state, never an error and
-- never a silent blank tab. Community Observations are their own section,
-- never merged with or replacing Personal Notes.
--
-- The abandoned moderation system (Helpful/Not Helpful/Report/Hide voting)
-- has been removed entirely -- there is no shared backend, so a real vote
-- or report from anyone but the observation's own author was never
-- possible, and those controls existed only as inert, disabled "Coming
-- soon" placeholders. Community Observations Phase 1 (Foundation) is
-- deliberately read/write only, with no moderation surface at all.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

-------------------------------------------------------------------------------
-- Add Observation Button
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildAddObservationButton(yOffset)

    if not self.AddObservationButton then

        local button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        button:SetSize(140, 22)
        button:SetText(AC.L:Get("Community.AddObservation"))

        button:SetScript("OnClick", function()

            local identity = self.CurrentIdentity

            AC.ObservationDialog:Show(self.CurrentPlayerKey, identity and identity.name, identity and identity.realm)

        end)

        self.AddObservationButton = button

    end

    self.AddObservationButton:ClearAllPoints()
    self.AddObservationButton:SetPoint("TOPLEFT", 6, yOffset)
    self.AddObservationButton:Show()

    return yOffset - 22 - 8

end

-------------------------------------------------------------------------------
-- Build Tab
--
-- No "not player selected" branch here -- PlayerJournalWindow:ShowTab()
-- already guarantees a valid record before ever calling this (see
-- PLAYER_SCOPED_TABS/BuildNoPlayerSelectedTab in PlayerJournalWindow.lua).
-- The one precondition still checked locally, module-disabled, is a
-- genuinely different fact (applies regardless of which player, or
-- whether one is even selected) and stays gated here.
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildCommunityObservationsTab()

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if not self.ObservationRowPool then
        self.ObservationRowPool = {}
    end

    if not communityModule or not communityModule:IsModuleEnabled() then

        if self.AddObservationButton then
            self.AddObservationButton:Hide()
        end

        for _, row in ipairs(self.ObservationRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("Community.Disabled") }
        local yOffset = self:LayoutLines("CommunityObservations", lines, -4, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    local yOffset = self:BuildAddObservationButton(-4)

    yOffset = yOffset - 8

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    -- A per-viewer preference set via the context menu's "Hide <Player>'s
    -- Observations" checkbox (Core/UI/PlayerJournalContextMenu.lua) --
    -- checked here rather than in CommunityModule itself, since it's
    -- about what THIS window shows you, not a moderation action against
    -- the observations themselves. Stored as record.hideCommunityNotes --
    -- an internal PlayerJournal field name, never shown to the player,
    -- left unrenamed to avoid a second, unrelated PlayerJournal schema
    -- migration in this same pass.
    if record and record.hideCommunityNotes then

        for _, row in ipairs(self.ObservationRowPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("Community.HiddenForPlayer") }
        yOffset = self:LayoutLines("CommunityObservations", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    local observations = communityModule:GetObservationsForPlayer(self.CurrentPlayerKey)

    -- UX Audit -- a genuinely new feature's zero-state is the moment
    -- someone decides whether it's worth using at all, so this teaches
    -- rather than just reports absence: what an observation is, why it's
    -- attributed (never anonymous), a concrete example of a good one, and
    -- a pointer at the Add Observation button already above. Same
    -- "empty states should feel intentional" principle Dashboard's own
    -- Recommendations page already applies to its "Caught Up" state.
    if #observations == 0 then

        for _, row in ipairs(self.ObservationRowPool) do
            row:Hide()
        end

        local lines =
        {
            { text = AC.L:Get("Community.NoObservationsTitle"), r = 1, g = 0.82, b = 0 },
            AC.L:Get("Community.NoObservationsDescription"),
            AC.L:Get("Community.NoObservationsExample"),
            AC.L:Get("Community.NoObservationsCallToAction"),
        }

        yOffset = self:LayoutLines("CommunityObservations", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    for i = #observations, 1, -1 do

        local observation = observations[i]
        local poolIndex = (#observations - i) + 1

        local row = self.ObservationRowPool[poolIndex]

        if not row then
            row = self:BuildTextMetaRow()
            self.ObservationRowPool[poolIndex] = row
        end

        local authorName = (observation.authorName and observation.authorName ~= "") and observation.authorName or AC.L:Get("Common.Unknown")

        row:SetWidth(self.CONTENT_WIDTH)
        row.TextLine:SetWidth(self.CONTENT_WIDTH - 12)
        row.TextLine:SetText(observation.text)
        row.MetaLine:SetText(AC.L:Format("Community.ObservationMetaFormat", authorName, AC.Presentation.FormatDate(observation.createdDate, "short")))

        local textHeight = row.TextLine:GetStringHeight() or 14
        local metaHeight = row.MetaLine:GetStringHeight() or 12

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetHeight(textHeight + metaHeight + 8)
        row:Show()

        yOffset = yOffset - (textHeight + metaHeight + 8) - 8

    end

    for index = #observations + 1, #self.ObservationRowPool do
        self.ObservationRowPool[index]:Hide()
    end

    return (-yOffset) + 16

end
