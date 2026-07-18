-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Window
--
-- The standalone BaseWindow for the Player Journal -- seven tabs
-- (Overview, History, Statistics, Personal Notes, Community Observations,
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
        PlayerJournalWindow:NavigateTab("Search")
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
local CONTENT_PADDING = AC.SharedScrollFrame.PADDING
local CONTENT_WIDTH = AC.SharedScrollFrame:ContentWidth(WINDOW_WIDTH, CONTENT_PADDING)
local TAB_BAR_HEIGHT = 26

local TABS = { "Overview", "History", "Statistics", "PersonalNotes", "CommunityObservations", "Timeline", "Search" }

-- Exposed so AC.NavigationService can derive Views.PlayerJournal from this
-- same list at its own Initialize() (Core/UI/Shared/NavigationService.lua)
-- rather than a second, independently-typed copy of these seven names.
PlayerJournalWindow.Tabs = TABS

local TAB_LABEL_KEY =
{
    Overview = "PlayerJournal.TabOverview",
    History = "PlayerJournal.TabHistory",
    Statistics = "PlayerJournal.TabStatistics",
    PersonalNotes = "PlayerJournal.TabPersonalNotes",
    CommunityObservations = "PlayerJournal.TabCommunityObservations",
    Timeline = "PlayerJournal.TabTimeline",
    Search = "PlayerJournal.TabSearch",
}

PlayerJournalWindow.CONTENT_WIDTH = CONTENT_WIDTH

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function PlayerJournalWindow:Initialize()

    self.Frame = BaseWindow:Create("AzerothCompanionPlayerJournal", AC.L:Get("PlayerJournal.WindowTitle"), WINDOW_WIDTH, WINDOW_HEIGHT)

    -- Atmosphere Pass -- the one standalone window that never picked up
    -- Dashboard/Settings/DeveloperPanel/InventoryManager's own shared
    -- ApplyWindowBackground/StyleWindowTitle pairing (Core/Presentation/
    -- Presentation.lua). Not a Player-Journal-specific visual choice --
    -- the same two calls every other BaseWindow already makes.
    AC.Presentation.ApplyWindowBackground(self.Frame)
    AC.Presentation.StyleWindowTitle(self.Frame.Title)

    AC.NavigationService:RegisterWindow(AC.NavigationService.Windows.PlayerJournal, self)

    BaseWindow:AddCloseButton(self.Frame, self)
    BaseWindow:AddBackButton(self.Frame, self)

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

    -- Navigation System -- BaseWindow:AddBackButton (below) claims the top
    -- left corner this title used to start flush against; BACK_BUTTON_RESERVE
    -- shifts the title right by the Back button's own footprint so the two
    -- never overlap, only when a Back button is actually showing (Player
    -- Journal is always reached through AC.NavigationService now, so one
    -- effectively always is once any navigation exists).
    local BACK_BUTTON_RESERVE = 62

    self.Frame.Title:ClearAllPoints()
    self.Frame.Title:SetPoint("TOPLEFT", CONTENT_PADDING + BACK_BUTTON_RESERVE, -16)
    self.Frame.Title:SetJustifyH("LEFT")
    self.Frame.Title:SetWidth(WINDOW_WIDTH - (CONTENT_PADDING * 2) - 60 - BACK_BUTTON_RESERVE)

    self.IdentityText = self.Frame.Title

    local favoriteButton = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
    favoriteButton:SetSize(90, 20)
    favoriteButton:SetPoint("TOPRIGHT", -32, -18)

    favoriteButton:SetScript("OnClick", function()

        local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

        if journalModule and self.CurrentPlayerKey and self.CurrentIdentity then
            journalModule:RecordRelationship(self.CurrentIdentity, journalModule.RelationshipTypes.Favorite)
            journalModule:ToggleTag(self.CurrentPlayerKey, "FavoritePlayer")
            self:RefreshIdentityHeader()
            self:ShowTab(self.CurrentTab)
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
            self:NavigateTab(tabName)
        end)

        self.TabButtons[tabName] = button
        previousTab = button

    end

    -----------------------------------------------------------------------
    -- Content Area
    -----------------------------------------------------------------------

    -- Scrollbar Extraction -- was a hand-rolled scrollFrame whose right
    -- anchor only reserved CONTENT_PADDING, never SCROLLBAR_RESERVE, even
    -- though CONTENT_WIDTH already assumed both were reserved -- a dead
    -- gutter inside the window AND a scrollbar with nowhere to render but
    -- past the window's true edge. AC.SharedScrollFrame:Create
    -- (Core/UI/Shared/ScrollFrame.lua) is now the single owner of that
    -- math, shared with Dashboard and Developer Panel.
    local scrollFrame, scrollChild = AC.SharedScrollFrame:Create(self.Frame, CONTENT_WIDTH, 42 + TAB_BAR_HEIGHT, CONTENT_PADDING, CONTENT_PADDING)

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

-------------------------------------------------------------------------------
-- Text/Meta Row
--
-- Shared shell for "a word-wrapped text line with a dimmed meta line
-- underneath it" -- Personal Notes' own note rows and Community
-- Observations' observation rows were two hand-written copies of this
-- exact same frame/anchor layout (the only difference between them is
-- which extra buttons, if any, each caller attaches afterward). One
-- shared builder here on the spine, since both are tabs of this same
-- window -- not promoted further up into Dashboard's generic Sections.lua,
-- where no consumer outside PlayerJournal exists today.
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildTextMetaRow()

    local row = CreateFrame("Frame", nil, self.ScrollChild)

    local textLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textLine:SetPoint("TOPLEFT", 6, 0)
    textLine:SetJustifyH("LEFT")
    textLine:SetWordWrap(true)

    local metaLine = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaLine:SetPoint("TOPLEFT", textLine, "BOTTOMLEFT", 0, -2)
    metaLine:SetJustifyH("LEFT")

    row.TextLine = textLine
    row.MetaLine = metaLine

    return row

end

-- UX Audit -- rendering/lifecycle fix. Confirmed live: switching tabs left
-- every previous tab's own widgets fully visible, overlapping the new
-- tab's content (Search's result rows and Favorites checkbox, Personal
-- Notes' tag grid, all still shown on top of Community Observations).
--
-- Root cause: this function used to only hide self.Pools[tabName] rows --
-- the bare FontString lines LayoutLines/GetPool manage. Every tab's OWN
-- dynamically-created widgets (buttons, edit boxes, checkboxes, and the
-- Frame-based rows BuildTextMetaRow/BuildSearchResultRow build) are
-- stored under their own tab-specific fields (self.SearchBox,
-- self.TagButtonPool, self.ObservationRowPool, etc.), entirely outside
-- self.Pools -- this function never knew they existed, so nothing ever
-- hid them on a tab switch. Not a Community Observations bug, or a
-- Search/Personal Notes bug -- every tab that creates anything other
-- than plain LayoutLines text independently falls into this same gap.
--
-- Fix: hide everything ScrollChild owns, unconditionally, before the
-- newly active tab's own Build<Tab>Tab() runs -- both GetChildren()
-- (Frame-type widgets: buttons, edit boxes, checkboxes, pooled row
-- frames) and GetRegions() (bare Region-type widgets: LayoutLines'
-- FontStrings, Personal Notes' TagGridHeader). This replaces the old
-- self.Pools-only sweep entirely rather than layering alongside it, since
-- it's a strict superset of what that sweep did. Safe even for the
-- soon-to-be-active tab's own widgets: every Build<Tab>Tab() already
-- re-:Show()s exactly what it currently needs on every single call
-- (that's how re-rendering the same tab already worked), so nothing
-- legitimate is lost -- only stale leftovers from whichever tab was
-- previously active. GetPool/LayoutLines' own reuse-across-refreshes
-- pooling (self.Pools) is unrelated to this and stays untouched.
function PlayerJournalWindow:ClearTabContent()

    for _, child in ipairs({ self.ScrollChild:GetChildren() }) do
        child:Hide()
    end

    for _, region in ipairs({ self.ScrollChild:GetRegions() }) do
        region:Hide()
    end

end

-------------------------------------------------------------------------------
-- Identity Header
-------------------------------------------------------------------------------

function PlayerJournalWindow:RefreshIdentityHeader()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey)
    local identity = record or self.CurrentIdentity

    if not identity then

        -- StyleWindowTitle (Initialize) colors this gold by default, same
        -- as every other BaseWindow's static title -- but this title
        -- doubles as a status line, and gold reads as "a real selection,"
        -- not "nothing selected." Reset to the same plain white the tab
        -- bar's own unselected buttons use (ShowTab, below) whenever
        -- there's no record to highlight gold for.
        self.IdentityText:SetText(AC.L:Get("PlayerJournal.NoPlayerSelected"))
        self.IdentityText:SetTextColor(1, 1, 1)
        self.FavoriteButton:Hide()

        return

    end

    self.IdentityText:SetText(identity.name .. AC.L:Format("PlayerJournal.RealmSuffixFormat", identity.realm))
    AC.DashboardFormat.SetHighlightColor(self.IdentityText)

    local isFavorite = record and journalModule:IsFavorite(self.CurrentPlayerKey)
    self.FavoriteButton:SetText(isFavorite and AC.L:Format("PlayerJournal.FavoriteOn", AC.DashboardFormat.STAR_FILLED) or AC.L:Get("PlayerJournal.FavoriteOff"))
    self.FavoriteButton:Show()

end

function PlayerJournalWindow:BuildUntrackedPlayerTab()

    local lines =
    {
        { text = AC.L:Get("PlayerJournal.UntrackedTitle"), r = 1, g = 0.82, b = 0 },
        AC.L:Get("PlayerJournal.UntrackedDescription"),
    }

    local yOffset = self:LayoutLines("UntrackedPlayer", lines, -4, self.CONTENT_WIDTH)

    if not self.AddToJournalButton then

        local button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        button:SetSize(130, 22)
        button:SetText(AC.L:Get("PlayerJournal.AddToJournal"))

        button:SetScript("OnClick", function()

            local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

            if journalModule and self.CurrentIdentity then
                journalModule:RecordRelationship(self.CurrentIdentity, journalModule.RelationshipTypes.Explicit)
                self:RefreshIdentityHeader()
                self:ShowTab(self.CurrentTab)
            end

        end)

        self.AddToJournalButton = button

    end

    self.AddToJournalButton:ClearAllPoints()
    self.AddToJournalButton:SetPoint("TOPLEFT", 6, yOffset - 4)
    self.AddToJournalButton:Show()

    return (-yOffset) + 42

end

-- Every tab except Search is scoped to whichever player CurrentPlayerKey
-- names -- Search is the one tab that browses the whole journal rather
-- than a single player, and is exactly where the shared "No Player
-- Selected" state below points.
local PLAYER_SCOPED_TABS =
{
    Overview = true,
    History = true,
    Statistics = true,
    PersonalNotes = true,
    CommunityObservations = true,
    Timeline = true,
}

-------------------------------------------------------------------------------
-- No Player Selected
--
-- UX Audit -- shell-owned. Every player-scoped tab used to duplicate this
-- exact check independently: Overview/Statistics/PersonalNotes each
-- rendered their own copy of "No player selected"; History/Timeline
-- instead conflated it with their own "nothing recorded yet" empty state
-- ("No run history with this player yet." reads as if a player IS
-- selected but has none -- misleading when nobody is selected at all);
-- Community Observations had no gate whatsoever, showing its own empty
-- state and a live Add Observation button with no player to act on. One
-- fact -- deciding whether a player is currently selected only ever
-- needs to happen once, here, before any player-scoped tab renders.
-------------------------------------------------------------------------------

function PlayerJournalWindow:BuildNoPlayerSelectedTab()

    local lines =
    {
        { text = AC.L:Get("PlayerJournal.NoPlayerSelectedTitle"), r = 1, g = 0.82, b = 0 },
        AC.L:Get("PlayerJournal.NoPlayerSelectedDescription"),
    }

    local yOffset = self:LayoutLines("NoPlayerSelected", lines, -4, self.CONTENT_WIDTH)

    yOffset = yOffset - 4

    if not self.NoPlayerGoToSearchButton then

        local button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        button:SetSize(130, 22)
        button:SetText(AC.L:Get("PlayerJournal.GoToSearch"))

        button:SetScript("OnClick", function()
            self:NavigateTab("Search")
        end)

        self.NoPlayerGoToSearchButton = button

    end

    self.NoPlayerGoToSearchButton:ClearAllPoints()
    self.NoPlayerGoToSearchButton:SetPoint("TOPLEFT", 6, yOffset)
    self.NoPlayerGoToSearchButton:Show()

    yOffset = yOffset - 22

    return (-yOffset) + 16

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

    self:ClearTabContent()

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local hasPlayer = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey) ~= nil
    local hasIdentity = self.CurrentIdentity ~= nil
    local supportsUntracked = tabName == "PersonalNotes" or tabName == "CommunityObservations"

    local contentHeight = 1

    if PLAYER_SCOPED_TABS[tabName] and not hasIdentity then

        contentHeight = self:BuildNoPlayerSelectedTab()

    elseif PLAYER_SCOPED_TABS[tabName] and not hasPlayer and not supportsUntracked then

        contentHeight = self:BuildUntrackedPlayerTab()

    else

        if tabName == "Overview" and self.BuildOverviewTab then
            contentHeight = self:BuildOverviewTab()
        elseif tabName == "History" and self.BuildHistoryTab then
            contentHeight = self:BuildHistoryTab()
        elseif tabName == "Statistics" and self.BuildStatisticsTab then
            contentHeight = self:BuildStatisticsTab()
        elseif tabName == "PersonalNotes" and self.BuildPersonalNotesTab then
            contentHeight = self:BuildPersonalNotesTab()
        elseif tabName == "CommunityObservations" and self.BuildCommunityObservationsTab then
            contentHeight = self:BuildCommunityObservationsTab()
        elseif tabName == "Timeline" and self.BuildTimelineTab then
            contentHeight = self:BuildTimelineTab()
        elseif tabName == "Search" and self.BuildSearchTab then
            contentHeight = self:BuildSearchTab()
        end

    end

    self.ScrollChild:SetHeight(math.max(contentHeight or 1, 1))
    self.ScrollFrame:SetVerticalScroll(0)

end

-- Sibling-tab switch (the tab bar, the shell's own "Go to Search" button)
-- -- Overview/History/Statistics/etc. for the SAME player are lateral, not
-- a drill-down, so this updates the navigation stack's current entry
-- in place (AC.NavigationService:Replace) rather than pushing a new one.
-- A later cross-window GoBack still lands on whichever tab was actually
-- last viewed, without every tab click becoming its own back-step.
function PlayerJournalWindow:NavigateTab(tabName)

    self:ShowTab(tabName)

    AC.NavigationService:Replace(AC.NavigationService.Windows.PlayerJournal, tabName,
        { playerKey = self.CurrentPlayerKey, identity = self.CurrentIdentity })

end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------

-- The one entry point every external caller (context menu, the end-of-run
-- popup) and Search's own result-row click already use -- always a real
-- drill-down (a specific player, possibly a different one from whatever
-- was showing before), so this always pushes through AC.NavigationService
-- rather than rendering directly. RestoreNavigation below is the other
-- half -- the actual render logic (RefreshIdentityHeader/ShowTab) lives
-- there now, reached identically whether by a fresh Show(), GoBack(), or
-- ESC.
function PlayerJournalWindow:Show(playerKey, identity)

    local view = playerKey and AC.NavigationService.Views.PlayerJournal.Overview
        or self.CurrentTab
        or AC.NavigationService.Views.PlayerJournal.Overview
    local targetIdentity = identity or (not playerKey and self.CurrentIdentity)

    AC.NavigationService:Push(AC.NavigationService.Windows.PlayerJournal, view,
        { playerKey = playerKey or self.CurrentPlayerKey, identity = targetIdentity })

end

-- Dispatched here by AC.NavigationService:Restore().
function PlayerJournalWindow:RestoreNavigation(entry)

    self.CurrentPlayerKey = entry.Context and entry.Context.playerKey

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local record = journalModule and self.CurrentPlayerKey and journalModule:GetPlayerRecord(self.CurrentPlayerKey)
    self.CurrentIdentity = record or (entry.Context and entry.Context.identity)

    if entry.View == "Search" and entry.Context then
        if self.SearchBox and entry.Context.searchText ~= nil then
            self.SearchBox:SetText(entry.Context.searchText)
        end
        if self.SearchFavoritesOnlyButton and entry.Context.favoritesOnly ~= nil then
            self.SearchFavoritesOnlyButton:SetChecked(entry.Context.favoritesOnly)
        end
    end

    self.Frame:Show()
    self:RefreshIdentityHeader()
    self:ShowTab(entry.View)

    if entry.Context and entry.Context.scrollPosition then
        self.ScrollFrame:SetVerticalScroll(entry.Context.scrollPosition)
    end

end

function PlayerJournalWindow:CaptureNavigation(entry)

    entry.Context = entry.Context or {}
    entry.Context.playerKey = self.CurrentPlayerKey
    entry.Context.identity = self.CurrentIdentity
    entry.Context.scrollPosition = self.ScrollFrame and self.ScrollFrame:GetVerticalScroll() or 0

    if entry.View == "Search" then
        entry.Context.searchText = self.SearchBox and self.SearchBox:GetText() or ""
        entry.Context.favoritesOnly = self.SearchFavoritesOnlyButton and self.SearchFavoritesOnlyButton:GetChecked() == true or false
    end

end

function PlayerJournalWindow:Hide()

    if self.Frame then
        if not AC.NavigationService:GoBackIfCurrent(self) then
            self.Frame:Hide()
        end
    end

end

function PlayerJournalWindow:Toggle(playerKey)

    if self.Frame and self.Frame:IsShown() and not playerKey
    and AC.NavigationService:IsCurrent(self) then
        AC.NavigationService:GoBack()
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
