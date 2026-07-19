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
-- recommendation records have the same title/description/priority shape.
-- `isRecommendation` additionally enables dismiss/inspect behavior and a
-- "Why?" hint -- callers showing Insights pass isRecommendation = false,
-- since an observation isn't something to dismiss or inspect the scoring
-- of.
--
-- Recommendations Information Architecture Pass -- a row shows exactly
-- four things now: Title, Description (the one thing this recommendation
-- is telling the player), Priority, and Why? -- answering "what should I
-- do / is it important / where do I go if I want more" in one glance, per
-- this addon's own design goal for this page. Reason/Expected Benefit/
-- Estimated Time/Supporting Evidence/Category/Confidence used to also
-- render here, turning every row into a small wall of metadata that
-- competed with the recommendation itself for attention -- all of them
-- were already fully rendered by the same Why? this row still offers
-- (RecommendationInspector.lua at the time, now Recommendation Details --
-- see Navigation UX Sprint), so removing them from the row is
-- not a loss of information, only of premature exposure. See
-- docs/GameplayModuleArchitecture.md's "Recommendations Information
-- Architecture" section for the full audit and reasoning.
-------------------------------------------------------------------------------

function Dashboard:LayoutItemRows(scrollChild, pool, items, yOffset, contentWidth, emptyTextKey, rowGap, isRecommendation)

    -- Companion Intelligence vNext -- only real recommendation lists
    -- (isRecommendation = true) can carry a dismissible `id`; Insight lists
    -- never do, so this filter is a no-op for them.
    if isRecommendation then
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

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        row.TitleText:ClearAllPoints()
        row.TitleText:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)

        -- Dismiss (Companion Intelligence vNext) -- only for real
        -- recommendations with a stable id, only while the history
        -- service exists to record the click.
        if isRecommendation and item.id and AC.RecommendationHistoryService then

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

        row.MetaText:ClearAllPoints()
        row.MetaText:SetPoint("TOPLEFT", row.DescriptionText, "BOTTOMLEFT", 0, -4)

        -- Priority is the one fact this row needs to answer "is it
        -- important" at a glance -- Category/Confidence/Reason/Expected
        -- Benefit/Estimated Time/Supporting Evidence all used to render
        -- here too and now live in the Why? inspector only (see this
        -- function's own header). Renders as a label (High/Medium/Low),
        -- not a raw 0-100 score -- the same readable-at-a-glance treatment
        -- DashboardCard's Detail Sections use (Format.GetPriorityLabel).
        local priorityLabel = item.priority and Format.GetPriorityLabel(item.priority) or AC.L:Get("Common.Unknown")
        local metaText = AC.L:Format("Dashboard.RecommendationMetaFormat", priorityLabel)

        -- Recommendation Details -- a "Why?" hint appended to the same
        -- meta line, and the whole row made clickable/hoverable, only for
        -- real recommendation rows (isRecommendation = true). Insight rows
        -- have nothing to inspect, so they stay inert, exactly as before.
        -- Navigation UX Sprint -- was AC.RecommendationInspector:Show(item)
        -- (a standalone popup); now navigates to the real
        -- RecommendationDetails Dashboard page, same as every other
        -- click-through on this page.
        if isRecommendation then

            metaText = metaText .. "   " .. AC.L:Get("Dashboard.ClickForWhy")

            row:EnableMouse(true)

            row:SetScript("OnEnter", function(self)
                self.Background:SetColorTexture(1, 1, 1, 0.06)
            end)

            row:SetScript("OnLeave", function(self)
                self.Background:SetColorTexture(1, 1, 1, 0)
            end)

            row:SetScript("OnMouseUp", function(self, button)

                if button == "LeftButton" then
                    AC.Dashboard:ShowRecommendationDetails(item)
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

        local rowHeight = titleHeight + 4 + descriptionHeight + 4 + metaHeight

        row:SetHeight(rowHeight)

        -- Row Separator -- shown in the gap below every row except the
        -- last (a trailing hairline right before the empty space at the
        -- bottom of the list reads as a stray mark, not a separator).
        row.Divider:ClearAllPoints()
        row.Divider:SetPoint("TOPLEFT", row, "BOTTOMLEFT", Layout.ROW_INDENT, -(rowGap / 2))
        row.Divider:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -(rowGap / 2))

        if index < #items then
            row.Divider:Show()
        else
            row.Divider:Hide()
        end

        yOffset = yOffset - rowHeight - rowGap

    end

    for index = #items + 1, #pool do
        pool[index]:Hide()
    end

    return yOffset

end

-------------------------------------------------------------------------------
-- Forecast Rows
--
-- Shared pooled planning-card presentation. The row understands only the
-- normalized ForecastItem display contract; collection and priority remain
-- entirely owned by ForecastService.
-------------------------------------------------------------------------------

function Dashboard:BuildForecastRow(scrollChild)

    local row = CreateFrame("Button", nil, scrollChild)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.04)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 10, -10)

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    title:SetJustifyH("LEFT")
    Format.SetHighlightColor(title)

    local description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    local priorityBadge = CreateFrame("Frame", nil, row)
    priorityBadge:SetPoint("TOPRIGHT", -10, -8)
    priorityBadge:SetHeight(18)

    local priorityBackground = priorityBadge:CreateTexture(nil, "BACKGROUND")
    priorityBackground:SetAllPoints()

    local priority = priorityBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priority:SetPoint("CENTER")
    priority:SetJustifyH("CENTER")

    local action = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    action:SetJustifyH("LEFT")
    action:SetTextColor(unpack(AC.Presentation.GetSemanticColor("accent")))

    row.Icon = icon
    row.TitleText = title
    row.DescriptionText = description
    row.PriorityBadge = priorityBadge
    row.PriorityBackground = priorityBackground
    row.PriorityText = priority
    row.ActionText = action

    return row

