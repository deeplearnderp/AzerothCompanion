-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Inventory
--
-- The only place the Dashboard reads inventory data. Everything here
-- comes from the Inventory module's public API. Any wording (hearthstone
-- present/missing, repair needed) is decided here, not in the module --
-- the module only ever returns plain booleans/numbers.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

function Dashboard:GetInventoryFieldValues()

    local values = {}

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not inventoryModule then
        return values
    end

    if inventoryModule.GetBagSummary then

        local bagSummary = inventoryModule:GetBagSummary()

        if bagSummary then
            values.usedSlots = tostring(bagSummary.usedSlots or 0)
            values.freeSlots = tostring(bagSummary.freeSlots or 0)
            values.totalSlots = tostring(bagSummary.totalSlots or 0)
            values.percentFull = AC.L:Format("Dashboard.PercentFullFormat", bagSummary.percentage or 0)
        end

    end

    if inventoryModule.GetEquipmentSummary then

        local equipmentSummary = inventoryModule:GetEquipmentSummary()

        if equipmentSummary then

            values.equippedSlots = tostring(equipmentSummary.equippedSlots or 0)
            values.emptyEquipmentSlots = tostring(equipmentSummary.emptySlots or 0)

            if equipmentSummary.averageItemLevel and equipmentSummary.averageItemLevel > 0 then
                values.averageItemLevel = AC.Presentation.FormatItemLevel(equipmentSummary.averageItemLevel)
            end

        end

    end

    if inventoryModule.GetImportantItemsSummary then

        local importantItems = inventoryModule:GetImportantItemsSummary()

        if importantItems and importantItems.hasHearthstone ~= nil then

            if importantItems.hasHearthstone then
                values.hearthstone = AC.L:Get("Inventory.HearthstoneInBags")
            else
                values.hearthstone = AC.L:Get("Inventory.HearthstoneMissing")
            end

        end

    end

    -----------------------------------------------------------------------
    -- Equipment Health (Equipment Health feature) -- read directly from
    -- InventoryModule's own summary, not through GetImportantItemsSummary
    -- (that function is hearthstone-only now -- One Fact, One Home).
    -- Wording/tier/color decisions all happen here, not in the module --
    -- InventoryModule only ever hands back plain numbers/booleans.
    -----------------------------------------------------------------------

    if inventoryModule.GetEquipmentHealthSummary then

        local equipmentHealth = inventoryModule:GetEquipmentHealthSummary()

        if equipmentHealth then

            if equipmentHealth.overallDurability then
                values.overallDurability = AC.Presentation.FormatPercent(equipmentHealth.overallDurability, 0)
            end

            if equipmentHealth.worstDurability then
                values.worstDurability = AC.Presentation.FormatPercent(equipmentHealth.worstDurability, 0)
            end

            local tierLabel, tierColor = AC.DashboardFormat.GetEquipmentHealthTier(equipmentHealth.worstDurability, equipmentHealth.brokenItems)
            values.repairStatus = tierLabel
            values.repairStatusColor = tierColor -- read by UpdateInventoryPage below; not a field key itself

            if equipmentHealth.repairCost and equipmentHealth.repairCost > 0 then
                values.repairCost = AC.Presentation.FormatMoney(equipmentHealth.repairCost)
            else
                values.repairCost = AC.L:Get("Inventory.RepairCostUnavailable")
            end

        end

    end

    if inventoryModule.GetSessionSummary then

        local sessionSummary = inventoryModule:GetSessionSummary()

        if sessionSummary then

            values.itemsAdded = tostring(sessionSummary.itemsAdded or 0)
            values.itemsRemoved = tostring(sessionSummary.itemsRemoved or 0)

            local change = sessionSummary.bagUsageChange or 0

            if change > 0 then
                values.bagUsageChange = string.format("+%.0f%%", change)
            else
                values.bagUsageChange = string.format("%.0f%%", change)
            end

        end

    end

    return values

end

function Dashboard:UpdateInventoryPage(frame)

    local page = frame.Pages and frame.Pages.Inventory

    if not page or not page.Fields then
        return
    end

    local values = self:GetInventoryFieldValues()
    local unknown = AC.L:Get("Common.Unknown")

    for key, fontString in pairs(page.Fields) do
        fontString:SetText(values[key] or unknown)
    end

    -- Equipment Health tier color (Equipment Health feature) -- the one
    -- field on this page whose value carries severity meaning, the same
    -- "label + color" treatment Priority/Confidence get on the
    -- Recommendation card. Every other field here is a plain string/number
    -- with no color decision to make.
    if page.Fields.repairStatus and values.repairStatusColor then
        page.Fields.repairStatus:SetTextColor(unpack(AC.Presentation.GetSemanticColor(values.repairStatusColor)))
    end

    -----------------------------------------------------------------------
    -- Recommendations / Insights (real data, category-filtered)
    -----------------------------------------------------------------------

    self:RefreshEngines(page)

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("Inventory")

    local yOffset = page.StaticEndOffset

    yOffset = self:AppendDynamicSection(page, "Recommendations", "Inventory.SectionRecommendations", yOffset, recommendations, "Inventory.NoRecommendations", true)
    yOffset = self:AppendDynamicSection(page, "Insights", "Inventory.SectionInsights", yOffset, insights, "Inventory.NoInsights")

    self:ApplyPageScrolling(page, (-yOffset) + Layout.PAGE_BOTTOM_PADDING)

end

return Dashboard
