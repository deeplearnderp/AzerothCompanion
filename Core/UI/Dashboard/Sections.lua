-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Sections
--
-- Shared infrastructure every data-backed page is built from: the page
-- shell (title, Back button, scrollable content area), the composable
-- section/field-row primitives, and the "measure once, build at the right
-- width" content builder for static-schema pages. Used by every secondary
-- Dashboard page -- Profile, Inventory, Accomplishments, MythicPlus,
-- Storage, Weekly, Recommendations, Progress, Statistics, and Journey
-- alike (corrected here -- this list had gone stale, missing the last
-- three, which is exactly why a Journey Back-button "inconsistency" audit
-- found none: CreateDataPage was already the one shared implementation
-- for it too) -- nothing here is specific to any one page.
--
-- Passing scrollChild = nil to a builder measures without creating any
-- widgets -- every function below still returns the correctly-advanced
-- yOffset, it just skips CreateFontString/CreateTexture. This is what
-- lets BuildDataPageContent measure a page's content height before
-- deciding which width to build it at, using the exact same code path
-- (and therefore the exact same arithmetic) as the real build -- there is
-- no separate "measure" formula that could drift out of sync with the
-- real one.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

-------------------------------------------------------------------------------
-- Page ScrollFrame (Dashboard Scrollbar Standardization)
--
-- The single, true owner of every Dashboard page's ScrollFrame: creates
-- it, positions it, and strips Blizzard's default chrome from it. Used by
-- CreateDataPage below (every secondary page) AND Home.lua -- previously
-- Home built its own copy of this inline (a second, independently-drifted
-- version that used the correct right inset but never hid the arrow
-- buttons), which is exactly why the scrollbar used to sit in a
-- different place, and look different, depending on which page you were
-- on. There is exactly one place left that calls CreateFrame("ScrollFrame",
-- ..., "UIPanelScrollFrameTemplate") for a real Dashboard page -- this
-- function -- and no page should ever call SetPoint on the ScrollFrame or
-- its ScrollBar itself again.
--
-- Right inset is always SCROLLBAR_RESERVE, unconditionally, on every
-- page -- not narrower when a page doesn't currently need to scroll (see
-- Layout.lua's own comment on PAGE_CONTENT_WIDTH_FULL for why: a
-- scrollbar that only sometimes reserves its footprint is a scrollbar
-- that can appear to move). Bottom inset is always PAGE_BOTTOM_INSET.
-- topInset/leftInset are the only two things that legitimately differ
-- between page shapes -- Home has no Back/Title/Updated header above its
-- content (topInset 0, not PAGE_HEADER_HEIGHT) and sizes its scrollChild
-- off an absolute WINDOW_WIDTH-based formula rather than a page-relative
-- one (leftInset 0, not PAGE_PADDING) -- both are genuine content-shape
-- differences, not scrollbar-position drift, so both stay parameters
-- rather than being forced identical.
-------------------------------------------------------------------------------

function Dashboard:CreatePageScrollFrame(parent, topInset, leftInset)

    topInset = topInset or Layout.PAGE_HEADER_HEIGHT
    leftInset = leftInset or Layout.PAGE_PADDING

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

    scrollFrame:SetPoint("TOPLEFT", leftInset, -topInset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -Layout.SCROLLBAR_RESERVE, Layout.PAGE_BOTTOM_INSET)

    -- Scrollbar Polish Pass -- UIPanelScrollFrameTemplate's ScrollBar
    -- (UIPanelScrollBarTemplate) ships its own ScrollUpButton/
    -- ScrollDownButton, stock Blizzard parchment-skinned arrow buttons
    -- that clash with this addon's dark custom aesthetic -- most visible
    -- as the odd button sitting at the very bottom of the track. Hidden
    -- once, here, for every page built through this one function.
    -- Mouse-wheel scrolling (bound to scrollFrame itself) and thumb-drag
    -- (bound to the ScrollBar/Slider) are both untouched -- neither
    -- depends on these buttons, only on incrementing/decrementing the
    -- Slider's value, which the buttons' own OnClick did on top of, not
    -- instead of. Guarded the same way ApplyPageScrolling already treats
    -- scrollFrame.ScrollBar, so a future template swap degrades to
    -- "buttons stay visible" rather than an error.
    local scrollBar = scrollFrame.ScrollBar

    if scrollBar then

        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
        end

        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
        end

    end

    return scrollFrame

