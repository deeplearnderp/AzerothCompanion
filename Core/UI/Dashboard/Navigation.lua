-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Navigation
--
-- In-window page switching, the Toggle entry point, and the final
-- Dashboard service registration. Loaded last among the Dashboard files:
-- ShowPage dispatches to every page's Update*Page method by name, which
-- only ever runs at user-triggered navigation time (well after every
-- Dashboard file has loaded), so this file has no load-order dependency
-- on the Pages/*.lua files beyond all of them existing by the time the
-- player actually opens the window.
--
-- Navigation System -- Dashboard's own NavigationHistory/GoBack/CanGoBack
-- and its hand-rolled ESC handler (formerly Home.lua) are retired.
-- AC.NavigationService (Core/UI/Shared/NavigationService.lua) now owns
-- history and ESC/Back for the whole addon, not just Dashboard; this file
-- keeps only what's genuinely Dashboard-specific -- ShowPage's rendering,
-- and RestoreNavigation, the one method NavigationService dispatches to
-- when Dashboard is the entry on top of the stack.
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
    elseif pageName == "Dungeons" then
        self:UpdateDungeonsPage(frame)
    elseif pageName == "ActivityLog" then
        self:UpdateActivityLogPage(frame)
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

-- Navigation System -- the one call every card/nav button uses to drill
-- into a page. Pushes through AC.NavigationService (Core/UI/Shared/
-- NavigationService.lua) rather than maintaining its own history array --
-- Dashboard used to be the only window with real back-navigation; now it's
-- one of several controllers the shared service dispatches to. RestoreNavigation
-- (below) is the only other half of this -- ShowPage itself stays pure
-- rendering, untouched.
function Dashboard:Navigate(pageName)

    if not self:IsValidPage(pageName) then
        return
    end

    if pageName == self.CurrentPage then
        return
    end

    AC.NavigationService:Push(AC.NavigationService.Windows.Dashboard, pageName)

end

-- Dispatched here by AC.NavigationService:Restore() -- the one place
-- Dashboard turns a NavigationEntry back into pixels, whether reached via
-- GoBack(), a fresh Push, or ESC. entry.Context only carries a payload for
-- RecommendationDetails (see ShowRecommendationDetails below); every other
-- Dashboard page needs nothing beyond its own name.
function Dashboard:RestoreNavigation(entry)

    self.Frame:Show()
    self.CurrentPage = entry.View

    if entry.View == AC.NavigationService.Views.Dashboard.RecommendationDetails and entry.Context then
        self.CurrentRecommendationDetails = entry.Context.recommendation
    end

    self:ShowPage(entry.View)

    local page = self.Frame.Pages and self.Frame.Pages[entry.View]
    if page and page.ScrollFrame and entry.Context and entry.Context.scrollPosition then
        page.ScrollFrame:SetVerticalScroll(entry.Context.scrollPosition)
    end

end

function Dashboard:CaptureNavigation(entry)

    local page = self.Frame and self.Frame.Pages and self.Frame.Pages[entry.View]

    entry.Context = entry.Context or {}

    if page and page.ScrollFrame then
        entry.Context.scrollPosition = page.ScrollFrame:GetVerticalScroll()
    end

end

-------------------------------------------------------------------------------
-- Recommendation Details (Navigation UX Sprint)
--
-- Replaces the standalone RecommendationInspector popup. Recommendations
-- have no stable persisted identity (rebuilt from scratch every
-- RecommendationEngine:Refresh()), so there is nothing to look up by page
-- name alone the way every other page reads its own module's state --
-- this stashes the actual clicked snapshot as NavigationEntry Context,
-- pushed directly rather than through Navigate() (see that function's own
-- header comment for why). Not a second navigation system -- AC.
-- NavigationService's stack, RestoreNavigation, and ShowPage all still
-- work exactly as they do for every other page; CurrentRecommendationDetails
-- is just an extra piece of state this one page happens to need, read
-- only by Dashboard:UpdateRecommendationDetailsPage (Pages/RecommendationDetails.lua).
-------------------------------------------------------------------------------

function Dashboard:ShowRecommendationDetails(recommendation)

    if not recommendation then
        return
    end

    -- Companion Intelligence vNext -- opening Recommendation Details is
    -- the one real, observable signal this addon has that the player
    -- actually looked at this recommendation (unchanged behavior, moved
    -- from the old popup's own Show()).
    if recommendation.id and AC.RecommendationHistoryService then
        AC.RecommendationHistoryService:MarkAcknowledged(recommendation.id)
    end

    -- Pushes directly rather than through Navigate() -- Navigate() carries
    -- no payload by design (see this section's own header comment);
    -- RestoreNavigation applies entry.Context.recommendation to
    -- CurrentRecommendationDetails, so it's set once, in the one place
    -- that turns entries back into state, not written here too.
    AC.NavigationService:Push(AC.NavigationService.Windows.Dashboard, AC.NavigationService.Views.Dashboard.RecommendationDetails, { recommendation = recommendation })

end

-------------------------------------------------------------------------------
-- Toggle
--
-- The one external entry point (minimap left-click, /ac, /ac dashboard).
-- Show()/Hide() as standalone methods are retired along with the old
-- history array -- nothing outside this file called them directly
-- (confirmed via a repo-wide grep) -- RestoreNavigation above and
-- AC.NavigationService's Suspend()/Resume()/Close() cover everything they
-- used to do while keeping visibility and history as separate facts.
-- NavigationService state -- not this Frame's own IsShown() -- decides the
-- branch, because "Azeroth Companion is open" can mean a completely
-- different window is currently on top of the navigation stack. Toggle
-- suspends that whole application session; the next toggle resumes its
-- exact top entry and history. Back/ESC at the root still use Close() and
-- end the session normally.
-------------------------------------------------------------------------------

function Dashboard:Toggle()

    if AC.NavigationService:IsOpen() then
        AC.NavigationService:Suspend()
    elseif AC.NavigationService:IsSuspended() then
        AC.NavigationService:Resume()
    else
        AC.NavigationService:Push(AC.NavigationService.Windows.Dashboard, self.CurrentPage or AC.NavigationService.Views.Dashboard.Home)
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("Dashboard", Dashboard)
AC.NavigationService:RegisterWindow(AC.NavigationService.Windows.Dashboard, Dashboard)

return Dashboard
