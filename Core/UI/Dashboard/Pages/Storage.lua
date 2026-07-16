-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Storage (Supply Manager)
--
-- "Do I have everything I need to play?" -- Supply Health answers that in
-- one sentence at the top; every section below explains why. Everything
-- here is driven by the active storage profile (switched via the
-- dropdown on this page, not just Settings) -- switching it recomputes
-- Supply Health, Bank Transfers, Shopping List, and Storage Insights
-- immediately. Consumables is the one section that does NOT re-scope
-- with the profile (your bags don't change because you switched
-- profiles) -- it's the definitive bag+bank supply list, full stop.
--
-- Storage Insights only -- no "Recommendations" mini-section. General
-- gameplay advice (e.g. "Complete Your Keystone") belongs on the
-- Recommendations page; this page reads AC.InsightEngine directly for
-- Storage-tagged insights only, not the combined
-- GetCategorizedRecommendationsAndInsights every other page uses.
--
-- Also owns the Storage Execute confirmation flow (StaticPopupDialogs +
-- ShowExecuteResult), unchanged from before this pass.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat

-------------------------------------------------------------------------------
-- Category Display Labels
--
-- AC.ItemClassification:ClassifyConsumable's own return strings
-- ("potion"/"flask"/"food"/"itemEnhancement"/"healthstone") are internal
-- keys, not display text -- Dashboard owns presentation, so the label
-- lookup lives here, not in StorageModule.
-------------------------------------------------------------------------------

local CATEGORY_DISPLAY_ORDER = { "potion", "flask", "food", "itemEnhancement", "healthstone" }

local function GetCategoryLabel(categoryKey)

    return AC.L:Get("Storage.Category." .. categoryKey)

end

