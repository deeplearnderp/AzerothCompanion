-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Forecast
--
-- Presentation only. ForecastService owns collection, normalization,
-- prioritization, and ordering; this page renders its public projection.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

local ACTION_HANDLERS =
{
    navigate = function(action)

        if type(action.destination) == "string" then
            Dashboard:Navigate(action.destination)
        end

    end,
}

-- Forecast actions are data descriptors, never callbacks stored on an item.
-- New action types register here (or through this method) without changing
-- the shared Forecast row renderer.
function Dashboard:RegisterForecastActionHandler(actionType, handler)

    if type(actionType) == "string" and actionType ~= "" and type(handler) == "function" then
        ACTION_HANDLERS[actionType] = handler
    end

end

function Dashboard:ExecuteForecastAction(action)

    if type(action) ~= "table" then
        return false
    end

    local handler = ACTION_HANDLERS[action.type]

    if not handler then
        return false
    end

    handler(action)

    return true

end

function Dashboard:UpdateForecastPage(frame)

    local page = frame.Pages and frame.Pages.Forecast
    local service = AC.ForecastService

    if not page or not service then
        return
    end

    service:Refresh()

    local items = service:GetForecasts()
    local highest = service:GetHighestPriorityForecast()
    local scrollChild = page.ScrollChild

    page.Rows = page.Rows or {}

    local function LayoutForecast(contentWidth)

        local _, _, _, yOffset = self:BuildHeroSection(
            page,
            scrollChild,
            -4,
            contentWidth,
            AC.L:Get("Forecast.HeroHeadline"),
            highest and highest.title or AC.L:Get("Forecast.EmptyTitle"),
            highest and highest.description or AC.L:Get("Forecast.EmptyDescription"))

        yOffset = self:BeginSection(scrollChild, "Forecast.SectionUpcoming", yOffset)
        yOffset = self:LayoutForecastRows(scrollChild, page.Rows, items, yOffset, contentWidth, "Forecast.EmptyDescription")
        yOffset = self:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, LayoutForecast)

    local lastRefresh = service:GetLastRefresh()
    page.LastUpdatedText:SetText(lastRefresh > 0 and AC.L:Format("Dashboard.LastUpdatedFormat", date("%H:%M:%S", lastRefresh)) or "")

end

return Dashboard
