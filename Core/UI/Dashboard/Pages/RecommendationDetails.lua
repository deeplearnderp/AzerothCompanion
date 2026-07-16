-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Recommendation Details
--
-- Navigation UX Sprint -- replaces the standalone RecommendationInspector
-- popup entirely. For one specific Recommendation (the snapshot stashed
-- by Dashboard:ShowRecommendationDetails, see Navigation.lua): why the
-- player is seeing it, how it was scored, what data contributed, which
-- modules participated, how confident the Companion is. Purely
-- presentation -- every field here already exists on the Recommendation
-- object RecommendationEngine built; this page computes nothing, it only
-- renders what's already real.
--
-- Ported directly from the old popup's own Layout* methods, adapted to
-- read/write page.Fields/page.Pools (the same per-page caching idiom
-- every other dynamic Dashboard page already uses -- Journey.lua's own
-- page.Pools, for one) instead of a standalone window's self.Fields/
-- self.Pools. Local functions here, not Dashboard: methods -- nothing
-- else in the codebase calls these, same as Journey.lua's own page-local
-- helpers (BuildMilestoneJourneyEntry, LayoutYearSeparator).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

-------------------------------------------------------------------------------
-- Module Routing -- unchanged from the old popup. Presentation-only
-- mapping from a recommendation's real sourceModules/evidence `module`
-- values to the Dashboard page that shows that module's own data.
-------------------------------------------------------------------------------

local MODULE_TO_PAGE =
{
    MythicPlus = "MythicPlus",
    Inventory = "Inventory",
    Storage = "Storage",
    Weekly = "Weekly",
    Accomplishments = "Accomplishments",
    Profile = "Profile",
    Character = "Profile",
}