end

function Dashboard:LayoutForecastRows(scrollChild, pool, items, yOffset, contentWidth, emptyTextKey)

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
            row = self:BuildForecastRow(scrollChild)
            pool[index] = row
        end

        local priorityLabel, priorityColor = Format.GetPriorityLabel(item.priority)
        local r, g, b = unpack(AC.Presentation.GetSemanticColor(priorityColor))

        row:SetWidth(contentWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)

        row.Icon:SetTexture(item.icon)
        row.TitleText:SetWidth(contentWidth - 128)
        row.TitleText:SetText(item.title)
        row.DescriptionText:SetWidth(contentWidth - 68)
        row.DescriptionText:SetText(item.description)
        row.PriorityText:SetText(priorityLabel)
        row.PriorityText:SetTextColor(r, g, b)
        row.PriorityBadge:SetWidth((row.PriorityText:GetStringWidth() or 30) + 12)
        row.PriorityBackground:SetColorTexture(r, g, b, 0.16)

        row.ActionText:ClearAllPoints()
        row.ActionText:SetPoint("TOPLEFT", row.DescriptionText, "BOTTOMLEFT", 0, -7)
        row.ActionText:SetText(item.actionText)

        -- Forecast rows are pooled, so the active item must be rebound on
        -- every layout pass rather than captured only when the row is built.
        row.ForecastItem = item
        row:SetScript("OnClick", function(self)

            local currentItem = self.ForecastItem

            if currentItem then
                AC.Dashboard:ExecuteForecastAction(currentItem.action)
            end

        end)

        local rowHeight = math.max(28, (row.TitleText:GetStringHeight() or 14) + 5 + (row.DescriptionText:GetStringHeight() or 12) + 7 + (row.ActionText:GetStringHeight() or 12)) + 20
        row:SetHeight(rowHeight)
        row:Show()

        yOffset = yOffset - rowHeight - 10

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
-- deliberately simpler than LayoutItemRows above (no priority/reason/
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
-- Append Text Section
--
-- Composes the section chrome and pooled text-list renderer used by pages
-- that already prepared their records and formatting callback. It owns no
-- data lookup, ordering, or gameplay formatting.
-------------------------------------------------------------------------------

function Dashboard:AppendTextSection(page, poolKey, titleKey, yOffset, items, emptyTextKey, formatLine)

    local scrollChild = page.ScrollChild
    local contentWidth = page.ContentWidth or Layout.PAGE_CONTENT_WIDTH_FULL

    yOffset = self:BeginSection(scrollChild, titleKey, yOffset)

    page.Pools = page.Pools or {}
    page.Pools[poolKey] = page.Pools[poolKey] or {}

    yOffset = self:LayoutTextLines(scrollChild, page.Pools[poolKey], items, yOffset, contentWidth, emptyTextKey, formatLine)

    return self:EndSection(yOffset)

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

function Dashboard:AppendDynamicSection(page, poolKey, titleKey, yOffset, items, emptyTextKey, isRecommendation)

    local scrollChild = page.ScrollChild
    local contentWidth = page.ContentWidth or Layout.PAGE_CONTENT_WIDTH_FULL

    yOffset = self:BeginSection(scrollChild, titleKey, yOffset)

    page.Pools = page.Pools or {}
    page.Pools[poolKey] = page.Pools[poolKey] or {}

    -- A tighter row gap than the standalone Recommendations page uses --
    -- here this is one compact section among several on the page, not
    -- the main content.
    yOffset = self:LayoutItemRows(scrollChild, page.Pools[poolKey], items, yOffset, contentWidth, emptyTextKey, 12, isRecommendation)

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

    -- Row Separator (Navigation Audit, UI Polish Pass) -- a static hairline
    -- in the gap below this row, same color/alpha as every other divider
    -- in this codebase. Anchored to the row's own BOTTOM and extending
    -- into that gap (WoW does not clip a frame's children to its own
    -- bounds, the same fact Home's own ScrollFrame comment already relies
    -- on) rather than a page-specific hack -- every caller of
    -- LayoutItemRows below (the standalone Recommendations page AND every
    -- other page's dynamic Recommendations/Insights mini-section) gets
    -- clearer card-to-card separation for free.
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.10)
    divider:SetHeight(Layout.DIVIDER_HEIGHT)
    row.Divider = divider

    -- Hover feedback for the Recommendation Inspector (see LayoutItemRows
    -- below) -- transparent normally, a faint highlight on mouseover.
    -- Insight rows never enable mouse, so this texture simply never
    -- changes color for them.
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0)

    row.Background = background

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

    row.TitleText = titleText
    row.DescriptionText = descriptionText
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
-- Append Statistics Section
--
-- Composes a standard section around a prepared statistics grid. Empty and
-- populated states share one lifecycle so pooled cells cannot remain visible
-- when a section becomes empty. Values arrive fully formatted by the caller.
-------------------------------------------------------------------------------