end

-------------------------------------------------------------------------------
-- Data Page
--
-- Shared shell for every real, data-backed page: a header (Back, Title,
-- Updated, a divider) and a scrollable content area. Starts at the full
-- content width -- BuildDataPageContent (static pages) or each dynamic
-- page's own Layout() narrow it later only if their content turns out to
-- need a scrollbar.
--
-- Header Polish Pass -- Back is now a real UIPanelButtonTemplate (matching
-- Settings' own styling, per explicit product direction superseding this
-- section's earlier "plain clickable FontString" redesign) rather than
-- text with hand-rolled hover-color handling -- the template already
-- provides its own hover/pressed states, so the old OnEnter/OnLeave color
-- swap is deleted, not carried forward as now-redundant code. Back and
-- Updated both anchor at Layout.PAGE_PADDING from their respective edges
-- now, not 0 -- previously they sat flush against the raw window edge
-- while the header's own divider and the content area below both already
-- used PAGE_PADDING, a real inconsistency this corrects by reusing the
-- existing shared constant rather than inventing a new one. Title's own
-- anchor is untouched (TOP, centered on the full page width, independent
-- of Back/Updated) -- it remains visually centered by construction.
-------------------------------------------------------------------------------

function Dashboard:CreateDataPage(parent, pageTitle)

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()

    local backButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    backButton:SetSize(76, 22)
    backButton:SetPoint("TOPLEFT", Layout.PAGE_PADDING, -Layout.PAGE_HEADER_SIDE_TOP)
    backButton:SetText(AC.L:Get("Dashboard.Back"))

    backButton:SetScript("OnClick", function()
        Dashboard:GoBack()
    end)

    local titleText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -Layout.PAGE_HEADER_TITLE_TOP)
    titleText:SetText(pageTitle or "")

    -- "Last updated" -- RecommendationEngine/InsightEngine's own
    -- GetLastRefresh(). Every dynamic page gets this for free;
    -- UpdateLastUpdatedText below is the one place that reads it. Still
    -- the same quiet, no-border treatment -- Back's upgrade to a real
    -- button doesn't change what Updated is: secondary metadata, not an
    -- action.
    local lastUpdatedText = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    lastUpdatedText:SetPoint("TOPRIGHT", -Layout.PAGE_PADDING, -Layout.PAGE_HEADER_SIDE_TOP)
    lastUpdatedText:SetJustifyH("RIGHT")

    page.LastUpdatedText = lastUpdatedText

    -- Header Divider -- a static hairline below Back/Title/Updated,
    -- separating the header from scrollable content on every page (the
    -- ASCII mockup's own "------" row). Same color/alpha as every other
    -- divider in this codebase (Dashboard:AddDivider) -- not a new visual
    -- language, just this file's own one-time (not per-section, not
    -- scrollable) version of it, since the header sits above ScrollFrame,
    -- never inside scrollChild.
    local headerDivider = page:CreateTexture(nil, "ARTWORK")
    headerDivider:SetColorTexture(1, 1, 1, 0.10)
    headerDivider:SetHeight(Layout.DIVIDER_HEIGHT)
    headerDivider:SetPoint("TOPLEFT", Layout.PAGE_PADDING, -(Layout.PAGE_HEADER_HEIGHT - Layout.DIVIDER_MARGIN_BOTTOM))
    headerDivider:SetPoint("TOPRIGHT", -Layout.PAGE_PADDING, -(Layout.PAGE_HEADER_HEIGHT - Layout.DIVIDER_MARGIN_BOTTOM))

    local scrollFrame = self:CreatePageScrollFrame(page)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(Layout.PAGE_CONTENT_WIDTH_FULL)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    page.BackButton = backButton
    page.Title = titleText
    page.ScrollFrame = scrollFrame
    page.ScrollChild = scrollChild

    return page

end

