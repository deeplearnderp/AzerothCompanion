-------------------------------------------------------------------------------
-- Azeroth Companion
-- Inventory Manager
--
-- Dedicated presentation workspace for StorageModule. The window owns only
-- lifecycle, navigation, and prepared display state. StorageModule remains the
-- sole owner of scanning, storage facts, analysis, and future workflows.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow
local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

local InventoryManager = {}
AC.InventoryManager = InventoryManager

local WINDOW_WIDTH = 900
local WINDOW_HEIGHT = 650
local WINDOW_PADDING = 10
local HEADER_HEIGHT = 35
local FOOTER_HEIGHT = 36
local NAVIGATION_WIDTH = 190
local PANEL_GAP = 10
local PAGE_CONTENT_WIDTH = 620
local NAVIGATION_BUTTON_HEIGHT = 24
local NAVIGATION_BUTTON_GAP = 6
local SEARCH_ALL = "All"
local SEARCH_UNKNOWN_QUALITY = "Unknown"
local SEARCH_CONTROL_GAP = 10
local SEARCH_LABEL_GAP = 4
local SEARCH_FILTER_ROW_GAP = 12
local SEARCH_INPUT_WIDTH = 396
local SEARCH_ACTION_WIDTH = 90
local SEARCH_RESULT_CARD_HEIGHT = 92
local SHOPPING_CARD_HEIGHT = 92
local LOADOUT_LIST_WIDTH = 220
local LOADOUT_ROW_HEIGHT = 28
local LOADOUT_CONTENT_GAP = 12

local PAGE_DEFINITIONS =
{
    { id = "Overview", label = "InventoryManager.NavOverview" },
    { id = "Categories", label = "InventoryManager.NavCategories" },
    { id = "Explorer", label = "InventoryManager.NavExplorer" },
    { id = "Search", label = "InventoryManager.NavSearch" },
    { id = "Transfers", label = "InventoryManager.NavTransfers", placeholder = "InventoryManager.TransfersPlanned" },
    { id = "ShoppingList", label = "InventoryManager.NavShoppingList" },
    { id = "Consumables", label = "InventoryManager.NavConsumables", placeholder = "InventoryManager.ConsumablesPlanned" },
    { id = "Loadouts", label = "InventoryManager.NavLoadouts" },
    { id = "Forecast", label = "InventoryManager.NavForecast", placeholder = "InventoryManager.ForecastPlanned" },
    { id = "Settings", label = "InventoryManager.NavSettings", placeholder = "InventoryManager.SettingsPlanned" },
}

local PAGE_BY_ID = {}
local STORAGE_SOURCE_LABELS =
{
    bags = "InventoryManager.SourceBags",
    character_bank = "InventoryManager.SourceCharacterBank",
    warband_bank = "InventoryManager.SourceWarbandBank",
}

local STORAGE_CATEGORY_LABELS =
{
    Equipment = "InventoryManager.CategoryEquipment",
    Consumables = "InventoryManager.CategoryConsumables",
    Reagents = "InventoryManager.CategoryReagents",
    TradeGoods = "InventoryManager.CategoryTradeGoods",
    QuestItems = "InventoryManager.CategoryQuestItems",
    Mounts = "InventoryManager.CategoryMounts",
    BattlePets = "InventoryManager.CategoryBattlePets",
    Miscellaneous = "InventoryManager.CategoryMiscellaneous",
    Unknown = "InventoryManager.CategoryUnknown",
}

local STORAGE_QUALITY_LABELS =
{
    [0] = "InventoryManager.QualityPoor",
    [1] = "InventoryManager.QualityCommon",
    [2] = "InventoryManager.QualityUncommon",
    [3] = "InventoryManager.QualityRare",
    [4] = "InventoryManager.QualityEpic",
    [5] = "InventoryManager.QualityLegendary",
    [6] = "InventoryManager.QualityArtifact",
    [7] = "InventoryManager.QualityHeirloom",
    [8] = "InventoryManager.QualityWoWToken",
}

local STORAGE_SORT_LABELS =
{
    name = "InventoryManager.SortName",
    quantity = "InventoryManager.SortQuantity",
    category = "InventoryManager.SortCategory",
    source = "InventoryManager.SortSource",
}

local SEARCH_STATE_TEXT_KEYS =
{
    never_searched = "InventoryManager.SearchNeverSearched",
    pending = "InventoryManager.SearchPending",
    searching = "InventoryManager.SearchSearching",
    empty_query = "InventoryManager.SearchEmptyQuery",
    no_results = "InventoryManager.SearchNoResults",
    no_storage_data = "InventoryManager.SearchNoStorageData",
    storage_unavailable = "InventoryManager.SearchStorageUnavailable",
}

for _, definition in ipairs(PAGE_DEFINITIONS) do
    PAGE_BY_ID[definition.id] = definition
end

-------------------------------------------------------------------------------
-- StorageModule context
-------------------------------------------------------------------------------

function InventoryManager:GetStorageContext()

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local enabled = storageModule and storageModule.IsModuleEnabled and storageModule:IsModuleEnabled()
    local profile = enabled and storageModule.GetActiveProfile and storageModule:GetActiveProfile() or nil
    local scanStatus = enabled and storageModule.GetScanStatus and storageModule:GetScanStatus() or nil
    local lastScan = enabled and storageModule.GetLastScan and storageModule:GetLastScan() or nil
    local sources = enabled and storageModule.GetStorageSources and storageModule:GetStorageSources() or {}
    local readiness = enabled and profile and storageModule.GetStorageReadiness and storageModule:GetStorageReadiness(profile.id) or nil
    local lastKnownStorage = enabled and storageModule.GetLastKnownStorage and storageModule:GetLastKnownStorage() or nil

    return
    {
        storageModule = storageModule,
        enabled = enabled == true,
        profile = profile,
        scanStatus = scanStatus or { state = "unknown", freshness = "unknown", hasSnapshot = false, available = false },
        lastScan = lastScan,
        sources = sources,
        readiness = readiness,
        lastKnownStorage = lastKnownStorage,
    }

end

-- Presentation-only split over data StorageModule already exposes: never
-- scanned at all vs. scanned before but not currently live (bank
-- closed/stale -- BankCacheReady semantics, confirmed intentional) vs.
-- genuinely live and ready. No new backend state -- context.scanStatus.
-- hasSnapshot and context.readiness.state already distinguish the live
-- cases; the Storage Knowledge Base adds one more source for the "not
-- live" case -- context.lastKnownStorage.analysis.preparation, a cached
-- GetPreparationStatus() result from the last successful scan (possibly
-- a prior login), never recomputed here. Same Ready/ReadinessFormat
-- wording either way, since both are a real readiness percentage, just
-- from different moments in time.
function InventoryManager:GetReadiness(context)

    if not context.enabled then
        return AC.L:Get("Common.Unknown")
    end

    if context.scanStatus.hasSnapshot then

        if not context.readiness or context.readiness.state ~= "known" then
            return AC.L:Get("InventoryManager.BankNotConnected")
        end

        if context.readiness.ready then
            return AC.L:Get("InventoryManager.Ready")
        end

        return AC.L:Format("InventoryManager.ReadinessFormat", context.readiness.readinessPercent or 0)

    end

    local preparation = context.lastKnownStorage and context.lastKnownStorage.analysis and context.lastKnownStorage.analysis.preparation

    if preparation then

        if preparation.ready then
            return AC.L:Get("InventoryManager.Ready")
        end

        return AC.L:Format("InventoryManager.ReadinessFormat", preparation.readinessPercent or 0)

    end

    return AC.L:Get("InventoryManager.NoSnapshotTitle")

end

function InventoryManager:GetScanStatusText(context)

    if not context.enabled then
        return AC.L:Get("InventoryManager.StorageDisabled")
    end

    if context.scanStatus.state == "failed" then
        return AC.L:Get("InventoryManager.ScanFailed")
    end

    if context.scanStatus.freshness == "current" then
        return AC.L:Get("InventoryManager.LiveDataAvailable")
    end

    if context.scanStatus.freshness == "stale" and context.lastScan then
        return AC.L:Format("InventoryManager.StaleDataAvailable", AC.Presentation.FormatDate(context.lastScan.timestamp, "shortTime"))
    end

    return AC.L:Get("InventoryManager.OpenBankPrompt")

end

-------------------------------------------------------------------------------
-- Window shell
-------------------------------------------------------------------------------

function InventoryManager:CreatePage(parent)

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()

    local scrollFrame = Dashboard:CreatePageScrollFrame(page, 12, 12)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)

    scrollChild:SetWidth(PAGE_CONTENT_WIDTH)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    page.ScrollFrame = scrollFrame
    page.ScrollChild = scrollChild
    page.ContentWidth = PAGE_CONTENT_WIDTH
    page.Pools = {}

    return page

end

function InventoryManager:Create()

    local frame = BaseWindow:Create("AzerothCompanionInventoryManager", AC.L:Get("InventoryManager.Title"), WINDOW_WIDTH, WINDOW_HEIGHT)

    AC.Presentation.ApplyWindowBackground(frame)
    AC.Presentation.StyleWindowTitle(frame.Title)
    BaseWindow:AddCloseButton(frame, self)

    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", WINDOW_PADDING, 8)
    footer:SetPoint("BOTTOMRIGHT", -WINDOW_PADDING, 8)
    footer:SetHeight(24)
    AC.Presentation.ApplyCardBackdrop(footer)

    local statusText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("LEFT", 8, 0)
    statusText:SetPoint("RIGHT", -154, 0)
    statusText:SetJustifyH("LEFT")

    local navigationPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    navigationPanel:SetPoint("TOPLEFT", WINDOW_PADDING, -HEADER_HEIGHT)
    navigationPanel:SetPoint("BOTTOMLEFT", WINDOW_PADDING, FOOTER_HEIGHT)
    navigationPanel:SetWidth(NAVIGATION_WIDTH)
    AC.Presentation.ApplyCardBackdrop(navigationPanel)

    local contentPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", navigationPanel, "TOPRIGHT", PANEL_GAP, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", -WINDOW_PADDING, FOOTER_HEIGHT)
    AC.Presentation.ApplyCardBackdrop(contentPanel)

    self.NavigationButtons = {}
    self.Pages = {}

    local previousButton

    for _, definition in ipairs(PAGE_DEFINITIONS) do

        local pageName = definition.id
        local button = CreateFrame("Button", nil, navigationPanel, "UIPanelButtonTemplate")
        button:SetSize(NAVIGATION_WIDTH - 20, NAVIGATION_BUTTON_HEIGHT)

        if previousButton then
            button:SetPoint("TOP", previousButton, "BOTTOM", 0, -NAVIGATION_BUTTON_GAP)
        else
            button:SetPoint("TOP", 0, -12)
        end

        button:SetText(AC.L:Get(definition.label))
        button:SetScript("OnClick", function()
            self:ShowPage(pageName)
        end)

        self.NavigationButtons[pageName] = button
        self.Pages[pageName] = self:CreatePage(contentPanel)
        previousButton = button

    end

    self.Footer = footer
    self.StatusText = statusText
    self.NavigationPanel = navigationPanel
    self.ContentPanel = contentPanel

    return frame

end

function InventoryManager:EnsureScanButton()

    if self.ScanButton then
        return
    end

    self.ScanButton = AC.WidgetManager:Create("Button", self.Footer,
    {
        width = 136,
        text = AC.L:Get("InventoryManager.ScanInventory"),
        onClick = function()
            self:RequestInventoryScan()
        end,
    })

    local frame = self.ScanButton:GetFrame()
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", -2, 0)

end

-------------------------------------------------------------------------------
-- Shared page composition
-------------------------------------------------------------------------------

function InventoryManager:LayoutPage(page, layoutFunction)

    page.ContentWidth = PAGE_CONTENT_WIDTH

    local contentHeight = layoutFunction(PAGE_CONTENT_WIDTH)

    page.ScrollChild:SetWidth(PAGE_CONTENT_WIDTH)
    Dashboard:ApplyPageScrolling(page, contentHeight)

end

function InventoryManager:BeginPageHero(page, titleKey, captionKey, bigValue)

    local _, _, _, yOffset = Dashboard:BuildHeroSection(
        page,
        page.ScrollChild,
        -8,
        page.ContentWidth,
        AC.L:Get(titleKey),
        bigValue or "",
        AC.L:Get(captionKey)
    )

    return yOffset

end

function InventoryManager:AppendNoScan(page, yOffset)

    yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.NoScanTitle", yOffset)
    yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "NoScanText", yOffset, page.ContentWidth, "InventoryManager.NoScanDescription")

    return Dashboard:EndSection(yOffset)

end

function InventoryManager:HideNoScan(page)

    if page.NoScanText then
        page.NoScanText:Hide()
    end

    local headers = page.ScrollChild and page.ScrollChild.SectionHeaders
    local header = headers and headers["InventoryManager.NoScanTitle"]

    if header then
        header:Hide()
    end

end

function InventoryManager:HideTextSection(page, poolKey, titleKey)

    local pool = page.Pools and page.Pools[poolKey]

    for _, row in ipairs(pool or {}) do
        row:Hide()
    end

    if pool and pool.EmptyText then
        pool.EmptyText:Hide()
    end

    local headers = page.ScrollChild and page.ScrollChild.SectionHeaders

    if headers and headers[titleKey] then
        headers[titleKey]:Hide()
    end

