-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Navigation
--
-- In-window page switching, the Show/Hide/Toggle window lifecycle, and
-- the final Dashboard service registration. Loaded last among the
-- Dashboard files: ShowPage dispatches to every page's Update*Page method
-- by name, which only ever runs at user-triggered navigation time (well
-- after every Dashboard file has loaded), so this file has no load-order
-- dependency on the Pages/*.lua files beyond all of them existing by the
-- time the player actually opens the window.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

function Dashboard:IsValidPage(pageName)

    return Layout.VALID_PAGES[pageName] == true

end

function Dashboard:ShowPage(pageName)

    local frame = self.Frame

    if not frame or not frame.Pages then
        return
    end

    for _, page in pairs(frame.Pages) do
        if page then
            page:Hide()
        end
    end

    local page = frame.Pages[pageName]

    if page then
        page:Show()
    end

    if pageName == "Home" then
        self:UpdateContent(frame)
    elseif pageName == "Profile" then
        self:UpdateProfilePage(frame)
    elseif pageName == "Inventory" then
        self:UpdateInventoryPage(frame)
    elseif pageName == "Accomplishments" then
        self:UpdateAccomplishmentsPage(frame)
    elseif pageName == "MythicPlus" then
        self:UpdateMythicPlusPage(frame)
    elseif pageName == "Storage" then
        self:UpdateStoragePage(frame)
    elseif pageName == "Weekly" then
        self:UpdateWeeklyPage(frame)
    elseif pageName == "Recommendations" then
        self:UpdateRecommendationsPage(frame)
    elseif pageName == "Progress" then
        self:UpdateProgressPage(frame)
    elseif pageName == "Statistics" then
        self:UpdateStatisticsPage(frame)
    elseif pageName == "Journey" then
        self:UpdateJourneyPage(frame)
    end

end

function Dashboard:Navigate(pageName)

    if not self:IsValidPage(pageName) then
        return
    end

    if pageName == self.CurrentPage then
        return
    end

    table.insert(self.NavigationHistory, self.CurrentPage)
    self.CurrentPage = pageName

    self:ShowPage(pageName)

end

function Dashboard:GoBack()

    if #self.NavigationHistory == 0 then
        return
    end

    local previousPage = table.remove(self.NavigationHistory)
    self.CurrentPage = previousPage

    self:ShowPage(previousPage)

end

-------------------------------------------------------------------------------
-- Show
-------------------------------------------------------------------------------

function Dashboard:Show()

    if not self.Frame then
        self.Frame = self:Create()
    end

    self:ShowPage(self.CurrentPage)
    self.Frame:Show()

end

-------------------------------------------------------------------------------
-- Hide
-------------------------------------------------------------------------------

function Dashboard:Hide()

    if self.Frame then
        self.Frame:Hide()
    end

end

-------------------------------------------------------------------------------
-- Toggle
-------------------------------------------------------------------------------

function Dashboard:Toggle()

    if self.Frame and self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("Dashboard", Dashboard)

return Dashboard
