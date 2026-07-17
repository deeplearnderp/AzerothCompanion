-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window
--
-- The standalone BaseWindow for the Player Journal -- seven tabs
-- (Overview, History, Statistics, Personal Notes, Community Notes,
-- Timeline, Search), matching Dashboard styling. This file is the spine
-- only (window shell, tab bar, ScrollFrame, pooled-row helpers, tab
-- dispatch) -- one Build<X>Tab() method per tab lives in its own file
-- under Core/UI/PlayerJournal/Tabs/, added onto this same shared table,
-- the same spine-then-leaves split the Dashboard framework uses for Pages/*.lua
-- (and the same reason: the load order in the .toc puts this file before
-- every Tabs/*.lua file, since they add methods onto AC.PlayerJournalWindow
-- rather than this file needing to know about them).
--
-- Show(playerKey) takes a stable id, not a live object -- a deliberate
-- divergence from Dashboard:ShowRecommendationDetails(recommendation)
-- (Core/UI/Dashboard/Navigation.lua), which takes a live object
-- specifically because Recommendations are rebuilt from scratch every
-- refresh with no stable identity. Player Journal
-- records are real persisted state with a stable identity ("Name-Realm"),
-- so re-reading by id on every tab switch/refresh is both correct and
-- simpler than threading a live table reference through every tab file.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow

local PlayerJournalWindow = {}
AC.PlayerJournalWindow = PlayerJournalWindow

-------------------------------------------------------------------------------
-- End-of-Run Prompt
--
-- Shown from OnPlayerJournalRunRecorded (below) -- matches
-- Blizzard's standard StaticPopupDialogs confirmation pattern. "Yes"
-- opens the Journal on the Search tab, pre-filtered to
-- that run's roster (PendingEndOfRunRosterKeys) -- rather than guessing
-- which one companion the player wants to note.
-------------------------------------------------------------------------------

StaticPopupDialogs["AZEROTHCOMPANION_PLAYERJOURNAL_ENDOFRUN"] =
{
    text = "",
    button1 = _G.YES or "Yes",
    button2 = _G.NO or "No",
    OnAccept = function()
        PlayerJournalWindow:Show()
        PlayerJournalWindow:ShowTab("Search")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local WINDOW_WIDTH = 520
local WINDOW_HEIGHT = 600
local CONTENT_PADDING = 16
local SCROLLBAR_RESERVE = 24
local CONTENT_WIDTH = WINDOW_WIDTH - (CONTENT_PADDING * 2) - SCROLLBAR_RESERVE
local TAB_BAR_HEIGHT = 26

local TABS = { "Overview", "History", "Statistics", "PersonalNotes", "CommunityNotes", "Timeline", "Search" }

local TAB_LABEL_KEY =
{
    Overview = "PlayerJournal.TabOverview",
    History = "PlayerJournal.TabHistory",
    Statistics = "PlayerJournal.TabStatistics",
    PersonalNotes = "PlayerJournal.TabPersonalNotes",
    CommunityNotes = "PlayerJournal.TabCommunityNotes",
    Timeline = "PlayerJournal.TabTimeline",
    Search = "PlayerJournal.TabSearch",
}

PlayerJournalWindow.CONTENT_WIDTH = CONTENT_WIDTH

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function PlayerJournalWindow:Initialize()

    self.Frame = BaseWindow:Create("AzerothCompanionPlayerJournal", AC.L:Get("PlayerJournal.WindowTitle"), WINDOW_WIDTH, WINDOW_HEIGHT)

    BaseWindow:AddCloseButton(self.Frame, self)

    -----------------------------------------------------------------------
    -- Identity Header -- name/realm/class of whichever player this
    -- window currently shows, always visible above the tabs regardless
    -- of which one is active.
    --
    -- Presentation System v2 -- BaseWindow already creates self.Frame.Title.
    -- Reposition it to double as the identity header (mirroring Home.lua's
    -- own precedent: "reposition it... rather than layering a second title
    -- on top of it") instead of the separate GameFontNormalLarge FontString
    -- this used to create, which duplicated it.
    -----------------------------------------------------------------------

    self.Frame.Title:ClearAllPoints()
    self.Frame.Title:SetPoint("TOPLEFT", CONTENT_PADDING, -16)
    self.Frame.Title:SetJustifyH("LEFT")
    self.Frame.Title:SetWidth(WINDOW_WIDTH - (CONTENT_PADDING * 2) - 60)

    self.IdentityText = self.Frame.Title

    local favoriteButton = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
    favoriteButton:SetSize(90, 20)
    favoriteButton:SetPoint("TOPRIGHT", -32, -18)

    favoriteButton:SetScript("OnClick", function()

        local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

        if journalModule and self.CurrentPlayerKey then
            journalModule:ToggleTag(self.CurrentPlayerKey, "FavoritePlayer")
            self:RefreshIdentityHeader()
        end

    end)

    self.FavoriteButton = favoriteButton

    -----------------------------------------------------------------------
    -- Tab Bar
    -----------------------------------------------------------------------

    self.TabButtons = {}

    local previousTab

    for _, tabName in ipairs(TABS) do

        local button = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
        button:SetSize(64, 22)

        if previousTab then
            button:SetPoint("LEFT", previousTab, "RIGHT", 2, 0)
        else
            button:SetPoint("TOPLEFT", CONTENT_PADDING, -42)
        end

        button:SetText(AC.L:Get(TAB_LABEL_KEY[tabName]))

        button:SetScript("OnClick", function()
            self:ShowTab(tabName)
        end)

        self.TabButtons[tabName] = button
        previousTab = button

    end

    -----------------------------------------------------------------------
    -- Content Area
    -----------------------------------------------------------------------

    local scrollFrame = CreateFrame("ScrollFrame", nil, self.Frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PADDING, -42 - TAB_BAR_HEIGHT)
    scrollFrame:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    self.ScrollFrame = scrollFrame
    self.ScrollChild = scrollChild
    self.Pools = {}

    self.CurrentTab = "Overview"

end

-------------------------------------------------------------------------------
-- Enable -- listens for PlayerJournalModule's own PLAYER_JOURNAL_RUN_RECORDED
-- (fired only when the "Prompt After Mythic+ Runs" setting is on), and
-- shows the end-of-run StaticPopup. This is the intended listener
-- EventManager's own FrameworkEvents entry for that event names -- the
-- module that fires it never touches presentation directly.
-------------------------------------------------------------------------------

function PlayerJournalWindow:Enable()

    AC.Events:Register("PLAYER_JOURNAL_RUN_RECORDED", self)

end

function PlayerJournalWindow:OnPlayerJournalRunRecorded(rosterKeys)

    self.PendingEndOfRunRosterKeys = rosterKeys

    local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_ENDOFRUN")

    if dialog then
        dialog.text:SetText(AC.L:Get("PlayerJournal.EndOfRunPromptText"))
    end

end

-------------------------------------------------------------------------------
-- Pooled Row Helpers -- same shape as DeveloperPanel's own GetPool/
-- LayoutLines (dense text lines, one pool per tab, hidden not destroyed
-- when a tab's row count shrinks).
-------------------------------------------------------------------------------

function PlayerJournalWindow:GetPool(tabName)

    self.Pools[tabName] = self.Pools[tabName] or {}

    return self.Pools[tabName]

end

function PlayerJournalWindow:LayoutLines(tabName, lines, yOffset, contentWidth, fontTemplate)

    local pool = self:GetPool(tabName)

    for index, line in ipairs(lines) do

        local row = pool[index]

        if not row then

            row = self.ScrollChild:CreateFontString(nil, "OVERLAY", fontTemplate or "GameFontHighlightSmall")
            row:SetJustifyH("LEFT")
            row:SetWordWrap(true)
            pool[index] = row

        end

        row:SetFontObject(fontTemplate or "GameFontHighlightSmall")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:SetWidth(contentWidth)

        if type(line) == "table" then
            row:SetText(line.text or "")
            row:SetTextColor(line.r or 0.9, line.g or 0.9, line.b or 0.9)
        else
            row:SetText(tostring(line))
            row:SetTextColor(0.9, 0.9, 0.9)
        end

        row:Show()

        yOffset = yOffset - (row:GetStringHeight() or 14) - 4

    end

    for index = #lines + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

function PlayerJournalWindow:HideOtherTabs(activeTab)

    for tabName, pool in pairs(self.Pools) do

        if tabName ~= activeTab then
            for _, row in ipairs(pool) do
                row:Hide()
            end
        end

    end

end

-------------------------------------------------------------------------------
-- Identity Header
-------------------------------------------------------------------------------

function PlayerJournalWindow:RefreshIdentityHeader()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey)

    if not record then

        self.IdentityText:SetText(AC.L:Get("PlayerJournal.NoPlayerSelected"))
        self.FavoriteButton:Hide()

        return

    end

    self.IdentityText:SetText(record.name .. AC.L:Format("PlayerJournal.RealmSuffixFormat", record.realm))
    AC.DashboardFormat.SetHighlightColor(self.IdentityText)

    local isFavorite = journalModule:IsFavorite(self.CurrentPlayerKey)
    self.FavoriteButton:SetText(isFavorite and AC.L:Format("PlayerJournal.FavoriteOn", AC.DashboardFormat.STAR_FILLED) or AC.L:Get("PlayerJournal.FavoriteOff"))
    self.FavoriteButton:Show()

end

-------------------------------------------------------------------------------
-- Show Tab
-------------------------------------------------------------------------------

function PlayerJournalWindow:ShowTab(tabName)

    self.CurrentTab = tabName

    for name, button in pairs(self.TabButtons) do

        if name == tabName then
            AC.DashboardFormat.SetHighlightColor(button:GetFontString())
        else
            button:GetFontString():SetTextColor(1, 1, 1)
        end

    end

    self:HideOtherTabs(tabName)

    local contentHeight = 1

    if tabName == "Overview" and self.BuildOverviewTab then
        contentHeight = self:BuildOverviewTab()
    elseif tabName == "History" and self.BuildHistoryTab then
        contentHeight = self:BuildHistoryTab()
    elseif tabName == "Statistics" and self.BuildStatisticsTab then
        contentHeight = self:BuildStatisticsTab()
    elseif tabName == "PersonalNotes" and self.BuildPersonalNotesTab then
        contentHeight = self:BuildPersonalNotesTab()
    elseif tabName == "CommunityNotes" and self.BuildCommunityNotesTab then
        contentHeight = self:BuildCommunityNotesTab()
    elseif tabName == "Timeline" and self.BuildTimelineTab then
        contentHeight = self:BuildTimelineTab()
    elseif tabName == "Search" and self.BuildSearchTab then
        contentHeight = self:BuildSearchTab()
    end

    self.ScrollChild:SetHeight(math.max(contentHeight or 1, 1))
    self.ScrollFrame:SetVerticalScroll(0)

end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------

function PlayerJournalWindow:Show(playerKey)

    if playerKey then
        self.CurrentPlayerKey = playerKey
    end

    self:RefreshIdentityHeader()
    self:ShowTab(self.CurrentTab or "Overview")
    self.Frame:Show()

end

function PlayerJournalWindow:Hide()

    if self.Frame then
        self.Frame:Hide()
    end

end

function PlayerJournalWindow:Toggle(playerKey)

    if self.Frame and self.Frame:IsShown() and not playerKey then
        self:Hide()
    else
        self:Show(playerKey)
    end

end

-------------------------------------------------------------------------------
-- Register
--
-- Registered as a Module (same as DeveloperPanel, also a standalone
-- window under Core/UI/) so Initialize() runs
-- automatically during ModuleManager:InitializeModules() -- self.Frame
-- always exists by the time anything calls Show()/Toggle(), no lazy-init
-- guard needed.
-------------------------------------------------------------------------------

AC.Core:RegisterModule("PlayerJournalWindow", PlayerJournalWindow)

return PlayerJournalWindow
