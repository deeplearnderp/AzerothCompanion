-------------------------------------------------------------------------------
-- Azeroth Companion
-- Developer Panel
--
-- The permanent developer-tooling surface for Azeroth Companion: eight tabs
-- (Overview, Modules, Events, Errors, Secret Values, Live API, Checklist,
-- History) inside one standalone window (BaseWindow, same tier as
-- DiagnosticsWindow/SettingsWindow), only ever shown from /ac dev once
-- Developer Mode is enabled. This comment previously said "seven tabs" and
-- didn't mention Secret Values at all -- proof, not just a guess, that
-- WINDOW_WIDTH below was never revisited when that tab was added, which is
-- exactly the bug that caused the tab bar to overflow the window (see
-- TAB_BAR_REQUIRED_WIDTH's own comment).
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
-- Tabs
--
-- Declared before Layout Constants (below) rather than after, because
-- WINDOW_WIDTH is now derived from #TABS -- see TAB_BAR_REQUIRED_WIDTH's
-- own comment for why a hand-picked literal is exactly what caused the
-- tab bar to overflow the window twice.
-------------------------------------------------------------------------------

local TABS = { "Overview", "Modules", "Events", "Errors", "SecretValues", "LiveAPI", "Checklist", "History" }

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local CONTENT_PADDING = 16
local SCROLLBAR_RESERVE = 24

-- Tab bar geometry -- named here so the width formula below and the tab
-- button loop in Initialize() both read from the same numbers, instead of
-- Initialize() hardcoding 100/4 inline and WINDOW_WIDTH being a separately
-- hand-computed literal with no structural link to them.
local TAB_BUTTON_WIDTH = 100
local TAB_BUTTON_GAP = 4

-- 40px -- deliberately more generous than the ~20px margin the previous
-- (also hand-computed) 864px width assumed, since that value was verified
-- live to still be insufficient and the exact missing pixel amount isn't
-- something this static analysis can pin down without the live client.
local TAB_BAR_RIGHT_MARGIN = 40

-- Derived, not hand-picked: whatever WINDOW_WIDTH used to be (760, then
-- 864), both were independent literals with no relationship to the tab
-- bar's actual required width, which is exactly why the window went stale
-- not once but twice as tabs were added (Secret Values, then this pass's
-- own investigation) without anyone re-deriving it by hand. This formula
-- uses the exact same CONTENT_PADDING/TAB_BUTTON_WIDTH/TAB_BUTTON_GAP the
-- tab loop in Initialize() lays out with, so the window is guaranteed at
-- least wide enough for however many tabs TABS actually holds -- adding or
-- removing a tab changes #TABS and this recomputes automatically, no
-- second constant to remember to update.
local TAB_BAR_REQUIRED_WIDTH = CONTENT_PADDING + (#TABS * TAB_BUTTON_WIDTH) + ((#TABS - 1) * TAB_BUTTON_GAP) + TAB_BAR_RIGHT_MARGIN

local WINDOW_WIDTH = TAB_BAR_REQUIRED_WIDTH
local WINDOW_HEIGHT = 620
local CONTENT_WIDTH = WINDOW_WIDTH - (CONTENT_PADDING * 2) - SCROLLBAR_RESERVE
local TAB_BAR_HEIGHT = 26
local FOOTER_HEIGHT = 68
local ROW_HEIGHT = 16

-- Header layout -- this is the one window in the addon with its own
-- persistent toolbar row (QoL buttons) in addition to BaseWindow's shared
-- title, so it's the one place that needs to reserve room below the title
-- rather than just starting content at a fixed offset. TITLE_TOP_OFFSET
-- matches BaseWindow:Create's own title anchor (-12) -- not a new,
-- independently-guessed number -- and the title's actual rendered height
-- is measured at Initialize() time rather than assumed, so this stays
-- correct if the title text or font ever changes. TOOLBAR_ROW_HEIGHT
-- matches the QoL/tab buttons' own real height (20-22px); TOOLBAR_GAP is
-- the one small breathing-room constant this file adds.
local TITLE_TOP_OFFSET = 12
local TOOLBAR_ROW_HEIGHT = 22
local TOOLBAR_GAP = 8

local TAB_LABEL_KEY =
{
    Overview = "Developer.TabOverview",
    Modules = "Developer.TabModules",
    Events = "Developer.TabEvents",
    Errors = "Developer.TabErrors",
    SecretValues = "Developer.TabSecretValues",
    LiveAPI = "Developer.TabLiveAPI",
    Checklist = "Developer.TabChecklist",
    History = "Developer.TabHistory",
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
-- A minimal pooled label-list, shared by every simple-text tab -- each tab
-- owns one pool (self.Pools[tabName]) of plain FontStrings, laid out
-- top-to-bottom. Deliberately simpler than Dashboard's own Rows.lua
-- primitives (no stars/hero/grid shapes needed here, just dense text) --
-- reusing those would mean fighting their player-facing spacing/typography
-- for a developer tool that wants density instead.
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

-- A pool's storage key doesn't always equal its owning tab's name -- the
-- Modules tab needs two independent pools (title lines, stats lines)
-- sharing one yOffset loop, so they're stored under their own keys. This
-- is the one place that split is reconciled back to "which tab owns this
-- pool" for hide/show purposes.
local POOL_TAB_OWNER =
{
    ModulesTitle = "Modules",
    ModulesStats = "Modules",
    ChecklistIntro = "Checklist",
}

-- Hides every pooled row belonging to a tab other than the one now active
-- -- switching tabs never destroys widgets, only hides them (reused if
-- that tab is revisited).
function DeveloperPanel:HideOtherTabs(activeTab)

    self.Pools = self.Pools or {}

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

    if self.ChecklistRows and activeTab ~= "Checklist" then
        for _, row in ipairs(self.ChecklistRows) do
            row.Label:Hide()
            row.Detail:Hide()
            row.Button:Hide()
        end
    end

    if self.EventsClearButton and activeTab ~= "Events" then
        self.EventsClearButton:Hide()
    end

    -- Errors tab's toolbar (status line + Clear Errors button) lives
    -- outside self.Pools, same reasoning as EventsClearButton above -- the
    -- accordion rows themselves are IN self.Pools (poolKey "Errors") and
    -- already covered by the generic loop at the top of this function.
    if self.ErrorsStatusText and activeTab ~= "Errors" then
        self.ErrorsStatusText:Hide()
    end

    if self.ErrorsClearButton and activeTab ~= "Errors" then
        self.ErrorsClearButton:Hide()
    end

    if self.ErrorsTestButton and activeTab ~= "Errors" then
        self.ErrorsTestButton:Hide()
    end

    if self.ErrorsExportButton and activeTab ~= "Errors" then
        self.ErrorsExportButton:Hide()
    end

    -- Secret Values tab's toolbar (status line + Clear Events button) --
    -- same reasoning as the Errors tab's own toolbar above; its accordion
    -- rows live in self.Pools (poolKey "SecretValues") and are already
    -- covered by the generic loop at the top of this function.
    if self.SecretValuesStatusText and activeTab ~= "SecretValues" then
        self.SecretValuesStatusText:Hide()
    end

    if self.SecretValuesClearButton and activeTab ~= "SecretValues" then
        self.SecretValuesClearButton:Hide()
    end

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function DeveloperPanel:Initialize()

    self.Frame = BaseWindow:Create("AzerothCompanionDeveloperPanel", AC.L:Get("Developer.Title"), WINDOW_WIDTH, WINDOW_HEIGHT)

    BaseWindow:AddCloseButton(self.Frame, self)

    -----------------------------------------------------------------------
    -- Header Layout
    --
    -- Measures the title's own real rendered height (already SetText'd by
    -- BaseWindow:Create above) rather than assuming a fixed number, so the
    -- QoL toolbar row and tab bar are placed with a guaranteed, correct
    -- gap below it regardless of title text/font -- fixing the title
    -- being visually overlapped by the QoL row's buttons.
    -----------------------------------------------------------------------

    local titleBottom = -(TITLE_TOP_OFFSET + (self.Frame.Title:GetStringHeight() or 20))
    local qolTop = titleBottom - TOOLBAR_GAP
    local tabTop = qolTop - TOOLBAR_ROW_HEIGHT - TOOLBAR_GAP

    -----------------------------------------------------------------------
    -- Tab Bar
    -----------------------------------------------------------------------

    self.TabButtons = {}

    local previousTab

    for _, tabName in ipairs(TABS) do

        local button = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
        button:SetSize(TAB_BUTTON_WIDTH, 22)

        if previousTab then
            button:SetPoint("LEFT", previousTab, "RIGHT", TAB_BUTTON_GAP, 0)
        else
            button:SetPoint("TOPLEFT", CONTENT_PADDING, tabTop)
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
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PADDING, tabTop - TAB_BAR_HEIGHT)
    scrollFrame:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, FOOTER_HEIGHT)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    self.ScrollFrame = scrollFrame
    self.ScrollChild = scrollChild

    -----------------------------------------------------------------------
    -- Footer -- Copy JSON / Copy Text / Copy Summary + the shared hidden
    -- EditBox every one of them populates (DiagnosticsWindow's own
    -- "SetFocus + HighlightText, player presses Ctrl+C" idiom -- WoW has
    -- no clipboard-write API, so this is the standard, already-validated
    -- pattern rather than a new one).
    -----------------------------------------------------------------------

    self:BuildFooter()

    self.CurrentTab = "Overview"

    self:BuildQoLRow(qolTop)

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

