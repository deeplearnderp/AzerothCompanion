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
-- Dates -- every date-bearing style includes a 4-digit year. The time-only
-- style is reserved for rows already grouped beneath a full date heading.
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
    time = "%H:%M",
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
-- treatment (BaseWindow's own long-standing values, unchanged) and the card
-- treatment that now defines Dashboard, Settings, and Developer content
-- surfaces. Keeping both here makes their differences intentional and
-- theme-ready instead of scattering nearly-identical backdrop tables across
-- individual windows.
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

Presentation.CARD_BACKDROP =
{
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
    bgColor = { 0.15, 0.15, 0.15, 0.85 },
    borderColor = { 1, 1, 1, 0.28 },
    emphasizedBorderAlpha = 0.5,
    hoverBackgroundDelta = 0.05,
    hoverBorderAlphaDelta = 0.2,
}

function Presentation.ApplyBackdrop(frame, backdrop)

    if not frame or not backdrop then
        return
    end

    frame:SetBackdrop(
    {
        bgFile = backdrop.bgFile,
        edgeFile = backdrop.edgeFile,
        edgeSize = backdrop.edgeSize,
        insets = backdrop.insets,
    })

    frame:SetBackdropColor(unpack(backdrop.bgColor))
    frame:SetBackdropBorderColor(unpack(backdrop.borderColor))

end

function Presentation.GetCardBorderColor(emphasized)

    if emphasized then
        return Presentation.HIGHLIGHT_COLOR[1], Presentation.HIGHLIGHT_COLOR[2], Presentation.HIGHLIGHT_COLOR[3], Presentation.CARD_BACKDROP.emphasizedBorderAlpha
    end

    return unpack(Presentation.CARD_BACKDROP.borderColor)

end

function Presentation.ApplyCardBackdrop(frame, emphasized)

    Presentation.ApplyBackdrop(frame, Presentation.CARD_BACKDROP)
    frame:SetBackdropBorderColor(Presentation.GetCardBorderColor(emphasized))

end

-------------------------------------------------------------------------------
-- Application Window Background
--
-- The single decorative identity shared by every standalone window
-- (Dashboard, Settings, Developer Panel, Inventory Manager, Player Journal).
-- ApplyWindowBackground uses texture-coordinate cropping rather than stretching
-- the portrait artwork or sizing it beyond a wide window's bounds. The same
-- helper therefore works for Dashboard's narrow frame and the much wider
-- internal-tool windows without duplicate aspect-ratio math.
--
-- WINDOW_BACKGROUND_TEXTURE keeps the .png extension -- final call,
-- made per explicit delegation ("use the format appropriate for the
-- client"). Reasoning: extension-less paths only resolve implicitly for
-- Blizzard's own MPQ/BLP-archived art; a loose file an addon ships itself
-- (this PNG, not BLP-converted) is a literal file-path read by the
-- client's loader, so the extension is required rather than optional.
-- This is a technical judgment, not a live-client-confirmed fact -- worth
-- a one-line check (drop the extension here) if the background doesn't
-- appear in-game.
--
-- WINDOW_BACKGROUND_ASPECT_RATIO (width / height) -- the artwork is confirmed
-- 957x1643px (read directly from the PNG header), giving 957/1643 =
-- 0.5825. This is centralized presentation metadata, not window layout.
--
-- Atmosphere Pass -- a single flat WINDOW_BACKGROUND_ALPHA competed equally
-- with every part of every window, including the title bar and tab row,
-- which is exactly the part of the window that can least afford to lose
-- contrast. Replaced with a vertical gradient (TextureBase:SetGradient,
-- confirmed current API as of Patch 10.0.0 -- the old SetGradientAlpha(
-- orientation, minR,minG,minB,minA, maxR,maxG,maxB,maxA) form was merged
-- into it and no longer exists) -- darker/near-invisible at the top where
-- title/tab text lives, a little more present toward the bottom where a
-- window's content has usually thinned out. "VERTICAL" orientation places
-- minColor at the texture's bottom and maxColor at its top (confirmed via
-- Warcraft Wiki, not assumed) -- ALPHA_BOTTOM/ALPHA_TOP are named for what
-- they visually mean, not for which SetGradient argument slot they land in.
-------------------------------------------------------------------------------

Presentation.WINDOW_BACKGROUND_TEXTURE = "Interface\\AddOns\\AzerothCompanion\\Images\\background1.png"
Presentation.WINDOW_BACKGROUND_ALPHA_TOP = 0.08
Presentation.WINDOW_BACKGROUND_ALPHA_BOTTOM = 0.22
Presentation.WINDOW_BACKGROUND_ASPECT_RATIO = 957 / 1643

-- Backward-compatible names for any developer tooling that inspected the
-- original Dashboard-specific constants directly.
Presentation.DASHBOARD_BACKGROUND_TEXTURE = Presentation.WINDOW_BACKGROUND_TEXTURE
Presentation.DASHBOARD_BACKGROUND_ASPECT_RATIO = Presentation.WINDOW_BACKGROUND_ASPECT_RATIO

function Presentation.ApplyWindowBackground(frame)

    if not frame then
        return nil
    end

    local background = frame.AzerothCompanionWindowBackground

    if not background then

        background = frame:CreateTexture(nil, "ARTWORK", nil, -7)
        background:SetAllPoints(frame)

        frame.AzerothCompanionWindowBackground = background
        frame.Background = background

    end

    local function UpdateCrop(width, height)

        width = tonumber(width) or frame:GetWidth() or 1
        height = tonumber(height) or frame:GetHeight() or 1

        if width <= 0 or height <= 0 then
            return
        end

        local frameAspectRatio = width / height
        local artworkAspectRatio = Presentation.WINDOW_BACKGROUND_ASPECT_RATIO

        if frameAspectRatio > artworkAspectRatio then

            local visibleHeight = artworkAspectRatio / frameAspectRatio
            local verticalCrop = (1 - visibleHeight) / 2

            background:SetTexCoord(0, 1, verticalCrop, 1 - verticalCrop)

        else

            local visibleWidth = frameAspectRatio / artworkAspectRatio
            local horizontalCrop = (1 - visibleWidth) / 2

            background:SetTexCoord(horizontalCrop, 1 - horizontalCrop, 0, 1)

        end

    end

    background:SetTexture(Presentation.WINDOW_BACKGROUND_TEXTURE)

    -- VERTICAL places minColor at the bottom, maxColor at the top -- the
    -- bottom gets the higher (more visible) alpha, the top gets the lower
    -- one, so title bars and tab rows keep their contrast.
    background:SetGradient("VERTICAL",
        CreateColor(1, 1, 1, Presentation.WINDOW_BACKGROUND_ALPHA_BOTTOM),
        CreateColor(1, 1, 1, Presentation.WINDOW_BACKGROUND_ALPHA_TOP))

    if not frame.AzerothCompanionWindowBackgroundHooked then

        frame:HookScript("OnSizeChanged", function(_, width, height)
            UpdateCrop(width, height)
        end)

        frame.AzerothCompanionWindowBackgroundHooked = true

    end

    UpdateCrop(frame:GetWidth(), frame:GetHeight())

    return background

end

function Presentation.StyleWindowTitle(title)

    if not title then
        return
    end

    title:SetTextColor(unpack(Presentation.HIGHLIGHT_COLOR))
    title:SetShadowColor(0, 0, 0, 0.9)
    title:SetShadowOffset(1, -1)

end

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
