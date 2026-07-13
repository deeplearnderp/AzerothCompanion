-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Formatting Helpers
--
-- Dashboard/Recommendation-specific COMPOSED presentation -- star
-- rendering, status glyphs, trend arrows. Generic primitives (numbers,
-- durations, money, dates, semantic colors) moved to Core/Presentation/
-- Presentation.lua (Presentation Layer centralization) since they're
-- addon-wide, not Dashboard-specific -- a module/service can use them the
-- same as a page. The functions/constants below stay thin backward-
-- compatible aliases to Presentation's versions so the ~50 existing
-- AC.DashboardFormat.X(...) call sites across the codebase keep working
-- completely unchanged -- a non-breaking migration, not a rewrite.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DashboardFormat = {}
AC.DashboardFormat = DashboardFormat

-------------------------------------------------------------------------------
-- Numbers / Durations / Money / Clock -- moved to AC.Presentation, kept
-- here as aliases (see file header).
-------------------------------------------------------------------------------

DashboardFormat.FormatNumberWithCommas = AC.Presentation.FormatNumberWithCommas
DashboardFormat.FormatDuration = AC.Presentation.FormatDuration
DashboardFormat.FormatMoney = AC.Presentation.FormatMoney
DashboardFormat.FormatClock = AC.Presentation.FormatClock

-------------------------------------------------------------------------------
-- Priority Stars
--
-- Presentation-only encoding of the priority number RecommendationEngine
-- already sorts by -- not a new scale the engine needs to know about.
-------------------------------------------------------------------------------

DashboardFormat.STAR_FILLED = "\226\152\133" -- "★"
DashboardFormat.STAR_EMPTY = "\226\152\134" -- "☆"

-------------------------------------------------------------------------------
-- Accordion Disclosure Glyphs
--
-- Accordion Polish Pass -- Blizzard-style expand/collapse indicators for
-- LayoutAccordionRows (Rows.lua). Same raw-UTF-8-glyph-constant
-- convention as STAR_FILLED/STAR_EMPTY above.
-------------------------------------------------------------------------------

DashboardFormat.DISCLOSURE_COLLAPSED = "\226\150\182" -- "▶"
DashboardFormat.DISCLOSURE_EXPANDED = "\226\150\188" -- "▼"

-------------------------------------------------------------------------------
-- Highlight Color
--
-- The one gold accent color titles/headers/stars use addon-wide (v1.0
-- Polish Sprint) -- now owned by AC.Presentation (Presentation Layer
-- centralization) alongside the other semantic colors, kept here as an
-- alias so existing call sites are unaffected. `SetHighlightColor
-- (fontString)` is the terse form for the common "tint this FontString
-- gold" call site; `HIGHLIGHT_COLOR` (a plain `{r, g, b}` table) is for
-- the rarer case that needs the raw components, e.g. a color-keyed lookup
-- table.
-------------------------------------------------------------------------------

DashboardFormat.HIGHLIGHT_COLOR = AC.Presentation.HIGHLIGHT_COLOR

function DashboardFormat.SetHighlightColor(fontString)

    fontString:SetTextColor(DashboardFormat.HIGHLIGHT_COLOR[1], DashboardFormat.HIGHLIGHT_COLOR[2], DashboardFormat.HIGHLIGHT_COLOR[3])

end

-------------------------------------------------------------------------------
-- Status Glyphs
--
-- Shared by every pooled "completed/failed" row: the History Table
-- (Rows.lua) and the Home page's Recent Activity feed (Home.lua) both
-- render one of these two colored glyphs per record -- previously
-- written out as an inline literal only in Rows.lua; promoted here once
-- a second call site needed the exact same glyph (Home Dashboard
-- Evolution).
-------------------------------------------------------------------------------

DashboardFormat.CHECK_SUCCESS = "|cff40c040\226\156\147|r" -- green "✓"
DashboardFormat.CHECK_FAILURE = "|cffc04040\226\156\151|r" -- red "✗"

-------------------------------------------------------------------------------
-- Trend Arrows (Progress Dashboard)
--
-- One fixed, colored glyph per ProgressSummaryService trend direction --
-- "Improving"/"Declining"/"Stable" map to an up/down/flat arrow;
-- "Unknown" (not enough historical data to compare) maps to an empty
-- string, since "only display trends supported by real data" means a
-- caller should simply not render that row at all, never show a blank
-- or guessed arrow in its place.
-------------------------------------------------------------------------------

local TREND_ARROWS =
{
    Improving = "|cff40c040\226\150\178|r", -- green "▲"
    Declining = "|cffc04040\226\150\188|r", -- red "▼"
    Stable = "|cff999999\226\128\148|r", -- gray "—"
}

function DashboardFormat.GetTrendArrow(direction)

    return TREND_ARROWS[direction] or ""

end

function DashboardFormat.PriorityToStars(priority)

    priority = tonumber(priority) or 0

    local stars = math.ceil(priority / 20)

    if stars < 1 then
        stars = 1
    elseif stars > 5 then
        stars = 5
    end

    return stars

end

-- The finished "filled/empty star" string -- extracted (Recommendation
-- Inspector) once a third call site needed the exact same
-- PriorityToStars-then-string.rep composition Rows.lua's LayoutItemRows
-- and DashboardCard's SetStarRating each already wrote inline;
-- DashboardCard's copy had also drifted into its own duplicate
-- priority-to-stars formula (identical math, just never routed through
-- PriorityToStars) rather than a wording difference -- both now call
-- this one function instead.
function DashboardFormat.RenderStars(priority)

    local stars = DashboardFormat.PriorityToStars(priority)

    return string.rep(DashboardFormat.STAR_FILLED, stars) .. string.rep(DashboardFormat.STAR_EMPTY, 5 - stars)

end

return DashboardFormat
