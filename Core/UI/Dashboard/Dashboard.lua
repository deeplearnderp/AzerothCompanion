-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard
--
-- Primary presentation layer for Azeroth Companion. A single window with
-- in-window page navigation -- cards navigate to pages inside this frame
-- rather than opening separate popup windows. Home is the landing page;
-- every other feature gets its own Dashboard page over time.
--
-- The Dashboard never owns player data and never touches Blizzard APIs
-- directly for gameplay state. Every gameplay value shown here is read
-- through a gameplay module's public API -- it is purely presentation.
-- All visible text goes through AC.L:Get()/AC.L:Format() rather than
-- literal strings, per the Localization system -- nothing in here reads a
-- locale table directly.
--
-- Adding a future module page (Delves, Raids, Professions, Collections,
-- Reputation, Weekly Activities, ...) means, and should only ever mean:
--   1. Add its schema to Schemas.lua, if it is a static-field page.
--   2. Add its page name to DashboardLayout.VALID_PAGES (Layout.lua).
--   3. Call CreateDataPage()/BuildDataPageContent() for it in Home.lua's
--      Create(), the same way every existing static page does.
--   4. Add a Pages/X.lua with a GetXFieldValues()/UpdateXPage() pair
--      reading that module's public API, and a branch in Navigation.lua's
--      ShowPage().
--   5. Add a Home card in Home.lua if it warrants one.
-- No part of the shared layout/padding/scrolling/typography helpers
-- (Sections.lua, Rows.lua) needs redesigning to fit a new page in -- that
-- is the point of those shared helpers. BuildDataPageContent automatically
-- decides whether the page needs a scrollbar and which content width to
-- use; a page builder never makes that decision by hand.
--
-- File layout (Dashboard Refactor -- split out of one 3,900+ line file
-- once the Dashboard became the addon's central presentation layer and
-- outgrew a single file):
--   Layout.lua           -- layout constants, VALID_PAGES, hero font
--   Format.lua            -- number/duration/money/clock/star formatting
--   Schemas.lua            -- static field-schema data for Profile/Inventory
--   Dashboard.lua (this file) -- creates the Dashboard table + Initialize()
--   Sections.lua            -- shared page-shell + section-building primitives
--   Rows.lua                 -- shared dynamic list/hero/grid/history row builders
--   Pages/*.lua                -- one file per page's Get*FieldValues/Update*Page
--   Home.lua                    -- window shell, Home card construction, Home refresh
--   Navigation.lua                -- ShowPage/Navigate/GoBack/Show/Hide/Toggle, service registration
-- Every file attaches its methods to the same AC.Dashboard table (Lua's
-- `function Dashboard:X()` just adds a key to whatever table `Dashboard`
-- refers to) -- externally this is still exactly one object with exactly
-- the same public surface as before the split.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = {}
AC.Dashboard = Dashboard

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Dashboard:Initialize()

    self.CurrentPage = "Home"
    self.NavigationHistory = {}

    self.Frame = self:Create()

end

return Dashboard
