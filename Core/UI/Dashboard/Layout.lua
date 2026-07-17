-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Layout Constants
--
-- Every magic number that controls Dashboard spacing/sizing lives here so
-- the whole Dashboard shares one visual rhythm. Nothing in any Dashboard
-- file should hand-tune padding/spacing per page/card -- change it here
-- and every page/card follows. Split out of the former monolithic Dashboard
-- (Technical Debt & Completion Sprint / Dashboard Refactor) so every other
-- Dashboard file can share these without duplicating them -- Lua has no
-- cross-file `local`, so this table is the mechanism that replaces what
-- used to be plain file-local constants.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DashboardLayout = {}
AC.DashboardLayout = DashboardLayout

-- Window ------------------------------------------------------------------

DashboardLayout.WINDOW_WIDTH = 420
DashboardLayout.WINDOW_HEIGHT = 720
DashboardLayout.CONTENT_TOP_OFFSET = -50

-- Home Cards ----------------------------------------------------------------

DashboardLayout.CARD_WIDTH = 360
DashboardLayout.CARD_HEIGHT = 112
DashboardLayout.CARD_HEIGHT_WITH_BAR = 128
DashboardLayout.RECOMMENDATION_HEIGHT = 150
DashboardLayout.HOME_SECTION_GAP = 16