function Dashboard:AppendStatisticsSection(page, gridKey, titleKey, yOffset, stats, emptyTextKey)

    local scrollChild = page.ScrollChild
    local contentWidth = page.ContentWidth or Layout.PAGE_CONTENT_WIDTH_FULL
    local emptyCacheKey = gridKey .. "EmptyText"

    stats = stats or {}
    yOffset = self:BeginSection(scrollChild, titleKey, yOffset)

    if #stats == 0 then

        -- LayoutStatisticsGrid owns its pooled cells. An empty render hides
        -- any cells left from a previously populated refresh without changing
        -- the empty line's offset.
        self:LayoutStatisticsGrid(page, gridKey, scrollChild, yOffset, contentWidth, stats)

        if emptyTextKey then
            yOffset = self:ShowEmptyLine(page, scrollChild, emptyCacheKey, yOffset, contentWidth, emptyTextKey)
        end

    else

        if page[emptyCacheKey] then
            page[emptyCacheKey]:Hide()
        end

        yOffset = self:LayoutStatisticsGrid(page, gridKey, scrollChild, yOffset, contentWidth, stats)

    end

    return self:EndSection(yOffset)

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
    row:RegisterForClicks("LeftButtonUp")

    -- Clear default Button textures to ensure visual transparency
    -- (WoW Buttons can have default visual styling even without a template)
    row:SetNormalTexture("")
    row:SetPushedTexture("")
    row:SetHighlightTexture("")
    row:SetDisabledTexture("")

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
-- Pass) an ASCII ">"/"v" disclosure indicator (row.DisclosureIcon, a
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
        -- below, rather than a second comparison. Centered vertically in
        -- its reserved column and deliberately dimmed so it supports the
        -- full clickable row without competing with the dungeon name.
        if not row.DisclosureIcon then

            local icon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon:SetJustifyH("CENTER")
            icon:SetPoint("LEFT", row, "LEFT", 0, 0)
            icon:SetWidth(Layout.ACCORDION_DISCLOSURE_WIDTH)
            icon:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

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

    -- Clear default Button textures to ensure visual transparency
    -- (WoW Buttons can have default visual styling even without a template)
    row:SetNormalTexture("")
    row:SetPushedTexture("")
    row:SetHighlightTexture("")
    row:SetDisabledTexture("")

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
--
-- Optional cacheKey (Developer Panel Errors tab addition): defaults to
-- "Description" -- reconstructing the exact row.DescriptionText field
-- name both existing callers (Accomplishments/Journey, one description
-- block per row) already rely on, so this is fully backward compatible.
-- A caller needing more than one wrapped body-text block per row (Errors:
-- full message AND stack trace) passes a distinct cacheKey per block
-- instead of the two blocks clobbering the same field.
function Dashboard:SetAccordionDetailDescription(row, text, yOffset, width, cacheKey)

    local fieldKey = (cacheKey or "Description") .. "Text"

    if not text or text == "" then
        self:HideAccordionDetailDescription(row, cacheKey)
        return yOffset
    end

    if not row[fieldKey] then

        local descriptionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descriptionText:SetJustifyH("LEFT")
        descriptionText:SetWordWrap(true)
        row[fieldKey] = descriptionText

    end

    yOffset = yOffset - 4

    row[fieldKey]:ClearAllPoints()
    row[fieldKey]:SetPoint("TOPLEFT", Layout.ACCORDION_DETAIL_INDENT, yOffset)
    row[fieldKey]:SetWidth(width - Layout.ACCORDION_DETAIL_INDENT)
    row[fieldKey]:SetText(text)
    row[fieldKey]:Show()

    return yOffset - (row[fieldKey]:GetStringHeight() or 0)

end

function Dashboard:HideAccordionDetailDescription(row, cacheKey)

    local fieldKey = (cacheKey or "Description") .. "Text"

    if row[fieldKey] then
        row[fieldKey]:Hide()
    end

end

-- buildDetailLines(record) returns an array of already-localized detail
-- lines for the expanded state -- callers own what counts as a detail.
-- Thin wrapper over LayoutAccordionRows -- lays out the collapsed row's
-- dungeon/level/date/time fields plus optional pooled summary icons (same
-- anchor offset and total-height arithmetic:
-- collapsedHeight(=HISTORY_ROW_HEIGHT, now real-height-aware) +
-- detailGap(4) + detailHeight + detailBottomPad(8)). Accordion Polish
-- Pass: columns now shift right by Layout.ACCORDION_DISCLOSURE_WIDTH and
-- gain the engine's own disclosure icon -- an intentional, real, visible
-- change to MythicPlus's Recent Runs table (the one shared improvement
-- this pass explicitly extends to it), everything else unchanged.
local function ShowHistorySuppliedTooltip(frame)

    if not frame.TooltipTitle or frame.TooltipTitle == "" then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(frame.TooltipTitle, 1, 1, 1)

    if frame.TooltipText and frame.TooltipText ~= "" then
        GameTooltip:AddLine(frame.TooltipText, nil, nil, nil, true)
    end

    GameTooltip:Show()

