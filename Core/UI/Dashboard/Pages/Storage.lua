-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Storage Summary
--
-- The Dashboard answers "How prepared am I?" and links to the dedicated
-- Inventory Manager workspace. StorageModule remains the owner of every fact;
-- this page renders only a live, authoritative summary.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

function Dashboard:UpdateStoragePage(frame)

    local page = frame.Pages and frame.Pages.Storage

    if not page then
        return
    end

    self:RefreshEngines(page)

    local storageModule = AC.Core and AC.Core:GetModule("Storage")
    local enabled = storageModule and storageModule.IsModuleEnabled and storageModule:IsModuleEnabled()
    local profile = enabled and storageModule:GetActiveProfile() or nil
    local bankSummary = enabled and storageModule:GetBankSummary() or { accessible = false }
    local hasLiveScan = bankSummary.accessible == true
    local preparation = hasLiveScan and profile and storageModule:GetPreparationStatus(profile.id) or nil
    local recommendations = {}

    if hasLiveScan then
        recommendations = self:GetCategorizedRecommendationsAndInsights("Storage")
    end

    local function Layout_(width)

        page.ContentWidth = width

        local readinessText = AC.L:Get("Common.Unknown")

        if preparation then

            if preparation.ready then
                readinessText = AC.L:Get("InventoryManager.Ready")
            else
                readinessText = AC.L:Format("InventoryManager.ReadinessFormat", preparation.readinessPercent or 0)
            end

        end

        local _, _, _, yOffset = self:BuildHeroSection(
            page,
            page.ScrollChild,
            -4,
            width,
            AC.L:Get("InventoryManager.StatStorageReadiness"),
            readinessText,
            AC.L:Get("InventoryManager.DashboardCaption")
        )

        yOffset = self:LayoutStatisticsGrid(page, "StorageSummary", page.ScrollChild, yOffset, width,
        {
            { label = "InventoryManager.StatCurrentProfile", value = profile and AC.L:Get(profile.label) or AC.L:Get("Storage.NoProfileSelected") },
            { label = "InventoryManager.StatLastScan", value = AC.L:Get("InventoryManager.LastScanUnknown") },
        })

        if not hasLiveScan then
            yOffset = self:BeginSection(page.ScrollChild, "InventoryManager.NoScanTitle", yOffset)
            yOffset = self:ShowEmptyLine(page, page.ScrollChild, "NoScanText", yOffset, width, "InventoryManager.NoScanDescription")
            yOffset = self:EndSection(yOffset)
        else

            if page.NoScanText then
                page.NoScanText:Hide()
            end

            local headers = page.ScrollChild.SectionHeaders

            if headers and headers["InventoryManager.NoScanTitle"] then
                headers["InventoryManager.NoScanTitle"]:Hide()
            end

        end

        yOffset = self:AppendDynamicSection(page, "Recommendations", "InventoryManager.SectionRecommendations", yOffset, recommendations, hasLiveScan and "Weekly.NoRecommendations" or "InventoryManager.DataRequiresScan", true)

        yOffset = self:BeginSection(page.ScrollChild, "InventoryManager.WorkspaceSection", yOffset)
        yOffset = self:ShowEmptyLine(page, page.ScrollChild, "WorkspaceText", yOffset, width, "InventoryManager.WorkspaceDescription")
        yOffset = yOffset - 8

        if not page.OpenInventoryManagerButton then

            local button = CreateFrame("Button", nil, page.ScrollChild, "UIPanelButtonTemplate")
            button:SetSize(190, 22)
            button:SetText(AC.L:Get("InventoryManager.OpenButton"))
            button:SetScript("OnClick", function()

                local manager = AC.Core and AC.Core:GetModule("InventoryManager")

                if manager then
                    manager:Show()
                end

            end)

            page.OpenInventoryManagerButton = button

        end

        page.OpenInventoryManagerButton:ClearAllPoints()
        page.OpenInventoryManagerButton:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        page.OpenInventoryManagerButton:Show()
        yOffset = yOffset - 30
        yOffset = self:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, page.ScrollChild, Layout_)

end

return Dashboard
