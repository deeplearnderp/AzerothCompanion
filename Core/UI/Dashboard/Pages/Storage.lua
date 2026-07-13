-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Storage
--
-- Inventory Summary/Storage Health/Current Profile/Restock Status/
-- Shopping List/Recommendations/Insights. Profile switching itself lives
-- in Settings > Storage (a simple dropdown -- see StorageModule:Initialize)
-- rather than on this page, per "do not overload the page" -- this page
-- displays the active profile and what it means for the player right now,
-- it does not edit it.
--
-- Also owns the Storage Execute confirmation flow (StaticPopupDialogs +
-- ShowExecuteResult) -- previously registered in generic Dashboard chrome
-- even though it is entirely Storage-specific (Dashboard Refactor: moved
-- here so this file has the whole feature, not just the page rendering
-- half of it).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

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

    local profile = storageModule:GetActiveProfile()
    local analysis = profile and storageModule:AnalyzeProfile(profile.id) or { missing = {}, excess = {}, withdrawals = {}, deposits = {}, actionsNeeded = 0 }
    local bankSummary = storageModule:GetBankSummary()
    local bagSummary = inventoryModule:GetBagSummary()

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("Storage")

    -- Delegates to the shared Dashboard:ShowEmptyLine.
    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    -- A label/value field row, cached and reused across refreshes --
    -- unlike Dashboard:AddField (which is only ever called once, at
    -- static page construction time), this page rebuilds its layout on
    -- every ShowPage("Storage"), so a field row must reuse the same pair
    -- of FontStrings rather than creating a new pair each time.
    local function AddCachedField(cacheKey, labelKey, value, yOffset, width)

        local labelCacheKey = cacheKey .. "Label"
        local valueCacheKey = cacheKey .. "Value"

        if not page[labelCacheKey] then

            local labelText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelText:SetJustifyH("LEFT")
            labelText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
            page[labelCacheKey] = labelText

            local valueText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valueText:SetJustifyH("LEFT")
            page[valueCacheKey] = valueText

        end

        local valueWidth = width - Layout.ROW_INDENT - Layout.FIELD_LABEL_WIDTH - Layout.FIELD_LABEL_VALUE_GAP

        page[labelCacheKey]:ClearAllPoints()
        page[labelCacheKey]:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        page[labelCacheKey]:SetWidth(Layout.FIELD_LABEL_WIDTH)
        page[labelCacheKey]:SetText(AC.L:Get(labelKey))
        page[labelCacheKey]:Show()

        page[valueCacheKey]:ClearAllPoints()
        page[valueCacheKey]:SetPoint("TOPLEFT", Layout.ROW_INDENT + Layout.FIELD_LABEL_WIDTH + Layout.FIELD_LABEL_VALUE_GAP, yOffset)
        page[valueCacheKey]:SetWidth(valueWidth)
        page[valueCacheKey]:SetText(value)
        page[valueCacheKey]:Show()

        return yOffset - Layout.ROW_HEIGHT

    end

    local function HideCachedField(cacheKey)

        if page[cacheKey .. "Label"] then
            page[cacheKey .. "Label"]:Hide()
        end

        if page[cacheKey .. "Value"] then
            page[cacheKey .. "Value"]:Hide()
        end

    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Inventory Summary
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionInventorySummary", yOffset)

        local inventoryStats =
        {
            { label = "Storage.StatBagSlotsUsed", value = tostring(bagSummary.usedSlots or 0) },
            { label = "Storage.StatBagSlotsFree", value = tostring(bagSummary.freeSlots or 0) },
        }

        yOffset = self:LayoutStatisticsGrid(page, "InventorySummary", scrollChild, yOffset, width, inventoryStats)
        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Storage Health
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionStorageHealth", yOffset)

        if not bankSummary.accessible then

            yOffset = ShowEmptyLine("HealthEmptyText", yOffset, width, "Storage.NotAtBank")

        else

            if page.HealthEmptyText then
                page.HealthEmptyText:Hide()
            end

            local healthStats =
            {
                { label = "Storage.StatBankSlotsScanned", value = tostring(bankSummary.slotsScanned or 0) },
                { label = "Storage.StatBankDistinctItems", value = tostring(bankSummary.distinctItems or 0) },
            }

            yOffset = self:LayoutStatisticsGrid(page, "StorageHealth", scrollChild, yOffset, width, healthStats)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Current Profile
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionCurrentProfile", yOffset)

        if not profile then

            HideCachedField("ActiveProfile")
            HideCachedField("RuleCount")

            yOffset = ShowEmptyLine("ProfileEmptyText", yOffset, width, "Storage.NoProfileSelected")

        else

            if page.ProfileEmptyText then
                page.ProfileEmptyText:Hide()
            end

            yOffset = AddCachedField("ActiveProfile", "Storage.FieldActiveProfile", AC.L:Get(profile.label), yOffset, width)
            yOffset = AddCachedField("RuleCount", "Storage.FieldRuleCount", tostring(#profile.rules), yOffset, width)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Restock Status
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionRestockStatus", yOffset)

        local restockRows = {}

        for _, entry in ipairs(analysis.withdrawals) do
            table.insert(restockRows, { label = entry.label, value = AC.L:Format("Storage.AmountWithdrawFormat", entry.amount) })
        end

        for _, entry in ipairs(analysis.missing) do
            table.insert(restockRows, { label = entry.label, value = AC.L:Format("Storage.AmountMissingFormat", entry.amount) })
        end

        for _, entry in ipairs(analysis.deposits) do
            table.insert(restockRows, { label = entry.label, value = AC.L:Format("Storage.AmountDepositFormat", entry.amount) })
        end

        if #restockRows == 0 then

            yOffset = ShowEmptyLine("RestockEmptyText", yOffset, width, "Storage.NoRestockNeeded")

            if page.ExecuteButton then
                page.ExecuteButton:Hide()
            end

        else

            if page.RestockEmptyText then
                page.RestockEmptyText:Hide()
            end

            yOffset = self:LayoutStatisticsGrid(page, "RestockStatus", scrollChild, yOffset, width, restockRows)

            -- Execute -- only offered when the bank is actually open
            -- (moving to/from it requires that) and there's a real
            -- withdrawal or deposit to make -- "missing" entries have
            -- nothing to move, only to acquire, so they alone don't
            -- enable this button.
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
        -- Shopping List
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Storage.SectionShoppingList", yOffset)

        if #analysis.missing == 0 then

            yOffset = ShowEmptyLine("ShoppingListEmptyText", yOffset, width, "Storage.NothingToBuy")

        else

            if page.ShoppingListEmptyText then
                page.ShoppingListEmptyText:Hide()
            end

            local shoppingRows = {}

            for _, entry in ipairs(analysis.missing) do
                table.insert(shoppingRows, { label = entry.label, value = AC.L:Format("Storage.AmountMissingFormat", entry.amount) })
            end

            yOffset = self:LayoutStatisticsGrid(page, "ShoppingList", scrollChild, yOffset, width, shoppingRows)

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Recommendations
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Recommendations", "Storage.SectionRecommendations", yOffset, recommendations, "Storage.NoRecommendations", true)

        -----------------------------------------------------------------------
        -- Insights
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Insights", "Storage.SectionInsights", yOffset, insights, "Storage.NoInsights")

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
