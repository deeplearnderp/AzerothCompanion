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
-- Favorite Marker
--
-- A single "this player is a favorite" glyph -- PlayerJournal's own
-- concept, unrelated to recommendation priority (see Priority Label
-- below). Plain ASCII per the addon's established fallback convention --
-- the original Unicode "★" (U+2605, Miscellaneous Symbols block) was
-- confirmed live to render as a missing-character box, the same failure
-- already confirmed for the Geometric Shapes block (▶/▼/▲, see
-- DISCLOSURE_*/TREND_ARROWS below) -- Blizzard's client font (FRIZQT__.TTF)
-- doesn't cover either block.
-------------------------------------------------------------------------------

DashboardFormat.STAR_FILLED = "*"

-------------------------------------------------------------------------------
-- Priority Label
--
-- UI Polish Pass -- replaces the former 5-glyph "filled/empty star row"
-- rendering of a recommendation's priority. Two real problems with that
-- row, not one: (1) it was the same tofu-box bug as the favorite marker
-- above -- a row of up to 5 repeated unverified glyphs directly under a
-- card's title, which is what actually looked like "a stray colored
-- rectangle" / "placeholder squares" in a live report; (2) even with a
-- safe ASCII glyph, the row was genuinely redundant on the Recommendations
-- page -- Dashboard.RecommendationMetaFormat already showed the same
-- priority as a raw number on the very same row. A three-tier label
-- (High/Medium/Low) is more readable at a glance than counting filled vs.
-- empty glyphs, carries real color meaning (paired with a semantic color,
-- used to elevate Priority/Confidence above plain body text on
-- DashboardCard -- see SetDetailSections' `color` field), and replaces the
-- redundant raw number in the Recommendations page's meta line too.
-- Thresholds mirror the retired 5-star scale collapsed to 3 tiers (was:
-- 1-2 stars/Low, 3 stars/Medium, 4-5 stars/High).
-------------------------------------------------------------------------------

local PRIORITY_TIERS =
{
    { max = 40, labelKey = "Dashboard.PriorityLow", color = "dim" },
    { max = 60, labelKey = "Dashboard.PriorityMedium", color = "warning" },
    { max = 101, labelKey = "Dashboard.PriorityHigh", color = "critical" },
}

function DashboardFormat.GetPriorityLabel(priority)

    priority = tonumber(priority) or 0

    for _, tier in ipairs(PRIORITY_TIERS) do

        if priority <= tier.max then
            return AC.L:Get(tier.labelKey), tier.color
        end

    end

    return AC.L:Get("Dashboard.PriorityHigh"), "critical"

end

-------------------------------------------------------------------------------
-- Confidence Color
--
-- UI Polish Pass -- pairs RecommendationEngine's existing High/Medium/Low
-- confidence value (already localized via Dashboard.ConfidenceX) with a
-- semantic color, the same "label + color" treatment Priority above now
-- gets, so both read as equally important at a glance on DashboardCard.
-------------------------------------------------------------------------------

local CONFIDENCE_COLORS =
{
    High = "success",
    Medium = "warning",
    Low = "dim",
}

function DashboardFormat.GetConfidenceColor(confidence)

    return CONFIDENCE_COLORS[confidence] or "dim"

end

-------------------------------------------------------------------------------
-- Equipment Health Tier
--
-- Equipment Health feature -- InventoryModule exposes plain numbers only
-- (worstDurability, brokenItems); this is where those numbers become a
-- word and a color (Dashboard owns presentation, module owns data). Keyed
-- off worstDurability, not overallDurability -- see
-- InventoryModule:GetEquipmentHealthSummary's own comment for why the
-- worst single piece, not the average, should decide severity. Any broken
-- item forces Critical outright, bypassing the percentage thresholds --
-- "broken" is a hard fact (the item is non-functional), not a point on a
-- gradient.
-------------------------------------------------------------------------------

local EQUIPMENT_HEALTH_TIERS =
{
    { min = 90, labelKey = "Inventory.EquipmentHealthExcellent", color = "success" },
    { min = 70, labelKey = "Inventory.EquipmentHealthGood", color = "success" },
    { min = 40, labelKey = "Inventory.EquipmentHealthFair", color = "warning" },
    { min = 0, labelKey = "Inventory.EquipmentHealthCritical", color = "critical" },
}

function DashboardFormat.GetEquipmentHealthTier(worstDurability, brokenItems)

    if (brokenItems or 0) > 0 then
        return AC.L:Get("Inventory.EquipmentHealthCritical"), "critical"
    end

    worstDurability = tonumber(worstDurability)

    if not worstDurability then
        return AC.L:Get("Common.Unknown"), "dim"
    end

    for _, tier in ipairs(EQUIPMENT_HEALTH_TIERS) do

        if worstDurability >= tier.min then
            return AC.L:Get(tier.labelKey), tier.color
        end

    end

    return AC.L:Get("Inventory.EquipmentHealthCritical"), "critical"

end

-------------------------------------------------------------------------------
-- Storage Readiness Text
--
-- Turns StorageModule:GetReadinessFacts() (live readiness, historical
-- Storage-Knowledge-Base readiness, no wording) into the actual
-- "Ready" / "62% Ready" / "Bank Not Connected" / "No Storage Snapshot"
-- string -- same module-owns-data / Dashboard-owns-presentation split as
-- GetEquipmentHealthTier above. Single home for this branch logic,
-- shared by InventoryManager and the Dashboard Storage page so both
-- always render the same wording for the same facts.
-------------------------------------------------------------------------------

function DashboardFormat.GetStorageReadinessText(facts)

    if not facts or not facts.enabled then
        return AC.L:Get("Common.Unknown")
    end

    if facts.hasLiveScan then

        if not facts.live then
            return AC.L:Get("InventoryManager.BankNotConnected")
        end

        if facts.live.ready then
            return AC.L:Get("InventoryManager.Ready")
        end

        return AC.L:Format("InventoryManager.ReadinessFormat", facts.live.readinessPercent or 0)

    end

    if facts.historical then

        if facts.historical.ready then
            return AC.L:Get("InventoryManager.Ready")
        end

        return AC.L:Format("InventoryManager.ReadinessFormat", facts.historical.readinessPercent or 0)

    end

    return AC.L:Get("InventoryManager.NoSnapshotTitle")

end

-------------------------------------------------------------------------------
-- Accordion Disclosure Glyphs
--
-- Accordion Polish Pass -- expand/collapse indicators for
-- LayoutAccordionRows (Rows.lua). Plain ASCII, not Unicode -- the
-- original ▶/▼ (U+25B6/U+25BC, Geometric Shapes block) glyphs render as
-- missing-character boxes in-game because Blizzard's client font
-- (FRIZQT__.TTF) doesn't cover that block. No verified Blizzard native
-- disclosure texture/atlas to fall back on, so ASCII per the addon's
-- own fallback convention (same one CHECK_SUCCESS/CHECK_FAILURE above
-- would need if their glyphs ever proved unsupported).
-------------------------------------------------------------------------------

DashboardFormat.DISCLOSURE_COLLAPSED = ">"
DashboardFormat.DISCLOSURE_EXPANDED = "v"

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
-- Evolution). The bare glyphs themselves (Presentation.CHECK_GLYPH/
-- CROSS_GLYPH) are addon-wide primitives -- these constants just add the
-- Dashboard's own color composition on top (Presentation Asset Audit).
-------------------------------------------------------------------------------

