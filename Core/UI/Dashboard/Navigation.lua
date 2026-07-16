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

        -- Dashboard Initialization Fix -- scroll-to-top belongs to the
        -- navigation lifecycle, not to ApplyPageScrolling (Sections.lua),
        -- which also runs on every in-page refresh (accordion expand/
        -- collapse, Storage Execute, Plan switching, Home dismiss, sorting)
        -- and must never reset scroll position during those. Resetting
        -- here, once, exactly when a page is newly shown, guarantees every
        -- navigation starts at the top without touching the shared
        -- scrolling function's own behavior.
        if page.ScrollFrame then
            page.ScrollFrame:SetVerticalScroll(0)
        end

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
    elseif pageName == "RecommendationDetails" then
        self:UpdateRecommendationDetailsPage(frame)
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

-- Navigation UX Sprint -- the one place "is there anywhere to go back to"
-- is decided, so GoBack() and the keyboard handler below (and anything
-- else that ever needs to ask) read one real answer instead of each
-- re-checking #NavigationHistory itself.
function Dashboard:CanGoBack()

    return #self.NavigationHistory > 0

end

function Dashboard:GoBack()

    if not self:CanGoBack() then
        return
    end

    local previousPage = table.remove(self.NavigationHistory)
    self.CurrentPage = previousPage

    self:ShowPage(previousPage)

end

-------------------------------------------------------------------------------
-- Recommendation Details (Navigation UX Sprint)
--
-- Replaces the standalone RecommendationInspector popup. Recommendations
-- have no stable persisted identity (rebuilt from scratch every
-- RecommendationEngine:Refresh()), so there is nothing to look up by page
-- name alone the way every other page reads its own module's state --
-- this stashes the actual clicked snapshot on the Dashboard itself, then
-- navigates completely normally through the same Navigate() every other
-- page uses. This is the one deliberate exception to "Navigate(pageName)
-- takes no payload," not a second navigation system -- NavigationHistory,
-- ShowPage, and GoBack all still work exactly as they do for every other
-- page; CurrentRecommendationDetails is just an extra piece of state this
-- one page happens to need, read only by
-- Dashboard:UpdateRecommendationDetailsPage (Pages/RecommendationDetails.lua).
-------------------------------------------------------------------------------

function Dashboard:ShowRecommendationDetails(recommendation)

    if not recommendation then
        return
    end

    self.CurrentRecommendationDetails = recommendation

    -- Companion Intelligence vNext -- opening Recommendation Details is
    -- the one real, observable signal this addon has that the player
    -- actually looked at this recommendation (unchanged behavior, moved
    -- from the old popup's own Show()).
    if recommendation.id and AC.RecommendationHistoryService then
        AC.RecommendationHistoryService:MarkAcknowledged(recommendation.id)
    end

    self:Navigate("RecommendationDetails")

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
