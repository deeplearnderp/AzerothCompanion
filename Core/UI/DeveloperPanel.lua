-------------------------------------------------------------------------------
-- Azeroth Companion
-- Developer Panel
--
-- The permanent developer-tooling surface for Azeroth Companion: eleven pages
-- organized into Console, Runtime, Blizzard APIs, and Data & Maintenance
-- navigation groups inside one standalone window (BaseWindow, same tier as
-- DiagnosticsWindow/SettingsWindow), shown from /ac dev or the Dashboard's
-- Developer button once Developer Mode is enabled.
--
-- Presentation only, exactly like the Dashboard: every value shown here is
-- read through an existing public getter (CharacterModule:GetProfile(),
-- MythicPlusModule:GetProfile(), RecommendationEngine:GetRecommendations(),
-- ActivityHistoryService:GetByModule(), ...) or from
-- AC.DeveloperModeService's own observation state (event log, Refresh
-- timing). Nothing here computes a new gameplay fact, and nothing here
-- runs, registers, or costs anything while Developer Mode is disabled --
-- Show()/Toggle() below are the only entry points, and they refuse to do
-- anything at all unless AC.DeveloperModeService:IsEnabled() is true.
--
-- The one exception to "read-only observation," and a deliberate one: the
-- Live API Inspector tab calls a handful of real Blizzard APIs directly
-- (Weekly/Vault, Storage/Bank, Mythic+, Affixes) rather than only reading
-- through a module's own cached Profile -- the same precedent
-- Core/Diagnostics/DiagnosticsService.lua already established ("diagnostic
-- instrumentation reading raw Blizzard state is not a Dashboard-rule
-- violation; that rule governs the player-facing presentation layer").
-- Every one of those calls is pcall-wrapped, on-demand only (a button
-- press, never polled), and reuses the exact API names/enums each owning
-- module's own file already documents -- never a new guess at a Blizzard
-- API shape.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow

local DeveloperPanel = {}
AC.DeveloperPanel = DeveloperPanel

-------------------------------------------------------------------------------
-- Pages and Navigation Groups
-------------------------------------------------------------------------------

local TABS = { "Overview", "Modules", "CombatSession", "Events", "Errors", "SecretValues", "LiveAPI", "APIExplorer", "Checklist", "History", "Maintenance" }
DeveloperPanel.Tabs = TABS

local NAVIGATION_GROUPS =
{
    { key = "Console", labelKey = "Developer.NavConsole", tabs = { "Overview", "Modules", "CombatSession" } },
    { key = "Runtime", labelKey = "Developer.NavRuntime", tabs = { "Events", "Errors", "SecretValues" } },
    { key = "APIs", labelKey = "Developer.NavAPIs", tabs = { "LiveAPI", "APIExplorer", "Checklist" } },
    { key = "Data", labelKey = "Developer.NavData", tabs = { "History", "Maintenance" } },
}

local TAB_GROUP = {}

for _, group in ipairs(NAVIGATION_GROUPS) do
    for _, tabName in ipairs(group.tabs) do
        TAB_GROUP[tabName] = group.key
    end
end

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local CONTENT_PADDING = AC.SharedScrollFrame.PADDING

-- Grouped navigation keeps page count independent from window width.
local TAB_BUTTON_WIDTH = 120
local TAB_BUTTON_GAP = 4
local NAV_GROUP_BUTTON_WIDTH = 140
local WINDOW_WIDTH = 1040
local WINDOW_HEIGHT = 620
local CONTENT_WIDTH = AC.SharedScrollFrame:ContentWidth(WINDOW_WIDTH, CONTENT_PADDING)
local TAB_BAR_HEIGHT = 52
local FOOTER_HEIGHT = 68
local ROW_HEIGHT = 16
local MAINTENANCE_ACTION_HEIGHT = 58
local MAINTENANCE_ACTION_GAP = 8
local PAGE_CONTENT_TOP = -4
local TOOLBAR_CONTENT_TOP = -34

-- Header layout. TITLE_TOP_OFFSET
-- matches BaseWindow:Create's own title anchor (-12) -- not a new,
-- independently-guessed number -- and the title's actual rendered height
-- is measured at Initialize() time rather than assumed, so this stays
-- correct if the title text or font ever changes. HEADER_GAP is the one
-- small breathing-room constant this file adds.
local TITLE_TOP_OFFSET = 12
local HEADER_GAP = 8

local TAB_LABEL_KEY =
{
    Overview = "Developer.TabOverview",
    Modules = "Developer.TabModules",
    CombatSession = "Developer.TabCombatSession",
    Events = "Developer.TabEvents",
    Errors = "Developer.TabErrors",
    SecretValues = "Developer.TabSecretValues",
    LiveAPI = "Developer.TabLiveAPI",
    APIExplorer = "Developer.TabAPIExplorer",
    Checklist = "Developer.TabChecklist",
    History = "Developer.TabHistory",
    Maintenance = "Developer.TabMaintenance",
}

-------------------------------------------------------------------------------
-- Module Routing (mirrors Pages/RecommendationDetails.lua's own map -- the
-- module name -> display name convention used addon-wide for dev/diagnostic UI).
-------------------------------------------------------------------------------

local MODULE_DISPLAY_KEY =
{
    MythicPlus = "Dashboard.MythicPlus",
    Inventory = "Dashboard.Inventory",
    Storage = "Dashboard.Storage",
    Weekly = "Dashboard.Weekly",
    Accomplishments = "Dashboard.Accomplishments",
    Profile = "Dashboard.Profile",
    Character = "Dashboard.Profile",
}

local function DisplayName(name)

    local key = MODULE_DISPLAY_KEY[name]

    return key and AC.L:Get(key) or name

end

-------------------------------------------------------------------------------
-- Generic Row Helpers
--
-- A minimal pooled label-list, shared by every dense simple-text tab -- each
-- tab owns one pool (self.Pools[tabName]) of plain FontStrings, laid out
-- top-to-bottom. Overview and Maintenance use Dashboard's shared hero/grid/
-- section primitives where their information hierarchy genuinely matches;
-- the remaining tabs keep this denser renderer rather than forcing every
-- diagnostic line into a player-facing card shape.
--
-- The Errors tab is the one deliberate exception: it needs real
-- expand/collapse behavior, which this file has no primitive of its own
-- for, so it calls AC.Dashboard:LayoutAccordionRows directly (the same
-- shared engine Accomplishments/Journey/MythicPlus already call directly,
-- not through a page-specific wrapper) rather than maintain a second
-- accordion implementation. It still writes into this file's own
-- self.Pools table (poolKey "Errors"), so HideOtherTabs' existing generic
-- loop already covers it with no special-casing -- see BuildErrorsTab.
-------------------------------------------------------------------------------

function DeveloperPanel:GetPool(tabName)

    self.Pools = self.Pools or {}
    self.Pools[tabName] = self.Pools[tabName] or {}

    return self.Pools[tabName]

end

function DeveloperPanel:LayoutLines(tabName, lines, yOffset, contentWidth, fontTemplate)

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

        yOffset = yOffset - (row:GetStringHeight() or ROW_HEIGHT) - 4

    end

    for index = #lines + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

function DeveloperPanel:LayoutLinesOrEmpty(tabName, lines, yOffset, contentWidth, emptyTextKey)

    local pool = self:GetPool(tabName)

    if #lines == 0 then
        for _, row in ipairs(pool) do
            row:Hide()
        end

        return AC.Dashboard:ShowEmptyLine(pool, self.ScrollChild, "EmptyText", yOffset, contentWidth, emptyTextKey)
    end

    if pool.EmptyText then
        pool.EmptyText:Hide()
    end

    return self:LayoutLines(tabName, lines, yOffset, contentWidth)

end

-- A pool's storage key doesn't always equal its owning tab's name -- the
-- Modules tab needs two independent pools (title lines, stats lines)
-- sharing one yOffset loop, so they're stored under their own keys. This
-- is the one place that split is reconciled back to "which tab owns this
-- pool" for hide/show purposes.
local POOL_TAB_OWNER =
{
    ModulesTitle = "Modules",
    ModulesStats = "Modules",
    ModulesIntro = "Modules",
    ChecklistIntro = "Checklist",
    OverviewHeroStats = "Overview",
    OverviewProperties = "Overview",
    APIExplorerResults = "APIExplorer",
    CombatSessionStatus = "CombatSession",
    CombatSessionCache = "CombatSession",
    CombatSessionLatest = "CombatSession",
    CombatSessionParticipants = "CombatSession",
    CombatSessionDeaths = "CombatSession",
    LiveAPISummary = "LiveAPI",
}

-- Hides every pooled row belonging to a tab other than the one now active
-- -- switching tabs never destroys widgets, only hides them (reused if
-- that tab is revisited).
function DeveloperPanel:HideOtherTabs(activeTab)

    self.Pools = self.Pools or {}

    for _, header in pairs(self.ScrollChild and self.ScrollChild.SectionHeaders or {}) do
        header:Hide()
    end

    for poolKey, pool in pairs(self.Pools) do

        local owner = POOL_TAB_OWNER[poolKey] or poolKey

        if owner ~= activeTab then

            for _, row in ipairs(pool) do
                row:Hide()
            end

            -- Errors tab addition: LayoutAccordionRows' own empty-state
            -- line (Dashboard:ShowEmptyLine) caches itself on pool.EmptyText
            -- -- a string key ipairs() above never reaches, so it needs its
            -- own explicit hide or it would linger on screen over whatever
            -- tab is switched to next. No existing DeveloperPanel tab
            -- exercised this cached-empty-state convention before Errors,
            -- so this gap was real but previously unreachable.
            if pool.EmptyText then
                pool.EmptyText:Hide()
            end

        end

    end

    -- Live API's result rows and History's filter buttons live in their
    -- own dedicated pools (LiveAPIResults / HistoryButtons / HistoryRows)
    -- covered by the loop above since they're stored the same way; the
    -- Modules tab's per-row Refresh buttons need the same treatment since
    -- they are real interactive frames, not just text.
    if self.ModuleRefreshButtons and activeTab ~= "Modules" then
        for _, button in ipairs(self.ModuleRefreshButtons) do
            button:Hide()
        end
    end

    if self.HistoryFilterButtons and activeTab ~= "History" then
        for _, button in ipairs(self.HistoryFilterButtons) do
            button:Hide()
        end
    end

    if self.LiveAPIButtons and activeTab ~= "LiveAPI" then
        for _, button in ipairs(self.LiveAPIButtons) do
            button:Hide()
        end
    end

    if self.LiveAPIVerifyButtons and activeTab ~= "LiveAPI" then
        for _, pair in pairs(self.LiveAPIVerifyButtons) do
            pair.verified:Hide()
            pair.failed:Hide()
        end
    end

    if self.APIExplorerControls and activeTab ~= "APIExplorer" then
        self.APIExplorerControls:Hide()
    end
    if activeTab ~= "APIExplorer" then
        for _, button in ipairs(self.APIExplorerNavButtons or {}) do button:Hide() end
        for _, row in ipairs(self.APIExplorerNodeRows or {}) do row:Hide() end
    end

    if self.ChecklistRows and activeTab ~= "Checklist" then
        for _, row in ipairs(self.ChecklistRows) do
            row.Label:Hide()
            row.Detail:Hide()
            row.Button:Hide()
        end
    end

    if self.Hero and activeTab ~= "Overview" then
        self.Hero.Headline:Hide()
        self.Hero.Value:Hide()
        self.Hero.Caption:Hide()
    end

    if self.MaintenanceContainer and activeTab ~= "Maintenance" then
        self.MaintenanceContainer:Hide()
    end

    if self.ActionControls and activeTab ~= "Overview" then
        self.ActionControls:Hide()
    end

    for tabName, toolbar in pairs(self.PageToolbars or {}) do
        toolbar:SetShown(tabName == activeTab)
    end

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function DeveloperPanel:Initialize()

    self.Frame = BaseWindow:Create("AzerothCompanionDeveloperPanel", AC.L:Get("Developer.Title"), WINDOW_WIDTH, WINDOW_HEIGHT)

    AC.Presentation.ApplyWindowBackground(self.Frame)
    AC.Presentation.StyleWindowTitle(self.Frame.Title)

    AC.NavigationService:RegisterWindow(AC.NavigationService.Windows.DeveloperPanel, self)

    BaseWindow:AddCloseButton(self.Frame, self)
    BaseWindow:AddBackButton(self.Frame, self)

    -----------------------------------------------------------------------
    -- Header Layout
    --
    -- Measures the title's own real rendered height (already SetText'd by
    -- BaseWindow:Create above) rather than assuming a fixed number, so the
    -- grouped navigation is placed with a guaranteed, correct gap below it
    -- regardless of title text or font.
    -----------------------------------------------------------------------

    local titleBottom = -(TITLE_TOP_OFFSET + (self.Frame.Title:GetStringHeight() or 20))
    local tabTop = titleBottom - HEADER_GAP

    -----------------------------------------------------------------------
    -- Tab Bar
    -----------------------------------------------------------------------

    local tabBarPanel = CreateFrame("Frame", nil, self.Frame, "BackdropTemplate")
    tabBarPanel:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", CONTENT_PADDING - 6, tabTop + 4)
    tabBarPanel:SetSize(WINDOW_WIDTH - (CONTENT_PADDING * 2) + 12, TAB_BAR_HEIGHT + 4)
    AC.Presentation.ApplyCardBackdrop(tabBarPanel)

    self.TabBarPanel = tabBarPanel
    self.TabButtons = {}
    self.NavGroupButtons = {}
    self.LastTabByGroup = {}

    for groupIndex, group in ipairs(NAVIGATION_GROUPS) do
        local groupKey = group.key
        local defaultTab = group.tabs[1]
        local groupButton = CreateFrame("Button", nil, tabBarPanel, "UIPanelButtonTemplate")
        groupButton:SetSize(NAV_GROUP_BUTTON_WIDTH, 22)
        groupButton:SetPoint("TOPLEFT", 6 + ((groupIndex - 1) * (NAV_GROUP_BUTTON_WIDTH + TAB_BUTTON_GAP)), -4)
        groupButton:SetText(AC.L:Get(group.labelKey))
        groupButton:SetScript("OnClick", function()
            self:NavigateTab(self.LastTabByGroup[groupKey] or defaultTab)
        end)
        self.NavGroupButtons[groupKey] = groupButton
        self.LastTabByGroup[groupKey] = defaultTab

        for tabIndex, tabName in ipairs(group.tabs) do
            local pageName = tabName
            local button = CreateFrame("Button", nil, tabBarPanel, "UIPanelButtonTemplate")
            button:SetSize(TAB_BUTTON_WIDTH, 22)
            button:SetPoint("TOPLEFT", 6 + ((tabIndex - 1) * (TAB_BUTTON_WIDTH + TAB_BUTTON_GAP)), -30)
            button:SetText(AC.L:Get(TAB_LABEL_KEY[pageName]))
            button:SetScript("OnClick", function()
                self:NavigateTab(pageName)
            end)
            button:Hide()
            self.TabButtons[pageName] = button
        end
    end

    -----------------------------------------------------------------------
    -- Content Area
    -----------------------------------------------------------------------

    local contentPanel = CreateFrame("Frame", nil, self.Frame, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", CONTENT_PADDING - 6, tabTop - TAB_BAR_HEIGHT + 4)
    contentPanel:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING + 6, FOOTER_HEIGHT - 4)
    AC.Presentation.ApplyCardBackdrop(contentPanel)

    -- Scrollbar Extraction -- was a hand-rolled scrollFrame whose right
    -- anchor only reserved CONTENT_PADDING, never SCROLLBAR_RESERVE, even
    -- though CONTENT_WIDTH already assumed both were reserved -- the same
    -- bug Player Journal had. AC.SharedScrollFrame:Create
    -- (Core/UI/Shared/ScrollFrame.lua) is now the single owner of that
    -- math, shared with Dashboard and Player Journal.
    local scrollFrame, scrollChild = AC.SharedScrollFrame:Create(self.Frame, CONTENT_WIDTH, TAB_BAR_HEIGHT - tabTop, CONTENT_PADDING, FOOTER_HEIGHT)

    self.ScrollFrame = scrollFrame
    self.ScrollChild = scrollChild
    self.ContentPanel = contentPanel

    -----------------------------------------------------------------------
    -- Footer -- Copy JSON / Copy Text / Copy Summary + the shared hidden
    -- EditBox every one of them populates (DiagnosticsWindow's own
    -- "SetFocus + HighlightText, player presses Ctrl+C" idiom -- WoW has
    -- no clipboard-write API, so this is the standard, already-validated
    -- pattern rather than a new one).
    -----------------------------------------------------------------------

    self:RegisterConfirmationDialogs()
    self:BuildFooter()

    self.CurrentTab = "Overview"

    -- Stabilization pass -- real gap fixed: DEVELOPER_RUNTIME_UPDATED was
    -- being fired by DeveloperRuntime/ErrorCapture (its own doc comment
    -- already said "the Developer Panel is the intended listener"), but
    -- nothing here ever actually registered for it. A captured error
    -- while the Errors tab was already open had no way to make the tab
    -- refresh itself -- only navigating away and back forced a fresh
    -- BuildErrorsTab() call. Registered unconditionally (a framework
    -- event, zero real-Blizzard-event registration cost either way,
    -- matching how PROFILE_CHANGED/NOTIFICATION_CHANGED are already
    -- listened for elsewhere in this codebase regardless of any
    -- enable/disable state).
    AC.Events:Register("DEVELOPER_RUNTIME_UPDATED", self, "OnDeveloperRuntimeUpdated")
    AC.Events:Register("DEVELOPER_MODE_CHANGED", self, "OnDeveloperModeChanged")
    AC.Events:Register("USER_ACTION_STATE_CHANGED", self, "OnUserActionStateChanged")

