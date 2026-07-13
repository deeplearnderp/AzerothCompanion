-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Rows
--
-- Shared, reusable rendering components for dynamic, session-dependent
-- content: pooled recommendation/insight list rows, the Hero section, the
-- two-column Statistics Grid, and the expandable History Table. Each is
-- generic on purpose -- none of them know about MythicPlus, Storage, or
-- any specific module -- so a future flagship page (Delves, Raids, ...)
-- can reuse them directly the moment it exists.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat

-------------------------------------------------------------------------------
-- Dynamic List Rows
--
-- Shared by the standalone Recommendations page and any page's dynamic
-- Recommendations/Insights mini-section (Inventory, Accomplishments,
-- MythicPlus, Storage, Weekly): a pooled list of rows, or a single dimmed
-- empty-state line when there's nothing to show. Reuses
-- BuildRecommendationRow's row shape since insight records and
-- recommendation records have the same title/description/priority/
-- category shape. showStars additionally renders a priority star rating
-- and, when a recommendation supplies them, reason/expected benefit/
-- estimated time lines -- callers showing Insights pass showStars =
-- false, since an observation isn't something to rate.
-------------------------------------------------------------------------------

function Dashboard:LayoutItemRows(scrollChild, pool, items, yOffset, contentWidth, emptyTextKey, rowGap, showStars)

    -- Companion Intelligence vNext -- only real recommendation lists
    -- (showStars = true) can carry a dismissible `id`; Insight lists never
    -- do, so this filter is a no-op for them.
    if showStars then
        items = self:FilterDismissedRecommendations(items)
    end

    if not items or #items == 0 then

        for _, row in ipairs(pool) do
            row:Hide()
        end

        return self:ShowEmptyLine(pool, scrollChild, "EmptyText", yOffset, contentWidth, emptyTextKey)

    end

    if pool.EmptyText then
        pool.EmptyText:Hide()
    end

    rowGap = rowGap or Layout.SECTION_GROUP_GAP

    for index, item in ipairs(items) do

        local row = pool[index]

        if not row then
            row = self:BuildRecommendationRow(scrollChild)
            pool[index] = row
        end

        row:SetWidth(contentWidth)
        row.TitleText:SetWidth(contentWidth - Layout.ROW_INDENT)
        row.DescriptionText:SetWidth(contentWidth - Layout.ROW_INDENT)
        row.DetailsText:SetWidth(contentWidth - Layout.ROW_INDENT)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        row.TitleText:ClearAllPoints()

        local starsHeight = 0

        if showStars then

            row.StarsText:SetText(Format.RenderStars(item.priority))
            row.StarsText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)
            row.StarsText:Show()

            row.TitleText:SetPoint("TOPLEFT", row.StarsText, "BOTTOMLEFT", 0, -2)

            starsHeight = (row.StarsText:GetStringHeight() or 12) + 2

        else

            row.StarsText:Hide()
            row.TitleText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)

        end

        -- Dismiss (Companion Intelligence vNext) -- only for real
        -- recommendations with a stable id, only while the history
        -- service exists to record the click.
        if showStars and item.id and AC.RecommendationHistoryService then

            row.DismissButton:ClearAllPoints()
            row.DismissButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            row.DismissButton:Show()

            local dismissID = item.id

            row.DismissButton:SetScript("OnClick", function()

                AC.RecommendationHistoryService:DismissRecommendation(dismissID)

                -- Optimistic: hide immediately rather than waiting for
                -- this page's next natural refresh -- RecommendationEngine
                -- itself never re-runs from a dismiss click (it stays
                -- fully stateless), so without this the row would
                -- otherwise sit there unchanged until something else
                -- triggers a redraw.
                row:Hide()

            end)

        else
            row.DismissButton:Hide()
        end

        row.TitleText:SetText(item.title or AC.L:Get("Common.Unknown"))
        row.DescriptionText:SetText(item.description or "")

        local titleHeight = row.TitleText:GetStringHeight() or 14
        local descriptionHeight = row.DescriptionText:GetStringHeight() or 12

        local detailLines = {}

        if item.reason and item.reason ~= "" then
            table.insert(detailLines, AC.L:Format("Dashboard.RecommendationReasonFormat", item.reason))
        end

        if item.expectedBenefit and item.expectedBenefit ~= "" then
            table.insert(detailLines, AC.L:Format("Dashboard.RecommendationBenefitFormat", item.expectedBenefit))
        end

        if item.estimatedTime and item.estimatedTime ~= "" then
            table.insert(detailLines, AC.L:Format("Dashboard.RecommendationTimeFormat", item.estimatedTime))
        end

        -- Supporting Evidence -- one bullet per fact the recommendation
        -- was actually built from (RecommendationEngine's
        -- supportingEvidence list). Insights never set this field, so it
        -- naturally only ever appears here on the Recommendations page.
        if item.supportingEvidence and #item.supportingEvidence > 0 then

            for _, evidence in ipairs(item.supportingEvidence) do
                table.insert(detailLines, AC.L:Format("Dashboard.EvidenceLineFormat", evidence.label or "", evidence.value or ""))
            end

        end

        local detailsHeight = 0

        if #detailLines > 0 then

            row.DetailsText:SetText(table.concat(detailLines, "\n"))
            row.DetailsText:Show()
            detailsHeight = (row.DetailsText:GetStringHeight() or 0) + 4

        else

            row.DetailsText:SetText("")
            row.DetailsText:Hide()

        end

        row.MetaText:ClearAllPoints()

        if #detailLines > 0 then
            row.MetaText:SetPoint("TOPLEFT", row.DetailsText, "BOTTOMLEFT", 0, -4)
        else
            row.MetaText:SetPoint("TOPLEFT", row.DescriptionText, "BOTTOMLEFT", 0, -4)
        end

        -- Confidence (Companion Intelligence V3) -- only recommendations
        -- carry this field (Insights never do, same "optional field this
        -- row type doesn't set" pattern as supportingEvidence above), so
        -- this automatically only ever appears on real recommendation
        -- rows, on every page that renders them through this shared
        -- function -- no per-page/Home-specific code needed for it to
        -- show up everywhere at once.
        local metaText

        if item.confidence then

            metaText = AC.L:Format("Dashboard.RecommendationMetaWithConfidenceFormat",
                tostring(item.priority or AC.L:Get("Common.Unknown")),
                item.category or AC.L:Get("Common.Unknown"),
                AC.L:Get("Dashboard.Confidence" .. item.confidence))

        else

            metaText = AC.L:Format("Dashboard.RecommendationMetaFormat",
                tostring(item.priority or AC.L:Get("Common.Unknown")),
                item.category or AC.L:Get("Common.Unknown"))

        end

        -- Recommendation Inspector -- a "Click for Why?" hint appended to
        -- the same meta line, and the whole row made clickable/hoverable,
        -- only for real recommendation rows (showStars = true). Insight
        -- rows have no score/confidence/supportingEvidence to inspect, so
        -- they stay inert, exactly as before this feature.
        if showStars then

            metaText = metaText .. "   " .. AC.L:Get("Dashboard.ClickForWhy")

            row:EnableMouse(true)

            row:SetScript("OnEnter", function(self)
                self.Background:SetColorTexture(1, 1, 1, 0.06)
            end)

            row:SetScript("OnLeave", function(self)
                self.Background:SetColorTexture(1, 1, 1, 0)
            end)

            row:SetScript("OnMouseUp", function(self, button)

                if button == "LeftButton" and AC.RecommendationInspector then
                    AC.RecommendationInspector:Show(item)
                end

            end)

        else

            row:EnableMouse(false)
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row:SetScript("OnMouseUp", nil)
            row.Background:SetColorTexture(1, 1, 1, 0)

        end

        row.MetaText:SetText(metaText)

        local metaHeight = row.MetaText:GetStringHeight() or 12

        local rowHeight = starsHeight + titleHeight + 4 + descriptionHeight + 4 + detailsHeight + metaHeight

        row:SetHeight(rowHeight)

        yOffset = yOffset - rowHeight - rowGap

    end

    for index = #items + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

-------------------------------------------------------------------------------
-- Layout Text Lines (Progress Dashboard)
--
-- A minimal pooled list of one line per item, using a caller-supplied
-- formatLine(item) to turn each real item into display text --
-- deliberately simpler than LayoutItemRows above (no stars/reason/
-- expand), for a list that's just "a name and when it happened," not
-- something to rate or act on. Extracted from what used to be
-- Achievements' (now Accomplishments') own page-local LayoutRecentAchievements
-- (identical pooling/empty-state shape, one Achievements-specific format string
-- hardcoded inside it) once the Progress page needed the exact same
-- shape for Recent Milestones -- the formatting decision moves to each
-- caller (formatLine), the pooling/layout mechanics live here once.
-------------------------------------------------------------------------------