end

local function AcquireHistorySummaryIcon(row, index)

    row.SummaryIcons = row.SummaryIcons or {}

    local iconFrame = row.SummaryIcons[index]

    if iconFrame then
        return iconFrame
    end

    iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(16, 16)
    iconFrame:EnableMouse(true)

    iconFrame.Icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.Icon:SetAllPoints()

    iconFrame:SetScript("OnEnter", ShowHistorySuppliedTooltip)
    iconFrame:SetScript("OnLeave", GameTooltip_Hide)
    iconFrame:SetScript("OnMouseUp", function()
        row:Click()
    end)

    row.SummaryIcons[index] = iconFrame

    return iconFrame

end

function Dashboard:LayoutHistoryRows(page, poolKey, scrollChild, yOffset, contentWidth, records, buildDetailLines, buildSummaryIcons, onToggle)

    -- Accordion Polish Pass -- every column shifts right by
    -- ACCORDION_DISCLOSURE_WIDTH to make room for LayoutAccordionRows' own
    -- disclosure icon at X=0 (see layoutCollapsed below). A real, visible,
    -- intentional change to MythicPlus's Recent Runs table -- the one
    -- shared improvement this pass explicitly extends to it.
    local baseX = Layout.ACCORDION_DISCLOSURE_WIDTH
    -- Date and time share one compact two-line block. This keeps both values
    -- readable without allowing the year or AM/PM marker to wrap onto an
    -- extra line, and returns the former time column's width to the name.
    local dateTimeWidth = Layout.HISTORY_DATE_WIDTH + Layout.HISTORY_TIME_WIDTH
    local nameWidth = contentWidth - baseX - Layout.HISTORY_LEVEL_WIDTH - dateTimeWidth - (Layout.HISTORY_COLUMN_GAP * 2)

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
            local summaryIcons = buildSummaryIcons and buildSummaryIcons(record) or {}
            local iconSize = 16
            local iconGap = 2
            local iconLeadingGap = 5
            local iconsWidth = #summaryIcons > 0 and ((#summaryIcons * iconSize) + ((#summaryIcons - 1) * iconGap) + iconLeadingGap) or 0
            local availableNameWidth = math.max(20, nameWidth - iconsWidth)

            row.NameText:ClearAllPoints()
            row.NameText:SetPoint("TOPLEFT", baseX, 0)
            row.NameText:SetWidth(availableNameWidth)
            row.NameText:SetWordWrap(false)
            row.NameText:SetText(record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown"))

            local renderedNameWidth = math.min(row.NameText:GetStringWidth() or availableNameWidth, availableNameWidth)
            local iconX = baseX + renderedNameWidth + iconLeadingGap

            for index, descriptor in ipairs(summaryIcons) do

                local iconFrame = AcquireHistorySummaryIcon(row, index)

                iconFrame:ClearAllPoints()
                iconFrame:SetPoint("LEFT", row, "LEFT", iconX + ((index - 1) * (iconSize + iconGap)), 0)
                iconFrame.Icon:SetTexture(descriptor.icon)
                iconFrame.TooltipTitle = descriptor.tooltipTitle
                iconFrame.TooltipText = descriptor.tooltipText
                iconFrame:Show()

            end

            for index = #summaryIcons + 1, #(row.SummaryIcons or {}) do
                row.SummaryIcons[index]:Hide()
            end

            local levelX = baseX + nameWidth + Layout.HISTORY_COLUMN_GAP

            row.LevelText:ClearAllPoints()
            row.LevelText:SetPoint("TOPLEFT", levelX, 0)
            row.LevelText:SetWidth(Layout.HISTORY_LEVEL_WIDTH)
            row.LevelText:SetJustifyH("RIGHT")
            row.LevelText:SetText("+" .. AC.Presentation.FormatNumber(data.level, 0))

            row.DateText:ClearAllPoints()
            row.DateText:SetPoint("TOPRIGHT", 0, 2)
            row.DateText:SetWidth(dateTimeWidth)
            row.DateText:SetJustifyH("RIGHT")
            row.DateText:SetWordWrap(false)
            row.DateText:SetText(AC.Presentation.FormatDate(record.Timestamp, "short"))

            row.TimeText:ClearAllPoints()
            row.TimeText:SetPoint("TOPRIGHT", row.DateText, "BOTTOMRIGHT", 0, 1)
            row.TimeText:SetWidth(dateTimeWidth)
            row.TimeText:SetWordWrap(false)
            row.TimeText:SetText(AC.Presentation.FormatDate(record.Ended or record.Timestamp, "time12"))

            -- Summary row height remains unchanged. The name receives the
            -- width left after its affix icons and clips instead of growing
            -- the row; date/time share the compact metadata block above.
            return Layout.HISTORY_ROW_HEIGHT

        end,

        buildDetail = function(row, record, width, detailYOffset)

            local lines = buildDetailLines(record)

            row.DetailText:ClearAllPoints()
            row.DetailText:SetPoint("TOPLEFT", 0, detailYOffset)
            row.DetailText:SetWidth(width)
            row.DetailText:SetText(table.concat(lines, "\n"))
            row.DetailText:SetShown(#lines > 0)

            return #lines > 0 and (row.DetailText:GetStringHeight() or 0) or 0

        end,

        hideDetail = function(row)
            row.DetailText:Hide()
        end,

        onToggle = onToggle,
    })