-------------------------------------------------------------------------------
-- Last Updated -- reuses RecommendationEngine:GetLastRefresh().
-------------------------------------------------------------------------------

function Dashboard:UpdateLastUpdatedText(page)

    if not page or not page.LastUpdatedText then
        return
    end

    local lastRefresh = AC.RecommendationEngine and AC.RecommendationEngine:GetLastRefresh()

    if not lastRefresh or lastRefresh == 0 then
        page.LastUpdatedText:SetText("")
        return
    end

    page.LastUpdatedText:SetText(AC.L:Format("Dashboard.LastUpdatedFormat", date("%H:%M:%S", lastRefresh)))

end

-------------------------------------------------------------------------------
-- Refresh Engines
--
-- Shared by every page's refresh: re-run Insight/Recommendation
-- generation and update the page's "last updated" text. Consolidates
-- what used to be the same three lines copy-pasted at the top of every
-- Update*Page function (Dashboard Refactor -- one of those copies, in the
-- Home page's UpdateContent, referenced an undefined `page` local and was
-- a silent no-op; passing nil here is exactly as safe, since
-- UpdateLastUpdatedText already no-ops on a page with no LastUpdatedText
-- field, which the Home page frame never had).
-------------------------------------------------------------------------------

function Dashboard:RefreshEngines(page)

    if AC.InsightEngine then
        AC.InsightEngine:Refresh()
    end

    if AC.RecommendationEngine then
        AC.RecommendationEngine:Refresh()
    end

    -- Companion Intelligence vNext -- reads RecommendationEngine's
    -- just-refreshed list above to update per-recommendation history;
    -- must run before BriefingService (Companion Memory lines may read
    -- this service in a future pass) and before anything that reads
    -- GetHistoryFor/GetAllHistory this same refresh.
    if AC.RecommendationHistoryService then
        AC.RecommendationHistoryService:Refresh()
    end

    -- Companion Intelligence V4 -- all three read InsightEngine/
    -- RecommendationEngine's already-current output above, so they run
    -- after both, same ordering discipline as the two calls above.
    if AC.BriefingService then
        AC.BriefingService:Refresh()
    end

    if AC.NotificationService then
        AC.NotificationService:Refresh()
    end

    if AC.MilestoneService then
        AC.MilestoneService:Refresh()
    end

    -- Companion Intelligence vNext -- session-relative facts for Home's
    -- "Today's Companion Notes" card; independent of everything else
    -- above, ordered here only to sit alongside its Companion
    -- Intelligence siblings.
    if AC.SessionNotesService then
        AC.SessionNotesService:Refresh()
    end

    self:UpdateLastUpdatedText(page)

end

-------------------------------------------------------------------------------
-- Filter Dismissed Recommendations (Companion Intelligence vNext)
--
-- RecommendationEngine stays fully stateless (its own header's
-- discipline) -- it never learns a recommendation was dismissed. This is
-- purely presentation-layer filtering over its already-computed,
-- already-sorted list (Rule 2: the Dashboard never gathers gameplay data,
-- but reading another service's already-real flag to decide what to
-- render is exactly what every other Dashboard card already does),
-- shared by every surface that lists recommendations (the standalone
-- Recommendations page, any page's dynamic mini-section, Home's Highest
-- Priority card) so "dismissed" means the same thing everywhere, checked
-- once. A dismissed recommendation reappears the moment its underlying
-- situation genuinely changes (a new cycle -- RecommendationHistoryService
-- clears dismissedThisCycle when that happens), never permanently.
-------------------------------------------------------------------------------

function Dashboard:FilterDismissedRecommendations(recommendations)

    if not AC.RecommendationHistoryService or not recommendations then
        return recommendations
    end

    local filtered = {}

    for _, recommendation in ipairs(recommendations) do

        local history = recommendation.id and AC.RecommendationHistoryService:GetHistoryFor(recommendation.id)

        if not (history and history.dismissedThisCycle) then
            table.insert(filtered, recommendation)
        end

    end

    return filtered

end