local MODULE_DISPLAY_KEY =
{
    MythicPlus = "Dashboard.MythicPlus",
    Inventory = "Dashboard.Inventory",
    Storage = "Dashboard.Storage",
    Weekly = "Dashboard.Weekly",
    Accomplishments = "Dashboard.Accomplishments",
    Profile = "Dashboard.Profile",
    Character = "Dashboard.Profile",

    -- Evidence-only (never in sourceModules/MODULE_TO_PAGE -- see the
    -- Keystone Ready branch's own comment in RecommendationEngine.lua) --
    -- still needs a real display name for Supporting Evidence's own
    -- group header.
    PlayerJournal = "PlayerJournal.WindowTitle",
}

local function GetModuleDisplayName(moduleName)

    if not moduleName or moduleName == "" then
        return AC.L:Get("Common.Unknown")
    end

    local key = MODULE_DISPLAY_KEY[moduleName]

    return key and AC.L:Get(key) or moduleName

end

-------------------------------------------------------------------------------
-- Field / Note -- a cached "dim caption, then value" pair (or a single
-- dim sentence), pooled on page.Fields. Hides both pieces when a field
-- has no real value rather than showing a blank line.
-------------------------------------------------------------------------------

local function LayoutField(page, key, labelKey, valueText, yOffset, contentWidth, color)

    local field = page.Fields[key]

    if not valueText or valueText == "" then

        if field then
            field.Label:Hide()
            field.Value:Hide()
        end

        return yOffset

    end

    if not field then

        local label = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

        local value = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetJustifyH("LEFT")
        value:SetWordWrap(true)
        value:SetSpacing(2)

        field = { Label = label, Value = value }
        page.Fields[key] = field

    end

    field.Label:ClearAllPoints()
    field.Label:SetPoint("TOPLEFT", 0, yOffset)
    field.Label:SetText(AC.L:Get(labelKey))
    field.Label:Show()

    yOffset = yOffset - field.Label:GetStringHeight() - 2

    field.Value:ClearAllPoints()
    field.Value:SetPoint("TOPLEFT", 0, yOffset)
    field.Value:SetWidth(contentWidth)
    field.Value:SetText(valueText)
    field.Value:Show()

    if color then
        field.Value:SetTextColor(unpack(AC.Presentation.GetSemanticColor(color)))
    else
        field.Value:SetTextColor(1, 1, 1)
    end

    yOffset = yOffset - field.Value:GetStringHeight() - 12

    return yOffset

end

local function LayoutNote(page, key, text, yOffset, contentWidth)

    local note = page.Fields[key]

    if not text or text == "" then

        if note then
            note:Hide()
        end

        return yOffset

    end

    if not note then

        note = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        note:SetSpacing(2)

        page.Fields[key] = note

    end

    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", 0, yOffset)
    note:SetWidth(contentWidth)
    note:SetText(text)
    note:Show()

    return yOffset - note:GetStringHeight() - 14

end

-------------------------------------------------------------------------------
-- Supporting Evidence -- grouped by the real module each fact came from.
-- Groups render in first-appearance order; pooled by position so
-- switching to a different recommendation doesn't leak a new set of
-- headers/lines every time.
-------------------------------------------------------------------------------

local function LayoutSupportingEvidence(page, recommendation, yOffset, contentWidth)

    local evidence = recommendation.supportingEvidence or {}

    yOffset = Dashboard:BeginSection(page.ScrollChild, "Dashboard.SectionSupportingEvidence", yOffset)

    page.Pools.EvidenceGroups = page.Pools.EvidenceGroups or {}

    if #evidence == 0 then

        yOffset = LayoutNote(page, "NoEvidence", AC.L:Get("Inspector.NoSupportingEvidence"), yOffset, contentWidth)

        for index, header in ipairs(page.Pools.EvidenceGroups) do

            header:Hide()

            if page.Pools["EvidenceLines" .. index] then
                for _, row in ipairs(page.Pools["EvidenceLines" .. index]) do
                    row:Hide()
                end
            end

        end

        return Dashboard:EndSection(yOffset)

    end

    if page.Fields.NoEvidence then
        page.Fields.NoEvidence:Hide()
    end

    local groupOrder = {}
    local groups = {}

    for _, item in ipairs(evidence) do

        local moduleName = item.module or recommendation.category or ""

        if not groups[moduleName] then
            groups[moduleName] = {}
            table.insert(groupOrder, moduleName)
        end

        table.insert(groups[moduleName], item)

    end

    for index, moduleName in ipairs(groupOrder) do

        local header = page.Pools.EvidenceGroups[index]

        if not header then

            header = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetJustifyH("LEFT")
            AC.DashboardFormat.SetHighlightColor(header)

            page.Pools.EvidenceGroups[index] = header

        end

        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, yOffset)
        header:SetText(GetModuleDisplayName(moduleName))
        header:Show()

        yOffset = yOffset - header:GetStringHeight() - 4

        page.Pools["EvidenceLines" .. index] = page.Pools["EvidenceLines" .. index] or {}

        yOffset = Dashboard:LayoutTextLines(page.ScrollChild, page.Pools["EvidenceLines" .. index], groups[moduleName], yOffset, contentWidth, "Inspector.NoSupportingEvidence", function(item)
            return AC.DashboardFormat.BULLET .. " " .. (item.label or "") .. ": " .. (item.value or "")
        end)

        yOffset = yOffset - 6

    end

    for index = #groupOrder + 1, #page.Pools.EvidenceGroups do

        page.Pools.EvidenceGroups[index]:Hide()

        if page.Pools["EvidenceLines" .. index] then
            for _, row in ipairs(page.Pools["EvidenceLines" .. index]) do
                row:Hide()
            end
        end

    end

    return Dashboard:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Contributing Modules -- each a real, clickable link to that module's
-- own Dashboard page. Navigation UX Sprint: clicking now just calls
-- Dashboard:Navigate(self.TargetPage) directly -- no more Hide()/Show()
-- dance, since Recommendation Details and the target page are the same
-- window now, not a popup floating above it.
-------------------------------------------------------------------------------

