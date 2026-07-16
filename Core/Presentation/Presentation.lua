-------------------------------------------------------------------------------
-- Azeroth Companion
-- Presentation Layer
--
-- Generic, addon-wide formatting primitives -- dates, numbers, durations,
-- semantic colors. Not Dashboard-specific: a module or service can call
-- this the same as a page can. A leaf module, no lifecycle (Initialize/
-- Enable/etc.), same shape as Core/UI/Dashboard/Format.lua already used.
--
-- Why this exists: auditing a real bug (accomplishment/history dates
-- rendering with no year, e.g. "06/23" instead of "Jun 23, 2026" -- a real
-- problem for characters played 10-20 years) found `date("%b %d", ...)`
-- with no `%Y` duplicated at 10 separate call sites, while 11 OTHER sites
-- already correctly included the year -- the addon was already visually
-- inconsistent with itself. The same audit found the same "same concept,
-- duplicated and drifted" pattern for numbers (raw string.format at 8+
-- sites) and semantic colors (success/warning/critical literals at 10+
-- sites, with confirmed drift -- two different greens, two different reds,
-- for the same meaning). This module centralizes exactly what had
-- demonstrated duplication -- see docs/GameplayModuleArchitecture.md
-- section 8 for the full architecture and what was deliberately deferred
-- (Typography/Icon Styling/Density/Themes/Accessibility/UI Profiles --
-- zero duplication found for any of them, not built as speculative
-- scaffolding).
--
-- Core/UI/Dashboard/Format.lua (AC.DashboardFormat) keeps everything that
-- is Dashboard/Recommendation-specific COMPOSED presentation (star
-- rendering, status glyphs, trend arrows) -- not generic primitives, a
-- real category boundary. Its FormatNumberWithCommas/FormatDuration/
-- FormatMoney/FormatClock/HIGHLIGHT_COLOR are now thin aliases to this
-- module's versions, so the ~50 existing AC.DashboardFormat.X(...) call
-- sites across the codebase keep working completely unchanged -- a
-- non-breaking migration, not a rewrite-everything pass.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local tonumber = tonumber
local time = time

local Presentation = {}
AC.Presentation = Presentation

-------------------------------------------------------------------------------
-- Numbers / Durations / Money / Clock
--
-- Moved verbatim from Format.lua -- identical logic, relocated because
-- these are generic primitives, not Dashboard-specific.
-------------------------------------------------------------------------------

function Presentation.FormatNumberWithCommas(number)

    number = tonumber(number) or 0

    local formatted = string.format("%d", number)
    local separatorCount

    repeat
        formatted, separatorCount = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until separatorCount == 0

    return formatted

end

function Presentation.FormatDuration(totalSeconds)

    totalSeconds = tonumber(totalSeconds) or 0

    if totalSeconds < 0 then
        totalSeconds = 0
    end

    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh %dm", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end

end

function Presentation.FormatMoney(copper)

    copper = tonumber(copper) or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    return string.format("%sg %ds %dc", Presentation.FormatNumberWithCommas(gold), silver, bronze)

end

function Presentation.FormatClock(totalSeconds)

    totalSeconds = tonumber(totalSeconds) or 0

    if totalSeconds < 0 then
        totalSeconds = 0
    end

    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)

    return string.format("%d:%02d", minutes, seconds)

end