-------------------------------------------------------------------------------
-- Categorized Recommendations / Insights
--
-- Shared by every page's dynamic Recommendations/Insights mini-section:
-- filter RecommendationEngine's list down to one category, and fetch
-- InsightEngine's matching category list. Consolidates what used to be
-- the same filtering loop copy-pasted once per page, differing only by
-- the category string literal.
--
-- A recommendation matches a page's category either by its own
-- `category` field (every existing 1:1 Insight mapping, unchanged) OR by
-- appearing in its `sourceModules` list (Companion Intelligence V3) --
-- `sourceModules` already contains `category` for every non-merged
-- recommendation (AddRecommendation defaults it to `{category}`), so
-- this is exactly the old behavior for all of those. It only changes
-- anything for a genuinely merged recommendation like "Restock &
-- Prepare" (category = "Preparation", sourceModules = {"Inventory",
-- "Storage"}) -- which is real, since that recommendation IS actually
-- about both pages, not a category-matching bug to route around.
-------------------------------------------------------------------------------

local function RecommendationMatchesCategory(recommendation, category)

    if recommendation.category == category then
        return true
    end

    if recommendation.sourceModules then

        for _, moduleName in ipairs(recommendation.sourceModules) do

            if moduleName == category then
                return true
            end

        end

    end

    return false

end

function Dashboard:GetCategorizedRecommendationsAndInsights(category)

    local recommendations = {}

    if AC.RecommendationEngine then

        for _, recommendation in ipairs(AC.RecommendationEngine:GetRecommendations()) do

            if RecommendationMatchesCategory(recommendation, category) then
                table.insert(recommendations, recommendation)
            end

        end

    end

    local insights = AC.InsightEngine and AC.InsightEngine:GetInsightsByCategory(category) or {}

    return recommendations, insights

end

-------------------------------------------------------------------------------
-- Scroll Sizing
--
-- Decides, per page, whether a scrollbar is actually needed: only when
-- content exceeds the visible viewport. Pages whose content fits behave
-- as plain panels -- no scrollbar shown, no wheel scrolling, no leftover
-- scroll offset. Purely about the scrollbar/wheel/position -- content
-- WIDTH is decided by the caller before this runs, since that decision
-- has to happen before content is laid out, not after.
--
-- Dashboard Initialization Fix -- this function is called far more often
-- than just on navigation (every accordion expand/collapse, Storage
-- Execute, Plan switching, Home dismiss, sorting all refresh a page in
-- place), so it must never reset scroll position itself -- that now
-- happens exactly once, in Navigation.lua's ShowPage, at the one moment
-- a page is actually newly shown. What DOES belong here: `scrollFrame:
-- GetHeight()` is anchor-derived, not an explicit SetSize, and can read
-- 0 (or otherwise unresolved) if this runs before the frame tree's first
-- layout pass has completed -- most likely the very first time any page
-- is shown in a session. Treat that as "layout not ready" rather than
-- "content overflows a zero-height viewport" (which a bare `contentHeight
-- > viewportHeight` comparison would otherwise always conclude), since a
-- momentarily-unresolved read is not evidence that scrolling is actually
-- needed.
-------------------------------------------------------------------------------

function Dashboard:ApplyPageScrolling(page, contentHeight)

    local scrollFrame = page and page.ScrollFrame
    local scrollChild = page and page.ScrollChild

    if not scrollFrame or not scrollChild then
        return
    end

    scrollChild:SetHeight(math.max(contentHeight, 1))

    local viewportHeight = scrollFrame:GetHeight()
    local needsScroll = viewportHeight > 0 and contentHeight > viewportHeight

    -- ScrollBar is UIPanelScrollFrameTemplate's standard exposed child --
    -- guarded rather than assumed, so a template change degrades to
    -- "scrollbar stays visible" instead of an error.
    local scrollBar = scrollFrame.ScrollBar

    if needsScroll then

        if scrollBar then
            scrollBar:Show()
        end

        scrollFrame:EnableMouseWheel(true)

    else

        if scrollBar then
            scrollBar:Hide()
        end

        scrollFrame:EnableMouseWheel(false)
        scrollFrame:SetVerticalScroll(0)

    end

end