function Dashboard:LayoutTextLines(scrollChild, pool, items, yOffset, contentWidth, emptyTextKey, formatLine)

    if not items or #items == 0 then

        for _, row in ipairs(pool) do
            row:Hide()
        end

        return self:ShowEmptyLine(pool, scrollChild, "EmptyText", yOffset, contentWidth, emptyTextKey)

    end

    if pool.EmptyText then
        pool.EmptyText:Hide()
    end

    for index, item in ipairs(items) do

        local row = pool[index]

        if not row then
            row = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetJustifyH("LEFT")
            pool[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        row:SetWidth(contentWidth - Layout.ROW_INDENT)
        row:SetText(formatLine(item))
        row:Show()

        yOffset = yOffset - Layout.ROW_HEIGHT

    end

    for index = #items + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

-------------------------------------------------------------------------------
-- Append Dynamic Section
--
-- Appends one named Recommendations/Insights-shaped list section after a
-- page's static fields (page.StaticEndOffset), at the width that page's
-- static content was already built at (page.ContentWidth). Called fresh
-- on every page refresh, since the list itself is session-dependent.
--
-- Trade-off: if dynamic content pushes a page's total height past what
-- its static-only content needed, ApplyPageScrolling still correctly
-- shows a scrollbar -- but the static width decision from
-- BuildDataPageContent is not revisited, so the static fields keep
-- whichever width they were built at. Retroactively re-narrowing already-
-- built static content would mean rebuilding it on every refresh instead
-- of once at Create() time; given how rarely a short Insights/
-- Recommendations list pushes a page over the edge, keeping static
-- construction a one-time cost is the better trade.
-------------------------------------------------------------------------------

function Dashboard:AppendDynamicSection(page, poolKey, titleKey, yOffset, items, emptyTextKey, showStars)

    local scrollChild = page.ScrollChild
    local contentWidth = page.ContentWidth or Layout.PAGE_CONTENT_WIDTH_FULL

    yOffset = self:BeginSection(scrollChild, titleKey, yOffset)

    page.Pools = page.Pools or {}
    page.Pools[poolKey] = page.Pools[poolKey] or {}

    -- A tighter row gap than the standalone Recommendations page uses --
    -- here this is one compact section among several on the page, not
    -- the main content.
    yOffset = self:LayoutItemRows(scrollChild, page.Pools[poolKey], items, yOffset, contentWidth, emptyTextKey, 12, showStars)

    return self:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Recommendation Row
--
-- Recommendations are a dynamic, session-dependent list rather than a
-- fixed set of fields, so they get their own row builder instead of the
-- label/value schema. Rows are pooled on the page and reused across
-- refreshes rather than recreated every time; width is applied by the
-- caller on every refresh (it can change between refreshes as the list
-- grows/shrinks past the scroll threshold), not fixed here at creation.
-------------------------------------------------------------------------------

function Dashboard:BuildRecommendationRow(scrollChild)

    local row = CreateFrame("Frame", nil, scrollChild)

    -- Hover feedback for the Recommendation Inspector (see LayoutItemRows
    -- below) -- transparent normally, a faint highlight on mouseover.
    -- Insight rows never enable mouse, so this texture simply never
    -- changes color for them.
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    -- Only shown/positioned when the caller renders Recommendations
    -- (showStars = true in LayoutItemRows) -- hidden and out of the
    -- layout entirely for Insights.
    local starsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    starsText:SetJustifyH("LEFT")
    Format.SetHighlightColor(starsText)

    local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)
    titleText:SetJustifyH("LEFT")
    Format.SetHighlightColor(titleText)

    local descriptionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descriptionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    descriptionText:SetJustifyH("LEFT")
    descriptionText:SetWordWrap(true)

    -- Presentation System v2 -- was a hardcoded (0.85,0.85,0.85); migrated
    -- to the real "dim" token (0.7,0.7,0.7).
    descriptionText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    -- Optional reason/expected benefit/estimated time lines -- only shown
    -- when a recommendation actually supplies them.
    local detailsText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detailsText:SetPoint("TOPLEFT", descriptionText, "BOTTOMLEFT", 0, -4)
    detailsText:SetJustifyH("LEFT")
    detailsText:SetWordWrap(true)
    detailsText:SetSpacing(2)

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)
    metaText:SetJustifyH("LEFT")

    -- Dismiss (Companion Intelligence vNext) -- only shown/positioned for
    -- real recommendation rows with a stable id (LayoutItemRows below).
    -- Parented to `row` so it defaults to a higher frame level than its
    -- parent (WoW's own default child-frame-level rule) and naturally
    -- receives clicks before row's own OnMouseUp (the Inspector-opening
    -- click) does -- explicit SetFrameLevel below only to make that
    -- ordering intentional rather than incidental.
    local dismissButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    dismissButton:SetSize(20, 18)
    dismissButton:SetText(AC.L:Get("Dashboard.DismissButtonGlyph"))
    dismissButton:SetFrameLevel(row:GetFrameLevel() + 1)
    dismissButton:Hide()

    dismissButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(AC.L:Get("Dashboard.DismissButtonTooltip"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    dismissButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.DismissButton = dismissButton

    row.StarsText = starsText
    row.TitleText = titleText
    row.DescriptionText = descriptionText
    row.DetailsText = detailsText
    row.MetaText = metaText

    return row

end

-------------------------------------------------------------------------------
-- Hero Section
--
-- The visual focus of a flagship page: a centered headline, a large
-- value, and a dimmed caption underneath. Generic on purpose -- takes
-- plain strings rather than any MythicPlus-specific concept, so a future
-- flagship page (Delves, Raids, ...) can reuse it directly.
--
-- Cached on page.Hero (one instance per page, reused/repositioned every
-- call) rather than created fresh each time -- the caller (a flagship
-- page) rebuilds its whole layout on every show/refresh/row click, and a
-- page only ever has one Hero, so creating new FontStrings each call
-- would leak an overlapping duplicate set on every refresh.
-------------------------------------------------------------------------------

function Dashboard:BuildHeroSection(page, scrollChild, yOffset, contentWidth, headline, bigValue, caption)

    page.Hero = page.Hero or {}

    local hero = page.Hero

    if not hero.Headline then

        hero.Headline = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hero.Headline:SetJustifyH("CENTER")

        hero.Value = scrollChild:CreateFontString(nil, "OVERLAY")
        hero.Value:SetFontObject(Layout.HERO_VALUE_FONT)
        hero.Value:SetJustifyH("CENTER")

        hero.Caption = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hero.Caption:SetJustifyH("CENTER")

    end

    headline = headline or ""
    bigValue = bigValue or ""
    caption = caption or ""

    hero.Headline:ClearAllPoints()
    hero.Headline:SetPoint("TOP", 0, yOffset)
    hero.Headline:SetWidth(contentWidth)
    hero.Headline:SetText(headline)

    yOffset = yOffset - (hero.Headline:GetStringHeight() or 18) - Layout.HERO_HEADLINE_GAP

    hero.Value:ClearAllPoints()
    hero.Value:SetPoint("TOP", 0, yOffset)
    hero.Value:SetWidth(contentWidth)
    hero.Value:SetText(bigValue)

    if bigValue ~= "" then
        yOffset = yOffset - (hero.Value:GetStringHeight() or 30) - Layout.HERO_VALUE_GAP
    end

    hero.Caption:ClearAllPoints()
    hero.Caption:SetPoint("TOP", 0, yOffset)
    hero.Caption:SetWidth(contentWidth)
    hero.Caption:SetText(caption)

    if caption ~= "" then
        yOffset = yOffset - (hero.Caption:GetStringHeight() or 12) - Layout.HERO_CAPTION_GAP
    end

    yOffset = yOffset - Layout.HERO_BOTTOM_GAP

    return hero.Headline, hero.Value, hero.Caption, yOffset

end

-------------------------------------------------------------------------------
-- Run Level Chart (v1.0 Polish Sprint)
--
-- A small visual timeline of recent runs -- one bar per record, height
-- proportional to key level (relative to the tallest bar in the set),
-- colored by outcome (timed/failed, the same green/red every other
-- status glyph already uses). Purely a different rendering of data this
-- addon already recorded (MythicPlusModule's own ActivityHistoryService
-- records via GetRecentRuns) -- computes nothing, invents nothing.
-- Generic over any record list shaped like { Data = { level = N },
-- Success = bool }, so a future module with its own recorded history
-- (Delves, Raids) can reuse it. Oldest run on the left, newest on the
-- right -- reads left-to-right as "how did I get here," matching how a
-- reader scans a timeline.
-------------------------------------------------------------------------------

function Dashboard:LayoutRunLevelChart(page, poolKey, scrollChild, yOffset, contentWidth, records)

    page.Pools = page.Pools or {}

    local pool = page.Pools[poolKey]

    if not pool then
        pool = {}
        page.Pools[poolKey] = pool
    end

    local CHART_HEIGHT = 44
    local BAR_GAP = 4

    if not records or #records == 0 then

        for _, bar in ipairs(pool) do
            bar:Hide()
        end

        return yOffset

    end

    local maxLevel = 1

    for _, record in ipairs(records) do
        local level = (record.Data or {}).level or 0
        if level > maxLevel then
            maxLevel = level
        end
    end

    local count = #records
    local barWidth = (contentWidth - (BAR_GAP * (count - 1))) / count

    if not pool.Holder then

        local holder = CreateFrame("Frame", nil, scrollChild)
        pool.Holder = holder

    end

    pool.Holder:SetSize(contentWidth, CHART_HEIGHT)
    pool.Holder:ClearAllPoints()
    pool.Holder:SetPoint("TOPLEFT", 0, yOffset)
    pool.Holder:Show()

    -- Oldest first (records arrive newest-first from GetRecentRuns).
    for displayIndex = 1, count do

        local record = records[count - displayIndex + 1]
        local data = record.Data or {}
        local level = data.level or 0

        local bar = pool[displayIndex]

        if not bar then

            bar = CreateFrame("Frame", nil, pool.Holder)

            local fill = bar:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("BOTTOMLEFT")
            fill:SetPoint("BOTTOMRIGHT")
            bar.Fill = fill

            bar:SetScript("OnEnter", function(self)

                if not self.TooltipText then
                    return
                end

                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.TooltipText, 1, 1, 1, 1, true)
                GameTooltip:Show()

            end)

            bar:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            pool[displayIndex] = bar

        end

        local barHeight = math.max((level / maxLevel) * CHART_HEIGHT, 3)

        bar:SetSize(barWidth, CHART_HEIGHT)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", pool.Holder, "BOTTOMLEFT", (displayIndex - 1) * (barWidth + BAR_GAP), 0)
        bar:EnableMouse(true)

        bar.Fill:ClearAllPoints()
        bar.Fill:SetPoint("BOTTOMLEFT")
        bar.Fill:SetPoint("BOTTOMRIGHT")
        bar.Fill:SetHeight(barHeight)

        if record.Success then
            local r, g, b = unpack(AC.Presentation.GetSemanticColor("success"))
            bar.Fill:SetColorTexture(r, g, b, 0.9)
        else
            local r, g, b = unpack(AC.Presentation.GetSemanticColor("critical"))
            bar.Fill:SetColorTexture(r, g, b, 0.9)
        end

        bar.TooltipText = string.format("+%d  %s  %s",
            level,
            record.Success and AC.L:Get("Common.Timed") or AC.L:Get("Common.Failed"),
            AC.Presentation.FormatDate(record.Timestamp, "short"))

        bar:Show()

    end

    for index = count + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset - CHART_HEIGHT - Layout.SECTION_GROUP_GAP

end

-------------------------------------------------------------------------------
-- Statistics Grid
--
-- Two-column grid of label/value cells with larger typography than a
-- normal field row -- shared by Key Statistics, Season Statistics,
-- Personal Bests, Performance Trends, Consumables, and Storage's
-- summary grids, and reusable by any future module's "glanceable
-- numbers" section. Pooled per gridKey on the page so more than one grid
-- can coexist. "stats" is an ordered list of { label = locKey, value =
-- already-formatted string }.
-------------------------------------------------------------------------------

function Dashboard:LayoutStatisticsGrid(page, gridKey, scrollChild, yOffset, contentWidth, stats)

    page.Pools = page.Pools or {}

    local pool = page.Pools[gridKey]

    if not pool then
        pool = {}
        page.Pools[gridKey] = pool
    end

    local cellWidth = (contentWidth - Layout.STAT_CELL_GAP) / 2

    for index, stat in ipairs(stats) do

        local cell = pool[index]

        if not cell then

            cell = CreateFrame("Frame", nil, scrollChild)

            local labelText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetJustifyH("LEFT")
            labelText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

            local valueText = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            valueText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -Layout.STAT_LABEL_GAP)
            valueText:SetJustifyH("LEFT")

            cell.LabelText = labelText
            cell.ValueText = valueText

            pool[index] = cell

        end

        local column = (index - 1) % 2
        local gridRow = math.floor((index - 1) / 2)

        cell:SetSize(cellWidth, Layout.STAT_ROW_HEIGHT)
        cell.LabelText:SetWidth(cellWidth)
        cell.ValueText:SetWidth(cellWidth)

        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", column * (cellWidth + Layout.STAT_CELL_GAP), yOffset - (gridRow * Layout.STAT_ROW_HEIGHT))

        cell.LabelText:SetText(AC.L:Get(stat.label))
        cell.ValueText:SetText(stat.value or AC.L:Get("Common.Unknown"))

        cell:Show()

    end

    for index = #stats + 1, #pool do
        pool[index]:Hide()
    end

    local rowCount = math.ceil(#stats / 2)

    return yOffset - (rowCount * Layout.STAT_ROW_HEIGHT) - Layout.SECTION_GROUP_GAP

end

-------------------------------------------------------------------------------
-- History Table
--
-- A reusable "recent completions" table: fixed columns (status/date/
-- level/name/time), newest first, click a row to expand it in place --
-- only one row expanded at a time, tracked as page.ExpandedRunID (the
-- ActivityHistoryService record ID, not an index, since index shifts as
-- new runs are recorded). Built generically over ActivityHistoryService
-- records + a caller-supplied detail-line builder, so a future module
-- (Delves, Raids) with its own recorded history can reuse the same
-- table/expand mechanism instead of writing a new one.
-------------------------------------------------------------------------------

function Dashboard:BuildHistoryRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)

    -- Hover feedback, same treatment as the Recommendations list's own
    -- clickable rows (BuildRecommendationRow) -- this row is clickable
    -- too (expands/collapses its detail line), so it gets the same
    -- affordance.
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    row:SetScript("OnEnter", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0.06)
    end)

    row:SetScript("OnLeave", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0)
    end)

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetJustifyH("LEFT")

    local dateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateText:SetJustifyH("LEFT")
    dateText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelText:SetJustifyH("LEFT")

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetJustifyH("LEFT")

    local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    local detailText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetJustifyH("LEFT")
    detailText:SetWordWrap(true)
    detailText:SetSpacing(3)
    detailText:Hide()

    row.StatusText = statusText
    row.DateText = dateText
    row.LevelText = levelText
    row.NameText = nameText
    row.TimeText = timeText
    row.DetailText = detailText

    return row

