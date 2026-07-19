-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Weekly
--
-- Focused Great Vault status: category and reward-slot presentation only.
-- Guidance remains owned by Home and the Recommendations destination.
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
    local vaultCategories = weeklyModule.GetVaultCategories and weeklyModule:GetVaultCategories() or {}

    -- Delegates to the shared Dashboard:ShowEmptyLine.
    local function ShowEmptyLine(cacheKey, yOffset, width, textKey)
        return self:ShowEmptyLine(page, scrollChild, cacheKey, yOffset, width, textKey)
    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        if vaultProgress and vaultProgress.hasAvailableRewards then

            if not page.VaultRewardReadyText then
                page.VaultRewardReadyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                page.VaultRewardReadyText:SetJustifyH("LEFT")
                page.VaultRewardReadyText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("success")))
            end

            page.VaultRewardReadyText:ClearAllPoints()
            page.VaultRewardReadyText:SetPoint("TOPLEFT", 0, yOffset)
            page.VaultRewardReadyText:SetWidth(width)
            page.VaultRewardReadyText:SetText(AC.L:Get("Weekly.RewardReady"))
            page.VaultRewardReadyText:Show()
            yOffset = yOffset - Layout.ROW_HEIGHT

        elseif page.VaultRewardReadyText then
            page.VaultRewardReadyText:Hide()
        end

        if #vaultCategories == 0 then

            yOffset = ShowEmptyLine("VaultEmptyText", yOffset, width, "Weekly.NoVaultData")

        else

            if page.VaultEmptyText then
                page.VaultEmptyText:Hide()
            end

            yOffset = self:LayoutVaultOverview(page, "WeeklyVault", scrollChild, yOffset, width, vaultCategories)

        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