-------------------------------------------------------------------------------
-- Measure And Apply Scrolling (Presentation System v2)
--
-- The one-measure-pass decision every dynamic page (Storage/Weekly/
-- MythicPlus/Accomplishments/Progress/Statistics/Recommendations) needs --
-- previously hand-copied, byte-identical, into all 7 of those files' own
-- Update*Page functions instead of factored once, the way
-- BuildDataPageContent already does this exact job for the two
-- static-schema pages. `measureFn` is the page's own `Layout_(width)`
-- closure -- called once at PAGE_CONTENT_WIDTH_FULL, the only content
-- width there is now (Dashboard Scrollbar Standardization -- see
-- Layout.lua) -- returning the measured content height, same contract
-- every page's own `Layout_` already implements. Sets `scrollChild`'s
-- width and calls ApplyPageScrolling -- the one thing left for the caller
-- to do afterward is nothing; this is the whole sequence.
-------------------------------------------------------------------------------

function Dashboard:MeasureAndApplyScrolling(page, scrollChild, measureFn)

    local contentWidth = Layout.PAGE_CONTENT_WIDTH_FULL
    local contentHeight = measureFn(contentWidth)

    scrollChild:SetWidth(contentWidth)

    self:ApplyPageScrolling(page, contentHeight)

end

-------------------------------------------------------------------------------
-- Section Helpers
--
-- The composable primitives every section-based page is built from.
-- BuildFieldRows/AppendFutureFeatures below are just fixed recipes of
-- these calls -- a page with unusual needs (mixed fields and custom rows)
-- can call them directly instead of going through a schema table. No
-- positioning math is duplicated between them or between the two recipes.
-------------------------------------------------------------------------------

-- Accordion Polish Pass -- pooled on scrollChild (same "cache on the
-- object that owns it" idiom ShowEmptyLine's container[cacheKey] already
-- uses below), keyed by titleKey, which is already a stable, page-unique
-- string at every call site -- no signature change, zero call-site
-- changes anywhere. Root-cause fix for section headers occasionally
-- clipping the following section: every dynamic page's Layout_ re-runs
-- this on every refresh (and, on accordion pages, on every single row
-- click), and this used to CreateFontString a brand-new, never-hidden
-- header on every call -- old ghost headers from earlier layout passes
-- froze at stale Y positions and could visually intrude into a section
-- that had since become shorter or longer. Pooling means each call now
-- repositions the SAME header instead of stacking a new one on top.
function Dashboard:BeginSection(scrollChild, titleKey, yOffset)

    if scrollChild then

        scrollChild.SectionHeaders = scrollChild.SectionHeaders or {}

        local header = scrollChild.SectionHeaders[titleKey]

        if not header then

            header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            AC.DashboardFormat.SetHighlightColor(header)

            scrollChild.SectionHeaders[titleKey] = header

        end

        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, yOffset)
        header:SetText(AC.L:Get(titleKey))
        header:Show()

    end

    return yOffset - Layout.SECTION_HEADER_GAP

end

function Dashboard:EndSection(yOffset)

    return self:AddSpacer(yOffset, Layout.SECTION_GROUP_GAP)

end

function Dashboard:AddField(scrollChild, labelKey, yOffset, contentWidth)

    if not scrollChild then
        return nil, yOffset - Layout.ROW_HEIGHT
    end

    contentWidth = contentWidth or Layout.PAGE_CONTENT_WIDTH_FULL

    local valueWidth = contentWidth - Layout.ROW_INDENT - Layout.FIELD_LABEL_WIDTH - Layout.FIELD_LABEL_VALUE_GAP

    local labelText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
    labelText:SetWidth(Layout.FIELD_LABEL_WIDTH)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(AC.L:Get(labelKey))
    labelText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    local valueText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPLEFT", Layout.ROW_INDENT + Layout.FIELD_LABEL_WIDTH + Layout.FIELD_LABEL_VALUE_GAP, yOffset)
    valueText:SetWidth(valueWidth)
    valueText:SetJustifyH("LEFT")
    valueText:SetText(AC.L:Get("Common.Unknown"))

    return valueText, yOffset - Layout.ROW_HEIGHT

end