end

-------------------------------------------------------------------------------
-- Overview
-------------------------------------------------------------------------------

function InventoryManager:BuildOverviewPage()

    local page = self.Pages.Overview
    local context = self:GetStorageContext()
    local hasLiveSnapshot = context.scanStatus.hasSnapshot
    local isLive = context.scanStatus.freshness == "current"
    local lastKnownStorage = context.lastKnownStorage
    local hasLastKnownStorage = lastKnownStorage ~= nil

    -- Storage Knowledge Base -- "amnesia" only when there is genuinely
    -- nothing to show, live or carried over from a prior login.
    -- hasLiveSnapshot alone already covers everything within a single
    -- session (including a same-session bank close, unchanged from
    -- before); lastKnownStorage only ever fills the gap on a fresh login
    -- where nothing has been scanned yet this session.
    local hasAnyData = hasLiveSnapshot or hasLastKnownStorage

    -- Only meaningful once there is no live snapshot to answer instead --
    -- a same-session profile switch after a live scan is already reflected
    -- correctly by context.readiness (recomputed live, not cached).
    local profileMismatch = hasLastKnownStorage and (not hasLiveSnapshot)
        and context.profile and lastKnownStorage.metadata.profileID ~= context.profile.id

    local readinessText = self:GetReadiness(context)

    local lastScanTimestamp = context.lastScan and context.lastScan.timestamp
        or (lastKnownStorage and lastKnownStorage.metadata.timestamp)
    local lastScanText = lastScanTimestamp and AC.Presentation.FormatDate(lastScanTimestamp, "shortTime") or AC.L:Get("InventoryManager.LastScanUnknown")

    local distinctItems = context.lastScan and context.lastScan.distinctItems
        or (lastKnownStorage and lastKnownStorage.snapshot and lastKnownStorage.snapshot.distinctItems)
    local itemsText = distinctItems and tostring(distinctItems) or AC.L:Get("Common.Unknown")

    local insights = {}

    if hasLiveSnapshot and context.storageModule and context.storageModule.GetInsights then
        insights = context.storageModule:GetInsights()
    elseif (not hasLiveSnapshot) and lastKnownStorage then
        insights = (lastKnownStorage.analysis and lastKnownStorage.analysis.recommendations) or {}
    end

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        -- Never any data vs. have something to show (live or carried over)
        -- get their own hero caption ("visit a bank once" vs. "here's what
        -- we know"), same distinction GetReadiness() already makes for the
        -- big value.
        local heroCaptionKey = hasAnyData and "InventoryManager.OverviewHeroCaption" or "InventoryManager.NoSnapshotDescription"
        local yOffset = self:BeginPageHero(page, "InventoryManager.OverviewHeroTitle", heroCaptionKey, readinessText)

        -- Live Storage Status -- separates "can I execute prep work right
        -- now" (BankCacheReady-gated, resets on bank close, unchanged
        -- backend behavior) from the historical fields below it, which all
        -- correctly survive a bank close already, whether that history is
        -- this session's own stale scan or the Storage Knowledge Base's
        -- carried-over lastKnownStorage. Only fully hidden when there is
        -- truly nothing to report (hasAnyData false) -- the never-scanned
        -- empty state below covers that case instead.
        if hasAnyData then

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.LiveStatusSectionTitle", yOffset)

            if isLive then

                yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "LiveStatusLine", yOffset, width,
                    AC.L:Format("InventoryManager.LiveStatusConnectedFormat", AC.DashboardFormat.CHECK_SUCCESS))

                if page.LiveStatusDetail then
                    page.LiveStatusDetail:Hide()
                end

                if page.ProfileMismatchLine then
                    page.ProfileMismatchLine:Hide()
                end

            else

                yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "LiveStatusLine", yOffset, width,
                    AC.L:Format("InventoryManager.LiveStatusDisconnectedFormat", "|cffffcc00" .. AC.Presentation.WARNING_GLYPH .. "|r"))
                yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "LiveStatusDetail", yOffset, width, "InventoryManager.LiveStatusDisconnectedDescription")

                if profileMismatch then

                    -- Same built-in profile list StorageModule itself reads
                    -- (AC.StorageProfiles.BuiltIn) -- looked up by id here
                    -- since lastKnownStorage only stored the id, not a
                    -- live profile object reference.
                    local oldProfileLabel = lastKnownStorage.metadata.profileID

                    for _, candidate in ipairs(AC.StorageProfiles and AC.StorageProfiles.BuiltIn or {}) do
                        if candidate.id == lastKnownStorage.metadata.profileID then
                            oldProfileLabel = AC.L:Get(candidate.label)
                            break
                        end
                    end

                    local newProfileLabel = context.profile and AC.L:Get(context.profile.label) or AC.L:Get("Common.Unknown")

                    yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "ProfileMismatchLine", yOffset, width,
                        AC.L:Format("InventoryManager.ProfileMismatchFormat", oldProfileLabel, newProfileLabel))

                elseif page.ProfileMismatchLine then
                    page.ProfileMismatchLine:Hide()
                end

            end

            yOffset = Dashboard:EndSection(yOffset)

        else

            if page.LiveStatusLine then
                page.LiveStatusLine:Hide()
            end

            if page.LiveStatusDetail then
                page.LiveStatusDetail:Hide()
            end

            if page.ProfileMismatchLine then
                page.ProfileMismatchLine:Hide()
            end

            local headers = page.ScrollChild.SectionHeaders

            if headers and headers["InventoryManager.LiveStatusSectionTitle"] then
                headers["InventoryManager.LiveStatusSectionTitle"]:Hide()
            end

        end

        local profileText = context.profile and AC.L:Get(context.profile.label) or AC.L:Get("Storage.NoProfileSelected")

        -- "Sources Available" removed -- it was a raw BankOpen-derived live
        -- count that only meaningfully duplicated Live Storage Status above.
        -- Per-source detail already lives in the Storage Sources list below.
        yOffset = Dashboard:LayoutStatisticsGrid(page, "OverviewHeroStats", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatCurrentProfile", value = profileText },
            { label = "InventoryManager.StatLastScan", value = lastScanText },
            { label = "InventoryManager.StatItemsScanned", value = itemsText },
        })

        if hasAnyData then
            self:HideNoScan(page)
        else
            yOffset = self:AppendNoScan(page, yOffset)
            self:HideTextSection(page, "StorageSources", "InventoryManager.SectionStorageSources")
            self:HideTextSection(page, "StorageRecommendations", "InventoryManager.SectionRecommendations")
        end

        -- Same per-source line format either way -- persisted source
        -- entries (Storage Knowledge Base) simply lack the live-only
        -- .freshness/.available fields GetStorageSources() adds on top, so
        -- they fall straight to the "Last scanned <time>" branch below,
        -- which is the factually correct thing to show for carried-over
        -- data regardless.
        local sourceList = hasLiveSnapshot and context.sources
            or (lastKnownStorage and lastKnownStorage.snapshot and lastKnownStorage.snapshot.sources)
            or {}

        local sourceLines = {}

        for _, source in ipairs(sourceList) do

            local sourceState

            if source.freshness == "current" then
                sourceState = AC.L:Get("InventoryManager.SourceStateCurrent")
            elseif source.timestamp then
                sourceState = AC.L:Format("InventoryManager.SourceStateLastScanFormat", AC.Presentation.FormatDate(source.timestamp, "shortTime"))
            else
                sourceState = AC.L:Get("InventoryManager.SourceUnavailable")
            end

            table.insert(sourceLines, AC.L:Format(
                "InventoryManager.SourceLineFormat",
                AC.L:Get(STORAGE_SOURCE_LABELS[source.id] or "Common.Unknown"),
                sourceState,
                source.slotsScanned or 0,
                source.distinctItems or 0
            ))

        end

        if hasAnyData then

            yOffset = Dashboard:AppendTextSection(page, "StorageSources", "InventoryManager.SectionStorageSources", yOffset, sourceLines, "InventoryManager.NoSources", function(line)
                return line
            end)

            -- Recommendations survive a bank close already (gated on
            -- hasAnyData, not BankCacheReady) -- unchanged, now also true
            -- across a fresh login via lastKnownStorage. Only addition is
            -- the caption explaining why advice is still showing with no
            -- bank open, built from the same BeginSection/ShowEmptyLine/
            -- LayoutTextLines/EndSection primitives AppendTextSection
            -- itself already composes, just with one extra line.
            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionRecommendations", yOffset)
            yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "RecommendationsCaption", yOffset, width, "InventoryManager.RecommendationsCaption")

            page.Pools = page.Pools or {}
            page.Pools.StorageRecommendations = page.Pools.StorageRecommendations or {}

            yOffset = Dashboard:LayoutTextLines(page.ScrollChild, page.Pools.StorageRecommendations, insights, yOffset, width, "Weekly.NoRecommendations", function(insight)
                return insight.description or insight.title or AC.L:Get("Common.Unknown")
            end)

            yOffset = Dashboard:EndSection(yOffset)

        elseif page.RecommendationsCaption then
            page.RecommendationsCaption:Hide()
        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

-------------------------------------------------------------------------------
-- Categories
-------------------------------------------------------------------------------

function InventoryManager:FormatCategoryLocations(category)

    local lines = {}

    for _, location in ipairs(category.locations or {}) do

        local sourceLabel = AC.L:Get(STORAGE_SOURCE_LABELS[location.sourceID] or "Common.Unknown")

        table.insert(lines, AC.L:Format(
            "InventoryManager.CategoryLocationFormat",
            sourceLabel,
            location.stackCount or 0,
            location.quantity or 0
        ))

    end

    return table.concat(lines, "   ")

end

function InventoryManager:LayoutCategoryCards(page, yOffset, width, categories)

    local self_ref = self

    return AC.InventoryComponents:LayoutItemCards(
        page,
        "CategoryCards",
        "CategoriesEmptyText",
        yOffset,
        width,
        categories,
        84,
        function(card, category)
            card:SetTitle(AC.L:Get(STORAGE_CATEGORY_LABELS[category.id] or "InventoryManager.CategoryUnknown"))
            card:SetPrimaryValue(AC.L:Format("InventoryManager.CategoryItemCountFormat", category.itemCount or 0))
            card:SetSecondaryText(AC.L:Format("InventoryManager.CategoryStackCountFormat", category.quantity or 0, category.stackCount or 0))
            card:SetDetailText(self_ref:FormatCategoryLocations(category))
            card:SetStatus(nil, "")
        end,
        "InventoryManager.CategoriesEmpty"
    )

end

function InventoryManager:BuildCategoriesPage()

    local page = self.Pages.Categories
    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local summary = storageModule and storageModule.GetCategorySummary and storageModule:GetCategorySummary() or
    {
        categories = {},
        statistics = { itemCount = 0, stackCount = 0, quantity = 0, sourceCount = 0, availableSourceCount = 0 },
        status = {},
    }

    page.CategorySummary = summary

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local statistics = summary.statistics or {}
        local categories = summary.categories or {}
        local yOffset = self:BeginPageHero(
            page,
            "InventoryManager.CategoriesHeroTitle",
            "InventoryManager.CategoriesHeroCaption",
            tostring(statistics.quantity or 0)
        )

        yOffset = Dashboard:LayoutStatisticsGrid(page, "CategoriesHeroStats", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatCategories", value = tostring(statistics.categoryCount or 0) },
            { label = "InventoryManager.StatAggregateItemTypes", value = tostring(statistics.itemCount or 0) },
            { label = "InventoryManager.StatAggregateStacks", value = tostring(statistics.stackCount or 0) },
            { label = "InventoryManager.StatAggregateSources", value = AC.L:Format("InventoryManager.SourceCountFormat", statistics.availableSourceCount or 0, statistics.sourceCount or 0) },
        })

        yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionCategories", yOffset)
        yOffset = self:LayoutCategoryCards(page, yOffset, width, categories)
        yOffset = Dashboard:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:GetCategoriesStatusText()

    local page = self.Pages and self.Pages.Categories
    local status = page and page.CategorySummary and page.CategorySummary.status or {}
    local inventory = status.inventory or {}
    local bank = status.bank or {}

    if inventory.available and bank.hasSnapshot then
        return AC.L:Get("InventoryManager.AggregateBagsAndBanks")
    end

    if inventory.available then
        return AC.L:Get("InventoryManager.AggregateBagsOnly")
    end

    if bank.hasSnapshot then
        return AC.L:Get("InventoryManager.AggregateBanksOnly")
    end

    return AC.L:Get("InventoryManager.AggregateUnavailable")

end

-------------------------------------------------------------------------------
-- Search
-------------------------------------------------------------------------------

function InventoryManager:GetSearchState()

    if not self.SearchState then

        self.SearchState =
        {
            query = "",
            category = SEARCH_ALL,
            source = SEARCH_ALL,
            owner = SEARCH_ALL,
            quality = SEARCH_ALL,
            sortBy = "name",
            status = "never_searched",
            hasSearched = false,
            result = nil,
        }

    end

    return self.SearchState

end

function InventoryManager:CreateSearchLabel(page, key, localizationKey)

    page.SearchLabels = page.SearchLabels or {}

    if not page.SearchLabels[key] then

        local label = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
        page.SearchLabels[key] = label

    end

    page.SearchLabels[key]:SetText(AC.L:Get(localizationKey))

    return page.SearchLabels[key]