DashboardFormat.CHECK_SUCCESS = "|cff40c040" .. AC.Presentation.CHECK_GLYPH .. "|r" -- green "✓"
DashboardFormat.CHECK_FAILURE = "|cffc04040" .. AC.Presentation.CROSS_GLYPH .. "|r" -- red "✗"

-------------------------------------------------------------------------------
-- Bullet
--
-- Presentation Asset Audit -- single owner for the inline "• text" line
-- style, previously written out as an independent raw-byte literal at 5
-- call sites (Sections.lua, Home.lua x2, RecommendationInspector.lua)
-- with no shared constant.
-------------------------------------------------------------------------------

DashboardFormat.BULLET = "\226\128\162" -- "•"

-------------------------------------------------------------------------------
-- Trend Arrows (Progress Dashboard)
--
-- One fixed, colored glyph per ProgressSummaryService trend direction --
-- "Improving"/"Declining"/"Stable" map to an up/down/flat arrow;
-- "Unknown" (not enough historical data to compare) maps to an empty
-- string, since "only display trends supported by real data" means a
-- caller should simply not render that row at all, never show a blank
-- or guessed arrow in its place.
--
-- Presentation Asset Audit -- originally Unicode ▲/▼/— (U+25B2/U+25BC/
-- U+2014). ▼ is the exact codepoint confirmed to render as a
-- missing-character box in-game (the accordion disclosure glyph fix,
-- same font). ▲ shares its Unicode block with that confirmed failure
-- and — was never independently confirmed either, so rather than ship
-- two of three as unverified Unicode, all three became plain ASCII for
-- one internally consistent trend-indicator set.
-------------------------------------------------------------------------------

local TREND_ARROWS =
{
    Improving = "|cff40c040^|r", -- green "^"
    Declining = "|cffc04040v|r", -- red "v"
    Stable = "|cff999999-|r", -- gray "-"
}

function DashboardFormat.GetTrendArrow(direction)

    return TREND_ARROWS[direction] or ""

end

return DashboardFormat
