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

local RELATIONSHIP_FILTER_ORDER =
{
    "Favorite",
    "PersonalNote",
    "CommunityObservation",
    "PersonalTag",
    "Friend",
    "Guild",
    "MythicPlus",
    "Raid",
    "Delve",
    "Dungeon",
    "RandomQueue",
    "Party",
    "Whisper",
    "Explicit",
}

local RELATIONSHIP_LABEL_KEYS =
{
    Favorite = "PlayerJournal.RelationshipFavorite",
    PersonalNote = "PlayerJournal.RelationshipPersonalNote",
    CommunityObservation = "PlayerJournal.RelationshipCommunityObservation",
    PersonalTag = "PlayerJournal.RelationshipPersonalTag",
    Friend = "PlayerJournal.RelationshipFriend",
    Guild = "PlayerJournal.RelationshipGuild",
    MythicPlus = "PlayerJournal.RelationshipMythicPlus",
    Raid = "PlayerJournal.RelationshipRaid",
    Delve = "PlayerJournal.RelationshipDelve",
    Dungeon = "PlayerJournal.RelationshipDungeon",
    RandomQueue = "PlayerJournal.RelationshipRandomQueue",
    Party = "PlayerJournal.RelationshipParty",
    Whisper = "PlayerJournal.RelationshipWhisper",
    Explicit = "PlayerJournal.RelationshipExplicit",
    Legacy = "PlayerJournal.RelationshipLegacy",
}

local COUNTED_RELATIONSHIPS =
{
    MythicPlus = "PlayerJournal.RelationshipRunsFormat",
    Raid = "PlayerJournal.RelationshipActivitiesFormat",
    Delve = "PlayerJournal.RelationshipActivitiesFormat",
    Dungeon = "PlayerJournal.RelationshipActivitiesFormat",
    RandomQueue = "PlayerJournal.RelationshipActivitiesFormat",
    Party = "PlayerJournal.RelationshipActivitiesFormat",
}

local function GetRelationshipLabel(relationshipType)

    local key = RELATIONSHIP_LABEL_KEYS[relationshipType]
    return key and AC.L:Get(key) or relationshipType

end

local function FormatRelationship(relationship)

    local label = GetRelationshipLabel(relationship.type)
    local countFormat = COUNTED_RELATIONSHIPS[relationship.type]

    if countFormat then
        return AC.L:Format(countFormat, label, relationship.count or 0)
    end

    if relationship.type == "PersonalNote" and (relationship.count or 0) > 1 then
        return AC.L:Format("PlayerJournal.RelationshipNotesFormat", relationship.count)
    end

    if relationship.type == "CommunityObservation" and (relationship.count or 0) > 1 then
        return AC.L:Format("PlayerJournal.RelationshipObservationsFormat", relationship.count)
    end

    return label

end

function PlayerJournalWindow:GetRelationshipFilterOptions(journalModule)

    local available = journalModule:GetAvailableRelationshipTypes()
    local options = { { type = nil, label = AC.L:Get("PlayerJournal.FilterAllRelationships") } }

    for _, relationshipType in ipairs(RELATIONSHIP_FILTER_ORDER) do
        if available[relationshipType] then
            table.insert(options, { type = relationshipType, label = GetRelationshipLabel(relationshipType) })
        end
    end

    return options

end

function PlayerJournalWindow:RefreshRelationshipFilter(journalModule)

    local options = self:GetRelationshipFilterOptions(journalModule)
    local selectedType = self.SearchRelationshipFilter
    local selectedLabel = options[1].label
    local selectedAvailable = selectedType == nil

    for _, option in ipairs(options) do
        if option.type == selectedType then
            selectedAvailable = true
            selectedLabel = option.label
            break
        end
    end

    if not selectedAvailable then
        self.SearchRelationshipFilter = nil
        selectedLabel = options[1].label
    end

    self.SearchRelationshipDropdown:SetDefaultText(selectedLabel)
    self.SearchRelationshipDropdown:SetupMenu(function(_, rootDescription)

        for _, option in ipairs(options) do
            local relationshipType = option.type
            local label = option.label

            rootDescription:CreateButton(label, function()
                self.SearchRelationshipFilter = relationshipType
                self:ShowTab("Search")
            end)
        end

    end)

end

function PlayerJournalWindow:BuildSearchControls(yOffset)

    if not self.SearchBox then

        local searchBox = CreateFrame("EditBox", nil, self.ScrollChild, "InputBoxTemplate")
        searchBox:SetSize(self.CONTENT_WIDTH - 174, 20)
        searchBox:SetAutoFocus(false)

        searchBox:SetScript("OnTextChanged", function()
            self:ShowTab("Search")
        end)

        searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        self.SearchBox = searchBox

        local relationshipDropdown = CreateFrame("DropdownButton", nil, self.ScrollChild, "WowStyle1DropdownTemplate")
        relationshipDropdown:SetSize(164, 20)

        self.SearchRelationshipDropdown = relationshipDropdown
        self.SearchRelationshipFilter = nil

    end

    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetPoint("TOPLEFT", 6, yOffset)
    self.SearchBox:Show()

    self.SearchRelationshipDropdown:ClearAllPoints()
    self.SearchRelationshipDropdown:SetPoint("LEFT", self.SearchBox, "RIGHT", 8, 0)
    self.SearchRelationshipDropdown:Show()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    if journalModule then
        self:RefreshRelationshipFilter(journalModule)
    end

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
    nameText:SetWidth(self.CONTENT_WIDTH - 8)
    nameText:SetWordWrap(false)

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    metaText:SetJustifyH("LEFT")
    metaText:SetWidth(self.CONTENT_WIDTH - 8)
    metaText:SetWordWrap(false)

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
    local resultKeys = journalModule:SearchPlayers(query, { relationshipType = self.SearchRelationshipFilter })

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
            row.NameText:SetText(record.name .. AC.L:Format("PlayerJournal.RealmSuffixFormat", record.realm))

            local summaries = {}

            for relationshipIndex, relationship in ipairs(journalModule:GetRelationships(playerKey)) do
                if relationshipIndex > 3 then
                    break
                end
                table.insert(summaries, FormatRelationship(relationship))
            end

            row.MetaText:SetText(table.concat(summaries, "   "))

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