end

function InventoryManager:CreateSearchWidget(widgetType, page, options)

    local widget = AC.WidgetManager:Create(widgetType, page.ScrollChild, options)

    self.SearchWidgets = self.SearchWidgets or {}
    table.insert(self.SearchWidgets, widget)

    return widget

end

function InventoryManager:EnsureSearchControls(page)

    if page.SearchControls then
        return
    end

    local state = self:GetSearchState()
    local controls = {}

    controls.Query = self:CreateSearchWidget("EditBox", page,
    {
        width = SEARCH_INPUT_WIDTH,
        value = state.query,
        tooltip = AC.L:Get("InventoryManager.SearchInputTooltip"),
        onChanged = function(_, value)
            self:OnSearchTextChanged(value)
        end,
        onEnterPressed = function()
            self:RunSearch()
        end,
    })
    controls.Search = self:CreateSearchWidget("Button", page,
    {
        width = SEARCH_ACTION_WIDTH,
        text = AC.L:Get("InventoryManager.SearchButton"),
        onClick = function()
            self:RunSearch()
        end,
    })
    controls.Clear = self:CreateSearchWidget("Button", page,
    {
        width = SEARCH_ACTION_WIDTH,
        text = AC.L:Get("InventoryManager.SearchClear"),
        onClick = function()
            self:ClearSearch()
        end,
    })
    controls.Category = self:CreateSearchWidget("Dropdown", page,
    {
        list = {},
        onChanged = function(_, value)
            self:SetSearchFilter("category", value)
        end,
    })
    controls.Source = self:CreateSearchWidget("Dropdown", page,
    {
        list = {},
        onChanged = function(_, value)
            self:SetSearchFilter("source", value)
        end,
    })
    controls.Owner = self:CreateSearchWidget("Dropdown", page,
    {
        list = {},
        onChanged = function(_, value)
            self:SetSearchFilter("owner", value)
        end,
    })
    controls.Quality = self:CreateSearchWidget("Dropdown", page,
    {
        list = {},
        onChanged = function(_, value)
            self:SetSearchFilter("quality", value)
        end,
    })
    controls.Sort = self:CreateSearchWidget("Dropdown", page,
    {
        list = {},
        onChanged = function(_, value)
            self:SetSearchFilter("sortBy", value)
        end,
    })

    self:CreateSearchLabel(page, "Query", "InventoryManager.SearchItemName")
    self:CreateSearchLabel(page, "Category", "InventoryManager.SearchFilterCategory")
    self:CreateSearchLabel(page, "Source", "InventoryManager.SearchFilterSource")
    self:CreateSearchLabel(page, "Owner", "InventoryManager.SearchFilterOwner")
    self:CreateSearchLabel(page, "Quality", "InventoryManager.SearchFilterQuality")
    self:CreateSearchLabel(page, "Sort", "InventoryManager.SearchSort")

    page.SearchControls = controls

end

function InventoryManager:SearchOptionExists(options, value)

    for _, option in ipairs(options) do
        if option.value == value then
            return true
        end
    end

    return false

end

function InventoryManager:UpdateSearchDropdown(control, options, stateKey, defaultValue)

    local state = self:GetSearchState()

    if not self:SearchOptionExists(options, state[stateKey]) then
        state[stateKey] = defaultValue
    end

    control:SetList(options)
    control:SetValue(state[stateKey])

end

function InventoryManager:BuildSearchFilterLists(filterInfo)

    local categories =
    {
        { text = AC.L:Get("InventoryManager.FilterAllCategories"), value = SEARCH_ALL },
    }
    local sources =
    {
        { text = AC.L:Get("InventoryManager.FilterAllSources"), value = SEARCH_ALL },
    }
    local owners =
    {
        { text = AC.L:Get("InventoryManager.FilterAllOwners"), value = SEARCH_ALL },
    }
    local qualities =
    {
        { text = AC.L:Get("InventoryManager.FilterAllQualities"), value = SEARCH_ALL },
    }
    local sortOptions = {}

    for _, categoryID in ipairs(filterInfo.categories or {}) do
        table.insert(categories,
        {
            text = AC.L:Get(STORAGE_CATEGORY_LABELS[categoryID] or "InventoryManager.CategoryUnknown"),
            value = categoryID,
        })
    end

    for _, sourceID in ipairs(filterInfo.sources or {}) do
        table.insert(sources,
        {
            text = AC.L:Get(STORAGE_SOURCE_LABELS[sourceID] or "Common.Unknown"),
            value = sourceID,
        })
    end

    for _, owner in ipairs(filterInfo.owners or {}) do

        local ownerText = owner.name or AC.L:Get("Common.Unknown")

        if owner.realm and owner.realm ~= "" then
            ownerText = AC.L:Format("InventoryManager.OwnerNameRealmFormat", ownerText, owner.realm)
        end

        table.insert(owners, { text = ownerText, value = owner.key })

    end

    for _, quality in ipairs(filterInfo.qualities or {}) do
        table.insert(qualities,
        {
            text = AC.L:Get(STORAGE_QUALITY_LABELS[quality] or "InventoryManager.QualityUnknown"),
            value = quality,
        })
    end

    if filterInfo.hasUnknownQuality then
        table.insert(qualities, { text = AC.L:Get("InventoryManager.QualityUnknown"), value = SEARCH_UNKNOWN_QUALITY })
    end

    for _, sortOption in ipairs(filterInfo.sortOptions or {}) do
        table.insert(sortOptions,
        {
            text = AC.L:Get(STORAGE_SORT_LABELS[sortOption] or "Common.Unknown"),
            value = sortOption,
        })
    end

    return categories, sources, owners, qualities, sortOptions

end

function InventoryManager:RefreshSearchFilterOptions(page)

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local filterInfo = storageModule and storageModule.GetSearchFilters and storageModule:GetSearchFilters() or
    {
        enabled = false,
        categories = {},
        sources = {},
        owners = {},
        qualities = {},
        sortOptions = { "name", "quantity", "category", "source" },
    }
    local categories, sources, owners, qualities, sortOptions = self:BuildSearchFilterLists(filterInfo)
    local controls = page.SearchControls

    self:UpdateSearchDropdown(controls.Category, categories, "category", SEARCH_ALL)
    self:UpdateSearchDropdown(controls.Source, sources, "source", SEARCH_ALL)
    self:UpdateSearchDropdown(controls.Owner, owners, "owner", SEARCH_ALL)
    self:UpdateSearchDropdown(controls.Quality, qualities, "quality", SEARCH_ALL)
    self:UpdateSearchDropdown(controls.Sort, sortOptions, "sortBy", "name")

    local enabled = filterInfo.enabled ~= false

    controls.Query:SetEnabled(enabled)
    controls.Search:SetEnabled(enabled)
    controls.Category:SetEnabled(enabled)
    controls.Source:SetEnabled(enabled)
    controls.Owner:SetEnabled(enabled)
    controls.Quality:SetEnabled(enabled)
    controls.Sort:SetEnabled(enabled)
    controls.Clear:SetEnabled(true)

    self.SearchFilterInfo = filterInfo

    return filterInfo

end

function InventoryManager:LayoutSearchBar(page, yOffset, width)

    local label = page.SearchLabels.Query
    local controls = page.SearchControls

    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
    label:SetWidth(SEARCH_INPUT_WIDTH)

    local controlY = yOffset - (label:GetStringHeight() or 12) - SEARCH_LABEL_GAP
    local queryFrame = controls.Query:GetFrame()
    local searchFrame = controls.Search:GetFrame()
    local clearFrame = controls.Clear:GetFrame()

    queryFrame:ClearAllPoints()
    queryFrame:SetPoint("TOPLEFT", Layout.ROW_INDENT, controlY)

    searchFrame:ClearAllPoints()
    searchFrame:SetPoint("TOPLEFT", queryFrame, "TOPRIGHT", SEARCH_CONTROL_GAP, 0)

    clearFrame:ClearAllPoints()
    clearFrame:SetPoint("TOPLEFT", searchFrame, "TOPRIGHT", SEARCH_CONTROL_GAP, 0)

    return controlY - 26 - SEARCH_FILTER_ROW_GAP

end

function InventoryManager:LayoutSearchFilterControl(page, labelKey, controlKey, xOffset, yOffset, width)

    local label = page.SearchLabels[labelKey]
    local control = page.SearchControls[controlKey]
    local frame = control:GetFrame()

    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetWidth(width)

    frame:SetWidth(width)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", xOffset, yOffset - (label:GetStringHeight() or 12) - SEARCH_LABEL_GAP)

end

function InventoryManager:LayoutSearchFilters(page, yOffset, width)

    local filterWidth = math.floor((width - (Layout.ROW_INDENT * 2) - (SEARCH_CONTROL_GAP * 2)) / 3)
    local firstX = Layout.ROW_INDENT
    local secondX = firstX + filterWidth + SEARCH_CONTROL_GAP
    local thirdX = secondX + filterWidth + SEARCH_CONTROL_GAP

    self:LayoutSearchFilterControl(page, "Category", "Category", firstX, yOffset, filterWidth)
    self:LayoutSearchFilterControl(page, "Source", "Source", secondX, yOffset, filterWidth)
    self:LayoutSearchFilterControl(page, "Owner", "Owner", thirdX, yOffset, filterWidth)

    yOffset = yOffset - 26 - SEARCH_LABEL_GAP - 12 - SEARCH_FILTER_ROW_GAP

    self:LayoutSearchFilterControl(page, "Quality", "Quality", firstX, yOffset, filterWidth)
    self:LayoutSearchFilterControl(page, "Sort", "Sort", secondX, yOffset, filterWidth)

    return yOffset - 26 - SEARCH_LABEL_GAP - 12 - SEARCH_FILTER_ROW_GAP

end

function InventoryManager:GetSearchDisplayState(filterInfo)

    local state = self:GetSearchState()

    if filterInfo.enabled == false then
        return "storage_unavailable"
    end

    if not filterInfo.snapshotIdentity then
        return "no_storage_data"
    end

    return state.status

end

function InventoryManager:HideSearchResults(page)

    AC.InventoryComponents:HideCardSection(page, "SearchResultCards", "InventoryManager.SectionSearchResults", nil)

end

function InventoryManager:GetSearchResultOwnerText(item)

    if not item.owningCharacter or item.owningCharacter == "" then
        return ""
    end

    local owner = item.owningCharacter

    if item.owningRealm and item.owningRealm ~= "" then
        owner = AC.L:Format("InventoryManager.OwnerNameRealmFormat", owner, item.owningRealm)
    end

    return AC.L:Format("InventoryManager.SearchOwnerFormat", owner)

end

function InventoryManager:GetSearchResultFreshness(item)

    if item.freshness == "current" and item.available then
        return "Normal", AC.L:Get("InventoryManager.SearchFreshnessCurrent")
    end

    if item.snapshotTimestamp then
        return "Warning", AC.L:Format("InventoryManager.SearchFreshnessRecorded", AC.Presentation.FormatDate(item.snapshotTimestamp, "shortTime"))
    end

    return nil, AC.L:Get("InventoryManager.SearchFreshnessUnknown")

end

function InventoryManager:LayoutSearchResultCards(page, yOffset, width, items)

    local self_ref = self

    return AC.InventoryComponents:LayoutItemCards(
        page,
        "SearchResultCards",
        nil,
        yOffset,
        width,
        items,
        SEARCH_RESULT_CARD_HEIGHT,
        function(card, item)
            local title = item.itemName

            if not title or title == "" then
                title = AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
            end

            local category = AC.L:Get(STORAGE_CATEGORY_LABELS[item.category] or "InventoryManager.CategoryUnknown")
            local source = AC.L:Get(STORAGE_SOURCE_LABELS[item.storageSource] or "Common.Unknown")
            local status, statusText = self_ref:GetSearchResultFreshness(item)

            card:SetIcon(item.icon)
            card:SetTitle(title)
            card:SetPrimaryValue(AC.L:Format("InventoryManager.SearchQuantityFormat", item.quantity or 0))
            card:SetSecondaryText(AC.L:Format("InventoryManager.SearchResultContextFormat", category, source, item.stackCount or 0))
            card:SetDetailText(self_ref:GetSearchResultOwnerText(item))
            card:SetStatus(status, statusText)
        end
    )

end