-------------------------------------------------------------------------------
-- Generic Number / Percent Formatting
--
-- Consolidates the 8+ call sites that each hand-wrote their own
-- string.format("%.0f", x)/("%.0f%%", x). FormatRating/FormatItemLevel
-- are semantically-named wrappers over the same FormatNumber(value, 0) --
-- their logic was already identical at every real call site found, so
-- this is one implementation with readable names at the call site, not
-- three separate formatters.
--
-- Of the 3 signed "+/-" call sites (Profile's itemLevelGained, Inventory's
-- bagUsageChange, MythicPlus's rating-change line), only Profile's is
-- consolidated below (Home Dashboard Evolution, Profile card pass) --
-- it now has two real call sites (the Profile page and Home's Profile
-- card) sharing one implementation instead of drifting into two copies.
-- Inventory's and MythicPlus's own sites are deliberately untouched --
-- out of scope for this pass, not overlooked. FormatSignedNumber matches
-- the behavior Profile's page already shipped (exactly 0 gets no "+")
-- rather than resolving it fresh -- docs/DEVELOPMENT_BACKLOG.md's open
-- question (whether 0 SHOULD earn a "+") is a UX judgment call, not
-- something this consolidation settles; it still needs a live look.
-------------------------------------------------------------------------------

function Presentation.FormatNumber(value, decimals)

    decimals = tonumber(decimals) or 0

    return string.format("%." .. decimals .. "f", tonumber(value) or 0)

end

function Presentation.FormatSignedNumber(value, decimals)

    value = tonumber(value) or 0

    if value > 0 then
        return "+" .. Presentation.FormatNumber(value, decimals)
    end

    return Presentation.FormatNumber(value, decimals)

end

function Presentation.FormatPercent(value, decimals)

    return Presentation.FormatNumber(value, decimals) .. "%"

end

function Presentation.FormatRating(value)

    return Presentation.FormatNumber(value, 0)

end

function Presentation.FormatItemLevel(value)

    return Presentation.FormatNumber(value, 0)

end

-------------------------------------------------------------------------------
-- Dates -- the actual bug fix. Every style ALWAYS includes a 4-digit year.
--
-- "shortTime"'s double space before %H:%M matches the exact convention
-- RecommendationInspector.lua's own already-correct date call sites
-- already used (its Timestamp field, its Recommendation History section)
-- -- migrated output matches this addon's existing correct convention,
-- not a third variant.
-------------------------------------------------------------------------------

local DATE_STYLES =
{
    short = "%b %d, %Y",
    shortTime = "%b %d, %Y  %H:%M",
}

function Presentation.FormatDate(timestamp, style)

    timestamp = timestamp or time()

    return date(DATE_STYLES[style or "short"], timestamp)

end

-------------------------------------------------------------------------------
-- Relative Time
--
-- A genuinely new capability -- no existing call site in this codebase
-- reused a shared "time since X" formatter (PlayerJournalModule's stale-
-- favorite check hand-rolls its own day math and sentence inline).
-- Thresholds are deliberately conservative: under 30 days gets a real,
-- precise "N days ago"; 30 days and older falls back to FormatDate's
-- absolute "short" style rather than a fabricated "N months/years ago"
-- bucket Blizzard/this addon has no real basis for rounding correctly
-- (months have different lengths; a naive "days / 30" would drift).
-------------------------------------------------------------------------------

local SECONDS_PER_DAY = 86400

function Presentation.FormatRelativeTime(timestamp)

    if not timestamp or timestamp <= 0 then
        return AC.L:Get("Common.Unknown")
    end

    local days = math.floor((time() - timestamp) / SECONDS_PER_DAY)

    if days <= 0 then
        return AC.L:Get("Presentation.RelativeToday")
    end

    if days == 1 then
        return AC.L:Get("Presentation.RelativeYesterday")
    end

    if days < 30 then
        return AC.L:Format("Presentation.RelativeDaysAgoFormat", days)
    end

    return Presentation.FormatDate(timestamp, "short")

end

-------------------------------------------------------------------------------
-- Semantic Colors
--
-- Consolidates drifted literals (e.g. two different greens meaning
-- "success" at different call sites) into one canonical {r,g,b} per
-- meaning. HIGHLIGHT_COLOR is the v1.0 Polish Sprint gold-accent constant,
-- promoted here from Format.lua since it's exactly this same category of
-- thing (a semantic color), not Dashboard-specific.
-------------------------------------------------------------------------------

Presentation.HIGHLIGHT_COLOR = { 1, 0.82, 0 }

local SEMANTIC_COLORS =
{
    success = { 0.3, 0.8, 0.4 },
    warning = { 0.9, 0.7, 0.2 },
    critical = { 0.85, 0.3, 0.3 },
    dim = { 0.7, 0.7, 0.7 },
    highlight = Presentation.HIGHLIGHT_COLOR,

    -- Presentation System v2 -- a real, pre-existing "info/link" blue this
    -- addon already used in three unrelated variants (RecommendationInspector's
    -- module-link buttons, Player Journal's Overview tags, Player Journal's
    -- Statistics tab). Canonicalized on the Statistics tab's own value since
    -- it already carried an explicit, deliberate justification in-file for
    -- being a distinct "cool" accent apart from the gold highlight -- the
    -- other two migrate to it (a real, visible color change on both).
    accent = { 0.55, 0.75, 1 },
}

function Presentation.GetSemanticColor(name)

    return SEMANTIC_COLORS[name] or SEMANTIC_COLORS.dim

end

-------------------------------------------------------------------------------
-- Backdrop Presets
--
-- Presentation System v2. Auditing every bordered panel in the addon found
-- 5 different border-alpha values and 2 different base backdrop grays for
-- what is conceptually the same "bordered dark panel" treatment -- including
-- SettingsWindow's own two side-by-side panels (navigationHost/contentHost)
-- disagreeing with EACH OTHER. Two presets, not one: a window-level
-- treatment (BaseWindow's own long-standing values, unchanged) and a
-- lighter-bordered inner-panel treatment (SettingsWindow.navigationHost's
-- own values, which contentHost now also adopts -- a real, visible fix,
-- not a renamed duplicate). DashboardCard's own backdrop (hover/emphasized
-- states, smaller edgeSize) is deliberately NOT unified here -- see
-- Core/UI/Widgets/DashboardCard.lua's own header for why.
-------------------------------------------------------------------------------

Presentation.WINDOW_BACKDROP =
{
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
    bgColor = { 0.10, 0.10, 0.10, 0.95 },
    borderColor = { 1, 1, 1, 0.55 },
}

Presentation.PANEL_BACKDROP =
{
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
    bgColor = { 0.10, 0.10, 0.10, 0.90 },
    borderColor = { 1, 1, 1, 0.25 },
}

-------------------------------------------------------------------------------
-- Dashboard Background (Shared Decorative Background)
--
-- Dashboard-specific only -- WINDOW_BACKDROP above is untouched and stays
-- shared by every OTHER BaseWindow (Developer Panel, Settings,
-- Diagnostics, PlayerJournal, RecommendationInspector); this pass does not
-- touch backdrop alpha at all, per explicit instruction -- see Home.lua's
-- own comment at the Dashboard:Create() call site. Centralized here, not
-- inline in Home.lua, so a future Appearance/Theme system has exactly one
-- place to read/override these two values from -- deliberately not a
-- ThemeService yet, just the values one would need to own.
--
-- DASHBOARD_BACKGROUND_TEXTURE keeps the .png extension -- final call,
-- made per explicit delegation ("use the format appropriate for the
-- client"). Reasoning: extension-less paths only resolve implicitly for
-- Blizzard's own MPQ/BLP-archived art; a loose file an addon ships itself
-- (this PNG, not BLP-converted) is a literal file-path read by the
-- client's loader, so the extension is required rather than optional.
-- This is a technical judgment, not a live-client-confirmed fact -- worth
-- a one-line check (drop the extension here) if the background doesn't
-- appear in-game.
--
-- DASHBOARD_BACKGROUND_ASPECT_RATIO (width / height) -- Background Polish
-- pass: the artwork at DASHBOARD_BACKGROUND_TEXTURE is now confirmed
-- 957x1643px (read directly from the PNG header), giving 957/1643 =
-- 0.5825 -- corrected from this constant's previous value of 1.5, a
-- landscape-image placeholder left over from before a portrait asset
-- existed. That stale value was the actual cause of this pass's reported
-- "busy center, corners not quite right" symptom: Home.lua's cover-fit
-- math trusted it over the real file, computing a background region far
-- wider than the frame (1080x720 instead of ~420x720), which showed only
-- the map's center strip inside the window while the true edges (and
-- this constant's own decorative corners) rendered outside the frame's
-- bounds entirely, unclipped (nothing in this codebase calls
-- SetClipsChildren). At the corrected ratio the region comes out to
-- ~420x721 -- effectively edge-to-edge with negligible overflow, matching
-- what the artwork was actually composed for.
-------------------------------------------------------------------------------

Presentation.DASHBOARD_BACKGROUND_TEXTURE = "Interface\\AddOns\\AzerothCompanion\\Images\\background1.png"
Presentation.DASHBOARD_BACKGROUND_ALPHA = 0.15
Presentation.DASHBOARD_BACKGROUND_ASPECT_RATIO = 957 / 1643

-------------------------------------------------------------------------------
-- Status Glyphs (raw, uncolored)
--
-- Presentation Asset Audit -- bare glyph primitives, not the composed
-- (colored) versions Dashboard call sites use. Promoted here (not
-- Format.lua) because VerificationService/DeveloperPanel need the exact
-- same checkmark/cross/warning concept and are not Dashboard code --
-- same "generic primitive, addon-wide" reasoning as HIGHLIGHT_COLOR
-- above. Format.lua's CHECK_SUCCESS/CHECK_FAILURE now compose color
-- codes around these instead of carrying an independent copy of the
-- glyph bytes.
-------------------------------------------------------------------------------

Presentation.CHECK_GLYPH = "\226\156\147" -- "✓"
Presentation.CROSS_GLYPH = "\226\156\151" -- "✗"
Presentation.WARNING_GLYPH = "\226\154\160" -- "⚠"

return Presentation
