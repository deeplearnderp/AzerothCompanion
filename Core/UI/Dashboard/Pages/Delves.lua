-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Delves
--
-- Delve-owned completion history, read only through DelvesModule's public API.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local ActivityPresentation = AC.DashboardActivityPresentation

function Dashboard:UpdateDelvesPage(frame)

    local page = frame.Pages and frame.Pages.Delves

    if not page then
        return
    end

    local delvesModule = AC.Core and AC.Core:GetModule("Delves")

    if not delvesModule then
        return
    end

    local recentDelves = delvesModule:GetRecentDelves(10)
    local scrollChild = page.ScrollChild

    local function Layout_(width)

        page.ContentWidth = width
        page.Pools = page.Pools or {}
        page.Pools.RecentDelves = page.Pools.RecentDelves or {}

        local yOffset = -4

        yOffset = self:BeginSection(scrollChild, "Delves.SectionRecentDelves", yOffset)
        yOffset = self:LayoutTextLines(scrollChild, page.Pools.RecentDelves, recentDelves, yOffset, width, "Delves.NoDelvesRecorded", function(record)
            return ActivityPresentation:FormatLine(record)
        end)
        yOffset = self:EndSection(yOffset)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