function InventoryManager:BuildSearchPage()

    local page = self.Pages.Search
    local state = self:GetSearchState()

    self:EnsureSearchControls(page)

    local filterInfo = self.SearchFilterInfo or self:RefreshSearchFilterOptions(page)

    if self.SearchResultDirty and state.hasSearched then
        self:ExecuteSearchQuery()
    end

    local displayState = self:GetSearchDisplayState(filterInfo)
    local result = state.result

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local heroValue = AC.L:Get("InventoryManager.SearchHeroValue")

        if result and (displayState == "success" or displayState == "no_results") then
            heroValue = tostring(result.statistics and result.statistics.resultCount or 0)
        end

        local yOffset = self:BeginPageHero(page, "InventoryManager.SearchHeroTitle", "InventoryManager.SearchHeroCaption", heroValue)

        yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionSearch", yOffset)
        yOffset = self:LayoutSearchBar(page, yOffset, width)
        yOffset = Dashboard:EndSection(yOffset)

        yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionSearchFilters", yOffset)
        yOffset = self:LayoutSearchFilters(page, yOffset, width)
        yOffset = Dashboard:EndSection(yOffset)

        if displayState == "success" and result then

            local statistics = result.statistics or {}

            yOffset = Dashboard:AppendStatisticsSection(page, "SearchSummary", "InventoryManager.SectionSearchSummary", yOffset,
            {
                { label = "InventoryManager.StatSearchItemTypes", value = tostring(statistics.itemCount or 0) },
                { label = "InventoryManager.StatSearchQuantity", value = tostring(statistics.quantity or 0) },
                { label = "InventoryManager.StatSearchStacks", value = tostring(statistics.stackCount or 0) },
                { label = "InventoryManager.StatSearchSources", value = tostring(statistics.sourceCount or 0) },
            })

            local resultsTitle = AC.L:Format("InventoryManager.SearchResultsTitleFormat", statistics.resultCount or 0)

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionSearchResults", yOffset, resultsTitle)
            yOffset = self:LayoutSearchResultCards(page, yOffset, width, result.items or {})
            yOffset = Dashboard:EndSection(yOffset)

        else

            self:HideSearchResults(page)

            yOffset = Dashboard:AppendStatisticsSection(
                page,
                "SearchSummary",
                "InventoryManager.SectionSearchSummary",
                yOffset,
                {},
                SEARCH_STATE_TEXT_KEYS[displayState] or "InventoryManager.SearchNeverSearched"
            )

        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:OnSearchTextChanged(value)

    local state = self:GetSearchState()

    state.query = value or ""
    state.status = state.query == "" and "never_searched" or "pending"
    state.hasSearched = false
    state.result = nil
    self.SearchResultDirty = false

    if self.CurrentPage == "Search" and self.Frame and self.Frame:IsShown() then
        self:BuildSearchPage()
        self:UpdateFooterStatus()
    end

end

function InventoryManager:ExecuteSearchQuery()

    local state = self:GetSearchState()
    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local result = storageModule and storageModule.SearchItems and storageModule:SearchItems(state.query,
    {
        category = state.category,
        source = state.source,
        owner = state.owner,
        quality = state.quality,
        sortBy = state.sortBy,
    }) or
    {
        state = "storage_unavailable",
        items = {},
        statistics = {},
    }

    state.result = result
    state.status = result.state
    self.SearchResultDirty = false

    return result

end

function InventoryManager:SetSearchFilter(key, value)

    local state = self:GetSearchState()

    state[key] = value

    if state.hasSearched then
        self:RunSearch()
    elseif self.CurrentPage == "Search" then
        self:BuildSearchPage()
        self:UpdateFooterStatus()
    end

end

function InventoryManager:RunSearch()

    local state = self:GetSearchState()
    local page = self.Pages and self.Pages.Search

    if not page then
        return
    end

    self:EnsureSearchControls(page)

    if not self.SearchFilterInfo then
        self:RefreshSearchFilterOptions(page)
    end

    state.status = "searching"
    state.hasSearched = true
    state.result = nil
    self.SearchResultDirty = false

    if self.CurrentPage == "Search" then
        self:BuildSearchPage()
    end

    self:ExecuteSearchQuery()

    if self.CurrentPage == "Search" then
        self:BuildSearchPage()
        self:UpdateFooterStatus()
    end

end

function InventoryManager:ClearSearch()

    local state = self:GetSearchState()

    state.query = ""
    state.category = SEARCH_ALL
    state.source = SEARCH_ALL
    state.owner = SEARCH_ALL
    state.quality = SEARCH_ALL
    state.sortBy = "name"
    state.status = "never_searched"
    state.hasSearched = false
    state.result = nil
    self.SearchResultDirty = false

    local page = self.Pages and self.Pages.Search
    local controls = page and page.SearchControls

    if controls then
        controls.Query:SetValue("")
        controls.Category:SetValue(state.category)
        controls.Source:SetValue(state.source)
        controls.Owner:SetValue(state.owner)
        controls.Quality:SetValue(state.quality)
        controls.Sort:SetValue(state.sortBy)
    end

    if self.CurrentPage == "Search" then
        self:BuildSearchPage()
        self:UpdateFooterStatus()
    end

end

function InventoryManager:GetSearchStatusText()

    local state = self:GetSearchState()
    local filterInfo = self.SearchFilterInfo or { enabled = false }
    local displayState = self:GetSearchDisplayState(filterInfo)

    if displayState == "success" and state.result then
        return AC.L:Format("InventoryManager.SearchSuccessStatus", state.result.statistics and state.result.statistics.resultCount or 0)
    end

    return AC.L:Get(SEARCH_STATE_TEXT_KEYS[displayState] or "InventoryManager.SearchNeverSearched")

end

-------------------------------------------------------------------------------
-- Shopping List
-------------------------------------------------------------------------------

function InventoryManager:GetShoppingListSummary()

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if not storageModule or not storageModule.GetShoppingListSummary then
        return
        {
            state = "unavailable",
            reason = "api_unavailable",
            missing = {},
            availableInStorage = {},
            statistics = {},
        }
    end

    return storageModule:GetShoppingListSummary()

end

function InventoryManager:GetShoppingListEmptyState(summary)

    if summary.state == "unavailable" then
        return "InventoryManager.ShoppingUnavailable"
    end

    if summary.reason == "snapshot_stale" then
        return "InventoryManager.ShoppingStale"
    end

    if summary.reason == "character_bank_unavailable" then
        return "InventoryManager.ShoppingCharacterBankRequired"
    end

    if summary.reason == "inventory_unavailable" then
        return "InventoryManager.ShoppingInventoryRequired"
    end

    return "InventoryManager.ShoppingUnknown"

end

function InventoryManager:GetShoppingHeroValue(summary)

    local statistics = summary.statistics or {}

    if summary.state == "unavailable" then
        return AC.L:Get("InventoryManager.ShoppingUnavailableValue")
    end

    if summary.state ~= "known" then
        return AC.L:Get("Common.Unknown")
    end

    if (statistics.requirementCount or 0) == 0 then
        return AC.L:Get("InventoryManager.ShoppingNoRequirementsValue")
    end

    if summary.ready then
        return AC.L:Get("InventoryManager.Ready")
    end

    return AC.L:Format("InventoryManager.ReadinessFormat", summary.readinessPercent or 0)

end

function InventoryManager:FormatShoppingHeldItems(entry)

    local lines = {}

    for _, item in ipairs(entry.items or {}) do

        local name = item.name

        if not name or name == "" then
            name = AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
        end

        table.insert(lines, AC.L:Format("Storage.ShoppingListItemFormat", name, item.currentCount or 0))

    end

    if #lines == 0 then
        return AC.L:Get("Storage.ShoppingListNoneHeld")
    end

    return table.concat(lines, "   ")

end

function InventoryManager:LayoutShoppingCards(page, poolKey, emptyKey, yOffset, width, entries, entryType, emptyTextKey)

    local self_ref = self
    local missing = entryType == "missing"

    return AC.InventoryComponents:LayoutItemCards(
        page,
        poolKey,
        emptyKey,
        yOffset,
        width,
        entries,
        SHOPPING_CARD_HEIGHT,
        function(card, entry)
            local icon = missing and entry.items and #entry.items == 1 and entry.items[1].icon or nil

            card:SetIcon(icon)
            card:SetTitle(AC.L:Get(entry.label or "Common.Unknown"))
            card:SetPrimaryValue(AC.L:Format(missing and "Storage.ShoppingListNeedFormat" or "Storage.AmountWithdrawFormat", entry.amount or 0))
            card:SetSecondaryText(AC.L:Get(missing and "InventoryManager.ShoppingMissingContext" or "InventoryManager.ShoppingAvailableContext"))
            card:SetDetailText(missing and self_ref:FormatShoppingHeldItems(entry) or "")
            card:SetStatus(missing and "Important" or "Warning", AC.L:Get(missing and "InventoryManager.ShoppingMissingStatus" or "InventoryManager.ShoppingAvailableStatus"))
        end,
        emptyTextKey
    )

end

function InventoryManager:BuildShoppingListPage()

    local page = self.Pages.ShoppingList
    local summary = self:GetShoppingListSummary()
    local statistics = summary.statistics or {}

    page.ShoppingSummary = summary

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local yOffset = self:BeginPageHero(
            page,
            "InventoryManager.ShoppingHeroTitle",
            "InventoryManager.ShoppingHeroCaption",
            self:GetShoppingHeroValue(summary)
        )

        if summary.state ~= "known" then

            yOffset = Dashboard:AppendStatisticsSection(
                page,
                "ShoppingSummary",
                "InventoryManager.SectionShoppingSummary",
                yOffset,
                {},
                self:GetShoppingListEmptyState(summary)
            )

            AC.InventoryComponents:HideCardSection(page, "ShoppingMissingCards", "InventoryManager.SectionShoppingMissing", "ShoppingMissingEmptyText")
            AC.InventoryComponents:HideCardSection(page, "ShoppingAvailableCards", "InventoryManager.SectionShoppingAvailable", "ShoppingAvailableEmptyText")

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        local readinessText = summary.ready and AC.L:Get("InventoryManager.Ready") or AC.L:Format("InventoryManager.ReadinessFormat", summary.readinessPercent or 0)

        yOffset = Dashboard:AppendStatisticsSection(page, "ShoppingSummary", "InventoryManager.SectionShoppingSummary", yOffset,
        {
            { label = "InventoryManager.StatCurrentProfile", value = summary.profileLabel and AC.L:Get(summary.profileLabel) or AC.L:Get("Storage.NoProfileSelected") },
            { label = "InventoryManager.StatShoppingReadiness", value = readinessText },
            { label = "InventoryManager.StatShoppingMissing", value = tostring(statistics.missingQuantity or 0) },
            { label = "InventoryManager.StatShoppingAvailable", value = tostring(statistics.availableQuantity or 0) },
        })

        local missingEmptyText = (statistics.requirementCount or 0) == 0 and "InventoryManager.ShoppingNoRequirements" or "Storage.NothingToBuy"

        yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionShoppingMissing", yOffset)
        yOffset = self:LayoutShoppingCards(page, "ShoppingMissingCards", "ShoppingMissingEmptyText", yOffset, width, summary.missing or {}, "missing", missingEmptyText)
        yOffset = Dashboard:EndSection(yOffset)

        if #(summary.availableInStorage or {}) > 0 then

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionShoppingAvailable", yOffset)
            yOffset = self:LayoutShoppingCards(page, "ShoppingAvailableCards", "ShoppingAvailableEmptyText", yOffset, width, summary.availableInStorage, "available", "Storage.NoBankTransfersNeeded")
            yOffset = Dashboard:EndSection(yOffset)

        else
            AC.InventoryComponents:HideCardSection(page, "ShoppingAvailableCards", "InventoryManager.SectionShoppingAvailable", "ShoppingAvailableEmptyText")
        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:GetShoppingListStatusText()

    local page = self.Pages and self.Pages.ShoppingList
    local summary = page and page.ShoppingSummary or self:GetShoppingListSummary()
    local statistics = summary.statistics or {}

    if summary.state ~= "known" then
        return AC.L:Get(self:GetShoppingListEmptyState(summary))
    end

    if (statistics.requirementCount or 0) == 0 then
        return AC.L:Get("InventoryManager.ShoppingNoRequirements")
    end

    if summary.ready then
        return AC.L:Get("InventoryManager.ShoppingReadyStatus")
    end

    return AC.L:Format("InventoryManager.ShoppingFooterFormat", statistics.missingQuantity or 0, statistics.availableQuantity or 0)

end

-------------------------------------------------------------------------------
-- Consumables
-------------------------------------------------------------------------------

local CONSUMABLE_SUBCLASS_ORDER =
{
    "flask",
    "food",
    "potion",
    "itemEnhancement",
    "healthstone",
}

local CONSUMABLE_CARD_HEIGHT = 76

function InventoryManager:GetConsumableSubclassLabel(subclass)

    return AC.L:Get("InventoryManager.ConsumableSubclass." .. (subclass or "unknown"))

end

function InventoryManager:GetConsumableInventorySummary()

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if not storageModule or not storageModule.GetConsumableInventory then
        return
        {
            enabled = false,
            categories = {},
            statistics = { itemCount = 0, totalQuantity = 0, bagQuantity = 0, bankQuantity = 0 },
        }
    end

    local inventory = storageModule:GetConsumableInventory()
    local categories = inventory.categories or {}
    local statistics =
    {
        itemCount = 0,
        totalQuantity = 0,
        bagQuantity = 0,
        bankQuantity = 0,
        subclassCount = 0,
    }

    for subclass, bucket in pairs(categories) do
        statistics.subclassCount = statistics.subclassCount + 1
        statistics.itemCount = statistics.itemCount + #(bucket.items or {})
        statistics.totalQuantity = statistics.totalQuantity + (bucket.categoryTotal or 0)
        statistics.bagQuantity = statistics.bagQuantity + (bucket.categoryBagTotal or 0)
        statistics.bankQuantity = statistics.bankQuantity + (bucket.categoryBankTotal or 0)
    end

    return
    {
        enabled = storageModule:IsModuleEnabled(),
        categories = categories,
        statistics = statistics,
    }

end

function InventoryManager:GetConsumableMissingItems()

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if not storageModule or not storageModule.AnalyzeProfile or not storageModule.GetActiveProfile then
        return {}
    end

    local profile = storageModule:GetActiveProfile()

    if not profile then
        return {}
    end

    local analysis = storageModule:AnalyzeProfile(profile.id)

    return analysis.missing or {}