-------------------------------------------------------------------------------
-- Footer / Copy Support
-------------------------------------------------------------------------------

function DeveloperPanel:BuildFooter()

    local footer = CreateFrame("Frame", nil, self.Frame)
    footer:SetPoint("BOTTOMLEFT", CONTENT_PADDING, CONTENT_PADDING)
    footer:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)
    footer:SetHeight(FOOTER_HEIGHT)

    local copyJSON = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    copyJSON:SetSize(90, 20)
    copyJSON:SetPoint("BOTTOMLEFT", 0, 24)
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

-------------------------------------------------------------------------------
-- Quality of Life Row -- Clear Notifications / Clear History / Force
-- Refresh / Toggle Tracing, always visible regardless of active tab.
-------------------------------------------------------------------------------

function DeveloperPanel:BuildQoLRow(topY)

    -- A row of always-visible action buttons, right-aligned above the tab
    -- bar so it never competes for space with the tabs themselves. topY is
    -- computed once in Initialize() from the title's own real measured
    -- height, not a hardcoded offset here -- see Initialize()'s Header
    -- Layout section for why.

    local clearNotifications = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
    clearNotifications:SetSize(140, 20)
    clearNotifications:SetPoint("TOPRIGHT", -CONTENT_PADDING, topY)
    clearNotifications:SetText(AC.L:Get("Developer.ClearNotifications"))

    clearNotifications:SetScript("OnClick", function()

        if AC.NotificationService then

            AC.NotificationService.Queue = {}
            AC.NotificationService.History = {}

            if AC.NotificationService.Active then
                AC.NotificationService:Dismiss()
            end

            AC.Logger:Info("Developer Panel: notifications cleared.")

        end

        if self.CurrentTab == "Overview" then
            self:ShowTab("Overview")
        end

    end)

    local forceRefresh = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
    forceRefresh:SetSize(100, 20)
    forceRefresh:SetPoint("RIGHT", clearNotifications, "LEFT", -6, 0)
    forceRefresh:SetText(AC.L:Get("Developer.ForceRefresh"))

    forceRefresh:SetScript("OnClick", function()

        if AC.Dashboard then
            AC.Dashboard:RefreshEngines(nil)
        end

        AC.Logger:Info("Developer Panel: forced a full refresh.")
        self:ShowTab(self.CurrentTab)

    end)

    local traceToggle = CreateFrame("Button", nil, self.Frame, "UIPanelButtonTemplate")
    traceToggle:SetSize(110, 20)
    traceToggle:SetPoint("RIGHT", forceRefresh, "LEFT", -6, 0)

    local function UpdateTraceButtonText()
        traceToggle:SetText(AC.Logger:GetActiveTraceDescription() == "off" and AC.L:Get("Developer.TracingOff") or AC.L:Get("Developer.TracingOn"))
    end

    traceToggle:SetScript("OnClick", function()

        if AC.Logger:GetActiveTraceDescription() == "off" then
            AC.Logger:SetDebugEnabled(true)
            AC.Logger:EnableAllTrace()
        else
            AC.Logger:DisableAllTrace()
        end

        UpdateTraceButtonText()

    end)

    UpdateTraceButtonText()

    self.QoLButtons = { clearNotifications, forceRefresh, traceToggle }

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

    local function AddLine(labelKey, value)

        local text = AC.L:Get(labelKey) .. ": " .. tostring(value)

        table.insert(lines, text)
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
        AddLine("Developer.PlayerJournalFavoritePlayers", journalStats.favoritePlayers)
        AddLine("Developer.PlayerJournalTotalNotes", journalStats.totalNotes)
        AddLine("Developer.PlayerJournalCommunityNotes", journalStats.communityNotes)
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

    local serviceCount = AC.ServiceManager and #AC.ServiceManager:GetAll() or 0
    local moduleCount = AC.ModuleManager and #AC.ModuleManager:GetAll() or 0
    AddLine("Developer.FieldLoadedModules", string.format("%d services, %d modules", serviceCount, moduleCount))

    local lastRefresh = AC.RecommendationEngine and AC.RecommendationEngine:GetLastRefresh()
    AddLine("Developer.FieldLastRefresh", (lastRefresh and lastRefresh > 0) and date("%H:%M:%S", lastRefresh) or AC.L:Get("Common.Unknown"))

    local lastEvent = AC.DeveloperModeService and AC.DeveloperModeService:GetLastEvent()
    AddLine("Developer.FieldLastEvent", lastEvent and (lastEvent.event .. " @ " .. lastEvent.timestamp) or AC.L:Get("Common.Unknown"))

    local framerate = GetFramerate and GetFramerate() or nil
    AddLine("Developer.FieldFrameRate", framerate and string.format("%.0f fps", framerate) or AC.L:Get("Common.Unknown"))

    local yOffset = self:LayoutLines("Overview", lines, -4, CONTENT_WIDTH)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Modules Tab
