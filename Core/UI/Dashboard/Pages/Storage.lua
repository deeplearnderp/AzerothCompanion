-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Storage Summary
--
-- The Dashboard answers "How prepared am I?" and links to the dedicated
-- Inventory Manager workspace. StorageModule remains the owner of every
-- fact; this page renders a live summary when one exists this session, and
-- falls back to the Storage Knowledge Base's persisted snapshot otherwise
-- (same live/historical distinction as the Overview page, just compact --
-- see AC.DashboardFormat.GetStorageReadinessText).
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
    local facts = enabled and storageModule.GetReadinessFacts and storageModule:GetReadinessFacts(profile and profile.id) or { enabled = false }
    local lastKnownStorage = enabled and storageModule:GetLastKnownStorage() or nil
    local lastScan = enabled and storageModule:GetLastScan() or nil
    local lastScanTimestamp = lastScan and lastScan.timestamp or (lastKnownStorage and lastKnownStorage.metadata.timestamp)

    -- Same "is there anything to show at all, live or carried over from a
    -- prior login" distinction the Inventory Manager Overview page makes
    -- (see BuildOverviewPage's hasAnyData) -- this compact summary should
    -- never disagree with that page about whether data exists.
    local hasAnyData = facts.hasLiveScan or lastKnownStorage ~= nil
    local recommendations = {}

    if facts.hasLiveScan then
        recommendations = self:GetCategorizedRecommendationsAndInsights("Storage")
    elseif lastKnownStorage then
        recommendations = (lastKnownStorage.analysis and lastKnownStorage.analysis.recommendations) or {}
    end

    local function Layout_(width)

        page.ContentWidth = width

        local readinessText = AC.DashboardFormat.GetStorageReadinessText(facts)

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
            { label = "InventoryManager.StatLastScan", value = lastScanTimestamp and AC.Presentation.FormatDate(lastScanTimestamp, "shortTime") or AC.L:Get("InventoryManager.LastScanUnknown") },
        })

        if not hasAnyData then
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

        -- Compact stand-in for Overview's full "Live Storage Status"
        -- section -- this page's role is a summary (Progressive
        -- Disclosure), so relying on carried-over Storage Knowledge Base
        -- data instead of a fresh scan this session gets one line, not an
        -- entire section.
        if hasAnyData and not facts.hasLiveScan and lastScanTimestamp then
            yOffset = self:ShowEmptyLineText(page, page.ScrollChild, "HistoricalNote", yOffset, width,
                AC.L:Format("InventoryManager.StaleDataAvailable", AC.Presentation.FormatDate(lastScanTimestamp, "shortTime")))
        elseif page.HistoricalNote then
            page.HistoricalNote:Hide()
        end

        yOffset = self:AppendDynamicSection(page, "Recommendations", "InventoryManager.SectionRecommendations", yOffset, recommendations, hasAnyData and "Weekly.NoRecommendations" or "InventoryManager.DataRequiresScan", true)

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