end

function InventoryManager:GetConsumableHeroValue(summary)

    if not summary.enabled then
        return AC.L:Get("InventoryManager.ConsumablesUnavailableValue")
    end

    local statistics = summary.statistics or {}

    if (statistics.itemCount or 0) == 0 then
        return "0"
    end

    return tostring(statistics.totalQuantity or 0)

end

function InventoryManager:GetConsumableSourceLabel(item)

    local hasBag = (item.bagCount or 0) > 0
    local hasBank = (item.bankCount or 0) > 0

    if hasBag and hasBank then
        return AC.L:Get("InventoryManager.ConsumableSourceBoth")
    end

    if hasBag then
        return AC.L:Get("InventoryManager.ConsumableSourceBags")
    end

    if hasBank then
        return AC.L:Get("InventoryManager.ConsumableSourceBank")
    end

    return AC.L:Get("Common.Unknown")

end

function InventoryManager:LayoutConsumableSubclassCards(page, poolKey, yOffset, width, items, subclass)

    local self_ref = self

    return AC.InventoryComponents:LayoutItemCards(
        page,
        poolKey,
        nil,
        yOffset,
        width,
        items,
        CONSUMABLE_CARD_HEIGHT,
        function(card, item)
            local name = item.name

            if not name or name == "" then
                name = AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
            end

            card:SetIcon(item.icon)
            card:SetTitle(name)
            card:SetPrimaryValue(AC.L:Format("InventoryManager.ConsumableQuantityFormat", item.totalCount or 0))
            card:SetSecondaryText(AC.L:Format("InventoryManager.ConsumableLocationFormat", item.bagCount or 0, item.bankCount or 0))
            card:SetDetailText(self_ref:GetConsumableSourceLabel(item))
            card:SetStatus(nil, "")
        end
    )

end

function InventoryManager:LayoutConsumableMissingCards(page, yOffset, width, missingItems)

    return AC.InventoryComponents:LayoutItemCards(
        page,
        "ConsumableMissingCards",
        "ConsumableMissingEmptyText",
        yOffset,
        width,
        missingItems,
        CONSUMABLE_CARD_HEIGHT,
        function(card, entry)
            card:SetIcon(nil)
            card:SetTitle(AC.L:Get(entry.label or "Common.Unknown"))
            card:SetPrimaryValue(AC.L:Format("InventoryManager.ConsumableMissingFormat", entry.amount or 0))
            card:SetSecondaryText(AC.L:Get("InventoryManager.ConsumableMissingContext"))
            card:SetDetailText("")
            card:SetStatus("Important", AC.L:Get("InventoryManager.ShoppingMissingStatus"))
        end,
        "InventoryManager.ConsumablesMissingEmpty"
    )

end