-- DashboardCard internal layout (Presentation System v2) -- moved here,
-- identical values, from Core/UI/Widgets/DashboardCard.lua's own
-- previously-independent constant block. That file never referenced this
-- one despite this file's own header rule ("nothing should hand-tune
-- padding per card") -- the single largest violator of that rule found in
-- the Phase 1 audit. DashboardCard.lua reads these inline at the point of
-- use inside Create() rather than caching a file-top `local Layout =
-- AC.DashboardLayout` upvalue -- Widgets/DashboardCard.lua loads before
-- this file in the .toc, so a cached upvalue would capture nil.
--
-- UI Polish Pass -- every gap below widened one notch (a live visual
-- review found the card interior "cramped," most visibly on the
-- Highest Priority card's dense recommendation content). Values chosen to
-- read as deliberate breathing room, not the maximum spacing that still
-- fits -- Blizzard's own panels stay dense, not airy.

DashboardLayout.CARD_PADDING_LEFT = 14
DashboardLayout.CARD_PADDING_RIGHT = 14
DashboardLayout.CARD_PADDING_TOP = 14
DashboardLayout.CARD_PADDING_BOTTOM = 14
DashboardLayout.CARD_INDICATOR_RESERVE = 20

DashboardLayout.CARD_TITLE_TO_PRIMARY_GAP = 12
DashboardLayout.CARD_PRIMARY_TO_SECONDARY_GAP = 10
DashboardLayout.CARD_SECONDARY_TO_DETAIL_GAP = 10
DashboardLayout.CARD_DETAIL_TO_BAR_GAP = 8

-- Detail Sections (Home Dashboard Evolution) -- a labeled "caption, then
-- value" block. CARD_SECTION_GAP separates one section from the next;
-- CARD_SECTION_LABEL_BODY_GAP separates a section's own caption from its
-- value.
DashboardLayout.CARD_SECTION_GAP = 10
DashboardLayout.CARD_SECTION_LABEL_BODY_GAP = 3

DashboardLayout.CARD_ICON_SIZE = 20
DashboardLayout.CARD_ICON_TITLE_GAP = 6

DashboardLayout.CARD_BAR_ANIMATION_DURATION = 0.35

-- UI Polish Pass -- the top-right action-button row (Home's Highest
-- Priority card: Dismiss + Why?). Both it and the click-navigation
-- indicator (DashboardCard.lua) now anchor at CARD_PADDING_RIGHT/TOP --
-- the same shared padding every other edge of the card already respects,
-- rather than independent hand-typed magic numbers (-10/-14/-4) that
-- could silently drift out of alignment with a future padding change.
DashboardLayout.CARD_ACTION_BUTTON_GAP = 6

-- Data Pages ------------------------------------------------------------------
--
-- Dashboard Scrollbar Standardization -- PAGE_CONTENT_WIDTH_FULL used to
-- have a narrower SCROLLABLE sibling, reserved only once a page's content
-- was actually measured to overflow, so a non-scrolling page could use
-- the couple dozen extra pixels a hidden scrollbar wasn't using. That
-- traded away a harder requirement: the scrollbar's own screen position
-- (and therefore every page's ScrollFrame's own outer bounds, which the
-- scrollbar anchors against) has to be identical and FIXED on every page,
-- whether or not that page happens to be scrolling right now -- a
-- scrollbar that only sometimes reserves its footprint is a scrollbar
-- that can appear to jump when content crosses the overflow threshold.
-- Every ScrollFrame (Dashboard:CreatePageScrollFrame, Sections.lua) now
-- reserves SCROLLBAR_RESERVE unconditionally, so there is only one
-- content width left -- not a FULL/SCROLLABLE pair to measure and choose
-- between.

DashboardLayout.PAGE_PADDING = 16
DashboardLayout.PAGE_HEADER_HEIGHT = 46
DashboardLayout.PAGE_BOTTOM_INSET = 8
DashboardLayout.PAGE_BOTTOM_PADDING = 12
DashboardLayout.SCROLLBAR_RESERVE = 24

-- Page Header (UI Polish Pass -- Navigation Audit, then Header Polish Pass)
-- -- the one Back/Title/Updated header every secondary page shares via
-- Dashboard:CreateDataPage (Sections.lua). PAGE_HEADER_TITLE_TOP/
-- PAGE_HEADER_SIDE_TOP are deliberately different values, not the same
-- offset reused twice: Title uses a taller font (GameFontNormalLarge) than
-- Updated (GameFontDisableSmall), and the 4px gap between them approximates
-- optical center-alignment across the two font sizes (half the visible
-- height difference) rather than both simply starting flush at the same Y,
-- which reads as "Title floats high" once the fonts differ this much. Back
-- is now a real UIPanelButtonTemplate button rather than text, so its
-- optical alignment against Title depends on the template's own internal
-- label-centering, not just font height -- this still anchors it at
-- PAGE_HEADER_SIDE_TOP as the best available reference point, but exact
-- pixel alignment against Title hasn't been confirmed against a live
-- client and may want a small nudge once seen rendered. PAGE_HEADER_HEIGHT
-- grew 36 -> 40 (Navigation Audit) -> 46 (Header Polish Pass, to give the
-- now-22px-tall Back button the same ~8px clearance before the divider
-- that DIVIDER_MARGIN_BOTTOM already establishes as this codebase's own
-- standard breathing room before a divider, rather than the button
-- crowding it).
DashboardLayout.PAGE_HEADER_TITLE_TOP = 4
DashboardLayout.PAGE_HEADER_SIDE_TOP = 8

-- The one content width every data page measures and builds at -- derived
-- from PAGE_PADDING (left inset) and SCROLLBAR_RESERVE (right inset,
-- reserved unconditionally -- see the comment above), matching exactly
-- what Dashboard:CreatePageScrollFrame's default insets produce.
DashboardLayout.PAGE_CONTENT_WIDTH_FULL = DashboardLayout.WINDOW_WIDTH - DashboardLayout.PAGE_PADDING - DashboardLayout.SCROLLBAR_RESERVE

-- Field Rows ------------------------------------------------------------------

DashboardLayout.ROW_HEIGHT = 20
DashboardLayout.ROW_INDENT = 8
DashboardLayout.SECTION_HEADER_GAP = 22
DashboardLayout.SECTION_GROUP_GAP = 22
DashboardLayout.FIELD_LABEL_WIDTH = 180
DashboardLayout.FIELD_LABEL_VALUE_GAP = 10

-- Dividers --------------------------------------------------------------------

DashboardLayout.DIVIDER_MARGIN_TOP = 4
DashboardLayout.DIVIDER_HEIGHT = 1
DashboardLayout.DIVIDER_MARGIN_BOTTOM = 8

-- Hero Section ------------------------------------------------------------
--
-- Blizzard has no "hero-sized" font template, so this creates one custom
-- font object sized larger than any template used elsewhere in the
-- Dashboard -- inheriting the current locale's actual font file from the
-- already-verified GameFontNormalLarge rather than hardcoding a font
-- path, so it stays correct for any locale.

DashboardLayout.HERO_VALUE_FONT = CreateFont("AzerothCompanionHeroValueFont")

do
    local fontFile, _, fontFlags = GameFontNormalLarge:GetFont()
    DashboardLayout.HERO_VALUE_FONT:SetFont(fontFile, 30, fontFlags)

    -- Kept as the literal here rather than DashboardFormat.HIGHLIGHT_COLOR
    -- (the shared constant every other gold-text call site now uses) --
    -- Layout.lua loads before Format.lua (see the .toc), and this runs at
    -- file-load time, not inside a function body, so AC.DashboardFormat
    -- would not exist yet when this line executes.
    DashboardLayout.HERO_VALUE_FONT:SetTextColor(1, 0.82, 0)
end

DashboardLayout.HERO_HEADLINE_GAP = 4
DashboardLayout.HERO_VALUE_GAP = 2
DashboardLayout.HERO_CAPTION_GAP = 4
DashboardLayout.HERO_BOTTOM_GAP = 16

-- Statistics Grid -----------------------------------------------------------
--
-- Shared by Key Statistics/Season Statistics/Storage's grids and any
-- future module wanting the same "glanceable numbers" treatment -- two
-- label/value cells per row, larger typography than a normal field row.

DashboardLayout.STAT_CELL_GAP = 12
DashboardLayout.STAT_ROW_HEIGHT = 40
DashboardLayout.STAT_LABEL_GAP = 2

-- History Table ---------------------------------------------------------------
--
-- Fixed columns (status/date/level/name/time) for MythicPlus's Recent
-- Runs table -- generic enough for a future module's own recorded history
-- to reuse the same table/expand mechanism.

DashboardLayout.HISTORY_STATUS_WIDTH = 16
DashboardLayout.HISTORY_DATE_WIDTH = 44
DashboardLayout.HISTORY_LEVEL_WIDTH = 30
DashboardLayout.HISTORY_TIME_WIDTH = 44
DashboardLayout.HISTORY_COLUMN_GAP = 6
DashboardLayout.HISTORY_ROW_HEIGHT = 18
DashboardLayout.HISTORY_ROW_GAP = 6

-- Activity Log's journal rows use the same compact time column as the
-- history table, with one subordinate context line beneath the title.
DashboardLayout.ACTIVITY_TIMELINE_ROW_HEIGHT = 34

-------------------------------------------------------------------------------
-- Accordion Engine (generic)
--
-- Shared spacing for Dashboard:LayoutAccordionRows -- deliberately NOT
-- named History* (those stay MythicPlus/History-table-scoped, unchanged)
-- since this engine now has more than one caller (MythicPlus's Recent
-- Runs via a thin LayoutHistoryRows wrapper, and Accomplishments'
-- expandable rows). Collapsed single-line row height reuses the existing
-- generic Layout.ROW_HEIGHT -- no new height constant needed for that.
-------------------------------------------------------------------------------

DashboardLayout.ACCORDION_ROW_GAP = 6
DashboardLayout.ACCORDION_DETAIL_GAP = 4
DashboardLayout.ACCORDION_DETAIL_BOTTOM_PADDING = 8

-- Accordion Polish Pass -- reserved left-column width for the disclosure
-- icon LayoutAccordionRows now draws on every row (every caller's own
-- collapsed-row content shifts right by this much), and how far expanded
-- detail fields indent beyond that so they read as visually nested under
-- the row's own (now-shifted) title rather than flush with it.
DashboardLayout.ACCORDION_DISCLOSURE_WIDTH = 14
DashboardLayout.ACCORDION_DETAIL_INDENT = DashboardLayout.ACCORDION_DISCLOSURE_WIDTH + DashboardLayout.ROW_INDENT + 8

-------------------------------------------------------------------------------
-- Character Journey
--
-- Spacing for Pages/Journey.lua's year separators -- a lighter-weight
-- divider than a full BeginSection/EndSection (wrong tool for a per-year
-- runtime string, and visually heavy repeated once per year on a
-- long-lived character).
-------------------------------------------------------------------------------

DashboardLayout.JOURNEY_YEAR_SEPARATOR_GAP = 10

-------------------------------------------------------------------------------
-- Navigation
--
-- "Settings" is intentionally not part of this in-window page stack.
-- It already has a fully working, standalone SettingsWindow, and folding
-- it into a "page" here would mean either duplicating that functionality
-- or temporarily replacing it with a placeholder -- neither of which is
-- an improvement. The Settings button keeps opening the real window, as
-- it always has.
-------------------------------------------------------------------------------

DashboardLayout.VALID_PAGES =
{
    Home = true,
    Recommendations = true,
    Profile = true,
    Inventory = true,
    Accomplishments = true,
    Dungeons = true,
    ActivityLog = true,
    MythicPlus = true,
    Storage = true,
    Weekly = true,
    Progress = true,
    Statistics = true,
    Journey = true,

    -- Navigation UX Sprint -- Recommendation Details, formerly the
    -- standalone RecommendationInspector popup, is now a real Dashboard
    -- page like every other entry above.
    RecommendationDetails = true,
}

return DashboardLayout
