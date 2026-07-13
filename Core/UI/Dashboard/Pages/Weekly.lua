-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Weekly
--
-- Vault slot progress, Recommendations, Insights -- the same three pieces
-- the Home card summarizes, just with room to actually list each slot's
-- own threshold/progress instead of a single "X / Y" number.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

function Dashboard:UpdateWeeklyPage(frame)

    local page = frame.Pages and frame.Pages.Weekly

    if not page then
        return
    end

    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")

    if not weeklyModule then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    local vaultProgress = weeklyModule:GetVaultProgress()

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("Weekly")

    -- Delegates to the shared Dashboard:ShowEmptyLine.
    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Vault Progress
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Weekly.SectionVaultProgress", yOffset)

        if not vaultProgress or not vaultProgress.totalSlots or vaultProgress.totalSlots == 0 then

            yOffset = ShowEmptyLine("VaultEmptyText", yOffset, width, "Weekly.NoVaultData")

        else

            if page.VaultEmptyText then
                page.VaultEmptyText:Hide()
            end

            local vaultStats =
            {
                { label = "Weekly.StatUnlockedSlots", value = AC.L:Format("Weekly.SlotsFormat", vaultProgress.unlockedSlots or 0, vaultProgress.totalSlots) },
                { label = "Weekly.StatRewardAvailable", value = vaultProgress.hasAvailableRewards and AC.L:Get("Common.Yes") or AC.L:Get("Common.No") },
            }

            yOffset = self:LayoutStatisticsGrid(page, "VaultProgress", scrollChild, yOffset, width, vaultStats)

            -- Per-slot threshold/progress -- the detail the Home card
            -- doesn't have room for.
            page.Pools = page.Pools or {}
            page.Pools.VaultSlots = page.Pools.VaultSlots or {}

            local slotRows = {}

            for _, slot in ipairs(vaultProgress.slots or {}) do
                table.insert(slotRows, { label = AC.L:Format("Weekly.SlotLabelFormat", slot.index or 0), value = AC.L:Format("Weekly.SlotProgressFormat", slot.progress or 0, slot.threshold or 0) })
            end

            if #slotRows > 0 then
                yOffset = self:LayoutStatisticsGrid(page, "VaultSlotDetail", scrollChild, yOffset, width, slotRows)
            end

        end

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Recommendations
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Recommendations", "Weekly.SectionRecommendations", yOffset, recommendations, "Weekly.NoRecommendations", true)

        -----------------------------------------------------------------------
        -- Insights
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Insights", "Weekly.SectionInsights", yOffset, insights, "Weekly.NoInsights")

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