local function LayoutContributingModules(page, recommendation, yOffset, contentWidth)

    local sourceModules = recommendation.sourceModules or {}

    yOffset = Dashboard:BeginSection(page.ScrollChild, "Inspector.ContributingModules", yOffset)

    page.Pools.ModuleButtons = page.Pools.ModuleButtons or {}

    if #sourceModules == 0 then

        yOffset = LayoutNote(page, "NoModules", AC.L:Get("Inspector.NoContributingModules"), yOffset, contentWidth)

        for _, button in ipairs(page.Pools.ModuleButtons) do
            button:Hide()
        end

        return Dashboard:EndSection(yOffset)

    end

    if page.Fields.NoModules then
        page.Fields.NoModules:Hide()
    end

    for index, moduleName in ipairs(sourceModules) do

        local button = page.Pools.ModuleButtons[index]

        if not button then

            button = CreateFrame("Button", nil, page.ScrollChild)
            button:SetHeight(Layout.ROW_HEIGHT)

            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 0, 0)
            text:SetJustifyH("LEFT")

            button.Text = text

            button:SetScript("OnEnter", function(self)

                AC.DashboardFormat.SetHighlightColor(self.Text)

                if self.TargetPage then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(AC.L:Format("Inspector.ModuleLinkTooltipFormat", self.DisplayName or ""), 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end

            end)

            button:SetScript("OnLeave", function(self)
                self.Text:SetTextColor(unpack(AC.Presentation.GetSemanticColor("accent")))
                GameTooltip:Hide()
            end)

            button:SetScript("OnClick", function(self)

                if self.TargetPage then
                    Dashboard:Navigate(self.TargetPage)
                end

            end)

            page.Pools.ModuleButtons[index] = button

        end

        button.DisplayName = GetModuleDisplayName(moduleName)
        button.TargetPage = MODULE_TO_PAGE[moduleName]

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, yOffset)
        button:SetWidth(contentWidth)
        button.Text:SetTextColor(unpack(AC.Presentation.GetSemanticColor("accent")))
        button.Text:SetText("> " .. button.DisplayName)
        button:Show()

        yOffset = yOffset - Layout.ROW_HEIGHT

    end

    for index = #sourceModules + 1, #page.Pools.ModuleButtons do
        page.Pools.ModuleButtons[index]:Hide()
    end

    return Dashboard:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Score Breakdown (Developer Mode only) -- unchanged from the old popup.
-- Only shown while Developer Mode is on; RecommendationEngine always
-- computes the breakdown regardless of who's looking.
-------------------------------------------------------------------------------

local function LayoutScoreBreakdown(page, recommendation, yOffset, contentWidth)

    page.Pools.ScoreBreakdown = page.Pools.ScoreBreakdown or {}

    if not page.ScoreBreakdownHeader then

        local header = page.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetJustifyH("LEFT")
        header:SetText(AC.L:Get("Inspector.ScoreBreakdown"))
        AC.DashboardFormat.SetHighlightColor(header)

        page.ScoreBreakdownHeader = header

    end

    if not AC.DeveloperModeService or not AC.DeveloperModeService:IsEnabled() then

        page.ScoreBreakdownHeader:Hide()

        for _, row in ipairs(page.Pools.ScoreBreakdown) do
            row:Hide()
        end

        return yOffset

    end

    page.ScoreBreakdownHeader:ClearAllPoints()
    page.ScoreBreakdownHeader:SetPoint("TOPLEFT", 0, yOffset)
    page.ScoreBreakdownHeader:Show()

    yOffset = yOffset - Layout.SECTION_HEADER_GAP

    local breakdown = recommendation.scoreBreakdown or {}

    yOffset = Dashboard:LayoutTextLines(page.ScrollChild, page.Pools.ScoreBreakdown, breakdown, yOffset, contentWidth, "Inspector.NoScoreBreakdown", function(term)

        local sign = (term.value or 0) >= 0 and "+" or ""

        return string.format("%s%d   %s", sign, term.value or 0, AC.L:Get(term.label))

    end)

    return yOffset - Layout.SECTION_GROUP_GAP

end

-------------------------------------------------------------------------------
-- Recommendation History (Companion Intelligence vNext) -- unchanged
-- from the old popup. "Likely Completed"/"Not Acknowledged" are inferred,
-- never proof the underlying gameplay action happened -- see
-- RecommendationHistoryService.lua's own header.
-------------------------------------------------------------------------------