end

-------------------------------------------------------------------------------
-- Great Vault Overview
--
-- Shared, presentation-only projection of WeeklyModule's normalized category
-- and slot models. It never calls C_WeeklyRewards or derives reward levels.
-------------------------------------------------------------------------------

local VAULT_SLOT_GAP = 8
local VAULT_SLOT_HEIGHT = 140

local function GetVaultSlotState(slot)

    if slot.unlocked and (slot.nextUpgradeLevel or slot.nextUpgradeItemLevel) then
        return "Weekly.StateUpgradeAvailable", "accent"
    elseif slot.unlocked then
        return "Weekly.StateUnlocked", "success"
    elseif (slot.progress or 0) > 0 then
        return "Weekly.StateInProgress", "warning"
    end

    return "Weekly.StateLocked", "dim"

end

local function HasCurrentVaultReward(slot)

    if not slot.unlocked or not slot.rewardItemLevel then
        return false
    end

    if not slot.rewardIsPreview then
        return true
    end

    -- Blizzard's WeeklyRewardsActivityMixin presents the first hyperlink from
    -- GetExampleRewardItemHyperlinks as CURRENT_REWARD for an unlocked slot;
    -- the second hyperlink/GetNext*Increase value is the future upgrade. Keep
    -- that current projection only while it remains strictly below a separately
    -- reported next reward. Equal or inverted values are ambiguous and must not
    -- be presented as already earned.
    if slot.nextUpgradeItemLevel then
        local currentItemLevel = tonumber(slot.rewardItemLevel)
        local nextItemLevel = tonumber(slot.nextUpgradeItemLevel)

        return currentItemLevel ~= nil and nextItemLevel ~= nil and currentItemLevel < nextItemLevel
    end

    return true