end

-------------------------------------------------------------------------------
-- Accordion Engine (generic)
--
-- The shared expand/collapse mechanic behind every accordion-style row
-- list on the Dashboard: pooling, a single-expanded-item-at-a-time
-- toggle, dynamic row height, detail show/hide, and (Accordion Polish
-- Pass) a Blizzard-style disclosure indicator (row.DisclosureIcon, a
-- pooled FontString the engine itself creates/updates every row --
-- callers never touch it, so it's automatic for every current and future
-- caller). Deliberately generic on the collapsed row's own visuals AND
-- the detail area's own contents -- callers own both via opts.buildRow/
-- layoutCollapsed/buildDetail/hideDetail, this engine only owns the
-- pooling/measurement/toggle/disclosure mechanics. Every layoutCollapsed
-- implementation must reserve Layout.ACCORDION_DISCLOSURE_WIDTH on the
-- left for the icon. `LayoutHistoryRows` below is a thin wrapper over
-- this engine (MythicPlus's Recent Runs table); Pages/Accomplishments.lua
-- and Pages/Journey.lua are the other two callers.
--
-- opts =
-- {
--     expandedField   = "ExpandedRunID"  -- page[expandedField] tracks the single page-wide expanded record
--     getRecordID     = function(record) return record.ID end
--     buildRow        = function(scrollChild) return row end
--     layoutCollapsed = function(row, record, contentWidth) return collapsedHeight end
--     buildDetail     = function(row, record, contentWidth, detailYOffset) return detailHeight end -- only called for the expanded row
--     hideDetail      = function(row) end -- called for every non-expanded pooled row
--     onToggle        = function(recordID) end
--     rowGap          = required, spacing between rows
--     detailGap       = optional, defaults to Layout.ACCORDION_DETAIL_GAP
--     detailBottomPad = optional, defaults to Layout.ACCORDION_DETAIL_BOTTOM_PADDING
--     emptyTextKey    = optional -- if provided and records is empty, shows the shared empty-state line; if omitted, empty is a silent no-op (matches LayoutHistoryRows' existing caller-guards-emptiness contract)
-- }
-------------------------------------------------------------------------------

function Dashboard:LayoutAccordionRows(page, poolKey, scrollChild, yOffset, contentWidth, records, opts)

    page.Pools = page.Pools or {}

    local pool = page.Pools[poolKey]

    if not pool then
        pool = {}
        page.Pools[poolKey] = pool
    end

    if not records or #records == 0 then

        for _, row in ipairs(pool) do
            row:Hide()
        end

        if opts.emptyTextKey then
            return self:ShowEmptyLine(pool, scrollChild, "EmptyText", yOffset, contentWidth, opts.emptyTextKey)
        end

        return yOffset

    end

    if pool.EmptyText then
        pool.EmptyText:Hide()
    end

    for index, record in ipairs(records) do

        local row = pool[index]

        if not row then
            row = opts.buildRow(scrollChild)
            pool[index] = row
        end

        row:SetWidth(contentWidth)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        local recordID = opts.getRecordID(record)
        local isExpanded = page[opts.expandedField] == recordID

        -- Accordion Polish Pass -- disclosure indicator, owned by the
        -- engine itself (not opts.buildRow/layoutCollapsed) so every
        -- current and future accordion caller (MythicPlus's Recent Runs
        -- included) gets it automatically. Reuses the same isExpanded
        -- boolean the engine already computes for its own toggle logic
        -- below, rather than a second comparison. Left uncolored
        -- (default) rather than gold-highlighted -- reads as UI chrome,
        -- not part of the row's own data.
        if not row.DisclosureIcon then

            local icon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon:SetJustifyH("LEFT")
            icon:SetPoint("TOPLEFT", 0, 0)

            row.DisclosureIcon = icon

        end

        row.DisclosureIcon:SetText(isExpanded and Format.DISCLOSURE_EXPANDED or Format.DISCLOSURE_COLLAPSED)
        row.DisclosureIcon:Show()

        local collapsedHeight = opts.layoutCollapsed(row, record, contentWidth)

        local rowHeight = collapsedHeight

        if isExpanded then

            local detailGap = opts.detailGap or Layout.ACCORDION_DETAIL_GAP
            local detailBottomPad = opts.detailBottomPad or Layout.ACCORDION_DETAIL_BOTTOM_PADDING
            local detailYOffset = -(collapsedHeight + detailGap)

            local detailHeight = opts.buildDetail(row, record, contentWidth, detailYOffset) or 0

            rowHeight = collapsedHeight + detailGap + detailHeight + detailBottomPad

        else
            opts.hideDetail(row)
        end

        row:SetHeight(rowHeight)

        row:SetScript("OnClick", function()
            opts.onToggle(recordID)
        end)

        yOffset = yOffset - rowHeight - opts.rowGap

    end

    for index = #records + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

-- A generic single-line clickable accordion row -- name only, no columns.
-- Reused today only by Accomplishments, but deliberately data-agnostic
-- (just a NameText FontString) so a future accordion list that only
-- needs "one name per row, click to expand" doesn't need its own copy.
-- GameFontNormal + the gold highlight color is the same "name has more
-- visual weight than its metadata" treatment BuildRecommendationRow's own
-- TitleText already gets (~line 392-395 above), not a new convention.
function Dashboard:BuildAccomplishmentRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

    row:SetScript("OnEnter", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0.06)
    end)

    row:SetScript("OnLeave", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0)
    end)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetJustifyH("LEFT")
    Format.SetHighlightColor(nameText)

    row.NameText = nameText

    return row