local function LayoutRecommendationHistory(page, recommendation, yOffset, contentWidth)

    local history = recommendation.id and AC.RecommendationHistoryService and AC.RecommendationHistoryService:GetHistoryFor(recommendation.id)

    page.Pools.ScoreHistory = page.Pools.ScoreHistory or {}

    if not history then

        yOffset = LayoutField(page, "HistoryLastGenerated", "Inspector.LastGenerated", nil, yOffset, contentWidth)
        yOffset = LayoutField(page, "HistoryTimesShown", "Inspector.TimesGenerated", nil, yOffset, contentWidth)
        yOffset = LayoutField(page, "HistoryCompletion", "Inspector.CompletionHistory", nil, yOffset, contentWidth)
        yOffset = LayoutField(page, "HistoryCompletionRate", "Inspector.CompletionRate", nil, yOffset, contentWidth)

        for _, row in ipairs(page.Pools.ScoreHistory) do
            row:Hide()
        end

        return yOffset

    end

    yOffset = LayoutField(page, "HistoryLastGenerated", "Inspector.LastGenerated", history.lastShown and AC.Presentation.FormatDate(history.lastShown, "shortTime") or nil, yOffset, contentWidth)
    yOffset = LayoutField(page, "HistoryTimesShown", "Inspector.TimesGenerated", tostring(history.timesShown or 0), yOffset, contentWidth)

    local completionText = AC.L:Format("Inspector.CompletionHistoryFormat", history.timesCompleted or 0, history.timesDismissed or 0, history.timesNotAcknowledged or 0)

    yOffset = LayoutField(page, "HistoryCompletion", "Inspector.CompletionHistory", completionText, yOffset, contentWidth)

    local completionRateText = nil

    if (history.timesShown or 0) > 0 then
        completionRateText = string.format("%.0f%%", ((history.timesCompleted or 0) / history.timesShown) * 100)
    end

    yOffset = LayoutField(page, "HistoryCompletionRate", "Inspector.CompletionRate", completionRateText, yOffset, contentWidth)

    if #(history.scoreHistory or {}) > 0 then

        yOffset = Dashboard:BeginSection(page.ScrollChild, "Inspector.ScoreHistory", yOffset)

        yOffset = Dashboard:LayoutTextLines(page.ScrollChild, page.Pools.ScoreHistory, history.scoreHistory, yOffset, contentWidth, "Inspector.NoScoreHistory", function(sample)
            return string.format("%s   %s %d", AC.Presentation.FormatDate(sample.timestamp, "shortTime"), AC.L:Get("Inspector.ScoreHistoryScoreLabel"), sample.score or 0)
        end)

        yOffset = Dashboard:EndSection(yOffset)

    else

        for _, row in ipairs(page.Pools.ScoreHistory) do
            row:Hide()
        end

        -- BeginSection is pooled (Sections.lua) -- a recommendation with
        -- no score history must also hide a header a PRIOR recommendation
        -- (which did have history) may have already created and cached on
        -- this same persistent ScrollChild, or it would stay stuck on
        -- screen.
        if page.ScrollChild.SectionHeaders and page.ScrollChild.SectionHeaders["Inspector.ScoreHistory"] then
            page.ScrollChild.SectionHeaders["Inspector.ScoreHistory"]:Hide()
        end

    end

    return yOffset

end

-------------------------------------------------------------------------------
-- Update -- called by Dashboard:ShowPage("RecommendationDetails"). Reads
-- Dashboard.CurrentRecommendationDetails, the snapshot
-- ShowRecommendationDetails stashed at click time (see Navigation.lua) --
-- a Recommendation has no stable persisted identity to look up any other
-- way. Same "measure at full width, narrow only if needed" shape as
-- Progress.lua/Journey.lua -- every Layout* helper above is idempotent,
-- safe to call twice in the same refresh.
-------------------------------------------------------------------------------