end

local function GetVaultUpgradeText(slot)

    if slot.nextUpgradeLevel and slot.nextUpgradeItemLevel then
        return AC.L:Format(
            "Weekly.UpgradeRewardFormat",
            AC.L:Format("Weekly.UpgradeLevelFormat", slot.nextUpgradeLevel),
            AC.Presentation.FormatItemLevel(slot.nextUpgradeItemLevel))
    elseif slot.nextUpgradeLevel then
        return AC.L:Format("Weekly.UpgradeOnlyFormat", AC.L:Format("Weekly.UpgradeLevelFormat", slot.nextUpgradeLevel))
    elseif slot.nextUpgradeItemLevel then
        return AC.L:Format("Weekly.UpgradeItemLevelOnlyFormat", AC.Presentation.FormatItemLevel(slot.nextUpgradeItemLevel))
    end

    return nil

end

local function GetVaultUnitLabel(category, count)

    return AC.L:Get(count == 1 and category.unitSingularKey or category.unitPluralKey)

end

local function GetVaultQualifyingText(category, slot)

    if slot.raidString and slot.raidString ~= "" then
        return slot.raidString
    elseif not slot.level or slot.level <= 0 then
        return nil
    elseif category.id == "Dungeons" then
        return AC.L:Format("Weekly.DungeonLevelFormat", slot.level)
    elseif category.id == "Delves" then
        return AC.L:Format("Weekly.DelveLevelFormat", slot.level)
    end

    return AC.L:Format("Weekly.ActivityLevelFormat", slot.level)

end

local function ShowVaultSlotTooltip(frame)

    local slot = frame.Slot
    local category = frame.Category

    if not slot or not category then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

    local hasCurrentReward = HasCurrentVaultReward(slot)

    if hasCurrentReward and slot.rewardHyperlink then
        GameTooltip:SetHyperlink(slot.rewardHyperlink)
        GameTooltip:AddLine(" ")
    else
        GameTooltip:SetText(AC.L:Format("Weekly.ChestLabel", slot.index or 0), 1, 0.82, 0)
    end

    local stateKey = GetVaultSlotState(slot)
    GameTooltip:AddLine(AC.L:Get(stateKey), 1, 0.82, 0)
    GameTooltip:AddDoubleLine(
        AC.L:Get("Weekly.TooltipProgress"),
        AC.L:Format("Weekly.ProgressFormat", slot.progress or 0, slot.threshold or 0),
        0.75, 0.75, 0.75, 1, 1, 1)

    if slot.remaining and slot.remaining > 0 then
        GameTooltip:AddLine(AC.L:Format("Weekly.RemainingFormat", slot.remaining, GetVaultUnitLabel(category, slot.remaining)), 0.85, 0.85, 0.85, true)
    end

    if hasCurrentReward and slot.rewardItemLevel then
        GameTooltip:AddDoubleLine(
            AC.L:Get("Weekly.TooltipItemLevel"),
            AC.Presentation.FormatItemLevel(slot.rewardItemLevel),
            0.75, 0.75, 0.75, 1, 1, 1)
    end

    local qualifyingText = GetVaultQualifyingText(category, slot)

    if qualifyingText then
        GameTooltip:AddLine(qualifyingText, 0.75, 0.75, 0.75, true)
    end

    local upgradeText = GetVaultUpgradeText(slot)

    if upgradeText then
        GameTooltip:AddDoubleLine(AC.L:Get("Weekly.TooltipNextUpgrade"), upgradeText, 0.75, 0.75, 0.75, 1, 1, 1)
    end

    GameTooltip:Show()

