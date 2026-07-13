-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Recommendations
--
-- The only place the Dashboard reads recommendation data. Titles and
-- descriptions arrive already localized from the Recommendation Engine --
-- the Dashboard only localizes its own chrome (the meta line, the empty
-- state). This is the one page whose content is genuinely variable-length,
-- so it lays itself out twice when necessary: once at the full width to
-- see if it fits, and -- only if it doesn't -- again at the narrower
-- scrollbar-safe width, the same "measure, then commit" shape
-- BuildDataPageContent uses for the static pages, just using the real
-- pooled row objects instead of a widget-free measure pass, since those
-- rows are reused across refreshes anyway.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

function Dashboard:UpdateRecommendationsPage(frame)

    local page = frame.Pages and frame.Pages.Recommendations

    if not page then
        return
    end

    -- Keep the list current even if this page is visited without Home
    -- having refreshed the engines first.
    self:RefreshEngines(page)

    local recommendations = {}

    if AC.RecommendationEngine then
        recommendations = AC.RecommendationEngine:GetRecommendations() or {}
    end

    page.Rows = page.Rows or {}

    local scrollChild = page.ScrollChild

    -- Presentation System v2 -- "Caught Up" deliberately keeps its own
    -- celebratory, centered, full-size treatment rather than the plain
    -- dim single line every other page's empty state uses (see
    -- Dashboard:ShowEmptyLine) -- being caught up is a genuinely positive,
    -- distinct moment. What WAS a bug, fixed here: the color was an
    -- untied (0.85,0.85,0.85) instead of a real semantic token, and the
    -- width/height were hardcoded literals (PAGE_CONTENT_WIDTH_FULL, a
    -- magic 60) bypassing real measurement entirely -- now routed through
    -- the same MeasureAndApplyScrolling every other dynamic page uses.
    local function LayoutRows(contentWidth)

        if #recommendations == 0 then

            for _, row in ipairs(page.Rows) do
                row:Hide()
            end

            if not page.EmptyText then

                local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                emptyText:SetJustifyH("CENTER")

                local r, g, b = unpack(AC.Presentation.GetSemanticColor("success"))
                emptyText:SetTextColor(r, g, b)

                page.EmptyText = emptyText

            end

            page.EmptyText:ClearAllPoints()
            page.EmptyText:SetPoint("TOP", 0, -10)
            page.EmptyText:SetWidth(contentWidth)
            page.EmptyText:SetText(AC.L:Get("Dashboard.CaughtUp"))
            page.EmptyText:Show()

            return (page.EmptyText:GetStringHeight() or 0) + 10 + Layout.PAGE_BOTTOM_PADDING

        end

        if page.EmptyText then
            page.EmptyText:Hide()
        end

        local yOffset = self:LayoutItemRows(scrollChild, page.Rows, recommendations, -4, contentWidth, "Dashboard.CaughtUp", nil, true)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, LayoutRows)

end

return Dashboard
