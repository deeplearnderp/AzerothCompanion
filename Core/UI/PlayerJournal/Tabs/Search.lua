-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window: Search Tab
--
-- Search by name/realm/guild substring, Favorites-only, or by tag --
-- PlayerJournalModule:SearchPlayers already does the filtering/sorting
-- (linear scan, bounded by Maximum Stored Players -- the same "rare
-- enough to be cheap" reasoning ActivityHistoryService:GetByModule
-- already uses for its own linear scans); this tab only renders results
-- and lets clicking one open it (switches CurrentPlayerKey, jumps to
-- Overview). Also the entry point the end-of-run prompt opens into,
-- pre-filtered to that run's roster via PlayerJournalModule.LastRunRosterKeys.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerJournalWindow = AC.PlayerJournalWindow

function PlayerJournalWindow:BuildSearchControls(yOffset)

    if not self.SearchBox then

        local searchBox = CreateFrame("EditBox", nil, self.ScrollChild, "InputBoxTemplate")
        searchBox:SetSize(self.CONTENT_WIDTH - 100, 20)
        searchBox:SetAutoFocus(false)

        searchBox:SetScript("OnTextChanged", function()
            self:ShowTab("Search")
        end)

        searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        self.SearchBox = searchBox

        -- Named (not anonymous) -- CreateFrame(..., nil, ...) makes
        -- GetName() return nil (confirmed: Warcraft Wiki's own
        -- CreateFrame/GetName reference), and UICheckButtonTemplate's own
        -- label FontString is only reachable via the standard Blizzard
        -- "$parentText" XML naming convention, which needs a real parent
        -- name to resolve. Anonymous, this threw "attempt to concatenate
        -- a nil value" the moment this line ran (confirmed live) -- not a
        -- timing issue, a frame that could never have produced a name to
        -- concatenate in the first place.
        local favoritesOnlyButton = CreateFrame("CheckButton", "AzerothCompanionPlayerJournalFavoritesOnlyButton", self.ScrollChild, "UICheckButtonTemplate")
        favoritesOnlyButton:SetSize(20, 20)

        favoritesOnlyButton.text = _G[favoritesOnlyButton:GetName() .. "Text"]

        if favoritesOnlyButton.text then
            favoritesOnlyButton.text:SetText(AC.L:Get("PlayerJournal.FavoritesOnly"))
        end

        favoritesOnlyButton:SetScript("OnClick", function()
            self:ShowTab("Search")
        end)

        self.SearchFavoritesOnlyButton = favoritesOnlyButton

    end

    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetPoint("TOPLEFT", 6, yOffset)
    self.SearchBox:Show()

    self.SearchFavoritesOnlyButton:ClearAllPoints()
    self.SearchFavoritesOnlyButton:SetPoint("LEFT", self.SearchBox, "RIGHT", 8, 0)
    self.SearchFavoritesOnlyButton:Show()

    return yOffset - 28

end

function PlayerJournalWindow:BuildSearchResultRow()

    local row = CreateFrame("Button", nil, self.ScrollChild)
    row:EnableMouse(true)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    row:SetScript("OnEnter", function(self) self.Background:SetColorTexture(1, 1, 1, 0.06) end)
    row:SetScript("OnLeave", function(self) self.Background:SetColorTexture(1, 1, 1, 0) end)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", 4, 0)
    nameText:SetJustifyH("LEFT")

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    metaText:SetJustifyH("LEFT")

    row.NameText = nameText
    row.MetaText = metaText

    return row

end

function PlayerJournalWindow:BuildSearchTab()

    if not self.SearchResultPool then
        self.SearchResultPool = {}
    end

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    local yOffset = self:BuildSearchControls(-4)
    yOffset = yOffset - 8

    if not journalModule then

        for _, row in ipairs(self.SearchResultPool) do
            row:Hide()
        end

        return (-yOffset) + 16

    end

    local query = self.SearchBox:GetText()
    local favoritesOnly = self.SearchFavoritesOnlyButton:GetChecked() == true

    local resultKeys = journalModule:SearchPlayers(query, { favoritesOnly = favoritesOnly })

    if #resultKeys == 0 then

        for _, row in ipairs(self.SearchResultPool) do
            row:Hide()
        end

        local lines = { AC.L:Get("PlayerJournal.NoSearchResults") }
        yOffset = self:LayoutLines("Search", lines, yOffset, self.CONTENT_WIDTH)

        return (-yOffset) + 16

    end

    if self.Pools and self.Pools.Search then

        for _, row in ipairs(self.Pools.Search) do
            row:Hide()
        end

    end

    for index, playerKey in ipairs(resultKeys) do

        local record = journalModule:GetPlayerRecord(playerKey)

        if record then

            local row = self.SearchResultPool[index]

            if not row then
                row = self:BuildSearchResultRow()
                self.SearchResultPool[index] = row
            end

            row:SetSize(self.CONTENT_WIDTH, 32)
            row.NameText:SetText(record.name .. AC.L:Format("PlayerJournal.RealmSuffixFormat", record.realm) .. (record.tags["FavoritePlayer"] and " " .. AC.DashboardFormat.STAR_FILLED or ""))
            row.MetaText:SetText(AC.L:Format("PlayerJournal.SearchResultMetaFormat", record.stats.runsTogether, AC.Presentation.FormatDate(record.lastSeen, "short")))

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, yOffset)
            row:Show()

            row:SetScript("OnClick", function()
                self:Show(playerKey)
            end)

            yOffset = yOffset - 32 - 4

        end

    end

    for index = #resultKeys + 1, #self.SearchResultPool do
        self.SearchResultPool[index]:Hide()
    end

    return (-yOffset) + 16

end