end

-------------------------------------------------------------------------------
-- Accordion Detail Fields (generic)
--
-- A cached label/value pair directly on a pooled accordion row -- same
-- lazy-create-once shape as Pages/Storage.lua's own AddCachedField, just
-- scoped to a row instead of a page. Promoted out of Pages/Accomplishments.lua
-- (Character Journey pass) the moment a second real caller (Pages/Journey.lua)
-- needed the identical mechanic -- same "shared the moment a second caller
-- needs it, not before" discipline LayoutTextLines/LayoutAccordionRows
-- themselves were already promoted under. Indented to Layout.ACCORDION_DETAIL_INDENT
-- (Accordion Polish Pass), deeper than the collapsed row's own title, so
-- expanded content reads as visually nested under the row it belongs to
-- rather than flush with it.
-------------------------------------------------------------------------------

function Dashboard:SetAccordionDetailField(row, cacheKey, labelKey, value, yOffset, width)

    local labelKeyName = cacheKey .. "Label"
    local valueKeyName = cacheKey .. "Value"

    if not row[labelKeyName] then

        local labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetJustifyH("LEFT")
        labelText:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
        row[labelKeyName] = labelText

        local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetJustifyH("LEFT")
        row[valueKeyName] = valueText

    end

    local valueWidth = width - Layout.ACCORDION_DETAIL_INDENT - Layout.FIELD_LABEL_WIDTH - Layout.FIELD_LABEL_VALUE_GAP

    row[labelKeyName]:ClearAllPoints()
    row[labelKeyName]:SetPoint("TOPLEFT", Layout.ACCORDION_DETAIL_INDENT, yOffset)
    row[labelKeyName]:SetWidth(Layout.FIELD_LABEL_WIDTH)
    row[labelKeyName]:SetText(AC.L:Get(labelKey))
    row[labelKeyName]:Show()

    row[valueKeyName]:ClearAllPoints()
    row[valueKeyName]:SetPoint("TOPLEFT", Layout.ACCORDION_DETAIL_INDENT + Layout.FIELD_LABEL_WIDTH + Layout.FIELD_LABEL_VALUE_GAP, yOffset)
    row[valueKeyName]:SetWidth(valueWidth)
    row[valueKeyName]:SetText(value)
    row[valueKeyName]:Show()

    return yOffset - Layout.ROW_HEIGHT