function Dashboard:AddSpacer(yOffset, amount)

    return yOffset - (amount or Layout.SECTION_GROUP_GAP)

end

-------------------------------------------------------------------------------
-- Empty-State Line
--
-- A single dimmed placeholder line for a dynamic section with nothing to
-- show, cached on `container[cacheKey]` so repeated refreshes reuse the
-- same FontString. `container` is any plain table the caller already owns
-- long enough to cache a widget on -- a page (most callers) or a pooled
-- list's own pool table (`Rows.lua`'s `LayoutItemRows`/`LayoutTextLines`,
-- which cache their own empty-state line the exact same way under
-- `pool.EmptyText` -- this is the one place that mechanism lives, not
-- duplicated a third time).
-------------------------------------------------------------------------------

function Dashboard:ShowEmptyLine(container, scrollChild, cacheKey, yOffset, width, textKey)

    if not container[cacheKey] then

        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emptyText:SetJustifyH("LEFT")

        -- Presentation System v2 -- was a hardcoded (0.55,0.55,0.55) found
        -- nowhere else in the addon; migrated to the real "dim" token
        -- (0.7,0.7,0.7) -- a genuine, visible brightening.
        emptyText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

        container[cacheKey] = emptyText

    end

    container[cacheKey]:ClearAllPoints()
    container[cacheKey]:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
    container[cacheKey]:SetWidth(width - Layout.ROW_INDENT)
    container[cacheKey]:SetText(AC.L:Get(textKey))
    container[cacheKey]:Show()

    -- Accordion Polish Pass -- was a hardcoded Layout.ROW_HEIGHT
    -- regardless of the real rendered height; a text string that wraps
    -- to more than one line at the given width silently under-reported
    -- its height, corrupting every offset after it. Real measured height
    -- (taken after SetText/SetWidth above, so it reflects this pass's
    -- real width), same "or <constant>" safe-fallback pattern already
    -- used elsewhere in this file (e.g. BuildHeroSection's GetStringHeight
    -- fallbacks).
    return yOffset - (container[cacheKey]:GetStringHeight() or Layout.ROW_HEIGHT)

end

-- Accordion Polish Pass -- optional trailing cacheKey pools the divider
-- the same way BeginSection above now pools headers (same root-cause
-- leak, same fix). Omitted (nil) keeps today's exact always-fresh
-- behavior -- safe for BuildFieldRows below, the one caller that only
-- ever runs once per page at Create() time and so was never actually
-- exposed to the leak.
function Dashboard:AddDivider(scrollChild, yOffset, contentWidth, cacheKey)

    yOffset = yOffset - Layout.DIVIDER_MARGIN_TOP

    if scrollChild then

        local divider

        if cacheKey then

            scrollChild.Dividers = scrollChild.Dividers or {}
            divider = scrollChild.Dividers[cacheKey]

            if not divider then

                divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetColorTexture(1, 1, 1, 0.10)

                scrollChild.Dividers[cacheKey] = divider

            end

        else

            divider = scrollChild:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.10)

        end

        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", 0, yOffset)
        divider:SetSize(contentWidth or Layout.PAGE_CONTENT_WIDTH_FULL, Layout.DIVIDER_HEIGHT)
        divider:Show()

    end

    return yOffset - Layout.DIVIDER_HEIGHT - Layout.DIVIDER_MARGIN_BOTTOM

end

-------------------------------------------------------------------------------
-- Field Rows
--
-- Builds the label/value rows described by a section schema (see
-- Schemas.lua), resolving each section title and field label through
-- AC.L:Get(). Returns a lookup of key -> value FontString (empty when
-- scrollChild is nil, i.e. measuring), plus the Y offset content ended
-- at -- which doubles as this page's measured content height (see
-- BuildDataPageContent), so there is no separate "measure" pass
-- duplicating this arithmetic.
-------------------------------------------------------------------------------