end

-------------------------------------------------------------------------------
-- Developer Runtime Integration
--
-- Refreshes the Errors tab live while it's the active tab and this
-- window is shown -- if the tab isn't showing (different tab active, or
-- the whole window hidden), there's nothing to redraw; the next ShowTab
-- call reads AC.DeveloperRuntime's current data fresh anyway.
-------------------------------------------------------------------------------

-- Capability name -> the one tab it refreshes, and the pool-of-record used
-- to double check the tab is really showing that data before rebuilding --
-- generalized here once a second capability (SecretValueEvents) needed the
-- exact same live-refresh behavior ErrorCapture already had, rather than a
-- second near-identical if/elseif block.
local CAPABILITY_TAB =
{
    ErrorCapture = "Errors",
    SecretValueEvents = "SecretValues",
}

function DeveloperPanel:OnDeveloperRuntimeUpdated(capabilityName)

    local tabName = CAPABILITY_TAB[capabilityName]

    if not tabName then
        return
    end

    if self.Frame and self.Frame:IsShown() and self.CurrentTab == tabName then

        if AC.Logger then
            AC.Logger:Debug(("Developer Panel: %s tab refreshed via DEVELOPER_RUNTIME_UPDATED."):format(tabName), "Framework")
        end

        self:ShowTab(tabName)

    elseif AC.Logger then
        AC.Logger:Debug(("Developer Panel: DEVELOPER_RUNTIME_UPDATED received for %s, %s tab not currently visible -- no immediate refresh needed."):format(capabilityName, tabName), "Framework")
    end

end

function DeveloperPanel:OnDeveloperModeChanged(enabled)

    if not enabled and self.Frame and self.Frame:IsShown() then
        self:Hide()
    elseif enabled and self.Frame and self.Frame:IsShown() and self.CurrentTab == "Overview" then
        self:ShowTab("Overview")
    end

end

function DeveloperPanel:OnUserActionStateChanged()

    self:RefreshActionControls()

    if self.Frame and self.Frame:IsShown() and self.CurrentTab == "Overview" then
        self:ShowTab("Overview")
    end

end

-------------------------------------------------------------------------------
-- Destructive Maintenance Actions
--
-- StaticPopupDialogs below own confirmation. These methods call only the
-- public clear API of the system that owns each data set, then refresh the
-- visible presentation. The broad DatabaseService reset APIs are deliberately
-- not used: they also erase unrelated player configuration and gameplay data.
-------------------------------------------------------------------------------

local function ClearActivityHistoryData()

    if AC.ActivityHistoryService then
        AC.ActivityHistoryService:ClearAll()
    end

end

local function ClearCapturedErrorsData()

    AC.UserActionService:ClearCapturedErrors()

end

local function ClearEventLogData()

    if AC.DeveloperModeService then
        AC.DeveloperModeService:ClearEventLog()
    end

end

local function ClearSecretValueData()

    local secretValueEvents = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("SecretValueEvents")

    if secretValueEvents then
        secretValueEvents:ClearEvents()
    end

end

local function ClearVerificationData()

    if AC.VerificationService then
        AC.VerificationService:ClearRecordedResults()
    end

end

function DeveloperPanel:RefreshAfterMaintenance()

    if AC.Dashboard and AC.Dashboard.Frame and AC.Dashboard.Frame:IsShown() then
        AC.Dashboard:ShowPage(AC.Dashboard.CurrentPage or "Home")
    end

    if self.Frame and self.Frame:IsShown() then
        self:ShowTab(self.CurrentTab or "Maintenance")
    end

end

function DeveloperPanel:ClearActivityHistory()

    ClearActivityHistoryData()
    AC.Logger:Info("Developer Panel: Activity History cleared.")
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:ClearCapturedErrors()

    ClearCapturedErrorsData()
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:ClearEventLog()

    ClearEventLogData()
    AC.Logger:Info("Developer Panel: event log cleared.")
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:ClearSecretValueEvents()

    ClearSecretValueData()
    AC.Logger:Info("Developer Panel: secret-value events cleared.")
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:ClearVerificationResults()

    ClearVerificationData()
    AC.Logger:Info("Developer Panel: verification and checklist records cleared.")
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:ClearNotifications()

    if AC.NotificationService then
        AC.NotificationService:ClearAll()
        AC.Logger:Info("Developer Panel: notifications cleared.")
    end

    if self.CurrentTab == "Overview" then
        self:ShowTab("Overview")
    end

end

function DeveloperPanel:ResetAllDeveloperData()

    ClearActivityHistoryData()
    ClearCapturedErrorsData()
    ClearEventLogData()
    ClearSecretValueData()
    ClearVerificationData()

    AC.Logger:Info("Developer Panel: all developer-managed data cleared.")
    self:RefreshAfterMaintenance()

end