-------------------------------------------------------------------------------
-- Supply Health Icons (UI Polish Pass)
--
-- Replaces the Unicode CHECK_GLYPH/WARNING_GLYPH/CROSS_GLYPH characters
-- Supply Health previously prefixed onto its verdict sentence. Those
-- glyphs were never live-confirmed (VerificationService's own registry
-- already flags "presentation.unverifiedGlyphs" as NEEDS_LIVE), and this
-- codebase has an established, CONFIRMED pattern of exactly this failure:
-- Unicode outside Latin/WGL4 (Geometric Shapes ▶/▼/▲, Miscellaneous
-- Symbols ★) rendering as missing-character boxes in Blizzard's client
-- font. Rather than fall back to another ASCII substitute (acceptable for
-- small inline indicators like DISCLOSURE_*/TREND_ARROWS, but this is the
-- page's single hero verdict line), these three states reuse Blizzard's
-- own Ready Check icon set (Interface\RaidFrame\ReadyCheck-*) --
-- standalone textures, not font glyphs, so there is no font-coverage risk
-- at all, and every player already recognizes this exact green
-- check/red X/amber-waiting visual language from raid ready checks. Only
-- Storage's Supply Health reads this table (single caller), so it stays
-- page-local rather than promoted to Presentation.lua.
-------------------------------------------------------------------------------

local SUPPLY_HEALTH_ICONS =
{
    ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
    waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
    notReady = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

local SUPPLY_HEALTH_ICON_SIZE = 20
local SUPPLY_HEALTH_ICON_GAP = 6

-- Supply Forecast's own low-runs-remaining marker used the same
-- unverified WARNING_GLYPH, appended into a LayoutStatisticsGrid value
-- string (a plain FontString, no icon slot) -- an icon texture isn't an
-- option here without extending that shared grid, so this follows the
-- addon's other established ASCII-fallback precedent instead (DISCLOSURE_*/
-- TREND_ARROWS in Format.lua), not a new convention.
local LOW_SUPPLY_MARKER = "|cffe6b800!|r"

-------------------------------------------------------------------------------
-- Storage Execute Confirmation
--
-- StaticPopupDialogs is Blizzard's own long-standing confirmation-dialog
-- system -- the one piece of this feature with high confidence against a
-- live client, unlike the item-movement calls it gates. The player must
-- explicitly click "Move Items" every time; nothing here ever executes
-- without this dialog appearing first ("player always remains in
-- control").
-------------------------------------------------------------------------------

StaticPopupDialogs["AZEROTHCOMPANION_STORAGE_EXECUTE"] =
{
    text = "",
    button1 = _G.YES or "Move Items",
    button2 = _G.CANCEL or "Cancel",
    OnAccept = function(self)

        local storageModule = AC.Core and AC.Core:GetModule("Storage")

        if not storageModule or not self.data then
            return
        end

        local result = storageModule:ExecutePreparation(self.data)

        Dashboard:ShowExecuteResult(result)
        Dashboard:UpdateStoragePage(Dashboard.Frame)

    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Dashboard:ShowExecuteResult(result)

    if not result then
        return
    end

    if not result.success then

        local reasonKey = "Dashboard.ExecuteFailedGeneric"

        if result.reason == "combat" then
            reasonKey = "Dashboard.ExecuteFailedCombat"
        elseif result.reason == "bank_closed" then
            reasonKey = "Dashboard.ExecuteFailedBankClosed"
        end

        if AC.Logger then
            AC.Logger:Error(AC.L:Get(reasonKey))
        end

        return

    end

    if AC.Logger then
        AC.Logger:Info(AC.L:Format("Dashboard.ExecuteResultFormat", result.withdrawn or 0, result.deposited or 0))
    end

end

-------------------------------------------------------------------------------
-- Consumables Accordion -- category (collapsed) expands to every tracked
-- item (icon/name/bag count/bank count/total). Reuses the shared
-- LayoutAccordionRows engine (Rows.lua -- the same one Accomplishments/
-- Journey/MythicPlus history already use) for the category-level
-- expand/collapse; the item-level rows are this page's own bespoke
-- content (icons aren't something the generic accordion detail-field
-- helper renders), pooled per accordion row exactly like
-- LayoutContributingModules pools its own buttons in
-- Pages/RecommendationDetails.lua.
-------------------------------------------------------------------------------

local function BuildConsumableCategoryRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)
    row.Background = background

    row:SetScript("OnEnter", function(self) self.Background:SetColorTexture(1, 1, 1, 0.06) end)
    row:SetScript("OnLeave", function(self) self.Background:SetColorTexture(1, 1, 1, 0) end)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetJustifyH("LEFT")
    Format.SetHighlightColor(nameText)
    row.NameText = nameText

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetJustifyH("RIGHT")
    row.CountText = countText

    return row

end

local function LayoutConsumableCollapsed(row, record, width)

    local baseX = Layout.ACCORDION_DISCLOSURE_WIDTH + Layout.ROW_INDENT
    local countWidth = 170

    row.NameText:ClearAllPoints()
    row.NameText:SetPoint("TOPLEFT", baseX, 0)
    row.NameText:SetWidth(width - baseX - countWidth)
    row.NameText:SetText(GetCategoryLabel(record.key))

    row.CountText:ClearAllPoints()
    row.CountText:SetPoint("TOPRIGHT", 0, 0)
    row.CountText:SetWidth(countWidth)
    row.CountText:SetJustifyH("RIGHT")
    row.CountText:SetText(AC.L:Format("Storage.ConsumableCountFormat", record.bucket.categoryTotal, record.bucket.categoryBagTotal, record.bucket.categoryBankTotal))

    return math.max(row.NameText:GetStringHeight() or Layout.ROW_HEIGHT, Layout.ROW_HEIGHT)

end

local function BuildConsumableItemRow(parent)

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    row.Icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetJustifyH("LEFT")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    row.NameText = nameText

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetJustifyH("RIGHT")
    countText:SetPoint("RIGHT", 0, 0)
    row.CountText = countText

    return row

end

local CONSUMABLE_ITEM_COUNT_WIDTH = 130

local function BuildConsumablesDetail(row, record, width, detailYOffset)

    row.ItemRows = row.ItemRows or {}

    local baseX = Layout.ACCORDION_DETAIL_INDENT
    local rowWidth = width - baseX
    local yOffset = detailYOffset

    for index, item in ipairs(record.bucket.items) do

        local itemRow = row.ItemRows[index]

        if not itemRow then
            itemRow = BuildConsumableItemRow(row)
            row.ItemRows[index] = itemRow
        end

        itemRow:ClearAllPoints()
        itemRow:SetPoint("TOPLEFT", baseX, yOffset)
        itemRow:SetWidth(rowWidth)

        itemRow.Icon:SetTexture(item.icon)

        itemRow.NameText:SetWidth(rowWidth - 16 - 4 - CONSUMABLE_ITEM_COUNT_WIDTH)
        itemRow.NameText:SetText(item.name)

        itemRow.CountText:SetWidth(CONSUMABLE_ITEM_COUNT_WIDTH)
        itemRow.CountText:SetText(AC.L:Format("Storage.ConsumableCountFormat", item.totalCount, item.bagCount, item.bankCount))

        itemRow:Show()

        yOffset = yOffset - 18

    end

    for index = #record.bucket.items + 1, #row.ItemRows do
        row.ItemRows[index]:Hide()
    end

    return detailYOffset - yOffset

end

local function HideConsumablesDetail(row)

    if row.ItemRows then
        for _, itemRow in ipairs(row.ItemRows) do
            itemRow:Hide()
        end
    end

end

-------------------------------------------------------------------------------
-- Profile Switcher -- on-page, per your explicit direction (editing/
-- creating/deleting profiles stays in Settings; this is the everyday
-- quick-switch). Built directly on WowStyle1DropdownTemplate -- the same
-- Blizzard building block AC.Widgets.Dropdown already wraps for the
-- Settings window -- rather than going through the full Widget/
-- WidgetManager framework that's built specifically for Settings pages.
-------------------------------------------------------------------------------

local function BuildProfileDropdown(page, parent)

    if page.ProfileDropdown then
        return page.ProfileDropdown
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 22)

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", frame, "LEFT", 0, 0)
    dropdown:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    frame.Dropdown = dropdown
    page.ProfileDropdown = frame

    return frame

end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function Dashboard:UpdateStoragePage(frame)

    local page = frame.Pages and frame.Pages.Storage

    if not page then
        return
    end

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not storageModule or not inventoryModule then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    -- Cleanup & Optimization pass -- analysis/consumableInventory are each
    -- computed exactly once here and threaded into GetShoppingListDetail/
    -- GetSupplyForecast below instead of letting those methods recompute
    -- them internally (both accept the precomputed result as an optional
    -- argument; a standalone caller with just a profileID still works
    -- unchanged).
    local profile = storageModule:GetActiveProfile()
    local analysis = profile and storageModule:AnalyzeProfile(profile.id) or { missing = {}, excess = {}, withdrawals = {}, deposits = {}, actionsNeeded = 0, readinessPercent = 100 }
    local shoppingDetail = profile and storageModule:GetShoppingListDetail(profile.id, analysis) or {}
    local consumableInventory = storageModule:GetConsumableInventory()
    local supplyForecast = storageModule:GetSupplyForecast(consumableInventory)
    local bankSummary = storageModule:GetBankSummary()
    local bagSummary = inventoryModule:GetBagSummary()

    -- Storage Insights only -- reads AC.InsightEngine directly, not
    -- GetCategorizedRecommendationsAndInsights (which also gathers
    -- RecommendationEngine's general advice -- deliberately not shown
    -- here, per this page's own scope).
    local insights = AC.InsightEngine and AC.InsightEngine:GetInsightsByCategory("Storage") or {}

    -- Delegates to the shared Dashboard:ShowEmptyLine.
    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    -- A single dim, label-less sentence -- Supply Health's one-line
    -- verdict. Same cached-FontString-reused-across-refreshes shape as
    -- every other page-local text cache in this codebase. `iconKey`
    -- (UI Polish Pass) is optional -- a key into SUPPLY_HEALTH_ICONS --
    -- and pools a sibling Texture alongside the FontString; omitting it
    -- (the "No profile selected" neutral state) hides the icon and keeps
    -- the sentence at the plain ROW_INDENT it always used.
    local function AddSentence(cacheKey, text, yOffset, width, color, iconKey)

        if not page[cacheKey] then

            local sentence = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            sentence:SetJustifyH("LEFT")
            sentence:SetWordWrap(true)
            page[cacheKey] = sentence

            local icon = scrollChild:CreateTexture(nil, "ARTWORK")
            icon:SetSize(SUPPLY_HEALTH_ICON_SIZE, SUPPLY_HEALTH_ICON_SIZE)
            page[cacheKey .. "Icon"] = icon

        end

        local sentence = page[cacheKey]
        local icon = page[cacheKey .. "Icon"]
        local textIndent = Layout.ROW_INDENT

        icon:ClearAllPoints()

        if iconKey and SUPPLY_HEALTH_ICONS[iconKey] then

            icon:SetTexture(SUPPLY_HEALTH_ICONS[iconKey])
            icon:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset - 1)
            icon:Show()
            textIndent = textIndent + SUPPLY_HEALTH_ICON_SIZE + SUPPLY_HEALTH_ICON_GAP

        else
            icon:Hide()
        end

        sentence:ClearAllPoints()
        sentence:SetPoint("TOPLEFT", textIndent, yOffset)
        sentence:SetWidth(width - textIndent)
        sentence:SetText(text)
        sentence:SetTextColor(unpack(AC.Presentation.GetSemanticColor(color or "dim")))
        sentence:Show()

        return yOffset - math.max(sentence:GetStringHeight(), SUPPLY_HEALTH_ICON_SIZE) - 8

    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Profile Switcher
        -----------------------------------------------------------------------

        local dropdownFrame = BuildProfileDropdown(page, scrollChild)
        dropdownFrame:ClearAllPoints()
        dropdownFrame:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)

        local profileList = AC.StorageProfiles and AC.StorageProfiles.BuiltIn or {}

        dropdownFrame.Dropdown:SetupMenu(function(_, rootDescription)

            for _, candidate in ipairs(profileList) do

                rootDescription:CreateButton(AC.L:Get(candidate.label), function()
                    storageModule:SetActiveProfileID(candidate.id)
                    Dashboard:UpdateStoragePage(frame)
                end)

            end

        end)

        dropdownFrame.Dropdown:SetDefaultText(profile and AC.L:Get(profile.label) or AC.L:Get("Storage.NoProfileSelected"))

        yOffset = yOffset - 26 - Layout.SECTION_GROUP_GAP

        -----------------------------------------------------------------------
        -- Supply Health -- one sentence. "Am I ready?" answered outright;
        -- every section below explains why, never repeated here.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionSupplyHealth", yOffset)

        local isReady = #analysis.missing == 0 and #analysis.withdrawals == 0

        -- Final Polish -- glyph-prefixed, four real states (not a single
        -- "not ready" catch-all): ready; exactly one thing missing (named
        -- directly, no "need...more" duplication); more than one thing
        -- missing (severe enough to earn the cross glyph instead of the
        -- warning triangle, and a summary phrase rather than picking one
        -- arbitrarily); nothing missing but Bank Transfers still pending.
        -- Detail for every state still lives in the sections below --
        -- this sentence never repeats it, only names the headline.
        if not profile then

            yOffset = AddSentence("SupplyHealthText", AC.L:Get("Storage.NoProfileSelected"), yOffset, width, "dim")

        elseif isReady then

            yOffset = AddSentence("SupplyHealthText", AC.L:Get("Storage.SupplyHealthReady"), yOffset, width, "success", "ready")

        elseif #analysis.missing == 1 then

            local onlyMissing = analysis.missing[1]
            local text = AC.L:Format("Storage.SupplyHealthMissingFormat", onlyMissing.amount, AC.L:Get(onlyMissing.label))

            yOffset = AddSentence("SupplyHealthText", text, yOffset, width, "warning", "waiting")

        elseif #analysis.missing > 1 then

            yOffset = AddSentence("SupplyHealthText", AC.L:Get("Storage.SupplyHealthMultipleMissing"), yOffset, width, "critical", "notReady")

        else

            local text = AC.L:Format("Storage.SupplyHealthTransfersFormat", #analysis.withdrawals + #analysis.deposits)

            yOffset = AddSentence("SupplyHealthText", text, yOffset, width, "warning", "waiting")

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Storage Summary (merged Inventory Summary + Storage Health)
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionStorageSummary", yOffset)

        local summaryStats =
        {
            { label = "Storage.StatBagSlotsUsed", value = tostring(bagSummary.usedSlots or 0) },
            { label = "Storage.StatBagSlotsFree", value = tostring(bagSummary.freeSlots or 0) },
        }

        if bankSummary.accessible then

            table.insert(summaryStats, { label = "Storage.StatBankSlotsScanned", value = tostring(bankSummary.slotsScanned or 0) })
            table.insert(summaryStats, { label = "Storage.StatBankDistinctItems", value = tostring(bankSummary.distinctItems or 0) })

        end

        yOffset = self:LayoutStatisticsGrid(page, "StorageSummary", scrollChild, yOffset, width, summaryStats)

        if not bankSummary.accessible then
            yOffset = ShowEmptyLine("BankNotAccessibleText", yOffset, width, "Storage.NotAtBank")
        elseif page.BankNotAccessibleText then
            page.BankNotAccessibleText:Hide()
        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Bank Transfers -- ONLY what Execute can actually move
        -- (withdrawals + deposits). Missing items live in Shopping List
        -- instead -- these two used to share one merged grid (a real
        -- in-page duplication with Shopping List), now cleanly split.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionBankTransfers", yOffset)

        local transferRows = {}

        for _, entry in ipairs(analysis.withdrawals) do
            table.insert(transferRows, { label = entry.label, value = AC.L:Format("Storage.AmountWithdrawFormat", entry.amount) })
        end

        for _, entry in ipairs(analysis.deposits) do
            table.insert(transferRows, { label = entry.label, value = AC.L:Format("Storage.AmountDepositFormat", entry.amount) })
        end

        if #transferRows == 0 then

            yOffset = ShowEmptyLine("TransfersEmptyText", yOffset, width, "Storage.NoBankTransfersNeeded")

            if page.ExecuteButton then
                page.ExecuteButton:Hide()
            end

        else

            if page.TransfersEmptyText then
                page.TransfersEmptyText:Hide()
            end

            yOffset = self:LayoutStatisticsGrid(page, "BankTransfers", scrollChild, yOffset, width, transferRows)

            local canExecute = bankSummary.accessible and (#analysis.withdrawals > 0 or #analysis.deposits > 0)

            if canExecute then

                if not page.ExecuteButton then

                    local button = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
                    button:SetSize(160, 22)
                    button:SetText(AC.L:Get("Storage.ExecuteButton"))

                    page.ExecuteButton = button

                end

                page.ExecuteButton:ClearAllPoints()
                page.ExecuteButton:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
                page.ExecuteButton:SetScript("OnClick", function()

                    local popup = StaticPopup_Show("AZEROTHCOMPANION_STORAGE_EXECUTE")

                    if popup then

                        popup.data = profile.id
                        popup.text:SetText(AC.L:Format("Storage.ExecuteConfirmFormat", #analysis.withdrawals, #analysis.deposits))

                    end

                end)
                page.ExecuteButton:Show()

                yOffset = yOffset - 30

            elseif page.ExecuteButton then
                page.ExecuteButton:Hide()
            end

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Shopping List -- ONLY items that must be obtained elsewhere,
        -- now itemized: the specific already-held item(s) per shortfall,
        -- never a guessed item for a category with nothing held.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionShoppingList", yOffset)

        if #analysis.missing == 0 then

            yOffset = ShowEmptyLine("ShoppingListEmptyText", yOffset, width, "Storage.NothingToBuy")

            if page.ShoppingHeaders then

                for label, header in pairs(page.ShoppingHeaders) do

                    header.Label:Hide()
                    header.Value:Hide()

                    local poolKey = "ShoppingItems" .. label

                    if page.Pools and page.Pools[poolKey] then
                        for _, row in ipairs(page.Pools[poolKey]) do
                            row:Hide()
                        end
                    end

                end

            end

        else

            if page.ShoppingListEmptyText then
                page.ShoppingListEmptyText:Hide()
            end

            -- Each missing rule gets its own small header -- category
            -- name and "Need N" as two separate FontStrings (Final
            -- Polish pass), matching the label/value visual language
            -- Storage Summary/Bank Transfers already use, not one
            -- concatenated string -- plus the specific already-held
            -- item(s), or the honest "none currently held" fallback,
            -- never a guessed item name. Headers/item pools are cached
            -- per rule label and explicitly hidden once a rule is no
            -- longer missing, so a resolved shortfall doesn't leave a
            -- stale header on screen.
            page.ShoppingHeaders = page.ShoppingHeaders or {}
            page.Pools = page.Pools or {}

            local seenLabels = {}
            local valueWidth = 100

            for _, entry in ipairs(analysis.missing) do

                seenLabels[entry.label] = true

                local header = page.ShoppingHeaders[entry.label]

                if not header then

                    local labelText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    labelText:SetJustifyH("LEFT")
                    Format.SetHighlightColor(labelText)

                    local valueText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    valueText:SetJustifyH("RIGHT")
                    valueText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("warning")))

                    header = { Label = labelText, Value = valueText }
                    page.ShoppingHeaders[entry.label] = header

                end

                header.Label:ClearAllPoints()
                header.Label:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
                header.Label:SetWidth(width - Layout.ROW_INDENT - valueWidth)
                header.Label:SetText(AC.L:Get(entry.label))
                header.Label:Show()

                -- TOPLEFT at an explicit X derived from `width` (not
                -- TOPRIGHT relative to scrollChild's own actual width,
                -- which MeasureAndApplyScrolling only updates AFTER
                -- Layout_ returns -- mid-layout it could still reflect a
                -- prior refresh's width). SetJustifyH("RIGHT") right-aligns
                -- the text within this box, ending flush with every other
                -- right edge on the page.
                header.Value:ClearAllPoints()
                header.Value:SetPoint("TOPLEFT", width - valueWidth, yOffset)
                header.Value:SetWidth(valueWidth)
                header.Value:SetText(AC.L:Format("Storage.ShoppingListNeedFormat", entry.amount))
                header.Value:Show()

                yOffset = yOffset - math.max(header.Label:GetStringHeight() or Layout.ROW_HEIGHT, Layout.ROW_HEIGHT) - 4

                local detail = shoppingDetail[entry.label]
                local lines = {}

                if detail and #detail.items > 0 then

                    for _, item in ipairs(detail.items) do
                        table.insert(lines, AC.L:Format("Storage.ShoppingListItemFormat", item.name, item.currentCount))
                    end

                else
                    table.insert(lines, AC.L:Get("Storage.ShoppingListNoneHeld"))
                end

                local poolKey = "ShoppingItems" .. entry.label
                page.Pools[poolKey] = page.Pools[poolKey] or {}

                yOffset = self:LayoutTextLines(scrollChild, page.Pools[poolKey], lines, yOffset, width, "Storage.ShoppingListNoneHeld", function(line)
                    return Format.BULLET .. " " .. line
                end)

                yOffset = yOffset - Layout.SECTION_HEADER_GAP

            end

            for label, header in pairs(page.ShoppingHeaders) do

                if not seenLabels[label] then

                    header.Label:Hide()
                    header.Value:Hide()

                    local poolKey = "ShoppingItems" .. label

                    if page.Pools[poolKey] then
                        for _, row in ipairs(page.Pools[poolKey]) do
                            row:Hide()
                        end
                    end

                end

            end

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Consumables -- the definitive supply-check view. Independent
        -- of the active profile (bag/bank contents don't change with it).
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionConsumables", yOffset)

        local consumableRecords = {}

        for _, categoryKey in ipairs(CATEGORY_DISPLAY_ORDER) do

            local bucket = consumableInventory.categories[categoryKey]

            if bucket and #bucket.items > 0 then
                table.insert(consumableRecords, { key = categoryKey, bucket = bucket })
            end

        end

        yOffset = self:LayoutAccordionRows(page, "Consumables", scrollChild, yOffset, width, consumableRecords,
        {
            buildRow = BuildConsumableCategoryRow,
            getRecordID = function(record) return record.key end,
            expandedField = "ExpandedConsumableCategory",
            layoutCollapsed = LayoutConsumableCollapsed,
            buildDetail = BuildConsumablesDetail,
            hideDetail = HideConsumablesDetail,
            onToggle = function(recordID)

                if page.ExpandedConsumableCategory == recordID then
                    page.ExpandedConsumableCategory = nil
                else
                    page.ExpandedConsumableCategory = recordID
                end

                Dashboard:UpdateStoragePage(frame)

            end,
            emptyTextKey = "Storage.NoConsumablesTracked",
            rowGap = Layout.ACCORDION_ROW_GAP,
        })

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Supply Forecast -- player-friendly sentences, real Mythic+
        -- history only.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionSupplyForecast", yOffset)

        local forecastRows = {}

        for _, categoryKey in ipairs(CATEGORY_DISPLAY_ORDER) do

            local forecast = supplyForecast[categoryKey]

            if forecast then

                local value = AC.L:Format("Storage.SupplyForecastFormat", forecast.estimatedRunsRemaining)

                if forecast.estimatedRunsRemaining <= 2 then
                    value = value .. " " .. LOW_SUPPLY_MARKER
                end

                table.insert(forecastRows, { label = "Storage.Category." .. categoryKey, value = value })

            end

        end

        if #forecastRows == 0 then
            yOffset = ShowEmptyLine("ForecastEmptyText", yOffset, width, "Storage.NoSupplyForecast")
        else

            if page.ForecastEmptyText then
                page.ForecastEmptyText:Hide()
            end

            yOffset = self:LayoutStatisticsGrid(page, "SupplyForecast", scrollChild, yOffset, width, forecastRows)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Storage Insights (Storage-only -- no Recommendations section)
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Insights", "Storage.SectionInsights", yOffset, insights, "Storage.NoInsights")

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