function Dashboard:UpdateRecommendationDetailsPage(frame)

    local page = frame.Pages and frame.Pages.RecommendationDetails

    if not page then
        return
    end

    self:RefreshEngines(page)

    local recommendation = self.CurrentRecommendationDetails
    local scrollChild = page.ScrollChild

    page.Fields = page.Fields or {}
    page.Pools = page.Pools or {}

    if not recommendation then
        self:ApplyPageScrolling(page, 1)
        return
    end

    local function Layout_(width)

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Header -- title + description
        -----------------------------------------------------------------------

        if not page.HeaderTitle then

            page.HeaderTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            page.HeaderTitle:SetJustifyH("LEFT")
            page.HeaderTitle:SetWordWrap(true)

            page.HeaderDescription = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            page.HeaderDescription:SetJustifyH("LEFT")
            page.HeaderDescription:SetWordWrap(true)
            page.HeaderDescription:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

        end

        page.HeaderTitle:ClearAllPoints()
        page.HeaderTitle:SetPoint("TOPLEFT", 0, yOffset)
        page.HeaderTitle:SetWidth(width)
        page.HeaderTitle:SetText(recommendation.title or AC.L:Get("Common.Unknown"))

        yOffset = yOffset - page.HeaderTitle:GetStringHeight() - 6

        page.HeaderDescription:ClearAllPoints()
        page.HeaderDescription:SetPoint("TOPLEFT", 0, yOffset)
        page.HeaderDescription:SetWidth(width)
        page.HeaderDescription:SetText(recommendation.description or "")

        if recommendation.description and recommendation.description ~= "" then
            yOffset = yOffset - page.HeaderDescription:GetStringHeight() - 16
        else
            yOffset = yOffset - 6
        end

        -----------------------------------------------------------------------
        -- Priority / Confidence / Opportunity Score / Estimated Time
        -----------------------------------------------------------------------

        local priorityLabel, priorityColor = AC.DashboardFormat.GetPriorityLabel(recommendation.priority)

        yOffset = LayoutField(page, "Priority", "Inspector.Priority", priorityLabel, yOffset, width, priorityColor)

        if recommendation.confidence then

            yOffset = LayoutField(page, "Confidence", "Dashboard.SectionConfidence", AC.L:Get("Dashboard.Confidence" .. recommendation.confidence), yOffset, width, AC.DashboardFormat.GetConfidenceColor(recommendation.confidence))
            yOffset = LayoutNote(page, "ConfidenceNote", AC.L:Get("Inspector.ConfidenceExplanation" .. recommendation.confidence), yOffset, width)

        else

            yOffset = LayoutField(page, "Confidence", "Dashboard.SectionConfidence", nil, yOffset, width)
            yOffset = LayoutNote(page, "ConfidenceNote", nil, yOffset, width)

        end

        yOffset = LayoutField(page, "Score", "Inspector.OpportunityScore", recommendation.score and tostring(math.floor(recommendation.score + 0.5)) or nil, yOffset, width)
        yOffset = LayoutField(page, "EstimatedTime", "Dashboard.SectionEstimatedTime", recommendation.estimatedTime, yOffset, width)

        -----------------------------------------------------------------------
        -- Reason / Expected Benefit
        -----------------------------------------------------------------------

        yOffset = LayoutField(page, "Reason", "Dashboard.SectionReason", recommendation.reason, yOffset, width)
        yOffset = LayoutField(page, "ExpectedBenefit", "Dashboard.SectionExpectedBenefit", recommendation.expectedBenefit, yOffset, width)

        -- Future Suggested Actions -- no field exists on the Recommendation
        -- object for this yet (RecommendationEngine doesn't compute one) --
        -- this is the rendering slot only, the same nil-guarded LayoutField
        -- every optional field above already uses, so it simply doesn't
        -- render today and needs no further wiring the day
        -- RecommendationEngine adds a real futureSuggestedActions field.
        yOffset = LayoutField(page, "FutureSuggestedActions", "Inspector.FutureSuggestedActions", recommendation.futureSuggestedActions, yOffset, width)

        -----------------------------------------------------------------------
        -- Supporting Evidence / Contributing Modules
        -----------------------------------------------------------------------

        yOffset = LayoutSupportingEvidence(page, recommendation, yOffset, width)
        yOffset = LayoutContributingModules(page, recommendation, yOffset, width)

        -----------------------------------------------------------------------
        -- Score Breakdown (Developer Mode only)
        -----------------------------------------------------------------------

        yOffset = LayoutScoreBreakdown(page, recommendation, yOffset, width)

        -----------------------------------------------------------------------
        -- Recommendation History (Companion Intelligence vNext)
        -----------------------------------------------------------------------

        yOffset = LayoutRecommendationHistory(page, recommendation, yOffset, width)

        -----------------------------------------------------------------------
        -- Timestamp
        -----------------------------------------------------------------------

        local timestampText = recommendation.timestamp and AC.Presentation.FormatDate(recommendation.timestamp, "shortTime") or nil

        yOffset = LayoutField(page, "Timestamp", "Inspector.Timestamp", timestampText, yOffset, width)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)
    page.ScrollFrame:SetVerticalScroll(0)

end

return Dashboard