--
-- Two lines per registered Service/Module: identity + a Refresh button,
-- then its own stats. "Initialized"/"Enabled" reflect real, observable
-- state -- Initialized is true for anything appearing in these registries
-- at all (ModuleManager/ServiceManager only ever list what actually
-- completed Initialize()); Enabled prefers a module's own
-- IsModuleEnabled() (the real per-feature Settings toggle) where one
-- exists, falling back to "Yes" for framework services that have no such
-- concept. Insight/Recommendation/History counts reuse
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

    local rowWidth = CONTENT_WIDTH - 80
    local yOffset = -4

    for index, entry in ipairs(entries) do

        local name = entry.name
        local object = entry.object

        local enabled = AC.L:Get("Developer.Yes")

        if object.IsModuleEnabled then

            local ok, result = pcall(object.IsModuleEnabled, object)
            enabled = (ok and result ~= false) and AC.L:Get("Developer.Yes") or AC.L:Get("Developer.No")

        end

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

        local titleText = string.format("%s   |   %s: %s   %s: %s", DisplayName(name), AC.L:Get("Developer.LabelInitialized"), AC.L:Get("Developer.Yes"), AC.L:Get("Developer.LabelEnabled"), enabled)
        local statsText = string.format("  %s: %s   %s: %s   %s: %d   %s: %d   %s: %d   %s: %s",
            AC.L:Get("Developer.LabelLastRefresh"), lastRefreshText,
            AC.L:Get("Developer.LabelDuration"), durationText,
            AC.L:Get("Developer.LabelInsightCount"), insightCount,
            AC.L:Get("Developer.LabelRecommendationCount"), recommendationCount,
            AC.L:Get("Developer.LabelHistoryCount"), historyCount,
            AC.L:Get("Developer.LabelLastError"), errorText)

        table.insert(summaryLines, titleText)
        table.insert(summaryLines, statsText)

        data[name] =
        {
            Initialized = true,
            Enabled = enabled,
            LastRefresh = lastRefreshText,
            Duration = durationText,
            LastError = errorText,
            InsightCount = insightCount,
            RecommendationCount = recommendationCount,
            HistoryCount = historyCount,
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

                DeveloperPanel:ShowTab("Modules")

            end)

            self.ModuleRefreshButtons[index] = button

        end

        button:SetText(AC.L:Get("Developer.Refresh"))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.ScrollChild, "TOPLEFT", rowWidth + 10, yOffset)
        button.ModuleName = name
        button:Show()

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
-- Events Tab
--
-- A live feed of AC.DeveloperModeService's own bounded event log, newest
-- first. The log itself is only ever populated while Developer Mode is
-- on (see that service's InstallEventMonitor) -- this tab purely renders
-- whatever is already there.
-------------------------------------------------------------------------------

function DeveloperPanel:BuildEventsTab()

    if not self.EventsClearButton then

        local clearButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        clearButton:SetSize(80, 20)
        clearButton:SetPoint("TOPRIGHT", 0, -4)
        clearButton:SetText(AC.L:Get("Developer.Clear"))

        clearButton:SetScript("OnClick", function()
            AC.DeveloperModeService:ClearEventLog()
            DeveloperPanel:ShowTab("Events")
        end)

        self.EventsClearButton = clearButton

    end

    self.EventsClearButton:Show()

    local log = AC.DeveloperModeService and AC.DeveloperModeService:GetEventLog() or {}
    local lines = {}
    local data = {}

    if #log == 0 then

        table.insert(lines, AC.L:Get("Developer.NoEvents"))

    else

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

    local yOffset = self:LayoutLines("Events", lines, -28, CONTENT_WIDTH)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

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

    local statusText = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetJustifyH("LEFT")
    statusText:SetPoint("TOPLEFT", 0, -4)
    self.ErrorsStatusText = statusText

    local clearButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
    clearButton:SetSize(110, 20)
    clearButton:SetPoint("TOPRIGHT", 0, -4)
    clearButton:SetText(AC.L:Get("Developer.ClearErrors"))

    clearButton:SetScript("OnClick", function()

        local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")

        if errorCapture then
            errorCapture:ClearErrors()
        end

        DeveloperPanel:ShowTab("Errors")

    end)

    self.ErrorsClearButton = clearButton

    -- Generate Test Error -- calls the exact same entry point as
    -- /ac dev testerror (AC.SlashCommandManager:HandleDev), never a
    -- second copy of the test-error logic. Whatever that command does
    -- (currently: throw a real, unwrapped error()) is exactly what this
    -- button does too, by construction, not by keeping two paths in sync.
    local testButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
    testButton:SetSize(150, 20)
    testButton:SetPoint("RIGHT", clearButton, "LEFT", -6, 0)
    testButton:SetText(AC.L:Get("Developer.GenerateTestError"))

    testButton:SetScript("OnClick", function()
        AC.SlashCommandManager:HandleDev("testerror")
    end)

    self.ErrorsTestButton = testButton

    -- Export All Errors -- see ExportAllErrors below for what this reuses.
    local exportButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
    exportButton:SetSize(140, 20)
    exportButton:SetPoint("RIGHT", testButton, "LEFT", -6, 0)
    exportButton:SetText(AC.L:Get("Developer.ExportAllErrors"))

    exportButton:SetScript("OnClick", function()
        self:ExportAllErrors()
    end)

    self.ErrorsExportButton = exportButton

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

    local yOffset = AC.Dashboard:LayoutAccordionRows(self, "Errors", self.ScrollChild, -34, CONTENT_WIDTH, records,
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

    local statusText = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetJustifyH("LEFT")
    statusText:SetPoint("TOPLEFT", 0, -4)
    self.SecretValuesStatusText = statusText

    local clearButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
    clearButton:SetSize(110, 20)
    clearButton:SetPoint("TOPRIGHT", 0, -4)
    clearButton:SetText(AC.L:Get("Developer.ClearSecretValues"))

    clearButton:SetScript("OnClick", function()

        local secretValueEvents = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("SecretValueEvents")

        if secretValueEvents then
            secretValueEvents:ClearEvents()
        end

        DeveloperPanel:ShowTab("SecretValues")

    end)

    self.SecretValuesClearButton = clearButton

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

    local yOffset = AC.Dashboard:LayoutAccordionRows(self, "SecretValues", self.ScrollChild, -34, CONTENT_WIDTH, records,
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

                DeveloperPanel:ShowTab("LiveAPI")

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

                DeveloperPanel:ShowTab("LiveAPI")

            end)

            failedButton:SetScript("OnClick", function()

                if not self.LiveAPIResults[probe.key] then
                    return
                end

                for _, id in ipairs(probe.verifyIds) do
                    AC.VerificationService:RecordResult(id, false)
                end

                DeveloperPanel:ShowTab("LiveAPI")

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

    table.insert(lines, { text = AC.L:Get("Developer.SummaryHeader"), r = 1, g = 0.82, b = 0 })
    table.insert(lines,
    {
        text = AC.L:Format("Developer.SummaryFormat", glyph.source, counts.source, glyph.wiki, counts.wiki, glyph.live, counts.live, glyph.needsLive, counts.needsLive, glyph.incorrect, counts.incorrect),
        r = 0.85, g = 0.85, b = 0.85,
    })

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

    local yOffset = self:LayoutLines("LiveAPI", lines, -52, CONTENT_WIDTH)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

    return (-yOffset) + 16

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

    local scenarios = AC.VerificationService:GetChecklist()
    local glyph = AC.VerificationService.StatusGlyph
    local lines = {}
    local data = {}

    local introLines = { AC.L:Get("Developer.ChecklistIntro") }
    local introYOffset = self:LayoutLines("ChecklistIntro", introLines, -4, CONTENT_WIDTH)

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
            DeveloperPanel:ShowTab("Checklist")
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

local HISTORY_MODULES = { "All", "MythicPlus", "Achievements" }
local HISTORY_TYPES = { "All", "Dungeon", "Achievement" }
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

    local function MakeCycleButton(labelPrefixKey, options, filterKey, anchorTo)

        local button = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
        button:SetSize(150, 22)

        if anchorTo then
            button:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", 0, -4)
        end

        local function UpdateText()
            local value = self.HistoryFilter[filterKey]
            local displayValue = (filterKey == "dateRange") and AC.L:Get(HISTORY_DATE_RANGE_LABEL_KEY[value]) or value
            button:SetText(AC.L:Get(labelPrefixKey) .. ": " .. displayValue)
        end

        button:SetScript("OnClick", function()
            self.HistoryFilter[filterKey] = NextOption(options, self.HistoryFilter[filterKey])
            UpdateText()
            DeveloperPanel:ShowTab("History")
        end)

        UpdateText()
        table.insert(self.HistoryFilterButtons, button)

        return button

    end

    local moduleButton = MakeCycleButton("Developer.FilterModule", HISTORY_MODULES, "module", nil)
    local typeButton = MakeCycleButton("Developer.FilterType", HISTORY_TYPES, "activityType", moduleButton)
    MakeCycleButton("Developer.FilterDateRange", HISTORY_DATE_RANGES, "dateRange", typeButton)

    local clearButton = CreateFrame("Button", nil, self.ScrollChild, "UIPanelButtonTemplate")
    clearButton:SetSize(110, 22)
    clearButton:SetPoint("TOPRIGHT", 0, -4)
    clearButton:SetText(AC.L:Get("Developer.ClearHistory"))

    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("AZEROTHCOMPANION_DEVELOPER_CLEAR_HISTORY")
    end)

    table.insert(self.HistoryFilterButtons, clearButton)

end

StaticPopupDialogs["AZEROTHCOMPANION_DEVELOPER_CLEAR_HISTORY"] =
{
    text = "Clear all recorded Activity History for this character? This cannot be undone.",
    button1 = _G.YES or "Clear",
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function()

        if AC.ActivityHistoryService then
            AC.ActivityHistoryService:ClearAll()
        end

        AC.Logger:Info("Developer Panel: Activity History cleared.")

        if AC.DeveloperPanel then
            AC.DeveloperPanel:ShowTab("History")
        end

    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

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

    if #matched == 0 then

        table.insert(lines, AC.L:Get("Developer.NoHistoryRecords"))

    else

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

    local yOffset = self:LayoutLines("History", lines, -34, CONTENT_WIDTH)

    self.CurrentTabData = data
    self.CurrentTabSummaryLines = lines

    return (-yOffset) + 16

end

-------------------------------------------------------------------------------
-- Show Tab
-------------------------------------------------------------------------------

function DeveloperPanel:ShowTab(tabName)

    self.CurrentTab = tabName

    for name, button in pairs(self.TabButtons) do

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
    elseif tabName == "Events" then
        contentHeight = self:BuildEventsTab()
    elseif tabName == "Errors" then
        contentHeight = self:BuildErrorsTab()
    elseif tabName == "SecretValues" then
        contentHeight = self:BuildSecretValuesTab()
    elseif tabName == "LiveAPI" then
        contentHeight = self:BuildLiveAPITab()
    elseif tabName == "Checklist" then
        contentHeight = self:BuildChecklistTab()
    elseif tabName == "History" then
        contentHeight = self:BuildHistoryTab()
    end

    self.ScrollChild:SetHeight(math.max(contentHeight or 1, 1))
    self.ScrollFrame:SetVerticalScroll(0)

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

    self:ShowTab(self.CurrentTab or "Overview")
    self.Frame:Show()

end

function DeveloperPanel:Hide()

    self.Frame:Hide()

end

function DeveloperPanel:Toggle()

    if self.Frame and self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("DeveloperPanel", DeveloperPanel)

return DeveloperPanel