end

local function CreateVaultOverviewSlot(parent)

    local slotFrame = CreateFrame("Frame", nil, parent)
    slotFrame:EnableMouse(true)

    slotFrame.Background = slotFrame:CreateTexture(nil, "BACKGROUND")
    slotFrame.Background:SetAllPoints()
    slotFrame.Background:SetColorTexture(1, 1, 1, 0.04)

    slotFrame.StateBar = slotFrame:CreateTexture(nil, "ARTWORK")
    slotFrame.StateBar:SetPoint("TOPLEFT")
    slotFrame.StateBar:SetPoint("BOTTOMLEFT")
    slotFrame.StateBar:SetWidth(3)

    slotFrame.Title = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotFrame.Title:SetPoint("TOPLEFT", 10, -9)
    slotFrame.Title:SetJustifyH("LEFT")

    slotFrame.State = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    slotFrame.State:SetPoint("TOPLEFT", slotFrame.Title, "BOTTOMLEFT", 0, -5)
    slotFrame.State:SetJustifyH("LEFT")
    slotFrame.State:SetWordWrap(false)

    slotFrame.ItemLevel = slotFrame:CreateFontString(nil, "OVERLAY")
    slotFrame.ItemLevel:SetFontObject(Layout.HERO_VALUE_FONT)
    slotFrame.ItemLevel:SetPoint("TOPLEFT", slotFrame.State, "BOTTOMLEFT", 0, -4)
    slotFrame.ItemLevel:SetJustifyH("LEFT")

    slotFrame.Quality = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slotFrame.Quality:SetPoint("TOPLEFT", slotFrame.ItemLevel, "BOTTOMLEFT", 0, 0)
    slotFrame.Quality:SetJustifyH("LEFT")

    slotFrame.Progress = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slotFrame.Progress:SetPoint("BOTTOMLEFT", 10, 10)
    slotFrame.Progress:SetJustifyH("LEFT")

    slotFrame.Remaining = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slotFrame.Remaining:SetPoint("BOTTOMRIGHT", -10, 11)
    slotFrame.Remaining:SetJustifyH("RIGHT")

    slotFrame:SetScript("OnEnter", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0.08)
        ShowVaultSlotTooltip(self)
    end)
    slotFrame:SetScript("OnLeave", function(self)
        self.Background:SetColorTexture(1, 1, 1, 0.04)
        GameTooltip:Hide()
    end)

    return slotFrame

end