function DeveloperPanel:RegisterConfirmationDialogs()

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_ACTIVITY_HISTORY"] =
{
    text = AC.L:Get("Developer.ConfirmClearActivityHistory"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearActivityHistory()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_ERRORS"] =
{
    text = AC.L:Get("Developer.ConfirmClearErrors"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearCapturedErrors()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_EVENTS"] =
{
    text = AC.L:Get("Developer.ConfirmClearEvents"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearEventLog()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_SECRET_VALUES"] =
{
    text = AC.L:Get("Developer.ConfirmClearSecretValues"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearSecretValueEvents()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_NOTIFICATIONS"] =
{
    text = AC.L:Get("Developer.ConfirmClearNotifications"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearNotifications()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_VERIFICATION"] =
{
    text = AC.L:Get("Developer.ConfirmClearVerification"),
    button1 = AC.L:Get("Developer.Clear"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ClearVerificationResults()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_RESET_ALL"] =
{
    text = AC.L:Get("Developer.ConfirmResetEverything"),
    button1 = AC.L:Get("Developer.Reset"),
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()
        AC.DeveloperPanel:ResetAllDeveloperData()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

end

-------------------------------------------------------------------------------
-- Footer / Copy Support
-------------------------------------------------------------------------------

function DeveloperPanel:BuildFooter()

    local footer = CreateFrame("Frame", nil, self.Frame, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", CONTENT_PADDING, CONTENT_PADDING)
    footer:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)
    footer:SetHeight(FOOTER_HEIGHT)
    AC.Presentation.ApplyCardBackdrop(footer)

    local copyJSON = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    copyJSON:SetSize(90, 20)
    copyJSON:SetPoint("BOTTOMLEFT", 8, 24)
    copyJSON:SetText(AC.L:Get("Developer.CopyJSON"))

    copyJSON:SetScript("OnClick", function()
        self:CopyCurrentTab("json")
    end)

    local copyText = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    copyText:SetSize(90, 20)
    copyText:SetPoint("LEFT", copyJSON, "RIGHT", 6, 0)
    copyText:SetText(AC.L:Get("Developer.CopyText"))

    copyText:SetScript("OnClick", function()
        self:CopyCurrentTab("text")
    end)

    local copySummary = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    copySummary:SetSize(90, 20)
    copySummary:SetPoint("LEFT", copyText, "RIGHT", 6, 0)
    copySummary:SetText(AC.L:Get("Developer.CopySummary"))

    copySummary:SetScript("OnClick", function()
        self:CopyCurrentTab("summary")
    end)

    local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", copySummary, "RIGHT", 10, 0)
    hint:SetText(AC.L:Get("Developer.CopyHint"))

    -- A single-line EditBox is all a "select-all-and-Ctrl+C" moment needs
    -- -- WoW has no clipboard-write API, so Copy just populates this,
    -- focuses it, and highlights it (DiagnosticsWindow's own established
    -- copy idiom); the player presses Ctrl+C themselves.
    local copyBox = CreateFrame("EditBox", nil, footer, "InputBoxTemplate")
    copyBox:SetAutoFocus(false)
    copyBox:SetSize(WINDOW_WIDTH - (CONTENT_PADDING * 2) - 20, 20)
    copyBox:SetPoint("BOTTOMLEFT", 10, 2)

    copyBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)

    self.CopyBox = copyBox
    self.Footer = footer

end

function DeveloperPanel:CopyCurrentTab(mode)

    local data = self.CurrentTabData or {}
    local text

    if mode == "json" then
        text = AC.DeveloperModeService:ToJSON(data)
    elseif mode == "text" then
        text = AC.DeveloperModeService:ToIndentedText(data)
    else

        -- Some tabs (Live API) store colored lines as {text=...} tables
        -- rather than plain strings -- table.concat requires strings, so
        -- normalize either shape before joining.
        local plainLines = {}

        for _, line in ipairs(self.CurrentTabSummaryLines or {}) do
            table.insert(plainLines, type(line) == "table" and (line.text or "") or tostring(line))
        end

        text = table.concat(plainLines, " | ")

    end

    self.CopyBox:SetText(text or "")
    self.CopyBox:SetFocus()
    self.CopyBox:HighlightText()

end

-- Shared User Actions
-------------------------------------------------------------------------------

local function CreateActionCheckbox(parent, label, x, y, onClick)

    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)
    checkbox.Text:SetText(label)
    checkbox:SetScript("OnClick", function(control)
        onClick(control:GetChecked() == true)
    end)

    return checkbox

end

local function CreateActionButton(parent, label, width, x, y, onClick)

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)

    return button

end

function DeveloperPanel:GetPageToolbar(tabName)
    self.PageToolbars = self.PageToolbars or {}

    local toolbar = self.PageToolbars[tabName]

    if toolbar then
        return toolbar
    end

    toolbar = CreateFrame("Frame", nil, self.ScrollChild)
    toolbar:SetPoint("TOPLEFT", 0, -4)
    toolbar:SetSize(CONTENT_WIDTH, 22)
    toolbar.Buttons = {}
    toolbar:Hide()
    self.PageToolbars[tabName] = toolbar
    return toolbar
end

function DeveloperPanel:GetPageToolbarButton(tabName, key, text, width, onClick)
    local toolbar = self:GetPageToolbar(tabName)
    local button = toolbar.Buttons[key]

    if not button then
        button = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        button:SetSize(width, 20)

        local previous = toolbar.LastButton

        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -6, 0)
        else
            button:SetPoint("TOPRIGHT", 0, 0)
        end

        toolbar.Buttons[key] = button
        toolbar.LastButton = button
    end

    button:SetText(text)
    button:SetScript("OnClick", onClick)
    button:Show()

    if toolbar.Status then
        toolbar.Status:ClearAllPoints()
        toolbar.Status:SetPoint("LEFT", 0, 0)
        toolbar.Status:SetPoint("RIGHT", toolbar.LastButton, "LEFT", -8, 0)
    end

    toolbar:Show()
    return button
end

function DeveloperPanel:GetPageToolbarStatus(tabName)
    local toolbar = self:GetPageToolbar(tabName)

    if not toolbar.Status then
        toolbar.Status = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        toolbar.Status:SetJustifyH("LEFT")
    end

    toolbar.Status:ClearAllPoints()
    toolbar.Status:SetPoint("LEFT", 0, 0)

    if toolbar.LastButton then
        toolbar.Status:SetPoint("RIGHT", toolbar.LastButton, "LEFT", -8, 0)
    else
        toolbar.Status:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    end

    toolbar.Status:Show()
    toolbar:Show()
    return toolbar.Status
end


function DeveloperPanel:BuildActionControls(parent)

    if self.ActionControls then
        return self.ActionControls
    end

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(CONTENT_WIDTH, 118)
    AC.Presentation.ApplyCardBackdrop(panel)

    local developerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    developerLabel:SetPoint("TOPLEFT", 12, -10)
    developerLabel:SetText(AC.L:Get("Developer.ActionsDeveloper"))

    local tracingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tracingLabel:SetPoint("TOPLEFT", 220, -10)
    tracingLabel:SetText(AC.L:Get("Developer.ActionsTracing"))

    local diagnosticsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diagnosticsLabel:SetPoint("TOPLEFT", 430, -10)
    diagnosticsLabel:SetText(AC.L:Get("Developer.ActionsDiagnostics"))

    local navigationLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    navigationLabel:SetPoint("TOPLEFT", 680, -10)
    navigationLabel:SetText(AC.L:Get("Developer.ActionsNavigation"))

    panel.DeveloperMode = CreateActionCheckbox(panel, AC.L:Get("Developer.ActionDeveloperMode"), 8, -28, function(enabled)
        AC.UserActionService:SetDeveloperModeEnabled(enabled)
    end)

    panel.DebugLogging = CreateActionCheckbox(panel, AC.L:Get("Developer.ActionDebugLogging"), 8, -56, function(enabled)
        AC.UserActionService:SetDebugLoggingEnabled(enabled)
    end)

    panel.AllTracing = CreateActionCheckbox(panel, AC.L:Get("Developer.ActionTraceAll"), 216, -28, function(enabled)

        if enabled then
            AC.UserActionService:EnableAllTracing()
        else
            AC.UserActionService:DisableAllTracing()
        end

    end)

    local traceDescriptor = AC.UserActionService:GetAvailableTraceCategories()[1]

    panel.CategoryTracing = CreateActionCheckbox(panel, AC.L:Get(traceDescriptor.labelKey), 216, -56, function(enabled)

        if enabled then
            AC.UserActionService:EnableTraceCategory(traceDescriptor.category)
        else
            AC.UserActionService:DisableTraceCategory(traceDescriptor.category)
        end

    end)

    CreateActionButton(panel, AC.L:Get("Developer.ActionOpenLog"), 72, 430, -32, function()
        AC.UserActionService:OpenLog()
    end)
    CreateActionButton(panel, AC.L:Get("Developer.ActionCopyLog"), 72, 508, -32, function()
        AC.UserActionService:CopyLog()
    end)
    CreateActionButton(panel, AC.L:Get("Developer.ActionClearLog"), 72, 586, -32, function()
        AC.UserActionService:ClearLog()
    end)
    CreateActionButton(panel, AC.L:Get("Developer.ClearNotifications"), 150, 430, -62, function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_NOTIFICATIONS")
    end)

    CreateActionButton(panel, AC.L:Get("Developer.ActionDashboard"), 90, 680, -32, function()
        AC.UserActionService:OpenDashboard()
    end)
    CreateActionButton(panel, AC.L:Get("Developer.ActionSettings"), 90, 776, -32, function()
        AC.UserActionService:OpenSettings()
    end)
    CreateActionButton(panel, AC.L:Get("Developer.ForceRefresh"), 90, 680, -62, function()

        if AC.UserActionService:RefreshAll() then
            self:ShowTab(self.CurrentTab)
        end

    end)

    self.ActionControls = panel

    return panel

end


function DeveloperPanel:RefreshActionControls()

    local panel = self.ActionControls

    if not panel or not AC.UserActionService then
        return
    end

    local traceState = AC.UserActionService:GetTraceState()
    local traceDescriptor = AC.UserActionService:GetAvailableTraceCategories()[1]

    panel.DeveloperMode:SetChecked(AC.UserActionService:IsDeveloperModeEnabled())
    panel.DebugLogging:SetChecked(AC.UserActionService:IsDebugLoggingEnabled())
    panel.AllTracing:SetChecked(traceState.all)
    panel.CategoryTracing:SetChecked(AC.UserActionService:IsTraceCategoryEnabled(traceDescriptor.category))
    panel.CategoryTracing:SetEnabled(not traceState.all)

end

-------------------------------------------------------------------------------
-- Overview Tab
--
-- The flat status board -- one line per fact, every one of them read
-- through an existing public getter. Nothing here is computed; a
-- "Storage Readiness" of "Unavailable" or a "Current Recommendation" of
-- "None" is the real, honest state, not a placeholder.
-------------------------------------------------------------------------------

function DeveloperPanel:BuildOverviewTab()

    local data = {}
    local lines = {}
    local properties = {}
    local serviceCount = AC.ServiceManager and #AC.ServiceManager:GetAll() or 0
    local moduleCount = AC.ModuleManager and #AC.ModuleManager:GetAll() or 0
    local eventCount = AC.DeveloperModeService and #AC.DeveloperModeService:GetEventLog() or 0
    local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")
    local errorCount = errorCapture and #errorCapture:GetErrors() or 0

    local function AddLine(labelKey, value)

        local text = AC.L:Get(labelKey) .. ": " .. tostring(value)

        table.insert(lines, text)
        table.insert(properties, { label = labelKey, value = tostring(value) })
        data[AC.L:Get(labelKey)] = value

    end

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()

    if characterProfile and characterProfile.name and characterProfile.name ~= "" then

        AddLine("Developer.FieldCharacter", characterProfile.name)
        AddLine("Developer.FieldZone", characterProfile.zone or AC.L:Get("Common.Unknown"))
        AddLine("Developer.FieldSpec", characterProfile.specName ~= "" and characterProfile.specName or AC.L:Get("Common.Unknown"))
        AddLine("Developer.FieldItemLevel", string.format("%.1f", characterProfile.equippedItemLevel or 0))

    else
        AddLine("Developer.FieldCharacter", AC.L:Get("Common.Unknown"))
    end

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local mpProfile = mythicPlusModule and mythicPlusModule:GetProfile()

    if mpProfile then

        if mpProfile.hasKeystone then
            AddLine("Developer.FieldKey", (mpProfile.currentDungeonName ~= "" and mpProfile.currentDungeonName or "#" .. tostring(mpProfile.currentDungeonID or 0)) .. " +" .. tostring(mpProfile.currentLevel or 0))
        else
            AddLine("Developer.FieldKey", AC.L:Get("MythicPlus.HeroNoKeystone"))
        end

        AddLine("Developer.FieldRating", AC.Presentation.FormatRating(mpProfile.rating))

    end

    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
    local vaultProgress = weeklyModule and weeklyModule.GetVaultProgress and weeklyModule:GetVaultProgress()

    if vaultProgress and vaultProgress.totalSlots and vaultProgress.totalSlots > 0 then
        AddLine("Developer.FieldVault", string.format("%d / %d%s", vaultProgress.unlockedSlots or 0, vaultProgress.totalSlots, vaultProgress.hasAvailableRewards and " (reward available)" or ""))
    else
        AddLine("Developer.FieldVault", AC.L:Get("Common.Unknown"))
    end

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if storageModule and storageModule.IsModuleEnabled and storageModule:IsModuleEnabled() then

        local storageProfile = storageModule:GetActiveProfile()
        local preparation = storageProfile and storageModule:GetPreparationStatus(storageProfile.id)

        AddLine("Developer.FieldStorageReadiness", preparation and string.format("%.0f%%%s", preparation.readinessPercent or 0, preparation.ready and " (ready)" or "") or AC.L:Get("Common.Unknown"))

    else
        AddLine("Developer.FieldStorageReadiness", AC.L:Get("Common.Unknown"))
    end

    -- Player Journal -- one flat subsection matching this tab's own
    -- "one line per fact" style, no new tab (the 7 facts requested are
    -- exactly this shape). Sourced entirely from
    -- PlayerJournalModule:GetDeveloperStats(), never recomputed here.
    local playerJournalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local journalStats = playerJournalModule and playerJournalModule:GetDeveloperStats()

    if journalStats then

        AddLine("Developer.PlayerJournalStoredPlayers", journalStats.storedPlayers)
        AddLine("Developer.PlayerJournalIncidentalPlayers", journalStats.incidentalPlayers)
        AddLine("Developer.PlayerJournalFavoritePlayers", journalStats.favoritePlayers)
        AddLine("Developer.PlayerJournalTotalNotes", journalStats.totalNotes)
        AddLine("Developer.PlayerJournalCommunityObservations", journalStats.communityObservations)
        AddLine("Developer.PlayerJournalOldestEntry", journalStats.oldestEntry and AC.Presentation.FormatDate(journalStats.oldestEntry, "short") or AC.L:Get("Common.Unknown"))
        AddLine("Developer.PlayerJournalNewestEntry", journalStats.newestEntry and AC.Presentation.FormatDate(journalStats.newestEntry, "short") or AC.L:Get("Common.Unknown"))
        AddLine("Developer.PlayerJournalDatabaseSize", string.format("%.1f KB", journalStats.databaseSize / 1024))
        AddLine("Developer.PlayerJournalPrunedEntries", journalStats.prunedEntries)

    end

    local recommendationCount = AC.RecommendationEngine and #AC.RecommendationEngine:GetRecommendations() or 0
    AddLine("Developer.FieldRecommendationCount", recommendationCount)

    AddLine("Developer.FieldNotificationQueue", AC.NotificationService and AC.NotificationService:GetQueueLength() or 0)

    local briefingLines = AC.BriefingService and AC.BriefingService:GetBriefing() or {}
    AddLine("Developer.FieldBriefing", #briefingLines .. " line(s)")

    local topRecommendation = AC.RecommendationEngine and AC.RecommendationEngine:GetHighestPriority()

    if topRecommendation then

        AddLine("Developer.FieldCurrentRecommendation", topRecommendation.title)
        AddLine("Developer.FieldOpportunityScore", topRecommendation.score or 0)
        AddLine("Developer.FieldConfidence", topRecommendation.confidence or AC.L:Get("Common.Unknown"))

    else

        AddLine("Developer.FieldCurrentRecommendation", AC.L:Get("Dashboard.CaughtUp"))
        AddLine("Developer.FieldOpportunityScore", AC.L:Get("Common.Unknown"))
        AddLine("Developer.FieldConfidence", AC.L:Get("Common.Unknown"))

    end

    AddLine("Developer.FieldLoadedModules", string.format("%d services, %d modules", serviceCount, moduleCount))

    local lastRefresh = AC.RecommendationEngine and AC.RecommendationEngine:GetLastRefresh()
    AddLine("Developer.FieldLastRefresh", (lastRefresh and lastRefresh > 0) and date("%H:%M:%S", lastRefresh) or AC.L:Get("Common.Unknown"))

    local lastEvent = AC.DeveloperModeService and AC.DeveloperModeService:GetLastEvent()
    AddLine("Developer.FieldLastEvent", lastEvent and (lastEvent.event .. " @ " .. lastEvent.timestamp) or AC.L:Get("Common.Unknown"))

    local framerate = GetFramerate and GetFramerate() or nil
    AddLine("Developer.FieldFrameRate", framerate and string.format("%.0f fps", framerate) or AC.L:Get("Common.Unknown"))

    local _, _, _, yOffset = AC.Dashboard:BuildHeroSection(
        self,
        self.ScrollChild,
        PAGE_CONTENT_TOP,
        CONTENT_WIDTH,
        AC.L:Get("Developer.HeroHeadline"),
        AC.L:Get("Developer.HeroValue"),
        AC.L:Get("Developer.HeroCaption")
    )

    self.Hero.Headline:Show()
    self.Hero.Value:Show()
    self.Hero.Caption:Show()

    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "OverviewHeroStats", self.ScrollChild, yOffset, CONTENT_WIDTH,
    {
        { label = "Developer.HeroModules", value = tostring(moduleCount) },
        { label = "Developer.HeroEvents", value = tostring(eventCount) },
        { label = "Developer.HeroErrors", value = tostring(errorCount) },
        { label = "Developer.HeroMode", value = AC.L:Get(AC.DeveloperModeService and AC.DeveloperModeService:IsEnabled() and "Developer.Yes" or "Developer.No") },
    })

    local actionControls = self:BuildActionControls(self.ScrollChild)
    actionControls:ClearAllPoints()
    actionControls:SetPoint("TOPLEFT", 0, yOffset)
    actionControls:Show()
    self:RefreshActionControls()
    yOffset = yOffset - actionControls:GetHeight() - 8

    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "OverviewProperties", self.ScrollChild, yOffset, CONTENT_WIDTH, properties)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Modules Tab
--
-- Two lines per registered Service/Module: registered identity and
-- capability-aware actions, then its own stats. Registration is the only
-- lifecycle fact the managers own; this page does not infer initialization or
-- enablement. Insight/Recommendation/History counts reuse
-- InsightEngine/Dashboard/ActivityHistoryService's own existing public
-- getters -- never recomputed here.
-------------------------------------------------------------------------------

function DeveloperPanel:BuildModulesTab()

    local data = {}
    local summaryLines = {}

    self.ModuleRefreshButtons = self.ModuleRefreshButtons or {}

    local titlePool = self:GetPool("ModulesTitle")
    local statsPool = self:GetPool("ModulesStats")

    local entries = {}
    local seen = {}

    if AC.ServiceManager then
        for _, service in ipairs(AC.ServiceManager:GetAll()) do
            if service.Name and not seen[service.Name] then
                seen[service.Name] = true
                table.insert(entries, { name = service.Name, object = service })
            end
        end
    end

    if AC.ModuleManager then
        for _, module in ipairs(AC.ModuleManager:GetAll()) do
            if module.Name and not seen[module.Name] then
                seen[module.Name] = true
                table.insert(entries, { name = module.Name, object = module })
            end
        end
    end

    table.sort(entries, function(a, b) return a.name < b.name end)

    local rowWidth = CONTENT_WIDTH - 170
    local introLines = { AC.L:Get("Developer.ModulesLifecycleLimitation") }
    local yOffset = self:LayoutLines("ModulesIntro", introLines, PAGE_CONTENT_TOP, CONTENT_WIDTH)
    yOffset = yOffset - 6

    for index, entry in ipairs(entries) do

        local name = entry.name
        local object = entry.object

        local stats = AC.DeveloperModeService and AC.DeveloperModeService:GetModuleStats(name)

        local lastRefreshText = AC.L:Get("Common.Unknown")
        local durationText = AC.L:Get("Common.Unknown")
        local errorText = AC.L:Get("Developer.NoError")

        if stats then

            lastRefreshText = stats.lastRefresh and date("%H:%M:%S", stats.lastRefresh) or AC.L:Get("Common.Unknown")
            durationText = stats.duration and string.format("%.2fms", stats.duration) or AC.L:Get("Common.Unknown")
            errorText = stats.lastError or AC.L:Get("Developer.NoError")

        elseif object.GetLastRefresh then

            local ok, result = pcall(object.GetLastRefresh, object)

            if ok and result and result > 0 then
                lastRefreshText = date("%H:%M:%S", result)
            end

        end

        local insightCount = AC.InsightEngine and #AC.InsightEngine:GetInsightsByCategory(name) or 0

        local recommendationCount = 0

        if AC.Dashboard and AC.Dashboard.GetCategorizedRecommendationsAndInsights then
            local recs = AC.Dashboard:GetCategorizedRecommendationsAndInsights(name)
            recommendationCount = recs and #recs or 0
        end

        local historyCount = AC.ActivityHistoryService and #AC.ActivityHistoryService:GetByModule(name) or 0
        local canRefresh = type(object.Refresh) == "function"
        local canDiagnose = type(object.GetDiagnostics) == "function"
        local capabilities = {}

        if canRefresh then capabilities[#capabilities + 1] = AC.L:Get("Developer.Refresh") end
        if canDiagnose then
            capabilities[#capabilities + 1] = AC.L:Get("Developer.ModulesDiagnostics")
        end

        if #capabilities == 0 then capabilities[1] = AC.L:Get("Developer.ModulesReadOnly") end

        local titleText = string.format("%s   |   %s: %s", DisplayName(name), AC.L:Get("Developer.LabelRegistered"), AC.L:Get("Developer.Yes"))
        local statsText = string.format("  %s: %s   %s: %s   %s: %d   %s: %d   %s: %d   %s: %s   %s: %s",
            AC.L:Get("Developer.LabelLastRefresh"), lastRefreshText,
            AC.L:Get("Developer.LabelDuration"), durationText,
            AC.L:Get("Developer.LabelInsightCount"), insightCount,
            AC.L:Get("Developer.LabelRecommendationCount"), recommendationCount,
            AC.L:Get("Developer.LabelHistoryCount"), historyCount,
            AC.L:Get("Developer.LabelLastError"), errorText,
            AC.L:Get("Developer.ModulesCapabilities"), table.concat(capabilities, ", "))

        table.insert(summaryLines, titleText)
        table.insert(summaryLines, statsText)

        data[name] =
        {
            Registered = true,
            LastRefresh = lastRefreshText,
            Duration = durationText,
            LastError = errorText,
            InsightCount = insightCount,
            RecommendationCount = recommendationCount,
            HistoryCount = historyCount,
            Capabilities = capabilities,
        }

        -- Title line + Refresh button, top-aligned to the same yOffset.
        local titleRow = titlePool[index]

        if not titleRow then

            titleRow = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            titleRow:SetJustifyH("LEFT")
            titleRow:SetWordWrap(true)
            titlePool[index] = titleRow

        end

        titleRow:ClearAllPoints()
        titleRow:SetPoint("TOPLEFT", 0, yOffset)
        titleRow:SetWidth(rowWidth)
        titleRow:SetText(titleText)
        AC.DashboardFormat.SetHighlightColor(titleRow)
        titleRow:Show()

        local button = self.ModuleRefreshButtons[index]

        if not button then

            button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            button:SetSize(70, 18)

            button:SetScript("OnClick", function(self_)

                if AC.DeveloperModeService:RefreshOne(self_.ModuleName) then
                    AC.Logger:Info("Developer Panel: refreshed " .. self_.ModuleName .. ".")
                else
                    AC.Logger:Warn(self_.ModuleName .. " has no Refresh() method.")
                end

                DeveloperPanel:NavigateTab("Modules")

            end)

            self.ModuleRefreshButtons[index] = button

        end

        button:SetText(AC.L:Get("Developer.Refresh"))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.ScrollChild, "TOPLEFT", rowWidth + 10, yOffset)
        button.ModuleName = name
        button:SetShown(canRefresh)

        local titleHeight = math.max(titleRow:GetStringHeight() or 14, 18)

        yOffset = yOffset - titleHeight - 2

        -- Stats line, directly beneath.
        local statsRow = statsPool[index]

        if not statsRow then

            statsRow = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statsRow:SetJustifyH("LEFT")
            statsRow:SetWordWrap(true)
            statsPool[index] = statsRow

        end

        statsRow:ClearAllPoints()
        statsRow:SetPoint("TOPLEFT", 0, yOffset)
        statsRow:SetWidth(rowWidth)
        statsRow:SetText(statsText)

        -- Presentation System v2 -- was a hardcoded (0.75,0.75,0.75);
        -- migrated to the real "dim" token.
        statsRow:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
        statsRow:Show()

        yOffset = yOffset - (statsRow:GetStringHeight() or 12) - 10

    end

    for index = #entries + 1, #titlePool do
        titlePool[index]:Hide()
    end

    for index = #entries + 1, #statsPool do
        statsPool[index]:Hide()
    end

    for index = #entries + 1, #self.ModuleRefreshButtons do
        self.ModuleRefreshButtons[index]:Hide()
    end

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = summaryLines

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Combat Session Tab
-------------------------------------------------------------------------------

function DeveloperPanel:BuildCombatSessionTab()
    local service = AC.CombatSessionService
    local toolbar = self:GetPageToolbar("CombatSession")
    local function FormatBoolean(value)
        if value == nil then return AC.L:Get("Common.Unknown") end
        return value and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No")
    end

    self:GetPageToolbarButton("CombatSession", "Refresh", AC.L:Get("Developer.Refresh"), 90, function()
        if service then
            service:Refresh("developer-panel")
        end

        DeveloperPanel:NavigateTab("CombatSession")
    end)
    toolbar:Show()

    local diagnostics = service and service:GetDiagnostics() or {}
    local latest = service and service:GetLatestSession() or nil
    local yOffset = TOOLBAR_CONTENT_TOP

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.CombatSessionStatus", yOffset)
    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "CombatSessionStatus", self.ScrollChild, yOffset, CONTENT_WIDTH,
    {
        { label = "Developer.CombatSessionInitialized", value = diagnostics.initialized and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No") },
        { label = "Developer.CombatSessionEnabled", value = diagnostics.enabled and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No") },
        { label = "Developer.CombatSessionAPIAvailable", value = diagnostics.available and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No") },
        { label = "Developer.CombatSessionLastReason", value = diagnostics.lastReason or AC.L:Get("Common.Unknown") },
    })
    yOffset = AC.Dashboard:EndSection(yOffset)

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.CombatSessionCache", yOffset)
    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "CombatSessionCache", self.ScrollChild, yOffset, CONTENT_WIDTH,
    {
        { label = "Developer.CombatSessionCached", value = tostring(diagnostics.cachedSessionCount or 0) },
        { label = "Developer.CombatSessionCacheLimit", value = tostring(diagnostics.cacheLimit or 0) },
        { label = "Developer.CombatSessionUpdates", value = tostring(diagnostics.updateCount or 0) },
        { label = "Developer.CombatSessionResets", value = tostring(diagnostics.resetCount or 0) },
        { label = "Developer.CombatSessionObserved", value = tostring(diagnostics.totalSessionsObserved or 0) },
        { label = "Developer.CombatSessionEvicted", value = tostring(diagnostics.evictedSessionCount or 0) },
    })
    yOffset = AC.Dashboard:EndSection(yOffset)

    local latestStats

    if latest then
        latestStats =
        {
            { label = "Developer.CombatSessionSessionID", value = tostring(latest.sessionID or AC.L:Get("Common.Unknown")) },
            { label = "Developer.CombatSessionParticipants", value = tostring(latest.participantCount or 0) },
            { label = "Developer.CombatSessionDeaths", value = tostring(latest.deathCount or 0) },
            { label = "Developer.CombatSessionLastUpdated", value = latest.updatedAt and AC.L:Format("Developer.CombatSessionUpdatedAgo", math.max(0, GetTime() - latest.updatedAt)) or AC.L:Get("Common.Unknown") },
        }
    else
        latestStats =
        {
            { label = "Developer.CombatSessionSessionID", value = AC.L:Get("Developer.CombatSessionNoSession") },
        }
    end

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.CombatSessionLatest", yOffset)
    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "CombatSessionLatest", self.ScrollChild, yOffset, CONTENT_WIDTH, latestStats)
    yOffset = AC.Dashboard:EndSection(yOffset)

    local participantLines = {}

    for _, participant in ipairs(latest and latest.participants or {}) do
        participantLines[#participantLines + 1] = string.format("%s | %s | %s | %s: %s",
            participant.name or AC.L:Get("Common.Unknown"),
            participant.sourceGUID or AC.L:Get("Common.Unknown"),
            participant.classFilename or AC.L:Get("Common.Unknown"),
            AC.L:Get("Developer.CombatSessionLocalPlayer"),
            FormatBoolean(participant.isLocalPlayer))
    end

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.CombatSessionParticipantSection", yOffset)
    yOffset = self:LayoutLinesOrEmpty("CombatSessionParticipants", participantLines, yOffset, CONTENT_WIDTH, "Developer.CombatSessionNoParticipants")
    yOffset = AC.Dashboard:EndSection(yOffset)

    local deathLines = {}

    for _, death in ipairs(latest and latest.deaths or {}) do
        deathLines[#deathLines + 1] = string.format("%s | %s: %s | %s: %s | %s: %s",
            death.deathTimeSeconds and string.format("%.1fs", death.deathTimeSeconds) or AC.L:Get("Common.Unknown"),
            AC.L:Get("Developer.CombatSessionRecapID"), tostring(death.deathRecapID or AC.L:Get("Common.Unknown")),
            AC.L:Get("Developer.CombatSessionRecapAvailable"), FormatBoolean(death.recap and death.recap.available),
            AC.L:Get("Developer.CombatSessionRecapEvents"), death.recap and death.recap.eventCount ~= nil and tostring(death.recap.eventCount) or AC.L:Get("Common.Unknown"))
    end

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.CombatSessionDeathSection", yOffset)
    yOffset = self:LayoutLinesOrEmpty("CombatSessionDeaths", deathLines, yOffset, CONTENT_WIDTH, "Developer.CombatSessionNoDeaths")
    yOffset = AC.Dashboard:EndSection(yOffset)

    self.CurrentTabData = { diagnostics = diagnostics, latestSession = latest }
    self.CurrentTabSummaryLines =
    {
        string.format("CombatSessionService: %s", diagnostics.enabled and "enabled" or "disabled"),
        string.format("Cache: %d/%d", diagnostics.cachedSessionCount or 0, diagnostics.cacheLimit or 0),
        latest and string.format("Latest: %s, participants=%d, deaths=%d", tostring(latest.sessionID), latest.participantCount or 0, latest.deathCount or 0)
            or AC.L:Get("Developer.CombatSessionNoSession"),
    }

    return (-yOffset) + 16
end

-------------------------------------------------------------------------------
-- Events Tab
--
-- A live feed of AC.DeveloperModeService's own bounded event log, newest
-- first. The log itself is only ever populated while Developer Mode is
-- on (see that service's InstallEventMonitor) -- this tab purely renders
-- whatever is already there.
-------------------------------------------------------------------------------

function DeveloperPanel:BuildEventsTab()
    self:GetPageToolbarButton("Events", "Clear", AC.L:Get("Developer.Clear"), 80, function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_EVENTS")
    end)

    local log = AC.DeveloperModeService and AC.DeveloperModeService:GetEventLog() or {}
    local lines = {}
    local data = {}

    if #log > 0 then

        for i = #log, 1, -1 do

            local entry = log[i]
            local text = string.format("[%s] %s", entry.timestamp, entry.event)

            if entry.args and entry.args ~= "" then
                text = text .. "  (" .. entry.args .. ")"
            end

            table.insert(lines, text)
            table.insert(data, { event = entry.event, timestamp = entry.timestamp, args = entry.args })

        end

    end

    local yOffset = self:LayoutLinesOrEmpty("Events", lines, TOOLBAR_CONTENT_TOP, CONTENT_WIDTH, "Developer.NoEvents")

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = #lines > 0 and lines or { AC.L:Get("Developer.NoEvents") }

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Errors Tab
--
-- Presents AC.DeveloperRuntime's "ErrorCapture" capability -- the primary
-- interface for captured runtime errors, and (per Developer Runtime's own
-- capability-host architecture) the intended home for future capabilities'
-- own tabs (Warning Capture, Performance Metrics, Memory Usage, Event
-- Statistics, Verification Results) alongside it. Presentation only:
-- ErrorCapture remains the single source of truth, read here through its
-- own public GetErrors()/ClearErrors()/GetSettings()/IsInstalled() --
-- no caching, no polling, no second copy of its data.
--
-- Reuses AC.Dashboard's shared accordion engine directly
-- (LayoutAccordionRows/SetAccordionDetailField/SetAccordionDetailDescription),
-- the same primitives Accomplishments/Journey/MythicPlus already call
-- directly -- not a second accordion implementation (see the Generic Row
-- Helpers header above for why this is the one exception to this file's
-- own simpler LayoutLines pattern).
--
-- Timestamps shown as-is (firstSeen/lastSeen are session-relative
-- HH:MM:SS.mmm clock strings, ErrorCapture's own existing format, not
-- changed here) -- not reformatted into a calendar date this addon
-- doesn't actually have for these entries.
--
-- Extension point, deliberately not built: ErrorCapture does not capture
-- local variables at the crash site today, so no "Locals" section is
-- rendered here. Adding one later is a new SetAccordionDetailField/
-- SetAccordionDetailDescription call inside BuildErrorDetail below, once
-- ErrorCapture's own data model actually carries that field -- not
-- invented as placeholder data now.
--
-- MESSAGE_PREVIEW_LENGTH/TruncateMessage and AddDetailHeader/HideDetailHeader
-- right below are deliberately generic (not Error-specific despite living
-- in this section first) -- the Secret Values Tab further below reuses
-- all four directly rather than keeping a second copy, per this file's own
-- "reuse shared infrastructure, don't duplicate" discipline.
-------------------------------------------------------------------------------

local MESSAGE_PREVIEW_LENGTH = 100

local function TruncateMessage(message)

    message = tostring(message or "")

    if #message <= MESSAGE_PREVIEW_LENGTH then
        return message
    end

    return message:sub(1, MESSAGE_PREVIEW_LENGTH) .. "..."

end

-- Error History persistence -- ErrorCapture now stores firstSeen/lastSeen
-- as absolute epoch seconds (time()), not a pre-formatted string, so every
-- presentation surface (collapsed row, detail view, summary line, Copy/
-- Export output) needs to format it the same way. One helper, not five
-- independent AC.Presentation.FormatDate calls, so there's exactly one
-- rule for "what does an error timestamp look like."
local function FormatErrorTimestamp(epoch)
    return epoch and AC.Presentation.FormatDate(epoch, "shortTime") or AC.L:Get("Common.Unknown")
end

function DeveloperPanel:BuildErrorRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    row:SetScript("OnEnter", function(self_)
        self_.Background:SetColorTexture(1, 1, 1, 0.06)
    end)

    row:SetScript("OnLeave", function(self_)
        self_.Background:SetColorTexture(1, 1, 1, 0)
    end)

    local messageText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    messageText:SetJustifyH("LEFT")
    row.MessageText = messageText

    local locationText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    locationText:SetJustifyH("LEFT")
    locationText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
    row.LocationText = locationText

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    metaText:SetJustifyH("LEFT")
    metaText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
    row.MetaText = metaText

    return row

end

-- Collapsed preview is a fixed 3-line layout (message preview / location /
-- occurrences+lastSeen) rather than word-wrapping the full message -- a
-- predictable, scannable row height for a log-style list, matching why
-- the requirement lists "Full error message" as an EXPANDED-only field.
function DeveloperPanel:LayoutErrorCollapsed(row, record, width)

    local baseX = AC.DashboardLayout.ACCORDION_DISCLOSURE_WIDTH
    local rowWidth = width - baseX

    row.MessageText:ClearAllPoints()
    row.MessageText:SetPoint("TOPLEFT", baseX, 0)
    row.MessageText:SetWidth(rowWidth)
    row.MessageText:SetText(TruncateMessage(record.message))

    row.LocationText:ClearAllPoints()
    row.LocationText:SetPoint("TOPLEFT", row.MessageText, "BOTTOMLEFT", 0, -2)
    row.LocationText:SetWidth(rowWidth)
    row.LocationText:SetText(record.location or AC.L:Get("Common.Unknown"))

    row.MetaText:ClearAllPoints()
    row.MetaText:SetPoint("TOPLEFT", row.LocationText, "BOTTOMLEFT", 0, -2)
    row.MetaText:SetWidth(rowWidth)
    row.MetaText:SetText(AC.L:Format("Developer.ErrorMetaFormat", record.occurrenceCount or 1, FormatErrorTimestamp(record.lastSeen)))

    return (row.MessageText:GetStringHeight() or 14) + (row.LocationText:GetStringHeight() or 12) + (row.MetaText:GetStringHeight() or 12) + 4

end

local function AddDetailHeader(row, cacheKey, labelKey, yOffset)

    local fieldKey = cacheKey .. "Header"

    if not row[fieldKey] then

        local header = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetJustifyH("LEFT")
        header:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
        row[fieldKey] = header

    end

    row[fieldKey]:ClearAllPoints()
    row[fieldKey]:SetPoint("TOPLEFT", AC.DashboardLayout.ACCORDION_DETAIL_INDENT, yOffset)
    row[fieldKey]:SetText(AC.L:Get(labelKey))
    row[fieldKey]:Show()

    return yOffset - AC.DashboardLayout.ROW_HEIGHT

end

local function HideDetailHeader(row, cacheKey)

    local fieldKey = cacheKey .. "Header"

    if row[fieldKey] then
        row[fieldKey]:Hide()
    end

end

function DeveloperPanel:BuildErrorDetail(row, record, width, detailYOffset)

    local yOffset = detailYOffset

    yOffset = AddDetailHeader(row, "FullMessage", "Developer.ErrorFieldMessage", yOffset)
    yOffset = AC.Dashboard:SetAccordionDetailDescription(row, record.message, yOffset, width, "FullMessage")

    yOffset = yOffset - 6

    yOffset = AC.Dashboard:SetAccordionDetailField(row, "ErrorSignature", "Developer.ErrorFieldSignature", record.key or AC.L:Get("Common.Unknown"), yOffset, width)

    local originText = record.origin or AC.L:Get("Common.Unknown")

    if record.origin == "Third Party" and record.thirdPartyAddon then
        originText = AC.L:Format("Developer.ErrorFieldOriginThirdPartyFormat", record.thirdPartyAddon)
    end

    yOffset = AC.Dashboard:SetAccordionDetailField(row, "ErrorOrigin", "Developer.ErrorFieldOrigin", originText, yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "ErrorFirstSeen", "Developer.ErrorFieldFirstSeen", FormatErrorTimestamp(record.firstSeen), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "ErrorLastSeen", "Developer.ErrorFieldLastSeen", FormatErrorTimestamp(record.lastSeen), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "ErrorOccurrences", "Developer.ErrorFieldOccurrences", tostring(record.occurrenceCount or 1), yOffset, width)

    yOffset = yOffset - 6

    yOffset = AddDetailHeader(row, "StackTrace", "Developer.ErrorFieldStackTrace", yOffset)
    yOffset = AC.Dashboard:SetAccordionDetailDescription(row, record.stackTrace or AC.L:Get("Developer.ErrorNoStackTrace"), yOffset, width, "StackTrace")

    return detailYOffset - yOffset

end

function DeveloperPanel:HideErrorDetail(row)

    HideDetailHeader(row, "FullMessage")
    AC.Dashboard:HideAccordionDetailDescription(row, "FullMessage")

    AC.Dashboard:HideAccordionDetailField(row, "ErrorSignature")
    AC.Dashboard:HideAccordionDetailField(row, "ErrorOrigin")
    AC.Dashboard:HideAccordionDetailField(row, "ErrorFirstSeen")
    AC.Dashboard:HideAccordionDetailField(row, "ErrorLastSeen")
    AC.Dashboard:HideAccordionDetailField(row, "ErrorOccurrences")

    HideDetailHeader(row, "StackTrace")
    AC.Dashboard:HideAccordionDetailDescription(row, "StackTrace")

end

function DeveloperPanel:BuildErrorsToolbar()

    if self.ErrorsStatusText then
        return
    end

    self.ErrorsStatusText = self:GetPageToolbarStatus("Errors")
    self.ErrorsClearButton = self:GetPageToolbarButton("Errors", "Clear", AC.L:Get("Developer.ClearErrors"), 110, function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_ERRORS")
    end)
    self.ErrorsTestButton = self:GetPageToolbarButton("Errors", "Test", AC.L:Get("Developer.GenerateTestError"), 150, function()
        AC.UserActionService:GenerateTestError()
    end)
    self.ErrorsExportButton = self:GetPageToolbarButton("Errors", "Export", AC.L:Get("Developer.ExportAllErrors"), 140, function()
        self:ExportAllErrors()
    end)

end

function DeveloperPanel:BuildErrorsTab()

    self:BuildErrorsToolbar()

    local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")

    if not errorCapture and AC.Logger then
        AC.Logger:Warn("Developer Panel: ErrorCapture capability unavailable -- Errors tab has nothing to read from. This should not happen; check Core/Runtime/ErrorCapture.lua registered correctly.")
    end

    local errors = errorCapture and errorCapture:GetErrors() or {}

    -- Capture (the persisted setting's intent, GetSettings().CaptureLuaErrors)
    -- and Installed (IsInstalled()'s ground truth) are shown separately --
    -- deliberately not collapsed into one boolean, since a real mismatch
    -- between them (setting says on, hook isn't actually installed) is
    -- exactly the kind of thing this status line exists to surface.
    local capturing = errorCapture ~= nil and errorCapture:GetSettings().CaptureLuaErrors
    local installed = errorCapture ~= nil and errorCapture:IsInstalled()
    local statusR, statusG, statusB = unpack(AC.Presentation.GetSemanticColor(installed and "success" or "dim"))

    self.ErrorsStatusText:SetText(AC.L:Format("Developer.ErrorsStatusFormat",
        capturing and AC.L:Get("Developer.CaptureOn") or AC.L:Get("Developer.CaptureOff"),
        installed and AC.L:Get("Developer.InstalledYes") or AC.L:Get("Developer.InstalledNo"),
        #errors))
    self.ErrorsStatusText:SetTextColor(statusR, statusG, statusB)
    self.ErrorsStatusText:Show()

    self.ErrorsClearButton:Show()
    self.ErrorsTestButton:Show()
    self.ErrorsExportButton:Show()

    -- Newest first -- a separate array, never reordering ErrorCapture's
    -- own (first-seen-ordered) storage.
    local records = {}

    for i = #errors, 1, -1 do
        table.insert(records, errors[i])
    end

    local yOffset = AC.Dashboard:LayoutAccordionRows(self, "Errors", self.ScrollChild, TOOLBAR_CONTENT_TOP, CONTENT_WIDTH, records,
    {
        expandedField = "ExpandedErrorKey",
        getRecordID = function(record) return record.key end,
        rowGap = AC.DashboardLayout.ACCORDION_ROW_GAP,
        emptyTextKey = "Developer.NoErrorsCaptured",

        buildRow = function(sc)
            return self:BuildErrorRow(sc)
        end,

        layoutCollapsed = function(row, record, width)
            return self:LayoutErrorCollapsed(row, record, width)
        end,

        buildDetail = function(row, record, width, detailYOffset)
            return self:BuildErrorDetail(row, record, width, detailYOffset)
        end,

        hideDetail = function(row)
            self:HideErrorDetail(row)
        end,

        onToggle = function(recordID)

            -- Deliberately not the `cond and nil or recordID` idiom -- it
            -- silently breaks when the "true" branch's value is nil,
            -- which is exactly this case (collapsing sets it to nil), so
            -- it always fell through to recordID and could never close
            -- an already-expanded row.
            if self.ExpandedErrorKey == recordID then
                self.ExpandedErrorKey = nil
            else
                self.ExpandedErrorKey = recordID
            end

            self:ShowTab("Errors")

        end,
    })

    local summaryLines = {}

    for _, record in ipairs(records) do

        table.insert(summaryLines, string.format("[%dx] %s -- %s (last seen %s)",
            record.occurrenceCount or 1, TruncateMessage(record.message), record.location or AC.L:Get("Common.Unknown"), FormatErrorTimestamp(record.lastSeen)))

    end

    self.CurrentTabData = self:BuildErrorExportData(records)
    self.CurrentTabSummaryLines = summaryLines

    return (-yOffset) + 16

end

-- The one place a stored error record becomes the field-subset shape any
-- export format serializes -- shared by BuildErrorsTab (Copy JSON/Text/
-- Summary, whichever tab is active) and ExportAllErrors below, so there is
-- exactly one mapping to maintain, not two.
function DeveloperPanel:BuildErrorExportData(records)

    local data = {}

    for _, record in ipairs(records) do

        table.insert(data,
        {
            message = record.message,
            location = record.location,
            module = record.module,
            origin = record.origin,
            thirdPartyAddon = record.thirdPartyAddon,
            functionName = record.functionName,
            lineNumber = record.lineNumber,
            occurrenceCount = record.occurrenceCount,
            firstSeen = FormatErrorTimestamp(record.firstSeen),
            lastSeen = FormatErrorTimestamp(record.lastSeen),
            signature = record.key,
        })

    end

    return data

end

-- Export All Errors -- every currently stored error, regardless of which
-- tab is active, as one plain-text report. Reuses BuildErrorExportData for
-- the exact same per-error shape Copy JSON/Text/Summary already produce,
-- and AC.DeveloperModeService:ToIndentedText for the exact same serializer
-- "Copy Text" already uses -- no new export format, no new mechanism. The
-- indented, one-field-per-line shape it already produces is plain text
-- with no color codes or WoW escape sequences, so it pastes cleanly into
-- GitHub Issues, Discord, a chat client, or a plain text editor as-is.
function DeveloperPanel:ExportAllErrors()

    local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")
    local errors = errorCapture and errorCapture:GetErrors() or {}

    -- Newest first, same convention BuildErrorsTab uses -- a separate
    -- array, never reordering ErrorCapture's own storage.
    local records = {}

    for i = #errors, 1, -1 do
        table.insert(records, errors[i])
    end

    local data = self:BuildErrorExportData(records)
    local text = AC.DeveloperModeService:ToIndentedText(data)

    self.CopyBox:SetText(text or "")
    self.CopyBox:SetFocus()
    self.CopyBox:HighlightText()

end

-------------------------------------------------------------------------------
-- Secret Values Tab
--
-- Diagnostics Hardening Pass -- presents AC.DeveloperRuntime's
-- "SecretValueEvents" capability, the diagnostic record of every event
-- AC.SecretValueGuard:TryRead has recorded: a Blizzard secure-callback read
-- (TooltipDataProcessor, Menu.ModifyMenu, and any future callback of the
-- same family) that was blocked as a secret value, or that failed for some
-- other reason while attempting one. Deliberately a separate tab, not rows
-- merged into the Errors tab -- these are a different kind of event
-- (expected, designed-for boundary behavior in the common case, not a
-- crash) even though a CALLBACK_EXCEPTION/UNKNOWN_EXCEPTION entry here will
-- also appear in the Errors tab (SecretValueGuard re-throws those after
-- recording -- see its own header for why real bugs are never hidden here).
-- The two tabs are complementary, not duplicates: this one adds the
-- secure-callback context (which boundary, which classification) the
-- Errors tab has no dedicated field for.
--
-- Row/detail/toolbar shape is a deliberate mirror of the Errors tab
-- immediately above -- same accordion engine (AC.Dashboard:LayoutAccordionRows),
-- same collapsed-row/detail-field primitives, and direct reuse of
-- TruncateMessage/AddDetailHeader/HideDetailHeader (already generalized
-- above, not Error-specific) rather than a second copy of any of it.
-------------------------------------------------------------------------------

local SECRET_VALUE_STATUS_COLOR =
{
    SECRET_VALUE_BLOCKED = "dim",       -- the expected, designed-for outcome -- not alarming.
    CALLBACK_EXCEPTION = "critical",    -- a real bug, re-thrown by SecretValueGuard -- also visible in the Errors tab.
    UNKNOWN_EXCEPTION = "critical",     -- likewise a real bug/unexpected failure shape.
}

local function SecretValueStatusColor(status)

    return SECRET_VALUE_STATUS_COLOR[status] or "dim"

end

function DeveloperPanel:BuildSecretValueRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    row:SetScript("OnEnter", function(self_)
        self_.Background:SetColorTexture(1, 1, 1, 0.06)
    end)

    row:SetScript("OnLeave", function(self_)
        self_.Background:SetColorTexture(1, 1, 1, 0)
    end)

    local contextText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contextText:SetJustifyH("LEFT")
    row.ContextText = contextText

    local messageText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    messageText:SetJustifyH("LEFT")
    messageText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
    row.MessageText = messageText

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    metaText:SetJustifyH("LEFT")
    metaText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
    row.MetaText = metaText

    return row

end

-- Collapsed preview: Context+Status (colored by severity) / Message preview
-- / Occurrences+Last Seen -- the same fixed 3-line shape LayoutErrorCollapsed
-- already uses, covering this tab's own "Context, Count, Last Seen, Status,
-- Message" column requirement as stacked lines rather than a literal grid,
-- consistent with how this file already renders every other log-style list.
function DeveloperPanel:LayoutSecretValueCollapsed(row, record, width)

    local baseX = AC.DashboardLayout.ACCORDION_DISCLOSURE_WIDTH
    local rowWidth = width - baseX

    row.ContextText:ClearAllPoints()
    row.ContextText:SetPoint("TOPLEFT", baseX, 0)
    row.ContextText:SetWidth(rowWidth)
    row.ContextText:SetText(AC.L:Format("Developer.SecretValueContextFormat", record.context or AC.L:Get("Common.Unknown"), record.status or AC.L:Get("Common.Unknown")))
    row.ContextText:SetTextColor(unpack(AC.Presentation.GetSemanticColor(SecretValueStatusColor(record.status))))

    row.MessageText:ClearAllPoints()
    row.MessageText:SetPoint("TOPLEFT", row.ContextText, "BOTTOMLEFT", 0, -2)
    row.MessageText:SetWidth(rowWidth)
    row.MessageText:SetText(TruncateMessage(record.message))

    row.MetaText:ClearAllPoints()
    row.MetaText:SetPoint("TOPLEFT", row.MessageText, "BOTTOMLEFT", 0, -2)
    row.MetaText:SetWidth(rowWidth)
    row.MetaText:SetText(AC.L:Format("Developer.SecretValueMetaFormat", record.occurrenceCount or 1, record.lastSeen or AC.L:Get("Common.Unknown")))

    return (row.ContextText:GetStringHeight() or 14) + (row.MessageText:GetStringHeight() or 12) + (row.MetaText:GetStringHeight() or 12) + 4

end

function DeveloperPanel:BuildSecretValueDetail(row, record, width, detailYOffset)

    local yOffset = detailYOffset

    yOffset = AddDetailHeader(row, "SecretValueFullMessage", "Developer.SecretValueFieldMessage", yOffset)
    yOffset = AC.Dashboard:SetAccordionDetailDescription(row, record.message, yOffset, width, "SecretValueFullMessage")

    yOffset = yOffset - 6

    yOffset = AC.Dashboard:SetAccordionDetailField(row, "SecretValueSource", "Developer.SecretValueFieldSource", record.source or AC.L:Get("Common.Unknown"), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "SecretValueStatus", "Developer.SecretValueFieldStatus", record.status or AC.L:Get("Common.Unknown"), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "SecretValueFirstSeen", "Developer.SecretValueFieldFirstSeen", record.firstSeen or AC.L:Get("Common.Unknown"), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "SecretValueLastSeen", "Developer.SecretValueFieldLastSeen", record.lastSeen or AC.L:Get("Common.Unknown"), yOffset, width)
    yOffset = AC.Dashboard:SetAccordionDetailField(row, "SecretValueOccurrences", "Developer.SecretValueFieldOccurrences", tostring(record.occurrenceCount or 1), yOffset, width)

    yOffset = yOffset - 6

    yOffset = AddDetailHeader(row, "SecretValueStackTrace", "Developer.SecretValueFieldStackTrace", yOffset)
    yOffset = AC.Dashboard:SetAccordionDetailDescription(row, record.stack or AC.L:Get("Developer.SecretValueNoStackTrace"), yOffset, width, "SecretValueStackTrace")

    return detailYOffset - yOffset

end

function DeveloperPanel:HideSecretValueDetail(row)

    HideDetailHeader(row, "SecretValueFullMessage")
    AC.Dashboard:HideAccordionDetailDescription(row, "SecretValueFullMessage")

    AC.Dashboard:HideAccordionDetailField(row, "SecretValueSource")
    AC.Dashboard:HideAccordionDetailField(row, "SecretValueStatus")
    AC.Dashboard:HideAccordionDetailField(row, "SecretValueFirstSeen")
    AC.Dashboard:HideAccordionDetailField(row, "SecretValueLastSeen")
    AC.Dashboard:HideAccordionDetailField(row, "SecretValueOccurrences")

    HideDetailHeader(row, "SecretValueStackTrace")
    AC.Dashboard:HideAccordionDetailDescription(row, "SecretValueStackTrace")

end

function DeveloperPanel:BuildSecretValuesToolbar()

    if self.SecretValuesStatusText then
        return
    end

    self.SecretValuesStatusText = self:GetPageToolbarStatus("SecretValues")
    self.SecretValuesClearButton = self:GetPageToolbarButton("SecretValues", "Clear", AC.L:Get("Developer.ClearSecretValues"), 110, function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_SECRET_VALUES")
    end)

end

function DeveloperPanel:BuildSecretValuesTab()

    self:BuildSecretValuesToolbar()

    local secretValueEvents = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("SecretValueEvents")

    if not secretValueEvents and AC.Logger then
        AC.Logger:Warn("Developer Panel: SecretValueEvents capability unavailable -- Secret Values tab has nothing to read from. This should not happen; check Core/Runtime/SecretValueEvents.lua registered correctly.")
    end

    local events = secretValueEvents and secretValueEvents:GetEvents() or {}

    -- Recording (SecretValueEvents.Enabled, gated on Developer Mode via
    -- Install/Remove) is shown separately from SecretValueGuard's own
    -- pcall protection, which is never gated -- a player with Developer
    -- Mode off is still fully protected from a crash, this line only says
    -- whether events are currently being recorded for this tab to show.
    local recording = secretValueEvents ~= nil and secretValueEvents.Enabled == true
    local statusR, statusG, statusB = unpack(AC.Presentation.GetSemanticColor(recording and "success" or "dim"))

    self.SecretValuesStatusText:SetText(AC.L:Format("Developer.SecretValuesStatusFormat",
        recording and AC.L:Get("Developer.CaptureOn") or AC.L:Get("Developer.CaptureOff"), #events))
    self.SecretValuesStatusText:SetTextColor(statusR, statusG, statusB)
    self.SecretValuesStatusText:Show()

    self.SecretValuesClearButton:Show()

    -- Newest first -- a separate array, never reordering the capability's
    -- own (first-seen-ordered) storage, same discipline the Errors tab
    -- already established.
    local records = {}

    for i = #events, 1, -1 do
        table.insert(records, events[i])
    end

    local yOffset = AC.Dashboard:LayoutAccordionRows(self, "SecretValues", self.ScrollChild, TOOLBAR_CONTENT_TOP, CONTENT_WIDTH, records,
    {
        expandedField = "ExpandedSecretValueKey",
        getRecordID = function(record) return record.key end,
        rowGap = AC.DashboardLayout.ACCORDION_ROW_GAP,
        emptyTextKey = "Developer.NoSecretValueEvents",

        buildRow = function(sc)
            return self:BuildSecretValueRow(sc)
        end,

        layoutCollapsed = function(row, record, width)
            return self:LayoutSecretValueCollapsed(row, record, width)
        end,

        buildDetail = function(row, record, width, detailYOffset)
            return self:BuildSecretValueDetail(row, record, width, detailYOffset)
        end,

        hideDetail = function(row)
            self:HideSecretValueDetail(row)
        end,

        onToggle = function(recordID)
            self.ExpandedSecretValueKey = (self.ExpandedSecretValueKey == recordID) and nil or recordID
            self:ShowTab("SecretValues")
        end,
    })

    local summaryLines = {}
    local data = {}

    for _, record in ipairs(records) do

        table.insert(summaryLines, string.format("[%dx] %s -- %s: %s (last seen %s)",
            record.occurrenceCount or 1, record.context or AC.L:Get("Common.Unknown"), record.status or AC.L:Get("Common.Unknown"), TruncateMessage(record.message), record.lastSeen or AC.L:Get("Common.Unknown")))

        table.insert(data,
        {
            context = record.context,
            source = record.source,
            status = record.status,
            message = record.message,
            occurrenceCount = record.occurrenceCount,
            firstSeen = record.firstSeen,
            lastSeen = record.lastSeen,
        })

    end

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = summaryLines

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Live API Inspector
--
-- One "Inspect Now" button per system named in DEVELOPMENT_BACKLOG.md's
-- "Needs Live Verification" list -- Weekly/Great Vault, Storage/Bank
-- (Character + Warband, the same Enum.BankType split StorageModule
-- itself uses), Mythic+, and Affixes. Each probe calls the real Blizzard
-- API directly (pcall-wrapped, on-demand only -- never polled) for "Raw"
-- and the owning module's own already-existing public getter for
-- "Final" -- this tab never reimplements a module's own parsing, it only
-- places two already-real values side by side. A row is highlighted red
-- when Raw and Final genuinely disagree; StorageModule/WeeklyModule's own
-- unverified-field-shape caveats (see their file headers) are exactly
-- what this exists to spot-check.
-------------------------------------------------------------------------------

local function ProbeWeeklyVault()

    local rows = {}

    local activityType = Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Activities
    local rawCount = 0
    local rawHasRewards

    if activityType and C_WeeklyRewards and C_WeeklyRewards.GetActivities then

        local ok, activities = pcall(C_WeeklyRewards.GetActivities, activityType)

        if ok and type(activities) == "table" then
            for _ in pairs(activities) do
                rawCount = rawCount + 1
            end
        end

    end

    if C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards then
        local ok, result = pcall(C_WeeklyRewards.HasAvailableRewards)
        rawHasRewards = ok and result or nil
    end

    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
    local profile = weeklyModule and weeklyModule:GetVaultProgress()

    table.insert(rows, { label = "Activities Count", raw = rawCount, final = profile and profile.totalSlots })
    table.insert(rows, { label = "Has Available Rewards", raw = rawHasRewards, final = profile and profile.hasAvailableRewards })

    return rows

end

-- Live Verification & Framework Hardening sprint: each probe result is
-- ONLY a Raw/Final side-by-side comparison of two already-real values --
-- it can catch a parsing mismatch, but it cannot by itself prove a
-- Blizzard field means what this addon assumes it means (see
-- weekly.progressUnits in VerificationService's registry). The
-- Mark Verified/Failed buttons below exist for exactly that gap: a human
-- who has actually watched the real in-game result records the
-- confirmation, this tab never self-certifies.

local function ProbeStorageBank()

    local rows = {}

    local characterBankType = Enum.BankType and Enum.BankType.Character
    local accountBankType = Enum.BankType and Enum.BankType.Account

    local characterTabCount = 0
    local accountTabCount = 0
    local canUseAccountBank

    if characterBankType and C_Bank and C_Bank.FetchPurchasedBankTabIDs then

        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, characterBankType)

        if ok and type(ids) == "table" then
            characterTabCount = #ids
        end

    end

    if accountBankType and C_Bank and C_Bank.CanUseBank then

        local ok, result = pcall(C_Bank.CanUseBank, accountBankType)
        canUseAccountBank = ok and result or false

        if canUseAccountBank and C_Bank.FetchPurchasedBankTabIDs then

            local okIDs, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, accountBankType)

            if okIDs and type(ids) == "table" then
                accountTabCount = #ids
            end

        end

    end

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local bankSummary = storageModule and storageModule.GetBankSummary and storageModule:GetBankSummary()

    table.insert(rows, { label = "Character Bank Tabs", raw = characterTabCount, final = nil })
    table.insert(rows, { label = "Can Use Warband Bank", raw = canUseAccountBank, final = nil })
    table.insert(rows, { label = "Warband Bank Tabs", raw = accountTabCount, final = nil })
    table.insert(rows, { label = "Bank Accessible (Final)", raw = nil, final = bankSummary and bankSummary.accessible })
    table.insert(rows, { label = "Distinct Items Scanned (Final)", raw = nil, final = bankSummary and bankSummary.distinctItems })

    return rows

end

local function ProbeMythicPlus()

    local rows = {}

    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    local rating = C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore and C_ChallengeMode.GetOverallDungeonScore()
    local season = C_MythicPlus and C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local profile = mythicPlusModule and mythicPlusModule:GetProfile()

    table.insert(rows, { label = "Owned Keystone Map ID", raw = mapID, final = profile and profile.currentDungeonID })
    table.insert(rows, { label = "Owned Keystone Level", raw = level, final = profile and profile.currentLevel })
    table.insert(rows, { label = "Overall Dungeon Score", raw = rating and AC.Presentation.FormatRating(rating), final = profile and AC.Presentation.FormatRating(profile.rating) })
    table.insert(rows, { label = "Current Season", raw = season, final = profile and profile.currentSeason })

    return rows

end

local function ProbeAffixes()

    local rows = {}

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local profile = mythicPlusModule and mythicPlusModule:GetProfile()
    local affixIDs = profile and (profile.weeklyAffixIDs or profile.currentAffixIDs) or {}

    if #affixIDs == 0 then
        table.insert(rows, { label = "Weekly Affixes", raw = AC.L:Get("Common.Unknown"), final = AC.L:Get("Common.Unknown") })
        return rows
    end

    for _, affixID in ipairs(affixIDs) do

        local rawName

        if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            local ok, name = pcall(C_ChallengeMode.GetAffixInfo, affixID)
            rawName = ok and name or nil
        end

        local finalName

        if mythicPlusModule and mythicPlusModule.GetAffixDisplayInfo then
            local ok, info = pcall(mythicPlusModule.GetAffixDisplayInfo, mythicPlusModule, affixID)
            finalName = ok and info and info.name or nil
        end

        table.insert(rows, { label = "Affix " .. tostring(affixID), raw = rawName, final = finalName })

    end

    return rows

end

local LIVE_API_PROBES =
{
    { key = "Weekly", labelKey = "Developer.ProbeWeekly", fn = ProbeWeeklyVault, verifyIds = { "weekly.activities" } },
    { key = "Storage", labelKey = "Developer.ProbeStorage", fn = ProbeStorageBank, verifyIds = { "storage.bankTabs" } },
    { key = "MythicPlus", labelKey = "Developer.ProbeMythicPlus", fn = ProbeMythicPlus, verifyIds = { "mp.mythicPlusNamespace" } },
    { key = "Affixes", labelKey = "Developer.ProbeAffixes", fn = ProbeAffixes, verifyIds = { "mp.challengeMode" } },
}

-- Timestamp formatting shared by the Live API and Checklist tabs.
local function FormatVerificationTimestamp(timestamp)

    if not timestamp or timestamp == 0 then
        return AC.L:Get("Developer.LabelNeverVerified")
    end

    return AC.Presentation.FormatDate(timestamp, "shortTime")

end

function DeveloperPanel:BuildLiveAPITab()

    self.LiveAPIButtons = self.LiveAPIButtons or {}
    self.LiveAPIResults = self.LiveAPIResults or {}
    self.LiveAPIVerifyButtons = self.LiveAPIVerifyButtons or {}

    if #self.LiveAPIButtons == 0 then

        local previous

        for _, probe in ipairs(LIVE_API_PROBES) do

            local button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            button:SetSize(150, 22)

            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
            else
                button:SetPoint("TOPLEFT", 0, -4)
            end

            button:SetText(AC.L:Get(probe.labelKey))

            button:SetScript("OnClick", function()

                local ok, rows = pcall(probe.fn)

                self.LiveAPIResults[probe.key] = ok and rows or { { label = AC.L:Get("Developer.ProbeFailed"), raw = "", final = "" } }

                DeveloperPanel:NavigateTab("LiveAPI")

            end)

            table.insert(self.LiveAPIButtons, button)
            previous = button

        end

    end

    if not self.LiveAPIVerifyButtonsBuilt then

        self.LiveAPIVerifyButtonsBuilt = true

        local previous

        for _, probe in ipairs(LIVE_API_PROBES) do

            local verifiedButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            verifiedButton:SetSize(90, 20)

            local failedButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            failedButton:SetSize(90, 20)

            if previous then
                verifiedButton:SetPoint("LEFT", previous, "RIGHT", 12, 0)
            else
                verifiedButton:SetPoint("TOPLEFT", self.LiveAPIButtons[1], "BOTTOMLEFT", 0, -6)
            end

            failedButton:SetPoint("LEFT", verifiedButton, "RIGHT", 4, 0)

            verifiedButton:SetText(AC.L:Get("Developer.MarkVerified"))
            failedButton:SetText(AC.L:Get("Developer.MarkFailed"))

            verifiedButton:SetScript("OnClick", function()

                if not self.LiveAPIResults[probe.key] then
                    return
                end

                for _, id in ipairs(probe.verifyIds) do
                    AC.VerificationService:RecordResult(id, true)
                end

                DeveloperPanel:NavigateTab("LiveAPI")

            end)

            failedButton:SetScript("OnClick", function()

                if not self.LiveAPIResults[probe.key] then
                    return
                end

                for _, id in ipairs(probe.verifyIds) do
                    AC.VerificationService:RecordResult(id, false)
                end

                DeveloperPanel:NavigateTab("LiveAPI")

            end)

            self.LiveAPIVerifyButtons[probe.key] = { verified = verifiedButton, failed = failedButton }
            previous = verifiedButton

        end

    end

    for _, button in ipairs(self.LiveAPIButtons) do
        button:Show()
    end

    for _, probe in ipairs(LIVE_API_PROBES) do

        local pair = self.LiveAPIVerifyButtons[probe.key]
        local hasResults = self.LiveAPIResults[probe.key] ~= nil

        pair.verified:SetShown(true)
        pair.failed:SetShown(true)
        pair.verified:SetEnabled(hasResults)
        pair.failed:SetEnabled(hasResults)

    end

    local lines = {}
    local data = {}

    local counts = AC.VerificationService:GetSummaryCounts()
    local glyph = AC.VerificationService.StatusGlyph
    local summaryLine = AC.L:Format("Developer.SummaryFormat", glyph.source, counts.source, glyph.wiki, counts.wiki, glyph.live, counts.live, glyph.needsLive, counts.needsLive, glyph.incorrect, counts.incorrect)
    local yOffset = -62

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Developer.SummaryHeader", yOffset)
    yOffset = AC.Dashboard:LayoutStatisticsGrid(self, "LiveAPISummary", self.ScrollChild, yOffset, CONTENT_WIDTH,
    {
        { label = "Developer.StatusSource", value = tostring(counts.source) },
        { label = "Developer.StatusWiki", value = tostring(counts.wiki) },
        { label = "Developer.StatusLive", value = tostring(counts.live) },
        { label = "Developer.StatusNeedsLive", value = tostring(counts.needsLive) },
        { label = "Developer.StatusIncorrect", value = tostring(counts.incorrect) },
    })
    yOffset = AC.Dashboard:EndSection(yOffset)

    for _, probe in ipairs(LIVE_API_PROBES) do

        local rows = self.LiveAPIResults[probe.key]

        if rows then

            table.insert(lines, { text = AC.L:Get(probe.labelKey), r = 1, g = 0.82, b = 0 })

            for _, row in ipairs(rows) do

                local rawText = row.raw == nil and AC.L:Get("Common.Unknown") or tostring(row.raw)
                local finalText = row.final == nil and AC.L:Get("Common.Unknown") or tostring(row.final)

                local mismatch = row.raw ~= nil and row.final ~= nil and rawText ~= finalText

                -- Presentation System v2 -- was its own hardcoded
                -- (1,0.3,0.3)/(0.85,0.85,0.85) pair, both distinct from
                -- the addon's canonical critical/dim tokens; migrated, a
                -- real visible shift on both branches.
                local mismatchR, mismatchG, mismatchB = unpack(AC.Presentation.GetSemanticColor(mismatch and "critical" or "dim"))

                table.insert(lines,
                {
                    text = string.format("  %s   %s: %s   %s: %s", row.label, AC.L:Get("Developer.LabelRaw"), rawText, AC.L:Get("Developer.LabelFinal"), finalText),
                    r = mismatchR,
                    g = mismatchG,
                    b = mismatchB,
                })

                table.insert(data, { probe = probe.key, label = row.label, raw = rawText, final = finalText, mismatch = mismatch })

            end

            -- One Expected/Confidence/Source/Last-Verified summary per
            -- probe (not per row) -- the probe's rows already share one
            -- underlying registry entry (see verifyIds above).
            local entry = AC.VerificationService:GetById(probe.verifyIds[1])

            if entry then

                table.insert(lines,
                {
                    text = string.format("  %s: %s", AC.L:Get("Developer.LabelExpected"), entry.expected or entry.citation or ""),
                    r = 0.7, g = 0.7, b = 0.7,
                })

                local record = AC.VerificationService:GetRecord(probe.verifyIds[1])

                table.insert(lines,
                {
                    text = string.format("  %s: %s   %s: %s   %s: %s",
                        AC.L:Get("Developer.LabelConfidence"), entry.confidence or "",
                        AC.L:Get("Developer.LabelSource"), entry.citation or "",
                        AC.L:Get("Developer.LabelLastVerified"), FormatVerificationTimestamp(record and record.timestamp)),
                    r = 0.7, g = 0.7, b = 0.7,
                })

            end

        end

    end

    if #data == 0 then
        table.insert(lines, AC.L:Get("Developer.NoProbeResults"))
    end

    -- Full Verification Registry -- every Blizzard API/behavior this
    -- addon depends on, not just the four with a live Raw/Final probe
    -- above. Read-only (no per-row buttons -- most of these have no live
    -- comparable value, only a static classification); a persisted
    -- record (from either this tab's own buttons or a completed
    -- Checklist scenario) overrides the static status/timestamp shown.
    table.insert(lines, { text = AC.L:Get("Developer.FullRegistryHeader"), r = 1, g = 0.82, b = 0 })

    for _, entry in ipairs(AC.VerificationService:GetRegistry()) do

        local status = AC.VerificationService:GetEffectiveStatus(entry.id)
        local record = AC.VerificationService:GetRecord(entry.id)
        local statusLabel = AC.L:Get(AC.VerificationService.StatusLabelKey[status])

        -- Presentation System v2 -- was its own hardcoded three-way
        -- (1,0.3,0.3)/(0.85,0.75,0.3)/(0.85,0.85,0.85) set, each distinct
        -- from the addon's canonical critical/warning/dim tokens; migrated,
        -- a real visible shift on all three branches.
        local statusColorName = status == "incorrect" and "critical" or (status == "needsLive" and "warning" or "dim")
        local statusR, statusG, statusB = unpack(AC.Presentation.GetSemanticColor(statusColorName))

        table.insert(lines,
        {
            text = string.format("  %s [%s] %s -- %s (%s)", glyph[status], entry.module, entry.api, statusLabel, entry.confidence or ""),
            r = statusR,
            g = statusG,
            b = statusB,
        })

        table.insert(lines,
        {
            text = string.format("    %s: %s   %s: %s", AC.L:Get("Developer.LabelSource"), entry.citation or "", AC.L:Get("Developer.LabelLastVerified"), FormatVerificationTimestamp(record and record.timestamp)),
            r = 0.6, g = 0.6, b = 0.6,
        })

    end

    yOffset = self:LayoutLines("LiveAPI", lines, yOffset, CONTENT_WIDTH)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = { summaryLine }

    for _, line in ipairs(lines) do
        table.insert(self.CurrentTabSummaryLines, line)
    end

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Blizzard API Explorer
--
-- Developer-only presentation for DeveloperApiExplorerService. Controls own
-- input state; the service owns resolution, parsing, execution, and raw output.
-------------------------------------------------------------------------------

function DeveloperPanel:ExecuteAPIExplorer()

    local functionName = self.APIExplorerFunctionInput:GetValue()
    local arguments = self.APIExplorerArgumentsInput:GetValue()
    local ok, status, lines = AC.DeveloperApiExplorerService:Execute(functionName, arguments)

    self.APIExplorerStatus = status
    self.APIExplorerStatusOK = ok
    self.APIExplorerResultLines = lines
    self.APIExplorerSearchMatches = nil
    self:EnsureAPIExplorerTreeRows(AC.DeveloperApiExplorerService:GetNodeCount())
    self:RefreshAPIExplorerRecent()
    self:RefreshAPIExplorer(false, false)

end

function DeveloperPanel:PopulateAPIExplorer(functionName, arguments)
    self.APIExplorerFunctionInput:SetValue(functionName or "")
    self.APIExplorerArgumentsInput:SetValue(arguments or "")
end

function DeveloperPanel:CopyAPIExplorerResult()
    self.CopyBox:SetText(AC.DeveloperApiExplorerService:ExportCurrent())
    self.CopyBox:SetFocus()
    self.CopyBox:HighlightText()
end

function DeveloperPanel:SearchAPIExplorer()
    local matches = AC.DeveloperApiExplorerService:Search(self.APIExplorerSearchInput:GetValue())
    self.APIExplorerSearchMatches = matches
    local node = matches[1]
    local parent = node and node.parent
    while parent do parent.expanded = true parent = parent.parent end
    self.APIExplorerStatus = #matches == 0 and "No search matches." or ("Found %d match(es); showing the first."):format(#matches)
    self:RefreshAPIExplorer(true)
    if node and self.APIExplorerNodeRows then
        for index, entry in ipairs(AC.DeveloperApiExplorerService:GetVisibleNodes()) do
            if entry.node == node then self.ScrollFrame:SetVerticalScroll(math.max(0, 190 + ((index - 1) * 20))) break end
        end
    end
end


function DeveloperPanel:GetAPIExplorerControls()

    if self.APIExplorerControls then
        return self.APIExplorerControls
    end

    local container = CreateFrame("Frame", nil, self.ScrollChild)
    container:SetPoint("TOPLEFT", 0, -4)
    container:SetSize(CONTENT_WIDTH, 194)
    local editorLeft = 220
    local editorWidth = CONTENT_WIDTH - editorLeft - 12

    local functionLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    functionLabel:SetPoint("TOPLEFT", editorLeft, 0)
    functionLabel:SetText(AC.L:Get("Developer.APIExplorerFunction"))

    local functionInput = AC.WidgetManager:Create("EditBox", container,
    {
        width = editorWidth,
        onEnterPressed = function()
            DeveloperPanel:ExecuteAPIExplorer()
        end,
    })
    functionInput:GetFrame():SetPoint("TOPLEFT", editorLeft, -18)

    local argumentsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    argumentsLabel:SetPoint("TOPLEFT", editorLeft, -54)
    argumentsLabel:SetText(AC.L:Get("Developer.APIExplorerArguments"))

    local argumentsInput = AC.WidgetManager:Create("EditBox", container,
    {
        width = editorWidth,
        onEnterPressed = function()
            DeveloperPanel:ExecuteAPIExplorer()
        end,
    })
    argumentsInput:GetFrame():SetPoint("TOPLEFT", editorLeft, -72)

    local searchInput = AC.WidgetManager:Create("EditBox", container, { width = editorWidth - 110, onEnterPressed = function() DeveloperPanel:ExecuteAPIExplorer() end })
    searchInput:GetFrame():SetPoint("TOPLEFT", editorLeft, -108)
    local searchButton = AC.WidgetManager:Create("Button", container, { width = 96, text = AC.L:Get("Developer.APIExplorerSearch"), onClick = function() DeveloperPanel:SearchAPIExplorer() end })
    searchButton:GetFrame():SetPoint("LEFT", searchInput:GetFrame(), "RIGHT", 8, 0)

    local executeButton = AC.WidgetManager:Create("Button", container,
    {
        width = 100,
        text = AC.L:Get("Developer.APIExplorerExecute"),
        onClick = function()
            DeveloperPanel:ExecuteAPIExplorer()
        end,
    })
    executeButton:GetFrame():SetPoint("TOPLEFT", editorLeft, -142)

    local favoriteButton = AC.WidgetManager:Create("Button", container, { width = 100, text = AC.L:Get("Developer.APIExplorerFavorite"), onClick = function()
        AC.DeveloperApiExplorerService:ToggleFavorite(DeveloperPanel.APIExplorerFunctionInput:GetValue())
        DeveloperPanel:EnsureAPIExplorerNavigationRows()
        DeveloperPanel:RefreshAPIExplorer(true)
    end })
    favoriteButton:GetFrame():SetPoint("LEFT", executeButton:GetFrame(), "RIGHT", 8, 0)
    local copyButton = AC.WidgetManager:Create("Button", container, { width = 100, text = AC.L:Get("Developer.APIExplorerCopyResult"), onClick = function() DeveloperPanel:CopyAPIExplorerResult() end })
    copyButton:GetFrame():SetPoint("LEFT", favoriteButton:GetFrame(), "RIGHT", 8, 0)

    local status = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", copyButton:GetFrame(), "RIGHT", 12, 0)
    status:SetWidth(math.max(120, editorWidth - 336))
    status:SetJustifyH("LEFT")

    local resultsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultsLabel:SetPoint("TOPLEFT", editorLeft, -178)
    resultsLabel:SetText(AC.L:Get("Developer.APIExplorerResults"))

    self.APIExplorerControls = container
    self.APIExplorerFunctionInput = functionInput
    self.APIExplorerArgumentsInput = argumentsInput
    self.APIExplorerSearchInput = searchInput
    self.APIExplorerExecuteButton = executeButton
    self.APIExplorerStatusText = status

    self:EnsureAPIExplorerNavigationRows()
    self:EnsureAPIExplorerTreeRows(1)

    return container

end


function DeveloperPanel:BuildAPIExplorerTab()

    local controls = self:GetAPIExplorerControls()
    controls:Show()

    self:RefreshAPIExplorer(true)

    return self.APIExplorerContentHeight or 360

end


function DeveloperPanel:RefreshAPIExplorer(preserveScroll, refreshNavigation)

    local scrollPosition = preserveScroll and self.ScrollFrame:GetVerticalScroll() or 0
    local result = AC.DeveloperApiExplorerService:GetCurrentResult()
    local status = self.APIExplorerStatus or AC.L:Get("Developer.APIExplorerReady")
    if result then status = ("%s | %s ms | %d returns%s"):format(result.metadata.status, result.metadata.executionTimeMs, result.metadata.returnCount, result.metadata.error and (" | " .. result.metadata.error) or "") end
    self.APIExplorerStatusText:SetText(status)

    if self.APIExplorerStatusOK == false then
        local r, g, b = unpack(AC.Presentation.GetSemanticColor("critical"))
        self.APIExplorerStatusText:SetTextColor(r, g, b)
    else
        local r, g, b = unpack(AC.Presentation.GetSemanticColor("dim"))
        self.APIExplorerStatusText:SetTextColor(r, g, b)
    end

    if refreshNavigation ~= false then
        self:BuildAPIExplorerNavigation()
    end
    local yOffset = self:LayoutAPIExplorerTree(-202)

    self.CurrentTabData = AC.DeveloperApiExplorerService:GetVisibleLines()
    self.CurrentTabSummaryLines = { status }

    self.APIExplorerContentHeight = math.max((-yOffset) + 16, self.APIExplorerNavigationHeight or 360, 360)
    self.ScrollChild:SetHeight(self.APIExplorerContentHeight)
    self.ScrollFrame:SetVerticalScroll(math.min(scrollPosition, self.ScrollFrame:GetVerticalScrollRange() or scrollPosition))

end

function DeveloperPanel:EnsureAPIExplorerNavigationRows()
    local namespaces = AC.DeveloperApiExplorerService:GetNamespaces()
    local maximumFunctions = 0
    local namespaceCount = 0
    for _, functions in pairs(namespaces) do namespaceCount = namespaceCount + 1 maximumFunctions = math.max(maximumFunctions, #functions) end
    local required = 3 + 5 + namespaceCount + maximumFunctions + #AC.DeveloperApiExplorerService:GetFavorites()
    for index = #(self.APIExplorerNavButtons or {}) + 1, required do self:GetAPIExplorerNavButton(index):Hide() end
end

function DeveloperPanel:EnsureAPIExplorerTreeRows(required)
    self.APIExplorerNodeRows = self.APIExplorerNodeRows or {}
    for index = #self.APIExplorerNodeRows + 1, math.max(1, required or 0) do
        local row = CreateFrame("Button", nil, self.ScrollChild)
        row:SetPoint("TOPLEFT", 220, -202 - ((index - 1) * 20))
        row:SetSize(CONTENT_WIDTH - 232, 18)
        row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Text:SetPoint("LEFT")
        row.Text:SetJustifyH("LEFT")
        row:Hide()
        self.APIExplorerNodeRows[index] = row
    end
end

function DeveloperPanel:GetAPIExplorerNavButton(index)
    self.APIExplorerNavButtons = self.APIExplorerNavButtons or {}
    local button = self.APIExplorerNavButtons[index]
    if not button then
        button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        button:SetSize(204, 18)
        self.APIExplorerNavButtons[index] = button
    end
    return button
end

function DeveloperPanel:BuildAPIExplorerNavigation()
    self.APIExplorerNavigationExpanded = self.APIExplorerNavigationExpanded or
    {
        Favorites = false,
        Recent = false,
        BlizzardAPIs = true,
    }

    local index, y = 0, -4
    local function add(text, callback, indent, visible)
        index = index + 1
        local button = self:GetAPIExplorerNavButton(index)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", indent or 0, y); button:SetWidth(204 - (indent or 0)); button:SetText(text or ""); button:SetScript("OnClick", callback)
        if visible == false then button:Hide() else button:Show() end
        y = y - 20
        return button
    end
    local function addSection(section, label)
        local expanded = self.APIExplorerNavigationExpanded[section]
        local glyph = expanded and AC.DashboardFormat.DISCLOSURE_EXPANDED or AC.DashboardFormat.DISCLOSURE_COLLAPSED
        add(glyph .. " " .. label, function()
            self.APIExplorerNavigationExpanded[section] = not self.APIExplorerNavigationExpanded[section]
            self:RefreshAPIExplorer(true)
        end)
        return expanded
    end

    if addSection("Favorites", AC.L:Get("Developer.APIExplorerFavorites")) then
        for _, name in ipairs(AC.DeveloperApiExplorerService:GetFavorites()) do
            local favoriteName = name
            add("* " .. favoriteName, function() self:PopulateAPIExplorer(favoriteName, "") end, 10)
        end
    end

    local recentExpanded = addSection("Recent", AC.L:Get("Developer.APIExplorerRecent"))
    local history = AC.DeveloperApiExplorerService:GetHistory()
    self.APIExplorerRecentButtons = {}
    if recentExpanded then
        -- The expanded branch always owns five rows. Empty slots stay hidden
        -- but retain their height, so execution updates the branch without
        -- moving the independent Blizzard API browser below it.
        for slot = 1, 5 do
            local call = history[#history - slot + 1]
            if call then
                self.APIExplorerRecentButtons[slot] = add(call.functionName, function() self:PopulateAPIExplorer(call.functionName, call.arguments) end, 10)
            else
                self.APIExplorerRecentButtons[slot] = add("", nil, 10, false)
            end
        end
    end

    local namespaces = AC.DeveloperApiExplorerService:GetNamespaces()
    local namespaceNames = {}
    for namespace in pairs(namespaces) do namespaceNames[#namespaceNames + 1] = namespace end
    table.sort(namespaceNames)
    if addSection("BlizzardAPIs", AC.L:Get("Developer.APIExplorerBlizzardAPIs")) then
        for _, namespace in ipairs(namespaceNames) do
            local namespaceName = namespace
            local functions = namespaces[namespaceName]
            local glyph = self.APIExplorerExpandedNamespace == namespaceName and AC.DashboardFormat.DISCLOSURE_EXPANDED or AC.DashboardFormat.DISCLOSURE_COLLAPSED
            add(glyph .. " " .. namespaceName, function()
                self.APIExplorerExpandedNamespace = self.APIExplorerExpandedNamespace == namespaceName and nil or namespaceName
                self:RefreshAPIExplorer(true)
            end, 10)
            if self.APIExplorerExpandedNamespace == namespaceName then
                for _, fn in ipairs(functions) do
                    local functionLabel = fn
                    local fullName = namespaceName .. "." .. functionLabel
                    add(functionLabel, function() self:PopulateAPIExplorer(fullName, "") end, 20)
                end
            end
        end
    end
    for i = index + 1, #(self.APIExplorerNavButtons or {}) do self.APIExplorerNavButtons[i]:Hide() end
    self.APIExplorerNavigationHeight = (-y) + 16
end

function DeveloperPanel:RefreshAPIExplorerRecent()
    if not self.APIExplorerNavigationExpanded or not self.APIExplorerNavigationExpanded.Recent then
        return
    end

    local history = AC.DeveloperApiExplorerService:GetHistory()
    for slot, button in ipairs(self.APIExplorerRecentButtons or {}) do
        local call = history[#history - slot + 1]
        if call then
            local functionName = call.functionName
            local arguments = call.arguments
            button:SetText(functionName)
            button:SetScript("OnClick", function() self:PopulateAPIExplorer(functionName, arguments) end)
            button:Show()
        else
            button:SetText("")
            button:SetScript("OnClick", nil)
            button:Hide()
        end
    end
end

function DeveloperPanel:LayoutAPIExplorerTree(yOffset)
    self.APIExplorerNodeRows = self.APIExplorerNodeRows or {}
    local entries = AC.DeveloperApiExplorerService:GetVisibleNodes()
    if #entries == 0 then entries = { { empty = true } } end
    for index, entry in ipairs(entries) do
        local row = self.APIExplorerNodeRows[index]
        if entry.empty then row.Text:SetText(AC.L:Get("Developer.APIExplorerNoResults")); row:SetScript("OnClick", nil)
        else
            local node, depth = entry.node, entry.depth
            local marker = node.children and #node.children > 0 and (node.expanded and "v " or "> ") or "  "
            row.Text:SetText(string.rep("  ", depth) .. marker .. node.key .. " | " .. node.valueType .. " | " .. node.value .. (node.methods and #node.methods > 0 and (" | Methods: " .. table.concat(node.methods, ", ")) or ""))
            local matched = false
            for _, match in ipairs(self.APIExplorerSearchMatches or {}) do if match == node then matched = true break end end
            if matched then row.Text:SetTextColor(1, 0.82, 0) else row.Text:SetTextColor(0.9, 0.9, 0.9) end
            row:SetScript("OnClick", function()
                if node.children and #node.children > 0 then
                    local scrollPosition = self.ScrollFrame:GetVerticalScroll()
                    node.expanded = not node.expanded
                    self:RefreshAPIExplorer(true)
                    self.ScrollFrame:SetVerticalScroll(scrollPosition)
                end
            end)
        end
        row:Show(); yOffset = yOffset - 20
    end
    for index = #entries + 1, #self.APIExplorerNodeRows do self.APIExplorerNodeRows[index]:Hide() end
    return yOffset
end

-------------------------------------------------------------------------------
-- Guided Verification Checklist
--
-- 26 scripted in-game scenarios (VerificationService:GetChecklist()), each
-- naming exactly which registry ids it exercises -- several deliberately
-- name none, rendered with an honest "nothing to check" line rather than
-- padding every scenario with a fabricated API. Marking a scenario done
-- only records that a human performed it and when (RecordChecklistScenario)
-- -- it never changes any registry id's own verification status; that
-- still requires the Live API tab's own Mark Verified/Failed buttons,
-- kept as two deliberately separate actions (one records "I did the
-- thing," the other records "I confirmed the result was correct").
-------------------------------------------------------------------------------

local CHECKLIST_ROW_HEIGHT = 40

function DeveloperPanel:BuildChecklistTab()

    self.ChecklistRows = self.ChecklistRows or {}
    self:GetPageToolbarButton("Checklist", "Clear", AC.L:Get("Developer.ClearVerification"), 130, function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_VERIFICATION")
    end)

    local scenarios = AC.VerificationService:GetChecklist()
    local glyph = AC.VerificationService.StatusGlyph
    local lines = {}
    local data = {}

    local introLines = { AC.L:Get("Developer.ChecklistIntro") }
    local introYOffset = self:LayoutLines("ChecklistIntro", introLines, TOOLBAR_CONTENT_TOP, CONTENT_WIDTH)

    local rowY = introYOffset - 10

    for index, scenario in ipairs(scenarios) do

        local row = self.ChecklistRows[index]

        if not row then

            row = {}

            row.Label = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.Label:SetJustifyH("LEFT")
            row.Label:SetWidth(CONTENT_WIDTH - 120)

            row.Detail = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.Detail:SetJustifyH("LEFT")
            row.Detail:SetWidth(CONTENT_WIDTH - 120)

            row.Button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
            row.Button:SetSize(110, 20)

            self.ChecklistRows[index] = row

        end

        row.Label:ClearAllPoints()
        row.Label:SetPoint("TOPLEFT", 0, rowY)

        row.Detail:ClearAllPoints()
        row.Detail:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -2)

        row.Button:ClearAllPoints()
        row.Button:SetPoint("TOPRIGHT", -4, rowY + 2)

        local record = AC.VerificationService:GetChecklistRecord(scenario.id)
        local done = record and record.completed

        row.Label:SetText(AC.L:Get(scenario.labelKey))

        -- Presentation System v2 -- "done" was its own hardcoded
        -- (0.4,1,0.4), a brighter green than the addon's canonical
        -- "success" token; migrated, a real visible shift. "not done"
        -- (1,0.82,0) already matches HIGHLIGHT_COLOR exactly -- untouched.
        if done then
            local r, g, b = unpack(AC.Presentation.GetSemanticColor("success"))
            row.Label:SetTextColor(r, g, b)
        else
            AC.DashboardFormat.SetHighlightColor(row.Label)
        end

        local relatedText

        if #scenario.relatedIds == 0 then
            relatedText = AC.L:Get("Developer.ChecklistNoAPI")
        else

            local glyphs = {}

            for _, id in ipairs(scenario.relatedIds) do
                local status = AC.VerificationService:GetEffectiveStatus(id)
                table.insert(glyphs, glyph[status])
            end

            relatedText = string.format("%s: %d (%s)   %s: %s",
                AC.L:Get("Developer.ChecklistRelatedAPIs"), #scenario.relatedIds, table.concat(glyphs, " "),
                AC.L:Get("Developer.ChecklistLastDone"), record and FormatVerificationTimestamp(record.timestamp) or AC.L:Get("Developer.ChecklistNeverDone"))

        end

        row.Detail:SetText(relatedText)

        row.Button:SetText(done and AC.L:Get("Developer.ChecklistMarkUndone") or AC.L:Get("Developer.ChecklistMarkDone"))

        row.Button:SetScript("OnClick", function()
            AC.VerificationService:RecordChecklistScenario(scenario.id, not done)
            DeveloperPanel:NavigateTab("Checklist")
        end)

        row.Label:Show()
        row.Detail:Show()
        row.Button:Show()

        table.insert(lines, string.format("%s %s -- %s", done and glyph.live or glyph.needsLive, AC.L:Get(scenario.labelKey), relatedText))
        table.insert(data, { scenario = scenario.id, completed = done and true or false, relatedIds = scenario.relatedIds })

        rowY = rowY - CHECKLIST_ROW_HEIGHT

    end

    for index = #scenarios + 1, #self.ChecklistRows do

        local row = self.ChecklistRows[index]

        row.Label:Hide()
        row.Detail:Hide()
        row.Button:Hide()

    end

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

    return (-rowY) + 16

end

-------------------------------------------------------------------------------
-- History Inspector
--
-- Displays real, already-stored ActivityHistoryService records --
-- filterable by Module, Type, and a Date preset, and by Character (every
-- record's own real `Character` field, though only the current
-- character's history is ever loaded in a single session -- see
-- ActivityHistoryService's own header for why cross-character history is
-- never combined). MODULE/TYPE options are a fixed, documented list
-- matching the only two real writers today (MythicPlusModule's "Dungeon"
-- records, AccomplishmentsModule's "Achievement" records) -- the same
-- "named, fixed list, not guessed" discipline this addon uses everywhere
-- else; a future module that starts writing history needs one line added
-- here, not a redesign. The literal filter value stays "Achievements"
-- (Accomplishments redesign) -- that's ActivityHistoryService's STORED
-- Module tag, deliberately not renamed to avoid orphaning existing
-- players' saved history; see AccomplishmentsModule.lua's own header.
-------------------------------------------------------------------------------

local HISTORY_MODULES = { "All", "MythicPlus", "Delves", "Achievements" }
local HISTORY_TYPES = { "All", "Dungeon", "Delve", "Achievement" }
local HISTORY_DATE_RANGES = { "All", "Today", "Last7", "Last30" }

local HISTORY_DATE_RANGE_LABEL_KEY =
{
    All = "Developer.DateRangeAll",
    Today = "Developer.DateRangeToday",
    Last7 = "Developer.DateRangeLast7",
    Last30 = "Developer.DateRangeLast30",
}

local function NextOption(list, current)

    for index, option in ipairs(list) do

        if option == current then
            return list[(index % #list) + 1]
        end

    end

    return list[1]

end

local function GetHistoryDateBounds(rangeKey)

    local now = time()

    if rangeKey == "Today" then
        return now - 86400, now
    elseif rangeKey == "Last7" then
        return now - (7 * 86400), now
    elseif rangeKey == "Last30" then
        return now - (30 * 86400), now
    end

    return 0, now

end

function DeveloperPanel:BuildHistoryFilterControls()

    if self.HistoryFilterButtons then
        return
    end

    self.HistoryFilter = { module = "All", activityType = "All", dateRange = "All" }
    self.HistoryFilterButtons = {}
    local toolbar = self:GetPageToolbar("History")

    local function MakeCycleButton(labelPrefixKey, options, filterKey, anchorTo)

        local button = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        button:SetSize(150, 22)

        if anchorTo then
            button:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", 0, 0)
        end

        local function UpdateText()
            local value = self.HistoryFilter[filterKey]
            local displayValue = (filterKey == "dateRange") and AC.L:Get(HISTORY_DATE_RANGE_LABEL_KEY[value]) or value
            button:SetText(AC.L:Get(labelPrefixKey) .. ": " .. displayValue)
        end

        button:SetScript("OnClick", function()
            self.HistoryFilter[filterKey] = NextOption(options, self.HistoryFilter[filterKey])
            UpdateText()
            DeveloperPanel:NavigateTab("History")
        end)

        UpdateText()
        table.insert(self.HistoryFilterButtons, button)

        return button

    end

    local moduleButton = MakeCycleButton("Developer.FilterModule", HISTORY_MODULES, "module", nil)
    local typeButton = MakeCycleButton("Developer.FilterType", HISTORY_TYPES, "activityType", moduleButton)
    MakeCycleButton("Developer.FilterDateRange", HISTORY_DATE_RANGES, "dateRange", typeButton)

    local clearButton = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    clearButton:SetSize(110, 22)
    clearButton:SetPoint("TOPRIGHT", 0, 0)
    clearButton:SetText(AC.L:Get("Developer.ClearHistory"))

    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_ACTIVITY_HISTORY")
    end)

    table.insert(self.HistoryFilterButtons, clearButton)

end

function DeveloperPanel:BuildHistoryTab()

    self:BuildHistoryFilterControls()

    for _, button in ipairs(self.HistoryFilterButtons) do
        button:Show()
    end

    local filter = self.HistoryFilter
    local startTime, endTime = GetHistoryDateBounds(filter.dateRange)

    local records = {}

    if AC.ActivityHistoryService then
        records = AC.ActivityHistoryService:GetByDateRange(startTime, endTime)
    end

    local matched = {}

    for _, record in ipairs(records) do

        local matchesModule = filter.module == "All" or record.Module == filter.module
        local matchesType = filter.activityType == "All" or record.ActivityType == filter.activityType

        if matchesModule and matchesType then
            table.insert(matched, record)
        end

    end

    table.sort(matched, function(a, b) return (a.Timestamp or 0) > (b.Timestamp or 0) end)

    local lines = {}
    local data = {}

    if #matched > 0 then

        for _, record in ipairs(matched) do

            table.insert(lines, string.format("[%s] %s / %s : %s (%s)  Character: %s",
                date("%Y-%m-%d %H:%M", record.Timestamp or 0),
                DisplayName(record.Module or ""),
                tostring(record.ActivityType or ""),
                record.ActivityName or "",
                record.Success and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No"),
                record.Character or AC.L:Get("Common.Unknown")))

            table.insert(data,
            {
                id = record.ID,
                timestamp = record.Timestamp,
                module = record.Module,
                activityType = record.ActivityType,
                activityName = record.ActivityName,
                success = record.Success,
                character = record.Character,
                data = record.Data,
            })

        end

    end

    local yOffset = self:LayoutLinesOrEmpty("History", lines, TOOLBAR_CONTENT_TOP, CONTENT_WIDTH, "Developer.NoHistoryRecords")

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = #lines > 0 and lines or { AC.L:Get("Developer.NoHistoryRecords") }

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Maintenance Tab
--
-- A presentation-only command surface over existing owner APIs. Each action
-- receives prepared text and a confirmed callback; this layout helper knows
-- nothing about the data it clears.
-------------------------------------------------------------------------------

function DeveloperPanel:GetMaintenanceContainer()

    if self.MaintenanceContainer then
        return self.MaintenanceContainer
    end

    local container = CreateFrame("Frame", nil, self.ScrollChild)
    container:SetPoint("TOPLEFT", 0, 0)
    container:SetWidth(CONTENT_WIDTH)
    container:SetHeight(1)

    self.MaintenanceContainer = container
    self.MaintenanceActions = {}

    return container

end

function DeveloperPanel:LayoutMaintenanceAction(key, parent, yOffset, titleText, descriptionText, buttonText, onClick, isDanger)

    local row = self.MaintenanceActions[key]

    if not row then

        row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        AC.Presentation.ApplyCardBackdrop(row)

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetJustifyH("LEFT")

        local description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        description:SetJustifyH("LEFT")
        description:SetWordWrap(true)
        description:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(150, 22)
        button:SetPoint("RIGHT", -12, 0)

        row.Title = title
        row.Description = description
        row.Button = button

        self.MaintenanceActions[key] = row

    end

    row:SetSize(CONTENT_WIDTH, MAINTENANCE_ACTION_HEIGHT)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)

    row.Title:SetText(titleText)
    row.Description:SetText(descriptionText)

    if buttonText and onClick then

        row.Title:SetWidth(CONTENT_WIDTH - 190)
        row.Description:SetWidth(CONTENT_WIDTH - 190)
        row.Button:SetText(buttonText)
        row.Button:SetScript("OnClick", onClick)
        row.Button:Show()

        if isDanger then
            row.Button:GetFontString():SetTextColor(unpack(AC.Presentation.GetSemanticColor("critical")))
        else
            row.Button:GetFontString():SetTextColor(1, 1, 1)
        end

    else

        row.Title:SetWidth(CONTENT_WIDTH - 24)
        row.Description:SetWidth(CONTENT_WIDTH - 24)
        row.Button:Hide()

    end

    if isDanger then
        local r, g, b = unpack(AC.Presentation.GetSemanticColor("critical"))
        row:SetBackdropBorderColor(r, g, b, 0.65)
    else
        row:SetBackdropBorderColor(unpack(AC.Presentation.CARD_BACKDROP.borderColor))
    end

    row:Show()

    return yOffset - MAINTENANCE_ACTION_HEIGHT - MAINTENANCE_ACTION_GAP

end

function DeveloperPanel:BuildMaintenanceTab()

    local container = self:GetMaintenanceContainer()
    local yOffset = PAGE_CONTENT_TOP

    container:Show()

    yOffset = AC.Dashboard:BeginSection(container, "Developer.MaintenanceDangerZone", yOffset)
    yOffset = self:LayoutMaintenanceAction(
        "ResetEverything",
        container,
        yOffset,
        AC.L:Get("Developer.ResetEverything"),
        AC.L:Get("Developer.MaintenanceResetDescription"),
        AC.L:Get("Developer.ResetEverything"),
        function()
            StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_RESET_ALL")
        end,
        true
    )
    yOffset = AC.Dashboard:EndSection(yOffset)

    container:SetHeight((-yOffset) + 16)

    self.CurrentTabData =
    {
        resetAllDeveloperDataAvailable = true,
    }

    self.CurrentTabSummaryLines =
    {
        AC.L:Get("Developer.MaintenanceResetDescription"),
    }

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Show Tab
-------------------------------------------------------------------------------

function DeveloperPanel:ShowTab(tabName)

    self.CurrentTab = tabName
    local activeGroup = TAB_GROUP[tabName] or NAVIGATION_GROUPS[1].key
    self.LastTabByGroup[activeGroup] = tabName

    for groupName, button in pairs(self.NavGroupButtons) do
        if groupName == activeGroup then
            AC.DashboardFormat.SetHighlightColor(button:GetFontString())
        else
            button:GetFontString():SetTextColor(1, 1, 1)
        end
    end

    for name, button in pairs(self.TabButtons) do
        button:SetShown(TAB_GROUP[name] == activeGroup)

        if name == tabName then
            AC.DashboardFormat.SetHighlightColor(button:GetFontString())
        else
            button:GetFontString():SetTextColor(1, 1, 1)
        end

    end

    self:HideOtherTabs(tabName)

    local contentHeight

    if tabName == "Overview" then
        contentHeight = self:BuildOverviewTab()
    elseif tabName == "Modules" then
        contentHeight = self:BuildModulesTab()
    elseif tabName == "CombatSession" then
        contentHeight = self:BuildCombatSessionTab()
    elseif tabName == "Events" then
        contentHeight = self:BuildEventsTab()
    elseif tabName == "Errors" then
        contentHeight = self:BuildErrorsTab()
    elseif tabName == "SecretValues" then
        contentHeight = self:BuildSecretValuesTab()
    elseif tabName == "LiveAPI" then
        contentHeight = self:BuildLiveAPITab()
    elseif tabName == "APIExplorer" then
        contentHeight = self:BuildAPIExplorerTab()
    elseif tabName == "Checklist" then
        contentHeight = self:BuildChecklistTab()
    elseif tabName == "History" then
        contentHeight = self:BuildHistoryTab()
    elseif tabName == "Maintenance" then
        contentHeight = self:BuildMaintenanceTab()
    end

    self.ScrollChild:SetHeight(math.max(contentHeight or 1, 1))
    self.ScrollFrame:SetVerticalScroll(0)

end

function DeveloperPanel:NavigateTab(tabName)

    self:ShowTab(tabName)
    AC.NavigationService:Replace(AC.NavigationService.Windows.DeveloperPanel, tabName)

end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
--
-- Refuses to do anything at all when Developer Mode is off -- this is the
-- literal enforcement of "no gameplay/UI impact while disabled": even a
-- direct call to Show() (e.g. a stale keybind) is a no-op.
-------------------------------------------------------------------------------

function DeveloperPanel:Show()

    if not AC.DeveloperModeService or not AC.DeveloperModeService:IsEnabled() then

        if AC.Logger then
            AC.Logger:Warn("Developer Mode is off. Enable it with /ac dev on.")
        end

        return

    end

    AC.NavigationService:Push(AC.NavigationService.Windows.DeveloperPanel, self.CurrentTab or AC.NavigationService.Views.DeveloperPanel.Overview)

end

function DeveloperPanel:RestoreNavigation(entry)

    self.Frame:Show()
    self:ShowTab(entry.View)

    if entry.Context and entry.Context.scrollPosition then
        self.ScrollFrame:SetVerticalScroll(entry.Context.scrollPosition)
    end

end

function DeveloperPanel:CaptureNavigation(entry)

    entry.Context = entry.Context or {}
    entry.Context.scrollPosition = self.ScrollFrame and self.ScrollFrame:GetVerticalScroll() or 0

end

function DeveloperPanel:Hide()

    if not AC.NavigationService:GoBackIfCurrent(self) then
        self.Frame:Hide()
    end

end

function DeveloperPanel:Toggle()

    if self.Frame and self.Frame:IsShown() and AC.NavigationService:IsCurrent(self) then
        AC.NavigationService:GoBack()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("DeveloperPanel", DeveloperPanel)

return DeveloperPanel
