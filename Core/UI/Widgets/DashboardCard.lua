-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Card Widget
--
-- Reusable presentation card for Dashboard display. Optionally clickable,
-- in which case it hover-highlights and shows a small navigation
-- indicator on the right edge.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DashboardCard = {}

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function DashboardCard:Create(parent, title, options)

    -- Presentation System v2 -- read inline here (a function-local, not a
    -- file-top upvalue) since Core/UI/Widgets/DashboardCard.lua loads
    -- before Core/UI/Dashboard/Layout.lua in the .toc; a cached upvalue
    -- would capture nil. Every closure below (SetIcon, UpdateHeight,
    -- SetDetailSections, ...) captures this same Layout local from Create's
    -- own scope, evaluated once per card, well after every file has loaded.
    local Layout = AC.DashboardLayout

    local PADDING_LEFT = Layout.CARD_PADDING_LEFT
    local PADDING_RIGHT = Layout.CARD_PADDING_RIGHT
    local PADDING_TOP = Layout.CARD_PADDING_TOP
    local PADDING_BOTTOM = Layout.CARD_PADDING_BOTTOM
    local INDICATOR_RESERVE = Layout.CARD_INDICATOR_RESERVE

    local TITLE_TO_PRIMARY_GAP = Layout.CARD_TITLE_TO_PRIMARY_GAP
    local PRIMARY_TO_SECONDARY_GAP = Layout.CARD_PRIMARY_TO_SECONDARY_GAP
    local SECONDARY_TO_DETAIL_GAP = Layout.CARD_SECONDARY_TO_DETAIL_GAP
    local DETAIL_TO_BAR_GAP = Layout.CARD_DETAIL_TO_BAR_GAP

    -- Detail Sections (Home Dashboard Evolution) -- a labeled "caption, then
    -- value" block, used instead of the single-line DetailText below when a
    -- card needs to tell a real story (Reason / Expected Benefit / Estimated
    -- Time / Supporting Evidence, "Missing" bullets, ...) rather than one
    -- undifferentiated line. SECTION_GAP separates one section from the
    -- next; SECTION_LABEL_BODY_GAP separates a section's own caption from
    -- its value.
    local SECTION_GAP = Layout.CARD_SECTION_GAP
    local SECTION_LABEL_BODY_GAP = Layout.CARD_SECTION_LABEL_BODY_GAP

    options = options or {}

    local width = options.width or 360
    local height = options.height or 100

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetWidth(width)
    card:SetHeight(height)

    -- The floor UpdateHeight() below never shrinks past -- see its
    -- comment. Preserves today's validated compact sizing while allowing
    -- growth for content that genuinely needs more room (Part 7).
    card.MinHeight = height

    -----------------------------------------------------------------------
    -- Background
    --
    -- A real bordered backdrop (v1.0 Polish Sprint audit) -- every card
    -- previously rendered as a flat, edgeless color rectangle, the same
    -- "developer-looking" gap BaseWindow.lua had. A thin border gives each
    -- card real visual definition against its neighbors and the window
    -- background instead of everything bleeding together as one solid
    -- gray field. The card's own backdrop color (not a separate texture)
    -- is what OnEnter/OnLeave below brightens on hover.
    --
    -- UI Polish Pass -- `emphasized` no longer tints the background at all
    -- (a live visual review called the prior olive/gold wash "heavy," and
    -- it was also the one real inconsistency between cards: every card
    -- otherwise shares this exact same neutral backdrop). Emphasis is now
    -- carried entirely by the border (brighter, gold-tinted) plus the
    -- card's own title/content font choices -- real definition without a
    -- second background color for players to learn.
    -----------------------------------------------------------------------

    local cardBackdrop = AC.Presentation.CARD_BACKDROP
    local baseR, baseG, baseB, baseA = unpack(cardBackdrop.bgColor)
    local borderR, borderG, borderB, borderA = AC.Presentation.GetCardBorderColor(options.emphasized)

    AC.Presentation.ApplyCardBackdrop(card, options.emphasized)

    -----------------------------------------------------------------------
    -- Title
    -----------------------------------------------------------------------

    local titleFont = options.titleFont or "GameFontNormal"

    local titleText = card:CreateFontString(nil, "OVERLAY", titleFont)
    titleText:SetPoint("TOPLEFT", PADDING_LEFT, -PADDING_TOP)
    titleText:SetText(title or "")
    AC.DashboardFormat.SetHighlightColor(titleText)

    card.Title = titleText

    -----------------------------------------------------------------------
    -- Icon (optional -- v1.0 Polish Sprint)
    --
    -- A small icon beside the title, using data this addon already
    -- collects (an achievement's real Blizzard icon FileID, a class icon
    -- via the same CLASS_ICON_TCOORDS atlas technique the default UI's
    -- own group/raid frames use) rather than inventing new art. Hidden by
    -- default -- SetIcon/SetClassIcon show it and shift Title right to
    -- make room; a card that never calls either behaves exactly as
    -- before this addition, since only Title's X position changes (every
    -- other line anchors below Title, not beside it).
    -----------------------------------------------------------------------

    local ICON_SIZE = Layout.CARD_ICON_SIZE
    local ICON_TITLE_GAP = Layout.CARD_ICON_TITLE_GAP

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", PADDING_LEFT, -PADDING_TOP)
    icon:Hide()

    card.Icon = icon

    function card:SetIcon(texture)

        if not texture or texture == 0 or texture == "" then

            self.Icon:Hide()
            self.Title:ClearAllPoints()
            self.Title:SetPoint("TOPLEFT", PADDING_LEFT, -PADDING_TOP)

            return

        end

        self.Icon:SetTexture(texture)
        self.Icon:SetTexCoord(0, 1, 0, 1)
        self.Icon:Show()

        self.Title:ClearAllPoints()
        self.Title:SetPoint("TOPLEFT", self.Icon, "TOPRIGHT", ICON_TITLE_GAP, 0)

    end

    -- classFile is the non-localized class token CharacterModule already
    -- captures (UnitClass's second return value, e.g. "WARRIOR") -- the
    -- same lookup key the default UI's own CLASS_ICON_TCOORDS table uses.
    function card:SetClassIcon(classFile)

        if not classFile or classFile == "" or not CLASS_ICON_TCOORDS or not CLASS_ICON_TCOORDS[classFile] then

            self.Icon:Hide()
            self.Title:ClearAllPoints()
            self.Title:SetPoint("TOPLEFT", PADDING_LEFT, -PADDING_TOP)

            return

        end

        self.Icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circle")
        self.Icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
        self.Icon:Show()

        self.Title:ClearAllPoints()
        self.Title:SetPoint("TOPLEFT", self.Icon, "TOPRIGHT", ICON_TITLE_GAP, 0)

    end

    -----------------------------------------------------------------------
    -- Primary Value
    --
    -- UI Polish Pass -- a recommendation's priority is no longer a
    -- separate line here; it renders as the first (colored, emphasized)
    -- Detail Section instead (see SetDetailSections' `color` field below),
    -- alongside Confidence, rather than a dedicated star-rating row
    -- between Title and PrimaryValue. See Format.lua's own header for why.
    -----------------------------------------------------------------------

    local primaryFont = options.primaryFont or "GameFontHighlight"
    local textWidth = width - PADDING_LEFT - PADDING_RIGHT - (options.onClick and not options.hideIndicator and INDICATOR_RESERVE or 0)

    card.TextWidth = textWidth

    local primaryValue = card:CreateFontString(nil, "OVERLAY", primaryFont)
    primaryValue:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -TITLE_TO_PRIMARY_GAP)
    primaryValue:SetWidth(textWidth)
    primaryValue:SetJustifyH("LEFT")
    primaryValue:SetWordWrap(true)
    primaryValue:SetText(options.primaryValue or "")

    card.PrimaryValue = primaryValue

    -----------------------------------------------------------------------
    -- Secondary Text
    -----------------------------------------------------------------------

    local secondaryText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secondaryText:SetPoint("TOPLEFT", primaryValue, "BOTTOMLEFT", 0, -PRIMARY_TO_SECONDARY_GAP)
    secondaryText:SetWidth(textWidth)
    secondaryText:SetJustifyH("LEFT")
    secondaryText:SetWordWrap(true)
    secondaryText:SetText(options.secondaryText or "")

    -- Presentation System v2 -- was a hardcoded (0.8,0.8,0.8), one of six
    -- different "muted/secondary text" grays found in active use across
    -- the addon for the same semantic role. Migrated to the real "dim"
    -- token (0.7,0.7,0.7) -- a genuine, deliberate, visible darkening.
    do
        local dimR, dimG, dimB = unpack(AC.Presentation.GetSemanticColor("dim"))
        secondaryText:SetTextColor(dimR, dimG, dimB)
    end

    card.SecondaryText = secondaryText

    -----------------------------------------------------------------------
    -- Detail Text
    --
    -- A third, dimmer line for one supplementary fact (equipped item
    -- level, current season, most recent achievement, ...). Its own
    -- FontString rather than a "\n" manually embedded inside
    -- SecondaryText, so each fact reads as its own row instead of two
    -- unrelated facts sharing one string. Cards that don't set one just
    -- leave it empty -- see Part 8/9.
    -----------------------------------------------------------------------

    local detailText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detailText:SetPoint("TOPLEFT", secondaryText, "BOTTOMLEFT", 0, -SECONDARY_TO_DETAIL_GAP)
    detailText:SetWidth(textWidth)
    detailText:SetJustifyH("LEFT")
    detailText:SetWordWrap(true)
    detailText:SetText(options.detailText or "")

    card.DetailText = detailText

    -- Tracks whichever frame the Bar (below) should actually anchor
    -- under: DetailText by default, or the last active Detail Section
    -- once SetDetailSections has been used -- see that method's comment
    -- for why this can't just stay hardcoded to DetailText.
    card.LastContentAnchor = detailText

    -----------------------------------------------------------------------
    -- Status Indicator
    -----------------------------------------------------------------------

    local statusText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMRIGHT", -PADDING_RIGHT, PADDING_BOTTOM)
    statusText:SetText(options.statusText or "")
    statusText:SetJustifyH("RIGHT")

    card.StatusText = statusText

    -----------------------------------------------------------------------
    -- Progress Bar (optional, standard Blizzard status bar texture)
    -----------------------------------------------------------------------

    if options.showBar then

        local barHolder = CreateFrame("Frame", nil, card)
        barHolder:SetSize(textWidth, 12)
        barHolder:SetPoint("TOPLEFT", card.LastContentAnchor, "BOTTOMLEFT", 0, -DETAIL_TO_BAR_GAP)

        local barBackground = barHolder:CreateTexture(nil, "BACKGROUND")
        barBackground:SetAllPoints()
        barBackground:SetColorTexture(0, 0, 0, 0.5)

        local bar = CreateFrame("StatusBar", nil, barHolder)
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        bar:SetStatusBarColor(0.3, 0.6, 0.9)

        card.Bar = bar
        card.BarHolder = barHolder

    end

    -----------------------------------------------------------------------
    -- Click Navigation (optional)
    --
    -- WoW does not expose a generic "pointer" cursor API for plain
    -- frames the way a browser does, so clickability is communicated
    -- through a hover highlight plus a right-side indicator instead.
    --
    -- UI Polish Pass -- the indicator now anchors at the same TOPRIGHT
    -- padding the title anchors its TOPLEFT at, instead of vertically
    -- centered on the whole (variable-height) card -- on a short card the
    -- two were close enough not to matter, but on a tall one (the Highest
    -- Priority card, RECOMMENDATION_HEIGHT well above CARD_HEIGHT) a
    -- chevron floating in empty space below the header read as
    -- disconnected from anything. `options.hideIndicator` lets a card with
    -- its own explicit action buttons already occupying that corner (Home's
    -- Highest Priority card: Dismiss + Why?) opt out of a second,
    -- redundant "click me" affordance entirely rather than overlapping one.
    -- The card body stays clickable either way -- this only affects the
    -- visual glyph.
    -----------------------------------------------------------------------

    if options.onClick then

        local indicator

        if not options.hideIndicator then

            indicator = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            indicator:SetPoint("TOPRIGHT", -PADDING_RIGHT, -PADDING_TOP)
            indicator:SetText(">") -- was Unicode "▶" -- same codepoint confirmed to render as a missing-character box (accordion disclosure glyph fix, Presentation Asset Audit)
            indicator:SetTextColor(0.6, 0.6, 0.6)

            card.Indicator = indicator

        end

        card:EnableMouse(true)

        card:SetScript("OnEnter", function(self)
            self:SetBackdropColor(baseR + cardBackdrop.hoverBackgroundDelta, baseG + cardBackdrop.hoverBackgroundDelta, baseB + cardBackdrop.hoverBackgroundDelta, baseA)
            self:SetBackdropBorderColor(borderR, borderG, borderB, math.min(borderA + cardBackdrop.hoverBorderAlphaDelta, 1))
            if self.Indicator then
                AC.DashboardFormat.SetHighlightColor(self.Indicator)
            end
            if options.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(options.tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)

        card:SetScript("OnLeave", function(self)
            self:SetBackdropColor(baseR, baseG, baseB, baseA)
            self:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
            if self.Indicator then
                self.Indicator:SetTextColor(0.6, 0.6, 0.6)
            end
            if options.tooltip then
                GameTooltip:Hide()
            end
        end)

        card:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                options.onClick(self)
            end
        end)

    end

    -----------------------------------------------------------------------
    -- Dynamic Height (Part 7)
    --
    -- Grows the card past its designed MinHeight when the actual
    -- (possibly word-wrapped) text needs more room than that minimum
    -- provides -- e.g. an unusually long character or realm name wrapping
    -- to a second line. Never shrinks below MinHeight, so today's
    -- validated compact sizing stays the common case and the row of Home
    -- cards doesn't turn jagged just because one card has less to say
    -- than its neighbor. Empty lines (an unused DetailText, no status bar)
    -- contribute no height at all, so a card never reserves blank space
    -- for a fact it isn't showing.
    -----------------------------------------------------------------------

    function card:UpdateHeight()

        local contentHeight = PADDING_TOP + PADDING_BOTTOM

        if self.Title:GetText() ~= "" then
            contentHeight = contentHeight + self.Title:GetStringHeight()
        end

        if self.PrimaryValue:GetText() ~= "" then
            contentHeight = contentHeight + TITLE_TO_PRIMARY_GAP + self.PrimaryValue:GetStringHeight()
        end

        if self.SecondaryText:GetText() ~= "" then
            contentHeight = contentHeight + PRIMARY_TO_SECONDARY_GAP + self.SecondaryText:GetStringHeight()
        end

        if self.DetailText:GetText() ~= "" then
            contentHeight = contentHeight + SECONDARY_TO_DETAIL_GAP + self.DetailText:GetStringHeight()
        end

        -- Detail Sections (mutually exclusive with DetailText above --
        -- SetDetailSections always clears DetailText, so at most one of
        -- these two contributes height).
        if self.ActiveSectionCount and self.ActiveSectionCount > 0 then

            for index = 1, self.ActiveSectionCount do

                local entry = self.Sections[index]

                contentHeight = contentHeight + (index == 1 and SECONDARY_TO_DETAIL_GAP or SECTION_GAP)

                if entry.Caption:IsShown() then
                    contentHeight = contentHeight + entry.Caption:GetStringHeight() + SECTION_LABEL_BODY_GAP
                end

                contentHeight = contentHeight + (entry.Body:GetStringHeight() or 0)

            end

        end

        if self.BarHolder then
            contentHeight = contentHeight + DETAIL_TO_BAR_GAP + self.BarHolder:GetHeight()
        end

        self:SetHeight(math.max(contentHeight, self.MinHeight or 0))

    end

    -----------------------------------------------------------------------
    -- Update Methods
    -----------------------------------------------------------------------

    function card:SetTitle(text)
        self.Title:SetText(text or "")
        self:UpdateHeight()
    end

    function card:SetPrimaryValue(text)
        self.PrimaryValue:SetText(text or "")
        self:UpdateHeight()
    end

    function card:SetSecondaryText(text)
        self.SecondaryText:SetText(text or "")
        self:UpdateHeight()
    end

    function card:SetDetailText(text)
        self.DetailText:SetText(text or "")
        self.LastContentAnchor = self.DetailText
        self:RepositionBar()
        self:UpdateHeight()
    end

    -----------------------------------------------------------------------
    -- Detail Sections (Home Dashboard Evolution)
    --
    -- A labeled "caption, then value" block per entry, replacing the
    -- single-line DetailText for a card that needs to tell a real story
    -- instead of one flat line -- Highest Priority's Reason/Expected
    -- Benefit/Estimated Time/Supporting Evidence, Profile's emphasized
    -- Item Level, Mythic+/Storage's "Missing" bullets, Vault's Highest
    -- Reward. `sections` is an ordered list of
    -- `{ label = "text or nil", text = "already-formatted string
    -- (may contain \n)", emphasized = true/nil, color = "semantic name or
    -- nil" }` -- wording and formatting are always decided by the caller,
    -- this widget only owns layout, exactly like DetailText/SetStatus
    -- already do.
    --
    -- UI Polish Pass -- `color` (a name from AC.Presentation.GetSemanticColor,
    -- e.g. "critical"/"warning"/"success"/"dim") lets a caller flag a
    -- section as carrying real at-a-glance meaning -- Home's Highest
    -- Priority card uses it for Priority and Confidence, so both read
    -- as important without the player parsing a sentence, while Reason/
    -- Expected Benefit/Estimated Time stay plain. Omitted (nil) keeps
    -- today's plain body-text color -- explicitly reset every call rather
    -- than left alone, since a pooled entry could otherwise keep a
    -- previous refresh's color after being reassigned to a differently-
    -- colored (or uncolored) section.
    --
    -- Pooled per index (entry.Caption/entry.Body), same reuse-don't-
    -- recreate pattern as every other pooled Dashboard list. Clears
    -- DetailText, since a card uses one detail mechanism or the other,
    -- never both -- UpdateHeight only ever counts whichever is non-empty.
    -----------------------------------------------------------------------

    function card:SetDetailSections(sections)

        self.DetailText:SetText("")

        sections = sections or {}

        self.Sections = self.Sections or {}

        local previousAnchor = self.SecondaryText
        local previousGap = SECONDARY_TO_DETAIL_GAP

        for index, section in ipairs(sections) do

            local entry = self.Sections[index]

            if not entry then

                local captionText = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                captionText:SetJustifyH("LEFT")
                captionText:SetTextColor(0.65, 0.6, 0.5)

                local bodyText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bodyText:SetJustifyH("LEFT")
                bodyText:SetWordWrap(true)
                bodyText:SetSpacing(2)

                entry = { Caption = captionText, Body = bodyText }
                self.Sections[index] = entry

            end

            entry.Body:SetFontObject(section.emphasized and "GameFontHighlight" or "GameFontHighlightSmall")

            if section.color then
                entry.Body:SetTextColor(unpack(AC.Presentation.GetSemanticColor(section.color)))
            else
                entry.Body:SetTextColor(1, 1, 1)
            end

            entry.Caption:ClearAllPoints()
            entry.Body:ClearAllPoints()

            if section.label and section.label ~= "" then

                entry.Caption:SetPoint("TOPLEFT", previousAnchor, "BOTTOMLEFT", 0, -previousGap)
                entry.Caption:SetWidth(self.TextWidth)
                entry.Caption:SetText(section.label)
                entry.Caption:Show()

                entry.Body:SetPoint("TOPLEFT", entry.Caption, "BOTTOMLEFT", 0, -SECTION_LABEL_BODY_GAP)

            else

                entry.Caption:Hide()
                entry.Body:SetPoint("TOPLEFT", previousAnchor, "BOTTOMLEFT", 0, -previousGap)

            end

            entry.Body:SetWidth(self.TextWidth)
            entry.Body:SetText(section.text or "")
            entry.Body:Show()

            previousAnchor = entry.Body
            previousGap = SECTION_GAP

        end

        for index = #sections + 1, #self.Sections do
            self.Sections[index].Caption:Hide()
            self.Sections[index].Body:Hide()
        end

        self.ActiveSectionCount = #sections
        self.LastContentAnchor = (#sections > 0) and previousAnchor or self.SecondaryText

        self:RepositionBar()
        self:UpdateHeight()

    end

    -----------------------------------------------------------------------
    -- Reposition Bar
    --
    -- The optional progress bar always sits directly below whichever
    -- content actually rendered last (DetailText, or the last active
    -- Detail Section) -- fixing it to always anchor under DetailText
    -- would leave it overlapping Section content on any card combining
    -- showBar with SetDetailSections (Mythic+/Vault/Storage).
    -----------------------------------------------------------------------

    function card:RepositionBar()

        if not self.BarHolder then
            return
        end

        self.BarHolder:ClearAllPoints()
        self.BarHolder:SetPoint("TOPLEFT", self.LastContentAnchor, "BOTTOMLEFT", 0, -DETAIL_TO_BAR_GAP)

    end

    function card:SetStatus(status, text)
        text = text or ""

        self.StatusText:SetText(text)

        -- Presentation System v2 -- "Normal"/"Important" were their own
        -- hand-typed green/red, distinct from the addon's canonical
        -- success/critical tokens (used everywhere else for the identical
        -- meaning). Migrated to the real tokens -- a genuine, visible color
        -- shift on both. The "else" (no status) branch keeps its own
        -- (0.8,0.8,0.8) -- out of scope this pass, see Layout.lua's own
        -- card-token header.
        if status == "Normal" then
            local r, g, b = unpack(AC.Presentation.GetSemanticColor("success"))
            self.StatusText:SetTextColor(r, g, b)
        elseif status == "Warning" then
            AC.DashboardFormat.SetHighlightColor(self.StatusText)
        elseif status == "Important" then
            local r, g, b = unpack(AC.Presentation.GetSemanticColor("critical"))
            self.StatusText:SetTextColor(r, g, b)
        else
            self.StatusText:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    -- Animates toward the new value instead of snapping to it (v1.0
    -- Polish Sprint) -- a short, fixed-duration ease-out driven by a
    -- per-bar OnUpdate script that clears itself the moment the
    -- animation finishes, so an idle card costs nothing between
    -- refreshes. Skips the animation entirely for a negligible change,
    -- so repeated refreshes with the same real value never restart it.
    local BAR_ANIMATION_DURATION = Layout.CARD_BAR_ANIMATION_DURATION

    function card:SetBarValue(percentage, r, g, b)

        if not self.Bar then
            return
        end

        percentage = tonumber(percentage) or 0

        if percentage < 0 then
            percentage = 0
        elseif percentage > 100 then
            percentage = 100
        end

        if r and g and b then
            self.Bar:SetStatusBarColor(r, g, b)
        end

        local bar = self.Bar
        local startValue = bar:GetValue() or 0

        if math.abs(startValue - percentage) < 0.1 then
            bar:SetValue(percentage)
            bar:SetScript("OnUpdate", nil)
            return
        end

        local elapsed = 0

        bar:SetScript("OnUpdate", function(self, delta)

            elapsed = elapsed + delta

            local progress = math.min(elapsed / BAR_ANIMATION_DURATION, 1)
            local eased = 1 - ((1 - progress) * (1 - progress))

            self:SetValue(startValue + (percentage - startValue) * eased)

            if progress >= 1 then
                self:SetScript("OnUpdate", nil)
            end

        end)

    end

    return card

end

AC.DashboardCard = DashboardCard

return DashboardCard