end

function Dashboard:HideAccordionDetailField(row, cacheKey)

    if row[cacheKey .. "Label"] then
        row[cacheKey .. "Label"]:Hide()
        row[cacheKey .. "Value"]:Hide()
    end

end

-- Wrapped body-text detail content (e.g. an achievement's own Description)
-- -- same Layout.ACCORDION_DETAIL_INDENT nesting as SetAccordionDetailField
-- above. Promoted out of Pages/Accomplishments.lua and Pages/Journey.lua
-- (Accordion Polish Pass), which had built byte-identical
-- row.DescriptionText blocks independently -- the same promotion
-- discipline SetAccordionDetailField itself already went through.
-- Takes an already-resolved string (not a whole record) so it stays
-- generic over both callers' different field names.
function Dashboard:SetAccordionDetailDescription(row, text, yOffset, width)

    if not text or text == "" then
        self:HideAccordionDetailDescription(row)
        return yOffset
    end

    if not row.DescriptionText then

        local descriptionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descriptionText:SetJustifyH("LEFT")
        descriptionText:SetWordWrap(true)
        row.DescriptionText = descriptionText

    end

    yOffset = yOffset - 4

    row.DescriptionText:ClearAllPoints()
    row.DescriptionText:SetPoint("TOPLEFT", Layout.ACCORDION_DETAIL_INDENT, yOffset)
    row.DescriptionText:SetWidth(width - Layout.ACCORDION_DETAIL_INDENT)
    row.DescriptionText:SetText(text)
    row.DescriptionText:Show()

    return yOffset - (row.DescriptionText:GetStringHeight() or 0)

end

function Dashboard:HideAccordionDetailDescription(row)

    if row.DescriptionText then
        row.DescriptionText:Hide()
    end

end

-- buildDetailLines(record) returns an array of already-localized detail
-- lines for the expanded state -- callers own what counts as a detail.
-- Thin wrapper over LayoutAccordionRows -- reproduces BuildHistoryRow's
-- 5-column collapsed layout and the original single-FontString detail
-- rendering (same anchor offset, same total-height arithmetic:
-- collapsedHeight(=HISTORY_ROW_HEIGHT, now real-height-aware) +
-- detailGap(4) + detailHeight + detailBottomPad(8)). Accordion Polish
-- Pass: columns now shift right by Layout.ACCORDION_DISCLOSURE_WIDTH and
-- gain the engine's own disclosure icon -- an intentional, real, visible
-- change to MythicPlus's Recent Runs table (the one shared improvement
-- this pass explicitly extends to it), everything else unchanged.
function Dashboard:LayoutHistoryRows(page, poolKey, scrollChild, yOffset, contentWidth, records, buildDetailLines, onToggle)

    -- Accordion Polish Pass -- every column shifts right by
    -- ACCORDION_DISCLOSURE_WIDTH to make room for LayoutAccordionRows' own
    -- disclosure icon at X=0 (see layoutCollapsed below). A real, visible,
    -- intentional change to MythicPlus's Recent Runs table -- the one
    -- shared improvement this pass explicitly extends to it.
    local baseX = Layout.ACCORDION_DISCLOSURE_WIDTH
    local nameWidth = contentWidth - baseX - Layout.HISTORY_STATUS_WIDTH - Layout.HISTORY_DATE_WIDTH - Layout.HISTORY_LEVEL_WIDTH - Layout.HISTORY_TIME_WIDTH - (Layout.HISTORY_COLUMN_GAP * 4)

    return self:LayoutAccordionRows(page, poolKey, scrollChild, yOffset, contentWidth, records,
    {
        expandedField = "ExpandedRunID",
        getRecordID = function(record) return record.ID end,
        rowGap = Layout.HISTORY_ROW_GAP,
        detailGap = 4,
        detailBottomPad = 8,

        buildRow = function(sc)
            return self:BuildHistoryRow(sc)
        end,

        layoutCollapsed = function(row, record, width)

            local data = record.Data or {}

            row.StatusText:ClearAllPoints()
            row.StatusText:SetPoint("TOPLEFT", baseX, 0)
            row.StatusText:SetWidth(Layout.HISTORY_STATUS_WIDTH)

            if record.Success then
                row.StatusText:SetText(Format.CHECK_SUCCESS)
            else
                row.StatusText:SetText(Format.CHECK_FAILURE)
            end

            row.DateText:ClearAllPoints()
            row.DateText:SetPoint("TOPLEFT", baseX + Layout.HISTORY_STATUS_WIDTH + Layout.HISTORY_COLUMN_GAP, 0)
            row.DateText:SetWidth(Layout.HISTORY_DATE_WIDTH)
            row.DateText:SetText(AC.Presentation.FormatDate(record.Timestamp, "short"))

            local levelX = baseX + Layout.HISTORY_STATUS_WIDTH + Layout.HISTORY_COLUMN_GAP + Layout.HISTORY_DATE_WIDTH + Layout.HISTORY_COLUMN_GAP

            row.LevelText:ClearAllPoints()
            row.LevelText:SetPoint("TOPLEFT", levelX, 0)
            row.LevelText:SetWidth(Layout.HISTORY_LEVEL_WIDTH)
            row.LevelText:SetText("+" .. tostring(data.level or 0))

            local nameX = levelX + Layout.HISTORY_LEVEL_WIDTH + Layout.HISTORY_COLUMN_GAP

            row.NameText:ClearAllPoints()
            row.NameText:SetPoint("TOPLEFT", nameX, 0)
            row.NameText:SetWidth(nameWidth)
            row.NameText:SetText(record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown"))

            row.TimeText:ClearAllPoints()
            row.TimeText:SetPoint("TOPRIGHT", 0, 0)
            row.TimeText:SetWidth(Layout.HISTORY_TIME_WIDTH)
            row.TimeText:SetText(Format.FormatClock(data.time or 0))

            -- Accordion Polish Pass -- was a hardcoded Layout.HISTORY_ROW_HEIGHT
            -- regardless of NameText's real rendered height; a long
            -- dungeon name that wraps to 2 lines under-reported its
            -- height. math.max keeps today's exact compact height for the
            -- overwhelmingly common short-name case and only grows the
            -- row on a genuine wrap.
            return math.max(row.NameText:GetStringHeight() or Layout.HISTORY_ROW_HEIGHT, Layout.HISTORY_ROW_HEIGHT)

        end,

        buildDetail = function(row, record, width, detailYOffset)

            local lines = buildDetailLines(record)

            row.DetailText:ClearAllPoints()
            row.DetailText:SetPoint("TOPLEFT", 0, detailYOffset)
            row.DetailText:SetWidth(width)
            row.DetailText:SetText(table.concat(lines, "\n"))
            row.DetailText:Show()

            return row.DetailText:GetStringHeight() or 0

        end,

        hideDetail = function(row)
            row.DetailText:Hide()
        end,

        onToggle = onToggle,
    })

end

return Dashboard