function InventoryManager:BuildConsumablesPage()

    local page = self.Pages.Consumables
    local summary = self:GetConsumableInventorySummary()
    local missingItems = self:GetConsumableMissingItems()
    local statistics = summary.statistics or {}

    page.ConsumableSummary = summary
    page.ConsumableMissing = missingItems

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local yOffset = self:BeginPageHero(
            page,
            "InventoryManager.ConsumablesHeroTitle",
            "InventoryManager.ConsumablesHeroCaption",
            self:GetConsumableHeroValue(summary)
        )

        if not summary.enabled then

            yOffset = Dashboard:AppendStatisticsSection(
                page,
                "ConsumableSummary",
                "InventoryManager.SectionConsumableSummary",
                yOffset,
                {},
                "InventoryManager.ConsumablesDisabled"
            )

            AC.InventoryComponents:HideCardSection(page, "ConsumableFlaskCards", "InventoryManager.ConsumableSubclass.flask", nil)
            AC.InventoryComponents:HideCardSection(page, "ConsumableFoodCards", "InventoryManager.ConsumableSubclass.food", nil)
            AC.InventoryComponents:HideCardSection(page, "ConsumablePotionCards", "InventoryManager.ConsumableSubclass.potion", nil)
            AC.InventoryComponents:HideCardSection(page, "ConsumableEnhancementCards", "InventoryManager.ConsumableSubclass.itemEnhancement", nil)
            AC.InventoryComponents:HideCardSection(page, "ConsumableHealthstoneCards", "InventoryManager.ConsumableSubclass.healthstone", nil)
            AC.InventoryComponents:HideCardSection(page, "ConsumableMissingCards", "InventoryManager.SectionMissingConsumables", "ConsumableMissingEmptyText")

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        yOffset = Dashboard:LayoutStatisticsGrid(page, "ConsumableHeroStats", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatConsumableTypes", value = tostring(statistics.itemCount or 0) },
            { label = "InventoryManager.StatConsumableTotal", value = tostring(statistics.totalQuantity or 0) },
            { label = "InventoryManager.StatConsumableInBags", value = tostring(statistics.bagQuantity or 0) },
            { label = "InventoryManager.StatConsumableInBank", value = tostring(statistics.bankQuantity or 0) },
        })

        local categories = summary.categories or {}
        local hasAnyConsumables = false

        for _, subclass in ipairs(CONSUMABLE_SUBCLASS_ORDER) do

            local bucket = categories[subclass]
            local items = bucket and bucket.items or {}

            if #items > 0 then

                hasAnyConsumables = true
                local poolKey = "Consumable" .. subclass:sub(1, 1):upper() .. subclass:sub(2) .. "Cards"

                if subclass == "itemEnhancement" then
                    poolKey = "ConsumableEnhancementCards"
                end

                local sectionTitle = self:GetConsumableSubclassLabel(subclass)

                yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.ConsumableSubclass." .. subclass, yOffset, sectionTitle)
                yOffset = self:LayoutConsumableSubclassCards(page, poolKey, yOffset, width, items, subclass)
                yOffset = Dashboard:EndSection(yOffset)

            else

                local poolKey = "Consumable" .. subclass:sub(1, 1):upper() .. subclass:sub(2) .. "Cards"

                if subclass == "itemEnhancement" then
                    poolKey = "ConsumableEnhancementCards"
                end

                AC.InventoryComponents:HideCardSection(page, poolKey, "InventoryManager.ConsumableSubclass." .. subclass, nil)

            end

        end

        if not hasAnyConsumables then

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionReadyConsumables", yOffset)
            yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "ConsumablesEmptyText", yOffset, width, "InventoryManager.ConsumablesEmpty")
            yOffset = Dashboard:EndSection(yOffset)

        end

        if #missingItems > 0 then

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionMissingConsumables", yOffset)
            yOffset = self:LayoutConsumableMissingCards(page, yOffset, width, missingItems)
            yOffset = Dashboard:EndSection(yOffset)

        else

            AC.InventoryComponents:HideCardSection(page, "ConsumableMissingCards", "InventoryManager.SectionMissingConsumables", "ConsumableMissingEmptyText")

        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:GetConsumablesStatusText()

    local page = self.Pages and self.Pages.Consumables
    local summary = page and page.ConsumableSummary or self:GetConsumableInventorySummary()
    local missing = page and page.ConsumableMissing or self:GetConsumableMissingItems()
    local statistics = summary.statistics or {}

    if not summary.enabled then
        return AC.L:Get("InventoryManager.ConsumablesDisabled")
    end

    if (statistics.itemCount or 0) == 0 and #missing == 0 then
        return AC.L:Get("InventoryManager.ConsumablesEmpty")
    end

    if #missing > 0 then
        return AC.L:Format("InventoryManager.ConsumablesFooterMissingFormat", statistics.itemCount or 0, statistics.totalQuantity or 0, #missing)
    end

    return AC.L:Format("InventoryManager.ConsumablesFooterFormat", statistics.itemCount or 0, statistics.totalQuantity or 0)

end

-------------------------------------------------------------------------------
-- Loadouts
-------------------------------------------------------------------------------

function InventoryManager:GetLoadoutService()

    if AC.LoadoutService then
        return AC.LoadoutService
    end

    if AC.Core and AC.Core.GetService then
        return AC.Core:GetService("LoadoutService")
    end

    return nil

end

function InventoryManager:GetLoadouts()

    local service = self:GetLoadoutService()

    if service and service.GetLoadouts then
        return service:GetLoadouts()
    end

    return {}

end

function InventoryManager:GetLoadoutViewState(loadout)

    local service = self:GetLoadoutService()

    if service and service.GetLoadoutViewState then
        return service:GetLoadoutViewState(loadout)
    end

    return { loadout = loadout, items = {} }

end

function InventoryManager:GetLoadoutPageState(page)

    if not page.LoadoutState then
        page.LoadoutState = {}
    end

    return page.LoadoutState

end

function InventoryManager:SetActiveLoadout(page, loadoutID)

    local state = self:GetLoadoutPageState(page)
    state.ActiveLoadoutID = loadoutID

end

function InventoryManager:GetActiveLoadout(page)

    local state = self:GetLoadoutPageState(page)
    local loadouts = self:GetLoadouts()
    local activeID = state.ActiveLoadoutID

    if activeID then
        for _, loadout in ipairs(loadouts) do
            if loadout.id == activeID then
                return loadout
            end
        end
    end

    if #loadouts > 0 then
        return loadouts[1]
    end

    return nil

end

function InventoryManager:IsBankTransferAvailable()

    local service = self:GetLoadoutService()

    if service and service.IsBankTransferAvailable then
        return service:IsBankTransferAvailable()
    end

    if IsBankFrameVisible then
        return IsBankFrameVisible() == true
    end

    return BankFrame and BankFrame:IsVisible() == true

end

function InventoryManager:WithdrawLoadout(page)

    local loadout = self:GetActiveLoadout(page)
    local service = self:GetLoadoutService()

    if not loadout or not service or not service.Withdraw then
        return false
    end

    local withdrew = service:Withdraw(loadout)

    if withdrew then
        C_Timer.After(0.2, function()
            self:RefreshCurrentPage()
        end)
    end

    return withdrew

end

function InventoryManager:DepositExtras(page)

    local loadout = self:GetActiveLoadout(page)
    local service = self:GetLoadoutService()

    if not loadout or not service or not service.Deposit then
        return false
    end

    local deposited = service:Deposit(loadout)

    if deposited then
        C_Timer.After(0.2, function()
            self:RefreshCurrentPage()
        end)
    end

    return deposited

end

function InventoryManager:BuildLoadoutsPage()

    local page = self.Pages.Loadouts
    local loadouts = self:GetLoadouts()
    local pageState = self:GetLoadoutPageState(page)

    if not pageState.ActiveLoadoutID and #loadouts > 0 then
        pageState.ActiveLoadoutID = loadouts[1].id
    end

    local activeLoadout = self:GetActiveLoadout(page)

    local function createLoadout()
        local service = page and page.LoadoutService or self:GetLoadoutService()
        local newLoadout = service and service.CreateLoadout and service:CreateLoadout()
        if newLoadout and newLoadout.id then
            self:SetActiveLoadout(page, newLoadout.id)
            self:BuildLoadoutsPage()
        end
    end

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        if page.LoadoutContent then
            page.LoadoutContent:Hide()
            page.LoadoutContent:SetParent(nil)
        end

        page.LoadoutContent = CreateFrame("Frame", nil, page.ScrollChild)
        page.LoadoutContent:SetPoint("TOPLEFT", 0, -12)
        page.LoadoutContent:SetSize(width, 1)

        local layoutOffset = -12

        local contentWidth = width - LOADOUT_LIST_WIDTH - LOADOUT_CONTENT_GAP
        local leftWidth = LOADOUT_LIST_WIDTH

        local columnsContainer = CreateFrame("Frame", nil, page.LoadoutContent)
        columnsContainer:SetPoint("TOPLEFT", 0, 0)
        columnsContainer:SetSize(width, 1)

        local listFrame = CreateFrame("Frame", nil, columnsContainer)
        listFrame:SetPoint("TOPLEFT", 0, 0)
        listFrame:SetSize(leftWidth, 1)

        local libraryTitle = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        libraryTitle:SetPoint("TOPLEFT", 12, -12)
        libraryTitle:SetText(AC.L:Get("InventoryManager.LoadoutLibraryTitle"))

        local summaryText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        summaryText:SetPoint("TOPLEFT", 12, -34)
        summaryText:SetText(#loadouts > 0 and AC.L:Format("InventoryManager.LoadoutsLibrarySummaryFormat", #loadouts) or AC.L:Get("InventoryManager.LoadoutsLibraryHint"))

        local y = 58

        for _, loadout in ipairs(loadouts) do
            local row = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
            row:SetPoint("TOPLEFT", 12, -y)
            row:SetSize(leftWidth - 24, LOADOUT_ROW_HEIGHT)
            row:SetText(loadout.name or AC.L:Get("InventoryManager.LoadoutDefaultName"))
            row:SetScript("OnClick", function()
                self:SetActiveLoadout(page, loadout.id)
                self:BuildLoadoutsPage()
            end)
            if activeLoadout and loadout.id == activeLoadout.id then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
            y = y + LOADOUT_ROW_HEIGHT + 6
        end

        local listHeight = math.max(220, 58 + math.max(#loadouts, 1) * (LOADOUT_ROW_HEIGHT + 6) + 16)
        listFrame:SetHeight(listHeight)

        local detailsFrame = CreateFrame("Frame", nil, columnsContainer)
        detailsFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", LOADOUT_CONTENT_GAP, 0)
        detailsFrame:SetSize(contentWidth, 1)

        local detailsTitle = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        detailsTitle:SetPoint("TOPLEFT", 12, -12)

        local detailsSubtitle = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        detailsSubtitle:SetPoint("TOPLEFT", 12, -34)
        detailsSubtitle:SetWidth(contentWidth - 24)

        local detailsHeight = 280

        if not activeLoadout then
            detailsTitle:SetText(AC.L:Get("InventoryManager.LoadoutsEmptyTitle"))
            detailsSubtitle:SetText(AC.L:Get("InventoryManager.LoadoutsEmptyDescription"))

            local emptyCreateButton = CreateFrame("Button", nil, detailsFrame, "UIPanelButtonTemplate")
            emptyCreateButton:SetPoint("TOPLEFT", 12, -74)
            emptyCreateButton:SetSize(180, 28)
            emptyCreateButton:SetText(AC.L:Get("InventoryManager.LoadoutsCreatePrimary"))
            emptyCreateButton:SetScript("OnClick", createLoadout)

            detailsHeight = 180
        else
            detailsTitle:SetText(activeLoadout.name or AC.L:Get("InventoryManager.LoadoutDefaultName"))
            detailsSubtitle:SetText(AC.L:Get("InventoryManager.LoadoutEditorSubtitle"))
        end

        detailsFrame:SetHeight(detailsHeight)

        local yOffset = layoutOffset

        if not activeLoadout then
            return -yOffset + Layout.PAGE_BOTTOM_PADDING
        end

        local nameLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLabel:SetPoint("TOPLEFT", 12, -74)
        nameLabel:SetText(AC.L:Get("InventoryManager.LoadoutNameLabel"))

        local nameBox = CreateFrame("EditBox", nil, detailsFrame, "InputBoxTemplate")
        nameBox:SetPoint("TOPLEFT", 12, -90)
        nameBox:SetSize(contentWidth - 24, 24)
        nameBox:SetText(activeLoadout.name or "")
        nameBox:SetAutoFocus(false)
        nameBox:SetScript("OnEnterPressed", function(editBox)
            activeLoadout.name = editBox:GetText() or ""
            editBox:ClearFocus()
            local service = self:GetLoadoutService()
            if service and service.SaveLoadout then
                service:SaveLoadout(activeLoadout)
            end
            self:BuildLoadoutsPage()
        end)

        local descriptionLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descriptionLabel:SetPoint("TOPLEFT", 12, -124)
        descriptionLabel:SetText(AC.L:Get("InventoryManager.LoadoutDescriptionLabel"))

        local descriptionBox = CreateFrame("EditBox", nil, detailsFrame, "InputBoxTemplate")
        descriptionBox:SetPoint("TOPLEFT", 12, -140)
        descriptionBox:SetSize(contentWidth - 24, 24)
        descriptionBox:SetText(activeLoadout.description or "")
        descriptionBox:SetAutoFocus(false)
        descriptionBox:SetScript("OnEnterPressed", function(editBox)
            activeLoadout.description = editBox:GetText() or ""
            editBox:ClearFocus()
            local service = self:GetLoadoutService()
            if service and service.SaveLoadout then
                service:SaveLoadout(activeLoadout)
            end
        end)

        local itemsHeader = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemsHeader:SetPoint("TOPLEFT", 12, -174)
        itemsHeader:SetText(AC.L:Get("InventoryManager.LoadoutItemsHeader"))

        local addItemButton = CreateFrame("Button", nil, detailsFrame, "UIPanelButtonTemplate")
        addItemButton:SetPoint("TOPRIGHT", -12, -170)
        addItemButton:SetSize(110, 24)
        addItemButton:SetText("+ " .. AC.L:Get("InventoryManager.LoadoutAddItemLabel"))
        addItemButton:SetScript("OnClick", function()
            page.LoadoutPickerOpen = true
            page.LoadoutPickerSearchText = ""
            self:BuildLoadoutsPage()
        end)

        local listStartY = -208
        local pickerOpen = page.LoadoutPickerOpen == true

        if pickerOpen then
            local pickerLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            pickerLabel:SetPoint("TOPLEFT", 12, listStartY)
            pickerLabel:SetText(AC.L:Get("InventoryManager.LoadoutAddItemLabel"))

            local pickerSearchBox = CreateFrame("EditBox", nil, detailsFrame, "InputBoxTemplate")
            pickerSearchBox:SetPoint("TOPLEFT", 12, listStartY - 20)
            pickerSearchBox:SetSize(contentWidth - 24, 24)
            pickerSearchBox:SetAutoFocus(false)
            pickerSearchBox:SetText(page.LoadoutPickerSearchText or "")
            pickerSearchBox:SetScript("OnTextChanged", function(editBox)
                page.LoadoutPickerSearchText = editBox:GetText() or ""
                self:BuildLoadoutsPage()
            end)

            local pickerItems = {}
            local explorerData = self:GetExplorerData()
            local searchText = (page.LoadoutPickerSearchText or ""):lower()

            for _, category in ipairs(explorerData.categories or {}) do
                for _, subclass in ipairs(category.subclasses or {}) do
                    for _, item in ipairs(subclass.items or {}) do
                        local name = (item.itemName or ""):lower()
                        local categoryName = (category.id or ""):lower()
                        local subclassName = (subclass.name or ""):lower()
                        if searchText == "" or name:find(searchText, 1, true) or categoryName:find(searchText, 1, true) or subclassName:find(searchText, 1, true) then
                            table.insert(pickerItems, { item = item, category = category, subclass = subclass })
                        end
                    end
                end
            end

            local pickerY = listStartY - 56
            local pickerEmptyText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            pickerEmptyText:SetPoint("TOPLEFT", 12, pickerY)
            pickerEmptyText:SetText(AC.L:Get("InventoryManager.SearchNoResults"))
            pickerEmptyText:Hide()

            for _, entry in ipairs(pickerItems) do
                local item = entry.item
                local name = item.itemName or AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
                local row = CreateFrame("Button", nil, detailsFrame)
                row:SetPoint("TOPLEFT", 12, pickerY)
                row:SetSize(contentWidth - 24, 28)
                row:SetScript("OnClick", function()
                    if not activeLoadout.items then
                        activeLoadout.items = {}
                    end

                    local quantity = 1
                    local entryData =
                    {
                        id = tostring(item.itemID) .. "-" .. tostring(time()),
                        itemID = item.itemID,
                        itemName = name,
                        itemLink = item.itemLink,
                        desiredQuantity = quantity,
                    }

                    table.insert(activeLoadout.items, entryData)
                    local service = self:GetLoadoutService()
                    if service and service.SaveLoadout then
                        service:SaveLoadout(activeLoadout)
                    end
                    page.LoadoutPickerOpen = false
                    page.LoadoutPickerSearchText = ""
                    self:BuildLoadoutsPage()
                end)
                row:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if item.itemLink then
                        GameTooltip:SetHyperlink(item.itemLink)
                    elseif item.itemID then
                        GameTooltip:SetItemByID(item.itemID)
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", 0, 0)
                icon:SetTexture(item.icon or (item.itemID and GetItemIcon(item.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark")

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("LEFT", 22, 0)
                label:SetText(name)

                local detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                detail:SetPoint("RIGHT", -4, 0)
                detail:SetText((entry.category and entry.category.id) or "")

                pickerY = pickerY - 32
            end

            if #pickerItems == 0 then
                pickerEmptyText:Show()
            end
        else
            local viewState = self:GetLoadoutViewState(activeLoadout)
            local rowY = listStartY

            for _, itemState in ipairs(viewState.items or {}) do
                local item = itemState.item
                local name = item.itemName or AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
                local desired = tonumber(itemState.desiredQuantity) or 0
                local bagCount = tonumber(itemState.bagCount) or 0
                local bankCount = tonumber(itemState.bankCount) or 0
                local status = itemState.status
                local statusText = itemState.statusText
                local row = CreateFrame("Frame", nil, detailsFrame, "BackdropTemplate")
                row:SetPoint("TOPLEFT", 12, rowY)
                row:SetSize(contentWidth - 24, 36)
                AC.Presentation.ApplyCardBackdrop(row)

                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", 8, 0)
                icon:SetTexture(item.icon or (item.itemID and GetItemIcon(item.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark")

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("LEFT", 30, -6)
                label:SetText(name)

                local quantityText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                quantityText:SetPoint("LEFT", 30, -20)
                quantityText:SetText(AC.L:Format("InventoryManager.LoadoutItemSummaryFormat", desired, bagCount, bankCount))

                local qtyBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                qtyBox:SetPoint("RIGHT", -70, 0)
                qtyBox:SetSize(56, 20)
                qtyBox:SetText(tostring(desired))
                qtyBox:SetAutoFocus(false)
                qtyBox:SetScript("OnEnterPressed", function(editBox)
                    local newQuantity = tonumber(editBox:GetText() or "1") or 1
                    item.desiredQuantity = newQuantity
                    local service = self:GetLoadoutService()
                    if service and service.SaveLoadout then
                        service:SaveLoadout(activeLoadout)
                    end
                    editBox:ClearFocus()
                    self:BuildLoadoutsPage()
                end)

                local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                removeButton:SetPoint("RIGHT", -8, 0)
                removeButton:SetSize(64, 20)
                removeButton:SetText(AC.L:Get("InventoryManager.LoadoutAddItemButton"))
                removeButton:SetScript("OnClick", function()
                    for index, existing in ipairs(activeLoadout.items or {}) do
                        if existing.id == item.id then
                            table.remove(activeLoadout.items, index)
                            break
                        end
                    end
                    local service = self:GetLoadoutService()
                    if service and service.SaveLoadout then
                        service:SaveLoadout(activeLoadout)
                    end
                    self:BuildLoadoutsPage()
                end)

                local statusTextString = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                statusTextString:SetPoint("RIGHT", -140, -8)
                statusTextString:SetText(statusText)
                if status == "ready" then
                    statusTextString:SetTextColor(0.2, 0.8, 0.2)
                elseif status == "bank" then
                    statusTextString:SetTextColor(0.9, 0.7, 0.2)
                else
                    statusTextString:SetTextColor(0.9, 0.2, 0.2)
                end

                rowY = rowY - 40
            end
        end

        local actionButtonRow = CreateFrame("Frame", nil, detailsFrame)
        actionButtonRow:SetPoint("TOPLEFT", 12, listStartY - 120)
        actionButtonRow:SetSize(contentWidth - 24, 24)

        local withdrawButton = CreateFrame("Button", nil, actionButtonRow, "UIPanelButtonTemplate")
        withdrawButton:SetPoint("LEFT", 0, 0)
        withdrawButton:SetSize(120, 24)
        withdrawButton:SetText(AC.L:Get("InventoryManager.LoadoutWithdrawButton"))
        withdrawButton:SetScript("OnClick", function()
            self:WithdrawLoadout(page)
        end)

        local depositButton = CreateFrame("Button", nil, actionButtonRow, "UIPanelButtonTemplate")
        depositButton:SetPoint("LEFT", withdrawButton, "RIGHT", 8, 0)
        depositButton:SetSize(120, 24)
        depositButton:SetText(AC.L:Get("InventoryManager.LoadoutDepositButton"))
        depositButton:SetScript("OnClick", function()
            self:DepositExtras(page)
        end)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:GetLoadoutsStatusText()

    local loadouts = self:GetLoadouts()

    if #loadouts == 0 then
        return AC.L:Get("InventoryManager.LoadoutsStatusEmpty")
    end

    return AC.L:Format("InventoryManager.LoadoutsStatusFormat", #loadouts)

end

-------------------------------------------------------------------------------
-- Explorer
--
-- A dedicated visual browser for all recorded storage, functioning like a
-- modern file explorer with collapsible tree sections. Unlike the Categories
-- page (which shows summary cards), Explorer reveals individual items with
-- icons, quality colors, and quantities -- supporting visual browsing without
-- requiring search.
--
-- Architecture:
--   - Reads aggregate storage through StorageModule:GetAggregateStorage()
--   - Groups items by category, then by subclass
--   - Uses lightweight tree rows (not DashboardCards) for visual hierarchy
--   - Single row pool with rebuild-from-scratch on every refresh
--   - Never calls Blizzard APIs directly
--
-- Design Philosophy (UI Polish Pass):
--   - Tree nodes are lightweight -- no card borders, no heavy backgrounds
--   - Categories and subclasses are accordion nodes with expand/collapse
--   - Items are simple rows with icon, quality-colored name, and quantity
--   - Proper indentation creates clear visual hierarchy
--   - Hover highlight provides selection feedback
-------------------------------------------------------------------------------

local EXPLORER_CATEGORY_ORDER =
{
    "Equipment",
    "Consumables",
    "Reagents",
    "TradeGoods",
    "QuestItems",
    "Mounts",
    "BattlePets",
    "Miscellaneous",
    "Unknown",
}

-- Tree row dimensions (lightweight, no card weight)
local EXPLORER_ROW_HEIGHT = 22
local EXPLORER_ROW_GAP = 2
local EXPLORER_ICON_SIZE = 16
local EXPLORER_ICON_LABEL_GAP = 6
local EXPLORER_ARROW_WIDTH = 12

-- Indentation levels for hierarchy
local EXPLORER_INDENT_CATEGORY = 8
local EXPLORER_INDENT_SUBCLASS = 24
local EXPLORER_INDENT_ITEM = 40

-- Colors
local EXPLORER_HOVER_COLOR = { 0.2, 0.3, 0.5, 0.2 }
local EXPLORER_CATEGORY_COLOR = { 1.0, 0.82, 0.0 }  -- Gold for categories
local EXPLORER_SUBCLASS_COLOR = { 0.8, 0.8, 0.8 }   -- Light gray for subclasses

-- Row version for pool invalidation (increment when row structure changes)
local EXPLORER_ROW_VERSION = 2

-- Category icons (Blizzard item icons representing each storage category)
local EXPLORER_CATEGORY_ICONS =
{
    Equipment     = "Interface\\Icons\\INV_Sword_01",
    Consumables   = "Interface\\Icons\\INV_Potion_01",
    Reagents      = "Interface\\Icons\\INV_Misc_Herb_01",
    TradeGoods    = "Interface\\Icons\\INV_Misc_Gear_01",
    QuestItems    = "Interface\\Icons\\INV_Scroll_01",
    Mounts        = "Interface\\Icons\\Ability_Mount_MechanoStrider",
    BattlePets    = "Interface\\Icons\\Spell_Nature_SpiritWolf",
    Miscellaneous = "Interface\\Icons\\INV_Misc_Bag_01",
    Unknown       = "Interface\\Icons\\INV_Misc_QuestionMark",
}

function InventoryManager:GetExplorerData()

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if not storageModule or not storageModule.GetAggregateStorage then
        return
        {
            enabled = false,
            categories = {},
            statistics = { itemCount = 0, quantity = 0, categoryCount = 0 },
            snapshotTimestamp = nil,
            freshness = "unknown",
        }
    end

    if not storageModule:IsModuleEnabled() then
        return
        {
            enabled = false,
            categories = {},
            statistics = { itemCount = 0, quantity = 0, categoryCount = 0 },
            snapshotTimestamp = nil,
            freshness = "unknown",
        }
    end

    local aggregate = storageModule:GetAggregateStorage()
    local scanStatus = storageModule:GetScanStatus()

    -- Group items by category, then by subclass
    local categoryByID = {}
    local itemCountByID = {}
    local quantityByID = {}

    for _, item in ipairs(aggregate.items or {}) do

        local category = item.category or "Unknown"
        local subclass = item.subclass or item.className or "Other"

        if not categoryByID[category] then
            categoryByID[category] =
            {
                id = category,
                subclasses = {},
                subclassByID = {},
                itemCount = 0,
                quantity = 0,
            }
        end

        local cat = categoryByID[category]

        if not cat.subclassByID[subclass] then
            cat.subclassByID[subclass] =
            {
                name = subclass,
                items = {},
                itemCount = 0,
                quantity = 0,
            }
            table.insert(cat.subclasses, cat.subclassByID[subclass])
        end

        local sub = cat.subclassByID[subclass]

        -- Aggregate by itemID within subclass
        local existingItem = nil
        for _, existing in ipairs(sub.items) do
            if existing.itemID == item.itemID then
                existingItem = existing
                break
            end
        end

        if existingItem then
            existingItem.quantity = existingItem.quantity + (item.quantity or 0)
        else
            table.insert(sub.items,
            {
                itemID = item.itemID,
                itemName = item.itemName,
                itemLink = item.itemLink,
                icon = item.icon,
                quality = item.quality,
                quantity = item.quantity or 0,
            })
            sub.itemCount = sub.itemCount + 1
            itemCountByID[item.itemID] = (itemCountByID[item.itemID] or 0) + 1
        end

        sub.quantity = sub.quantity + (item.quantity or 0)
        cat.itemCount = cat.itemCount + 1
        cat.quantity = cat.quantity + (item.quantity or 0)
        quantityByID[item.itemID] = (quantityByID[item.itemID] or 0) + (item.quantity or 0)

    end

    -- Build ordered category list
    local categories = {}
    local categoryCount = 0
    local totalItemCount = 0
    local totalQuantity = 0

    for _, categoryID in ipairs(EXPLORER_CATEGORY_ORDER) do

        local cat = categoryByID[categoryID]

        if cat then

            -- Sort subclasses alphabetically
            table.sort(cat.subclasses, function(a, b)
                return (a.name or "") < (b.name or "")
            end)

            -- Sort items within each subclass by name
            for _, sub in ipairs(cat.subclasses) do
                table.sort(sub.items, function(a, b)
                    return (a.itemName or "") < (b.itemName or "")
                end)
            end

            table.insert(categories, cat)
            categoryCount = categoryCount + 1
            totalItemCount = totalItemCount + cat.itemCount
            totalQuantity = totalQuantity + cat.quantity

        end

    end

    -- Count distinct items
    local distinctItemCount = 0
    for _ in pairs(itemCountByID) do
        distinctItemCount = distinctItemCount + 1
    end

    return
    {
        enabled = true,
        categories = categories,
        statistics =
        {
            itemCount = distinctItemCount,
            quantity = totalQuantity,
            categoryCount = categoryCount,
        },
        snapshotTimestamp = aggregate.snapshotTimestamp,
        freshness = scanStatus.freshness or "unknown",

        -- Sourced from the shared provider's own availability signal
        -- (GetAggregateStorage()'s hasStorageData), not scanStatus.hasSnapshot
        -- (StorageModule:GetScanStatus(), live-bank-only -- the exact
        -- bypass the Phase 4 architecture review found and this replaces).
        -- Explorer doesn't need to know whether that data is live or
        -- carried over from a prior login -- it just trusts the provider.
        hasSnapshot = aggregate.hasStorageData == true,
    }

end

function InventoryManager:GetExplorerHeroValue(data)

    if not data.enabled then
        return AC.L:Get("InventoryManager.ExplorerUnavailableValue")
    end

    if not data.hasSnapshot then
        return AC.L:Get("InventoryManager.ExplorerUnavailableValue")
    end

    return tostring(data.statistics.quantity or 0)

end

function InventoryManager:GetExplorerSnapshotText(data)

    if not data.hasSnapshot then
        return AC.L:Get("InventoryManager.ExplorerSnapshotNeedsScan")
    end

    if data.freshness == "current" then
        return AC.L:Get("InventoryManager.ExplorerSnapshotCurrent")
    end

    if data.snapshotTimestamp then
        return AC.L:Format("InventoryManager.ExplorerSnapshotStaleFormat", AC.Presentation.FormatDate(data.snapshotTimestamp, "shortTime"))
    end

    return AC.L:Get("InventoryManager.ExplorerSnapshotNeedsScan")

end

-------------------------------------------------------------------------------
-- Explorer Tree Row Pool
--
-- Lightweight row-based rendering for the Explorer tree. All rows (categories,
-- subclasses, and items) are drawn from a single pool and rebuilt from scratch
-- on every refresh. This ensures:
--   - No overlapping rows from stale positioning
--   - Consistent layout after expand/collapse operations
--   - Minimal visual weight (no card borders or backgrounds)
-------------------------------------------------------------------------------

function InventoryManager:EnsureExplorerRowPool(page)

    if not page.ExplorerRowPool then
        page.ExplorerRowPool = {}
    end

    return page.ExplorerRowPool

end

function InventoryManager:HideAllExplorerRows(page)

    local pool = page.ExplorerRowPool

    if not pool then
        return
    end

    for _, row in ipairs(pool) do
        -- Ensure hover background is hidden when row is hidden
        -- (OnLeave may not fire if row is hidden while mouse is over it)
        if row.HoverBg then
            row.HoverBg:Hide()
        end
        row:Hide()
    end

end

function InventoryManager:AcquireExplorerRow(page, parent, rowType)

    local pool = self:EnsureExplorerRowPool(page)

    -- Find a hidden row of the same type and version to reuse
    -- (version check ensures old Button-based rows are not reused after
    -- the migration to Frame-based rows)
    for _, row in ipairs(pool) do
        if not row:IsShown() and row.RowType == rowType and row.RowVersion == EXPLORER_ROW_VERSION then
            row.ItemID = nil
            row.ItemLink = nil
            return row
        end
    end

    -- Create a new row
    -- Use Button so the row can own click interaction while remaining visually lightweight
    -- and without any default button artwork.
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(EXPLORER_ROW_HEIGHT)
    row.RowType = rowType
    row.RowVersion = EXPLORER_ROW_VERSION
    row:EnableMouse(true)

    -- Expand/collapse arrow (for category and subclass rows)
    -- FontString with explicit width to avoid any bounding box artifacts
    local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetWidth(EXPLORER_ARROW_WIDTH)
    arrow:SetJustifyH("CENTER")
    row.Arrow = arrow

    -- Item icon (for item rows)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(EXPLORER_ICON_SIZE, EXPLORER_ICON_SIZE)
    icon:Hide()
    row.Icon = icon

    -- Label text
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    row.Label = label

    -- Quantity text (right-aligned, for item rows)
    local quantity = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    quantity:SetJustifyH("RIGHT")
    quantity:SetTextColor(0.7, 0.7, 0.7)
    row.Quantity = quantity

    -- Hover effects and Blizzard GameTooltip (active only for item rows
    -- where ItemID is set; category/subclass rows leave ItemID nil)
    -- No hover background texture - just tooltip for items
    row:SetScript("OnEnter", function(self)
        if self.ItemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.ItemLink then
                GameTooltip:SetHyperlink(self.ItemLink)
            else
                GameTooltip:SetItemByID(self.ItemID)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        if self.ItemID then
            GameTooltip:Hide()
        end
    end)

    table.insert(pool, row)

    return row

end

function InventoryManager:EnsureExplorerAccordionState(page)

    if not page.ExplorerAccordionState then
        page.ExplorerAccordionState = {}
    end

    return page.ExplorerAccordionState

end

function InventoryManager:ToggleExplorerCategory(page, categoryID)

    local state = self:EnsureExplorerAccordionState(page)
    state[categoryID] = not state[categoryID]

    if self.CurrentPage == "Explorer" then
        self:BuildExplorerPage()
    end

end

function InventoryManager:ToggleExplorerSubclass(page, categoryID, subclass)

    local state = self:EnsureExplorerAccordionState(page)
    local key = categoryID .. ":" .. subclass
    state[key] = not state[key]

    if self.CurrentPage == "Explorer" then
        self:BuildExplorerPage()
    end

end

function InventoryManager:IsExplorerCategoryExpanded(page, categoryID)

    local state = self:EnsureExplorerAccordionState(page)
    return state[categoryID] == true

end

function InventoryManager:IsExplorerSubclassExpanded(page, categoryID, subclass)

    local state = self:EnsureExplorerAccordionState(page)
    local key = categoryID .. ":" .. subclass
    return state[key] == true

end

-------------------------------------------------------------------------------
-- Explorer Tree Row Layout
--
-- Each row type (category, subclass, item) has specific layout:
--   Category: [>/v] CategoryName                    (gold text, bold)
--   Subclass:     [>/v] SubclassName (count)        (gray text)
--   Item:             [icon] ItemName        xCount  (quality color)
-------------------------------------------------------------------------------

function InventoryManager:LayoutExplorerCategoryRow(page, parent, category, yOffset, width)

    local self_ref = self
    local expanded = self:IsExplorerCategoryExpanded(page, category.id)
    local row = self:AcquireExplorerRow(page, parent, "category")

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", EXPLORER_INDENT_CATEGORY, yOffset)
    row:SetWidth(width - EXPLORER_INDENT_CATEGORY - Layout.ROW_INDENT)
    row:SetHeight(EXPLORER_ROW_HEIGHT)

    -- Arrow
    row.Arrow:ClearAllPoints()
    row.Arrow:SetPoint("LEFT", 0, 0)
    row.Arrow:SetText(expanded and "v" or ">")  -- v for expanded, > for collapsed
    row.Arrow:SetTextColor(unpack(EXPLORER_CATEGORY_COLOR))
    row.Arrow:Show()

    -- Category icon (16x16, Blizzard texture, between arrow and label)
    local categoryIcon = EXPLORER_CATEGORY_ICONS[category.id]
    if categoryIcon then
        row.Icon:ClearAllPoints()
        row.Icon:SetPoint("LEFT", EXPLORER_ARROW_WIDTH + 4, 0)
        row.Icon:SetSize(EXPLORER_ICON_SIZE, EXPLORER_ICON_SIZE)
        row.Icon:SetTexture(categoryIcon)
        row.Icon:Show()
    else
        row.Icon:Hide()
    end

    -- Label
    local categoryLabel = AC.L:Get(STORAGE_CATEGORY_LABELS[category.id] or "InventoryManager.CategoryUnknown")
    row.Label:ClearAllPoints()
    row.Label:SetPoint("LEFT", EXPLORER_ARROW_WIDTH + 4 + EXPLORER_ICON_SIZE + 4, 0)
    row.Label:SetPoint("RIGHT", -60, 0)
    row.Label:SetText(categoryLabel)
    row.Label:SetTextColor(unpack(EXPLORER_CATEGORY_COLOR))
    row.Label:SetFontObject("GameFontNormal")

    -- Quantity shows item count
    row.Quantity:ClearAllPoints()
    row.Quantity:SetPoint("RIGHT", -4, 0)
    row.Quantity:SetWidth(56)
    row.Quantity:SetText(AC.L:Format("InventoryManager.ExplorerItemCountFormat", category.itemCount or 0))
    row.Quantity:SetTextColor(0.6, 0.6, 0.6)
    row.Quantity:Show()

    -- Click handler
    row:SetScript("OnClick", function()
        self_ref:ToggleExplorerCategory(page, category.id)
    end)

    row:Show()

    return yOffset - EXPLORER_ROW_HEIGHT - EXPLORER_ROW_GAP

end

function InventoryManager:LayoutExplorerSubclassRow(page, parent, categoryID, subclass, yOffset, width)

    local self_ref = self
    local expanded = self:IsExplorerSubclassExpanded(page, categoryID, subclass.name)
    local row = self:AcquireExplorerRow(page, parent, "subclass")

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", EXPLORER_INDENT_SUBCLASS, yOffset)
    row:SetWidth(width - EXPLORER_INDENT_SUBCLASS - Layout.ROW_INDENT)
    row:SetHeight(EXPLORER_ROW_HEIGHT)

    -- Arrow
    row.Arrow:ClearAllPoints()
    row.Arrow:SetPoint("LEFT", 0, 0)
    row.Arrow:SetText(expanded and "v" or ">")  -- v for expanded, > for collapsed
    row.Arrow:SetTextColor(unpack(EXPLORER_SUBCLASS_COLOR))
    row.Arrow:Show()

    -- Icon hidden for subclasses
    row.Icon:Hide()

    -- Label
    row.Label:ClearAllPoints()
    row.Label:SetPoint("LEFT", EXPLORER_ARROW_WIDTH + 4, 0)
    row.Label:SetPoint("RIGHT", -60, 0)
    row.Label:SetText(AC.L:Format("InventoryManager.ExplorerSubclassFormat", subclass.name or "Other", subclass.itemCount or 0))
    row.Label:SetTextColor(unpack(EXPLORER_SUBCLASS_COLOR))
    row.Label:SetFontObject("GameFontNormalSmall")

    -- Quantity hidden for subclasses (count is in label)
    row.Quantity:Hide()

    -- Click handler
    row:SetScript("OnClick", function()
        self_ref:ToggleExplorerSubclass(page, categoryID, subclass.name)
    end)

    row:Show()

    return yOffset - EXPLORER_ROW_HEIGHT - EXPLORER_ROW_GAP

end

function InventoryManager:LayoutExplorerItemRow(page, parent, item, yOffset, width)

    local row = self:AcquireExplorerRow(page, parent, "item")

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", EXPLORER_INDENT_ITEM, yOffset)
    row:SetWidth(width - EXPLORER_INDENT_ITEM - Layout.ROW_INDENT)
    row:SetHeight(EXPLORER_ROW_HEIGHT)

    -- Arrow hidden for items
    row.Arrow:Hide()

    -- Icon
    row.Icon:ClearAllPoints()
    row.Icon:SetPoint("LEFT", 0, 0)
    if item.icon then
        row.Icon:SetTexture(item.icon)
        row.Icon:Show()
    else
        row.Icon:Hide()
    end

    -- Label with quality color
    local name = item.itemName
    if not name or name == "" then
        name = AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
    end

    row.Label:ClearAllPoints()
    row.Label:SetPoint("LEFT", EXPLORER_ICON_SIZE + EXPLORER_ICON_LABEL_GAP, 0)
    row.Label:SetPoint("RIGHT", -60, 0)
    row.Label:SetText(name)
    row.Label:SetFontObject("GameFontNormalSmall")

    -- Apply quality color
    if item.quality and item.quality > 0 then
        local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
        if qualityColor then
            row.Label:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
        else
            row.Label:SetTextColor(1, 1, 1)
        end
    else
        row.Label:SetTextColor(1, 1, 1)
    end

    -- Quantity
    row.Quantity:ClearAllPoints()
    row.Quantity:SetPoint("RIGHT", -4, 0)
    row.Quantity:SetWidth(56)
    row.Quantity:SetText("x" .. (item.quantity or 0))
    row.Quantity:SetTextColor(0.7, 0.7, 0.7)
    row.Quantity:Show()

    -- Store item reference for Blizzard GameTooltip (set in OnEnter/OnLeave)
    row.ItemID = item.itemID
    row.ItemLink = item.itemLink

    -- No click handler for items
    row:SetScript("OnClick", nil)

    row:Show()

    return yOffset - EXPLORER_ROW_HEIGHT - EXPLORER_ROW_GAP

end

function InventoryManager:BuildExplorerPage()

    local page = self.Pages.Explorer
    local data = self:GetExplorerData()

    page.ExplorerData = data

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        -- Hide all existing rows first (rebuild from scratch)
        self:HideAllExplorerRows(page)

        local yOffset = self:BeginPageHero(
            page,
            "InventoryManager.ExplorerHeroTitle",
            "InventoryManager.ExplorerHeroCaption",
            self:GetExplorerHeroValue(data)
        )

        if not data.enabled then

            yOffset = Dashboard:AppendStatisticsSection(
                page,
                "ExplorerSummary",
                "InventoryManager.SectionCategories",
                yOffset,
                {},
                "InventoryManager.ExplorerDisabled"
            )

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        if not data.hasSnapshot then

            yOffset = Dashboard:AppendStatisticsSection(
                page,
                "ExplorerSummary",
                "InventoryManager.SectionCategories",
                yOffset,
                {},
                "InventoryManager.ExplorerNeedsScan"
            )

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        local statistics = data.statistics or {}
        local snapshotText = self:GetExplorerSnapshotText(data)

        yOffset = Dashboard:LayoutStatisticsGrid(page, "ExplorerHeroStats", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatCategories", value = tostring(statistics.categoryCount or 0) },
            { label = "InventoryManager.StatAggregateItemTypes", value = tostring(statistics.itemCount or 0) },
            { label = "InventoryManager.StatAggregateStacks", value = tostring(statistics.quantity or 0) },
            { label = "InventoryManager.StatLastScan", value = snapshotText },
        })

        if #data.categories == 0 then

            yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.SectionCategories", yOffset)
            yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "ExplorerEmptyText", yOffset, width, "InventoryManager.ExplorerEmpty")
            yOffset = Dashboard:EndSection(yOffset)

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        -- Render tree: categories -> subclasses -> items
        for _, category in ipairs(data.categories) do

            yOffset = self:LayoutExplorerCategoryRow(page, page.ScrollChild, category, yOffset, width)

            if self:IsExplorerCategoryExpanded(page, category.id) then

                for _, subclass in ipairs(category.subclasses) do

                    yOffset = self:LayoutExplorerSubclassRow(page, page.ScrollChild, category.id, subclass, yOffset, width)

                    if self:IsExplorerSubclassExpanded(page, category.id, subclass.name) then

                        for _, item in ipairs(subclass.items) do
                            yOffset = self:LayoutExplorerItemRow(page, page.ScrollChild, item, yOffset, width)
                        end

                    end

                end

            end

        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

function InventoryManager:GetExplorerStatusText()

    local page = self.Pages and self.Pages.Explorer
    local data = page and page.ExplorerData or self:GetExplorerData()
    local statistics = data.statistics or {}

    if not data.enabled then
        return AC.L:Get("InventoryManager.ExplorerDisabled")
    end

    if not data.hasSnapshot then
        return AC.L:Get("InventoryManager.ExplorerNeedsScan")
    end

    if data.freshness == "current" then
        return AC.L:Format("InventoryManager.ExplorerFooterFormat", statistics.categoryCount or 0, statistics.itemCount or 0, statistics.quantity or 0)
    end

    local snapshotText = data.snapshotTimestamp and AC.Presentation.FormatDate(data.snapshotTimestamp, "shortTime") or AC.L:Get("Common.Unknown")

    return AC.L:Format("InventoryManager.ExplorerFooterStaleFormat", statistics.categoryCount or 0, statistics.itemCount or 0, statistics.quantity or 0, snapshotText)

end

-------------------------------------------------------------------------------
-- Planned pages
-------------------------------------------------------------------------------

function InventoryManager:BuildPlaceholderPage(pageName)

    local definition = PAGE_BY_ID[pageName]
    local page = definition and self.Pages[pageName]

    if not definition or not page then
        return
    end

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local yOffset = self:BeginPageHero(page, definition.label, "InventoryManager.PageCaption")

        yOffset = Dashboard:BeginSection(page.ScrollChild, "InventoryManager.PlannedSection", yOffset)
        yOffset = Dashboard:ShowEmptyLine(page, page.ScrollChild, "PlannedText", yOffset, width, definition.placeholder)
        yOffset = Dashboard:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end)

end

-------------------------------------------------------------------------------
-- Navigation / scan / lifecycle
-------------------------------------------------------------------------------

function InventoryManager:RefreshPage(pageName)

    if pageName == "Overview" then
        self:BuildOverviewPage()
    elseif pageName == "Categories" then
        self:BuildCategoriesPage()
    elseif pageName == "Explorer" then
        self:BuildExplorerPage()
    elseif pageName == "Search" then
        self:BuildSearchPage()
    elseif pageName == "ShoppingList" then
        self:BuildShoppingListPage()
    elseif pageName == "Consumables" then
        self:BuildConsumablesPage()
    elseif pageName == "Loadouts" then
        self:BuildLoadoutsPage()
    else
        self:BuildPlaceholderPage(pageName)
    end

end

function InventoryManager:RefreshCurrentPage()

    if self.CurrentPage then
        self:RefreshPage(self.CurrentPage)
        self:UpdateFooterStatus()
    end

end

function InventoryManager:ShowPage(pageName)

    if not self.Pages[pageName] then
        return
    end

    for name, page in pairs(self.Pages) do
        page:SetShown(name == pageName)
    end

    for name, button in pairs(self.NavigationButtons) do
        button:SetEnabled(name ~= pageName)
    end

    self.CurrentPage = pageName
    self:RefreshPage(pageName)
    self.Pages[pageName].ScrollFrame:SetVerticalScroll(0)
    self:UpdateFooterStatus()

end

function InventoryManager:SetStatusText(text)

    if self.StatusText then
        self.StatusText:SetText(text or "")
    end

end

function InventoryManager:UpdateFooterStatus()

    if self.CurrentPage == "Categories" then
        self:SetStatusText(self:GetCategoriesStatusText())
        return
    end

    if self.CurrentPage == "Explorer" then
        self:SetStatusText(self:GetExplorerStatusText())
        return
    end

    if self.CurrentPage == "Search" then
        self:SetStatusText(self:GetSearchStatusText())
        return
    end

    if self.CurrentPage == "ShoppingList" then
        self:SetStatusText(self:GetShoppingListStatusText())
        return
    end

    if self.CurrentPage == "Consumables" then
        self:SetStatusText(self:GetConsumablesStatusText())
        return
    end

    if self.CurrentPage == "Loadouts" then
        self:SetStatusText(self:GetLoadoutsStatusText())
        return
    end

    local context = self:GetStorageContext()

    self:SetStatusText(self:GetScanStatusText(context))

end

function InventoryManager:RequestInventoryScan()

    local context = self:GetStorageContext()
    local storageModule = context.storageModule

    if not storageModule or not storageModule.RefreshStorage then
        self:SetStatusText(AC.L:Get("InventoryManager.ScanUnavailable"))
        return
    end

    local result = storageModule:RefreshStorage()

    if not result or not result.success then

        if result and result.reason == "disabled" then
            self:SetStatusText(AC.L:Get("InventoryManager.StorageDisabled"))
        else
            self:SetStatusText(self:GetScanStatusText(self:GetStorageContext()))
        end

        return

    end

    self:SetStatusText(AC.L:Get("InventoryManager.ScanComplete"))

end

function InventoryManager:OnSettingsChanged(moduleName)

    if moduleName ~= "Storage" then
        return
    end

    self.SearchFilterInfo = nil
    self.SearchResultDirty = true

    if self.Frame and self.Frame:IsShown() then
        self:RefreshCurrentPage()
    end

end

function InventoryManager:OnStorageScanUpdated()

    self.SearchFilterInfo = nil
    self.SearchResultDirty = true

    if self.Frame and self.Frame:IsShown() then
        self:RefreshCurrentPage()
    end

end

function InventoryManager:Initialize()

    self.CurrentPage = "Overview"
    self:GetSearchState()
    self.Frame = self:Create()

end

function InventoryManager:Enable()

    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")
    AC.Events:Register("STORAGE_SCAN_UPDATED", self, "OnStorageScanUpdated")

end

function InventoryManager:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

    self:Hide()

end

function InventoryManager:Shutdown()

    self:Disable()

    if self.ScanButton and AC.WidgetManager then
        AC.WidgetManager:Destroy(self.ScanButton)
        self.ScanButton = nil
    end

    if AC.WidgetManager then

        for _, widget in ipairs(self.SearchWidgets or {}) do
            AC.WidgetManager:Destroy(widget)
        end

    end

    self.SearchWidgets = nil

end

function InventoryManager:Show()

    self:EnsureScanButton()
    self.Frame:Show()
    self:ShowPage(self.CurrentPage or "Overview")

end

function InventoryManager:Hide()

    if self.Frame then
        self.Frame:Hide()
    end

end

function InventoryManager:Toggle()

    if self.Frame and self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end

end

AC.Core:RegisterModule("InventoryManager", InventoryManager)

return InventoryManager