local function SetVaultOverviewSlot(slotFrame, category, slot, width)

    local stateKey, colorKey = GetVaultSlotState(slot)
    local r, g, b = unpack(AC.Presentation.GetSemanticColor(colorKey))

    slotFrame:SetWidth(width)
    slotFrame.Title:SetWidth(width - 20)
    slotFrame.State:SetWidth(width - 20)
    slotFrame.ItemLevel:SetWidth(width - 20)
    slotFrame.Quality:SetWidth(width - 20)
    slotFrame.Progress:SetWidth((width - 20) * 0.45)
    slotFrame.Remaining:SetWidth((width - 20) * 0.55)

    slotFrame.Title:SetText(AC.L:Format("Weekly.ChestLabel", slot.index or 0))
    slotFrame.State:SetText(AC.L:Get(stateKey))
    slotFrame.State:SetTextColor(r, g, b)
    slotFrame.StateBar:SetColorTexture(r, g, b, 0.9)

    if HasCurrentVaultReward(slot) and slot.rewardItemLevel then
        local qualityName = slot.rewardQuality and _G["ITEM_QUALITY" .. tostring(slot.rewardQuality) .. "_DESC"]
        local itemLevel = AC.Presentation.FormatItemLevel(slot.rewardItemLevel)
        local qualityColor = slot.rewardQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[slot.rewardQuality]

        slotFrame.ItemLevel:SetText(itemLevel)
        slotFrame.ItemLevel:SetTextColor(qualityColor and qualityColor.r or 1, qualityColor and qualityColor.g or 0.82, qualityColor and qualityColor.b or 0)
        slotFrame.ItemLevel:Show()

        if qualityName then
            slotFrame.Quality:SetText(qualityName)
            slotFrame.Quality:SetTextColor(qualityColor and qualityColor.r or 1, qualityColor and qualityColor.g or 1, qualityColor and qualityColor.b or 1)
            slotFrame.Quality:Show()
        else
            slotFrame.Quality:Hide()
        end
    else
        slotFrame.ItemLevel:Hide()
        slotFrame.Quality:Hide()
    end

    slotFrame.Progress:SetText(AC.L:Format("Weekly.ProgressFormat", slot.progress or 0, slot.threshold or 0))

    if slot.remaining and slot.remaining > 0 then
        slotFrame.Remaining:SetText(AC.L:Format("Weekly.NeedMoreFormat", slot.remaining))
        slotFrame.Remaining:Show()
    else
        slotFrame.Remaining:Hide()
    end

    slotFrame.Slot = slot
    slotFrame.Category = category
    slotFrame:Show()

end

function Dashboard:LayoutVaultOverview(page, poolKey, scrollChild, yOffset, width, categories)

    page.Pools = page.Pools or {}
    local pool = page.Pools[poolKey]

    if not pool then
        pool = { Categories = {}, HeaderKeys = {} }
        page.Pools[poolKey] = pool
    end

    for titleKey in pairs(pool.HeaderKeys) do
        local header = scrollChild.SectionHeaders and scrollChild.SectionHeaders[titleKey]
        if header then
            header:Hide()
        end
    end
    pool.HeaderKeys = {}

    for categoryIndex, category in ipairs(categories or {}) do

        yOffset = self:BeginSection(scrollChild, category.titleKey, yOffset)
        pool.HeaderKeys[category.titleKey] = true

        local categoryFrame = pool.Categories[categoryIndex]

        if not categoryFrame then
            categoryFrame = CreateFrame("Frame", nil, scrollChild)
            categoryFrame.Slots = {}
            pool.Categories[categoryIndex] = categoryFrame
        end

        categoryFrame:ClearAllPoints()
        categoryFrame:SetPoint("TOPLEFT", 0, yOffset)
        local slots = category.slots or {}
        local columnCount = math.min(3, math.max(1, #slots))
        local rowCount = math.ceil(#slots / columnCount)
        local categoryHeight = (rowCount * VAULT_SLOT_HEIGHT) + (math.max(0, rowCount - 1) * VAULT_SLOT_GAP)
        local slotWidth = (width - (VAULT_SLOT_GAP * (columnCount - 1))) / columnCount

        categoryFrame:SetSize(width, categoryHeight)

        for slotIndex, slot in ipairs(slots) do

            local slotFrame = categoryFrame.Slots[slotIndex]

            if not slotFrame then
                slotFrame = CreateVaultOverviewSlot(categoryFrame)
                categoryFrame.Slots[slotIndex] = slotFrame
            end

            slotFrame:ClearAllPoints()
            local columnIndex = (slotIndex - 1) % columnCount
            local rowIndex = math.floor((slotIndex - 1) / columnCount)

            slotFrame:SetPoint(
                "TOPLEFT",
                columnIndex * (slotWidth + VAULT_SLOT_GAP),
                -rowIndex * (VAULT_SLOT_HEIGHT + VAULT_SLOT_GAP))
            slotFrame:SetHeight(VAULT_SLOT_HEIGHT)
            SetVaultOverviewSlot(slotFrame, category, slot, slotWidth)

        end

        for slotIndex = #slots + 1, #categoryFrame.Slots do
            categoryFrame.Slots[slotIndex]:Hide()
        end

        categoryFrame:Show()
        yOffset = self:EndSection(yOffset - categoryHeight)

    end

    for categoryIndex = #(categories or {}) + 1, #pool.Categories do
        pool.Categories[categoryIndex]:Hide()
    end

    return yOffset

end

return Dashboard