function Dashboard:BuildFieldRows(scrollChild, sections, startOffset, contentWidth)

    local fields = {}

    local yOffset = startOffset or -4

    for _, section in ipairs(sections) do

        if section.divider then
            yOffset = self:AddDivider(scrollChild, yOffset, contentWidth)
        end

        yOffset = self:BeginSection(scrollChild, section.title, yOffset)

        -- Presentation System v2 -- this used to branch on a
        -- `section.emptyText` field for a bespoke placeholder line;
        -- confirmed dead (no schema in Schemas.lua ever set it --
        -- AppendFutureFeatures is what "not built yet" content actually
        -- uses today) and removed rather than kept as unreachable code.
        for _, field in ipairs(section.fields) do

            local valueText

            valueText, yOffset = self:AddField(scrollChild, field.label, yOffset, contentWidth)

            if scrollChild then
                fields[field.key] = valueText
            end

        end

        yOffset = self:EndSection(yOffset)

    end

    return fields, yOffset

end

-------------------------------------------------------------------------------
-- Future Features Note
--
-- Appends a "Future Features" section (same header styling as any other
-- section) listing what a page will eventually grow into. "items" is a
-- list of Localization keys, resolved here. Returns the Y offset content
-- ended at.
-------------------------------------------------------------------------------

function Dashboard:AppendFutureFeatures(scrollChild, yOffset, items, contentWidth)

    yOffset = self:BeginSection(scrollChild, "Dashboard.FutureFeatures", yOffset)

    if scrollChild then

        contentWidth = contentWidth or Layout.PAGE_CONTENT_WIDTH_FULL

        local bulletLines = {}

        for _, itemKey in ipairs(items or {}) do
            table.insert(bulletLines, AC.DashboardFormat.BULLET .. " " .. AC.L:Get(itemKey))
        end

        -- Same muted, "planned not built" font as the single-line
        -- placeholders (BuildFieldRows' emptyText) -- a bulleted list of
        -- several planned items reads as the same roadmap concept, just
        -- with more than one line, so it gets the same treatment.
        local bulletText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        bulletText:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        bulletText:SetWidth(contentWidth - Layout.ROW_INDENT)
        bulletText:SetJustifyH("LEFT")
        bulletText:SetWordWrap(true)
        bulletText:SetSpacing(4)
        bulletText:SetText(table.concat(bulletLines, "\n"))

    end

    local lineHeight = 14
    local blockHeight = (#(items or {}) * lineHeight) + 10

    yOffset = yOffset - blockHeight

    -- Same trailing gap every BuildFieldRows section ends with (EndSection)
    -- -- keeps spacing uniform whether this is the last thing on a page
    -- or content continues after it.
    return self:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Build Data Page Content
--
-- The single call a static-schema page needs: measures content once at
-- the one content width every page builds at (Dashboard Scrollbar
-- Standardization -- see Layout.lua's PAGE_CONTENT_WIDTH_FULL comment),
-- then builds at that same width and lets ApplyPageScrolling decide
-- whether a scrollbar is needed. A page builder just calls this and never
-- thinks about scrollbars or widths at all.
--
-- Stores page.StaticEndOffset and page.ContentWidth -- pages that also
-- have a dynamic trailing section (Inventory/Accomplishments' Recommendations
-- and Insights) append starting from that offset, at that width, on
-- every refresh (see Rows.lua's AppendDynamicSection).
-------------------------------------------------------------------------------

function Dashboard:BuildDataPageContent(page, sections, futureFeatureItems)

    local function Measure(contentWidth)

        local _, yOffset = self:BuildFieldRows(nil, sections, nil, contentWidth)

        if futureFeatureItems then
            yOffset = self:AppendFutureFeatures(nil, yOffset, futureFeatureItems, contentWidth)
        end

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    local contentWidth = Layout.PAGE_CONTENT_WIDTH_FULL
    local contentHeight = Measure(contentWidth)

    page.ScrollChild:SetWidth(contentWidth)

    local fields, yOffset = self:BuildFieldRows(page.ScrollChild, sections, nil, contentWidth)

    if futureFeatureItems then
        yOffset = self:AppendFutureFeatures(page.ScrollChild, yOffset, futureFeatureItems, contentWidth)
    end

    page.Fields = fields
    page.ContentWidth = contentWidth
    page.StaticEndOffset = yOffset

    self:ApplyPageScrolling(page, contentHeight)

end

return Dashboard
