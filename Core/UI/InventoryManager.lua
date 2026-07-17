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

local PAGE_DEFINITIONS =
{
    { id = "Overview", label = "InventoryManager.NavOverview" },
    { id = "Categories", label = "InventoryManager.NavCategories" },
    { id = "Search", label = "InventoryManager.NavSearch" },
    { id = "Transfers", label = "InventoryManager.NavTransfers", placeholder = "InventoryManager.TransfersPlanned" },
    { id = "ShoppingList", label = "InventoryManager.NavShoppingList" },
    { id = "Consumables", label = "InventoryManager.NavConsumables", placeholder = "InventoryManager.ConsumablesPlanned" },
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

    return
    {
        storageModule = storageModule,
        enabled = enabled == true,
        profile = profile,
        scanStatus = scanStatus or { state = "unknown", freshness = "unknown", hasSnapshot = false, available = false },
        lastScan = lastScan,
        sources = sources,
        readiness = readiness,
    }

end

function InventoryManager:GetReadiness(context)

    if not context.enabled or not context.readiness or context.readiness.state ~= "known" then
        return AC.L:Get("Common.Unknown")
    end

    if context.readiness.ready then
        return AC.L:Get("InventoryManager.Ready")
    end

    return AC.L:Format("InventoryManager.ReadinessFormat", context.readiness.readinessPercent or 0)

end

function InventoryManager:GetSourceSummary(context)

    if not context.scanStatus.hasSnapshot then
        return AC.L:Get("Common.Unknown")
    end

    local available = 0

    for _, source in ipairs(context.sources) do
        if source.available then
            available = available + 1
        end
    end

    return AC.L:Format("InventoryManager.SourceCountFormat", available, #context.sources)

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
    local readinessText = self:GetReadiness(context)
    local lastScanText = context.lastScan and AC.Presentation.FormatDate(context.lastScan.timestamp, "shortTime") or AC.L:Get("InventoryManager.LastScanUnknown")
    local insights = {}

    if context.scanStatus.hasSnapshot and context.storageModule and context.storageModule.GetInsights then
        insights = context.storageModule:GetInsights()
    end

    self:LayoutPage(page, function(width)

        page.ContentWidth = width

        local yOffset = self:BeginPageHero(page, "InventoryManager.Title", "InventoryManager.Description", readinessText)
        local profileText = context.profile and AC.L:Get(context.profile.label) or AC.L:Get("Storage.NoProfileSelected")
        local sourceText = self:GetSourceSummary(context)
        local itemsText = context.lastScan and tostring(context.lastScan.distinctItems or 0) or AC.L:Get("Common.Unknown")

        yOffset = Dashboard:LayoutStatisticsGrid(page, "OverviewHeroStats", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatCurrentProfile", value = profileText },
            { label = "InventoryManager.StatLastScan", value = lastScanText },
            { label = "InventoryManager.StatSourcesAvailable", value = sourceText },
            { label = "InventoryManager.StatItemsScanned", value = itemsText },
        })

        if context.scanStatus.hasSnapshot then
            self:HideNoScan(page)
        else
            yOffset = self:AppendNoScan(page, yOffset)
            self:HideTextSection(page, "StorageSources", "InventoryManager.SectionStorageSources")
            self:HideTextSection(page, "StorageRecommendations", "InventoryManager.SectionRecommendations")
        end

        local sourceLines = {}

        for _, source in ipairs(context.sources) do

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

        if context.scanStatus.hasSnapshot then

            yOffset = Dashboard:AppendTextSection(page, "StorageSources", "InventoryManager.SectionStorageSources", yOffset, sourceLines, "InventoryManager.NoSources", function(line)
                return line
            end)

            yOffset = Dashboard:AppendTextSection(page, "StorageRecommendations", "InventoryManager.SectionRecommendations", yOffset, insights, "Weekly.NoRecommendations", function(insight)
                return insight.description or insight.title or AC.L:Get("Common.Unknown")
            end)

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

    page.CategoryCards = page.CategoryCards or {}

    if #categories == 0 then

        for _, card in ipairs(page.CategoryCards) do
            card:Hide()
        end

        return Dashboard:ShowEmptyLine(page, page.ScrollChild, "CategoriesEmptyText", yOffset, width, "InventoryManager.CategoriesEmpty")

    end

    if page.CategoriesEmptyText then
        page.CategoriesEmptyText:Hide()
    end

    local cardWidth = width - (Layout.ROW_INDENT * 2)

    for index, category in ipairs(categories) do

        local card = page.CategoryCards[index]

        if not card then
            card = AC.DashboardCard:Create(page.ScrollChild, "", { width = cardWidth, height = 84 })
            page.CategoryCards[index] = card
        end

        card:SetWidth(cardWidth)
        card:SetTitle(AC.L:Get(STORAGE_CATEGORY_LABELS[category.id] or "InventoryManager.CategoryUnknown"))
        card:SetPrimaryValue(AC.L:Format("InventoryManager.CategoryItemCountFormat", category.itemCount or 0))
        card:SetSecondaryText(AC.L:Format("InventoryManager.CategoryStackCountFormat", category.quantity or 0, category.stackCount or 0))
        card:SetDetailText(self:FormatCategoryLocations(category))
        card:SetStatus(nil, "")
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        card:Show()

        yOffset = yOffset - card:GetHeight() - Layout.HOME_SECTION_GAP

    end

    for index = #categories + 1, #page.CategoryCards do
        page.CategoryCards[index]:Hide()
    end

    return yOffset

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

    for _, card in ipairs(page.SearchResultCards or {}) do
        card:Hide()
    end

    local headers = page.ScrollChild and page.ScrollChild.SectionHeaders

    if headers and headers["InventoryManager.SectionSearchResults"] then
        headers["InventoryManager.SectionSearchResults"]:Hide()
    end

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

    page.SearchResultCards = page.SearchResultCards or {}

    local cardWidth = width - (Layout.ROW_INDENT * 2)

    for index, item in ipairs(items) do

        local card = page.SearchResultCards[index]

        if not card then
            card = AC.DashboardCard:Create(page.ScrollChild, "", { width = cardWidth, height = SEARCH_RESULT_CARD_HEIGHT })
            page.SearchResultCards[index] = card
        end

        local title = item.itemName

        if not title or title == "" then
            title = AC.L:Format("InventoryManager.SearchUnknownItemFormat", item.itemID or 0)
        end

        local category = AC.L:Get(STORAGE_CATEGORY_LABELS[item.category] or "InventoryManager.CategoryUnknown")
        local source = AC.L:Get(STORAGE_SOURCE_LABELS[item.storageSource] or "Common.Unknown")
        local status, statusText = self:GetSearchResultFreshness(item)

        card:SetWidth(cardWidth)
        card:SetIcon(item.icon)
        card:SetTitle(title)
        card:SetPrimaryValue(AC.L:Format("InventoryManager.SearchQuantityFormat", item.quantity or 0))
        card:SetSecondaryText(AC.L:Format("InventoryManager.SearchResultContextFormat", category, source, item.stackCount or 0))
        card:SetDetailText(self:GetSearchResultOwnerText(item))
        card:SetStatus(status, statusText)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        card:Show()

        yOffset = yOffset - card:GetHeight() - Layout.HOME_SECTION_GAP

    end

    for index = #items + 1, #page.SearchResultCards do
        page.SearchResultCards[index]:Hide()
    end

    return yOffset

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

function InventoryManager:HideShoppingCardSection(page, poolKey, titleKey, emptyKey)

    for _, card in ipairs(page[poolKey] or {}) do
        card:Hide()
    end

    if page[emptyKey] then
        page[emptyKey]:Hide()
    end

    local headers = page.ScrollChild and page.ScrollChild.SectionHeaders

    if headers and headers[titleKey] then
        headers[titleKey]:Hide()
    end

end

function InventoryManager:LayoutShoppingCards(page, poolKey, emptyKey, yOffset, width, entries, entryType, emptyTextKey)

    page[poolKey] = page[poolKey] or {}

    if #entries == 0 then

        for _, card in ipairs(page[poolKey]) do
            card:Hide()
        end

        return Dashboard:ShowEmptyLine(page, page.ScrollChild, emptyKey, yOffset, width, emptyTextKey)

    end

    if page[emptyKey] then
        page[emptyKey]:Hide()
    end

    local cardWidth = width - (Layout.ROW_INDENT * 2)

    for index, entry in ipairs(entries) do

        local card = page[poolKey][index]

        if not card then
            card = AC.DashboardCard:Create(page.ScrollChild, "", { width = cardWidth, height = SHOPPING_CARD_HEIGHT })
            page[poolKey][index] = card
        end

        local missing = entryType == "missing"
        local icon = missing and entry.items and #entry.items == 1 and entry.items[1].icon or nil

        card:SetWidth(cardWidth)
        card:SetIcon(icon)
        card:SetTitle(AC.L:Get(entry.label or "Common.Unknown"))
        card:SetPrimaryValue(AC.L:Format(missing and "Storage.ShoppingListNeedFormat" or "Storage.AmountWithdrawFormat", entry.amount or 0))
        card:SetSecondaryText(AC.L:Get(missing and "InventoryManager.ShoppingMissingContext" or "InventoryManager.ShoppingAvailableContext"))
        card:SetDetailText(missing and self:FormatShoppingHeldItems(entry) or "")
        card:SetStatus(missing and "Important" or "Warning", AC.L:Get(missing and "InventoryManager.ShoppingMissingStatus" or "InventoryManager.ShoppingAvailableStatus"))
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        card:Show()

        yOffset = yOffset - card:GetHeight() - Layout.HOME_SECTION_GAP

    end

    for index = #entries + 1, #page[poolKey] do
        page[poolKey][index]:Hide()
    end

    return yOffset

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

            self:HideShoppingCardSection(page, "ShoppingMissingCards", "InventoryManager.SectionShoppingMissing", "ShoppingMissingEmptyText")
            self:HideShoppingCardSection(page, "ShoppingAvailableCards", "InventoryManager.SectionShoppingAvailable", "ShoppingAvailableEmptyText")

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
            self:HideShoppingCardSection(page, "ShoppingAvailableCards", "InventoryManager.SectionShoppingAvailable", "ShoppingAvailableEmptyText")
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
    elseif pageName == "Search" then
        self:BuildSearchPage()
    elseif pageName == "ShoppingList" then
        self:BuildShoppingListPage()
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

    if self.CurrentPage == "Search" then
        self:SetStatusText(self:GetSearchStatusText())
        return
    end

    if self.CurrentPage == "ShoppingList" then
        self:SetStatusText(self:GetShoppingListStatusText())
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
