-------------------------------------------------------------------------------
-- Azeroth Companion
-- Recommendation Inspector ("Why?")
--
-- A standalone window (not a Dashboard page) answering, for one specific
-- Recommendation: why am I seeing this, how was it scored, what data
-- contributed, which modules participated, how confident is the
-- Companion. Purely presentation -- every field it renders already
-- exists on the Recommendation object RecommendationEngine built (title,
-- description, priority, confidence, score, reason, expectedBenefit,
-- estimatedTime, supportingEvidence, sourceModules, timestamp). This
-- window computes nothing: no re-scoring, no re-deriving confidence, no
-- guessing which module a fact came from -- supportingEvidence entries
-- carry their own real `module` tag (RecommendationEngine.lua, this same
-- pass), never inferred here.
--
-- Show(recommendation) takes the actual Recommendation table already in
-- memory (captured by whichever row/card the player clicked) rather than
-- an id -- Recommendations are rebuilt from scratch every
-- RecommendationEngine:Refresh() and never persisted with a stable
-- identity, so there is nothing to look up later; this window only ever
-- displays a snapshot of what was real and current at click time, the
-- same "pooled row reused across refreshes" relationship every other
-- Dashboard list already has with its own data.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow

local RecommendationInspector = {}
AC.RecommendationInspector = RecommendationInspector

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local WINDOW_WIDTH = 420
local WINDOW_HEIGHT = 560
local CONTENT_PADDING = 16
local SCROLLBAR_RESERVE = 24
local CONTENT_WIDTH = WINDOW_WIDTH - (CONTENT_PADDING * 2) - SCROLLBAR_RESERVE

-------------------------------------------------------------------------------
-- Module Routing
--
-- Presentation-only mapping from a recommendation's real sourceModules/
-- evidence `module` values to the Dashboard page that shows that
-- module's own data, and the existing Dashboard.* localization key for
-- its display name -- every one of these keys already exists and is
-- already shown as that module's own page title/Home card title
-- elsewhere in the Dashboard, reused rather than duplicated. "Character"
-- is the one name that doesn't equal its own page name -- Character's
-- data is shown on the Profile page, the same split Home/Profile already
-- draws.
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
    -- Keystone Ready branch's own comment in RecommendationEngine.lua for
    -- why PlayerJournal is deliberately excluded from Contributing
    -- Modules) -- still needs a real display name for Supporting
    -- Evidence's own group header.
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
-- Initialize
-------------------------------------------------------------------------------

function RecommendationInspector:Initialize()

    self.Frame = BaseWindow:Create("AzerothCompanionRecommendationInspector", AC.L:Get("Inspector.Title"), WINDOW_WIDTH, WINDOW_HEIGHT)

    BaseWindow:AddCloseButton(self.Frame, self)

    local scrollFrame = CreateFrame("ScrollFrame", nil, self.Frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PADDING, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    self.ScrollFrame = scrollFrame
    self.ScrollChild = scrollChild

    self.Fields = {}
    self.Pools = {}
    self.Current = nil

end

-------------------------------------------------------------------------------
-- Layout Field -- a cached "dim caption, then value" pair, reused across
-- every Show() call rather than recreated (this window can be reopened
-- many times in a session). Hides both pieces when a field has no real
-- value rather than showing a blank line -- fields RecommendationEngine
-- didn't populate for a given recommendation (e.g. Estimated Time on a
-- recommendation with no historical timing data) simply don't render,
-- never a fabricated placeholder.
-------------------------------------------------------------------------------

-- UI Polish Pass -- optional trailing `color` (a semantic color name, see
-- AC.Presentation.GetSemanticColor) gives Priority/Confidence the same
-- at-a-glance color coding DashboardCard's Detail Sections now use for
-- the same two fields, so the Inspector's detail view and the Home card's
-- summary agree on what "important" looks like. Explicitly reset to plain
-- white when omitted (not left alone) -- this field is cached and reused
-- across Show() calls, so a stale color from a previous recommendation
-- would otherwise silently persist onto an uncolored field.
function RecommendationInspector:LayoutField(key, labelKey, valueText, yOffset, contentWidth, color)

    local field = self.Fields[key]

    if not valueText or valueText == "" then

        if field then
            field.Label:Hide()
            field.Value:Hide()
        end

        return yOffset

    end

    if not field then

        local label = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

        local value = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetJustifyH("LEFT")
        value:SetWordWrap(true)
        value:SetSpacing(2)

        field = { Label = label, Value = value }
        self.Fields[key] = field

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

-- A single dim, label-less sentence -- used only for the confidence
-- methodology note beneath the Confidence field.
function RecommendationInspector:LayoutNote(key, text, yOffset, contentWidth)

    local note = self.Fields[key]

    if not text or text == "" then

        if note then
            note:Hide()
        end

        return yOffset

    end

    if not note then

        note = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        note:SetSpacing(2)

        self.Fields[key] = note

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
-- Groups render in first-appearance order (never re-sorted or
-- re-judged); pooled by position so reopening the Inspector for a
-- different recommendation doesn't leak a new set of headers/lines every
-- time.
-------------------------------------------------------------------------------

function RecommendationInspector:LayoutSupportingEvidence(recommendation, yOffset, contentWidth)

    local evidence = recommendation.supportingEvidence or {}

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Dashboard.SectionSupportingEvidence", yOffset)

    self.Pools.EvidenceGroups = self.Pools.EvidenceGroups or {}

    if #evidence == 0 then

        yOffset = self:LayoutNote("NoEvidence", AC.L:Get("Inspector.NoSupportingEvidence"), yOffset, contentWidth)

        for index, header in ipairs(self.Pools.EvidenceGroups) do

            header:Hide()

            if self.Pools["EvidenceLines" .. index] then
                for _, row in ipairs(self.Pools["EvidenceLines" .. index]) do
                    row:Hide()
                end
            end

        end

        return AC.Dashboard:EndSection(yOffset)

    end

    if self.Fields.NoEvidence then
        self.Fields.NoEvidence:Hide()
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

        local header = self.Pools.EvidenceGroups[index]

        if not header then

            header = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetJustifyH("LEFT")
            AC.DashboardFormat.SetHighlightColor(header)

            self.Pools.EvidenceGroups[index] = header

        end

        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, yOffset)
        header:SetText(GetModuleDisplayName(moduleName))
        header:Show()

        yOffset = yOffset - header:GetStringHeight() - 4

        self.Pools["EvidenceLines" .. index] = self.Pools["EvidenceLines" .. index] or {}

        yOffset = AC.Dashboard:LayoutTextLines(self.ScrollChild, self.Pools["EvidenceLines" .. index], groups[moduleName], yOffset, contentWidth, "Inspector.NoSupportingEvidence", function(item)
            return AC.DashboardFormat.BULLET .. " " .. (item.label or "") .. ": " .. (item.value or "")
        end)

        yOffset = yOffset - 6

    end

    for index = #groupOrder + 1, #self.Pools.EvidenceGroups do

        self.Pools.EvidenceGroups[index]:Hide()

        if self.Pools["EvidenceLines" .. index] then
            for _, row in ipairs(self.Pools["EvidenceLines" .. index]) do
                row:Hide()
            end
        end

    end

    return AC.Dashboard:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Contributing Modules -- each a real, clickable link to that module's
-- own Dashboard page. Closing the Inspector on click rather than leaving
-- it floating on top keeps the player looking at the page it just sent
-- them to.
-------------------------------------------------------------------------------

function RecommendationInspector:LayoutContributingModules(recommendation, yOffset, contentWidth)

    local sourceModules = recommendation.sourceModules or {}

    yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Inspector.ContributingModules", yOffset)

    self.Pools.ModuleButtons = self.Pools.ModuleButtons or {}

    if #sourceModules == 0 then

        yOffset = self:LayoutNote("NoModules", AC.L:Get("Inspector.NoContributingModules"), yOffset, contentWidth)

        for _, button in ipairs(self.Pools.ModuleButtons) do
            button:Hide()
        end

        return AC.Dashboard:EndSection(yOffset)

    end

    if self.Fields.NoModules then
        self.Fields.NoModules:Hide()
    end

    local Layout = AC.DashboardLayout

    for index, moduleName in ipairs(sourceModules) do

        local button = self.Pools.ModuleButtons[index]

        if not button then

            button = CreateFrame("Button", nil, self.ScrollChild)
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
                    RecommendationInspector:Hide()
                    AC.Dashboard:Navigate(self.TargetPage)
                    AC.Dashboard:Show()
                end

            end)

            self.Pools.ModuleButtons[index] = button

        end

        button.DisplayName = GetModuleDisplayName(moduleName)
        button.TargetPage = MODULE_TO_PAGE[moduleName]

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, yOffset)
        button:SetWidth(contentWidth)
        button.Text:SetTextColor(unpack(AC.Presentation.GetSemanticColor("accent")))
        button.Text:SetText("> " .. button.DisplayName) -- was Unicode "▶ " -- same codepoint confirmed to render as a missing-character box (accordion disclosure glyph fix, Presentation Asset Audit)
        button:Show()

        yOffset = yOffset - Layout.ROW_HEIGHT

    end

    for index = #sourceModules + 1, #self.Pools.ModuleButtons do
        self.Pools.ModuleButtons[index]:Hide()
    end

    return AC.Dashboard:EndSection(yOffset)

end

-------------------------------------------------------------------------------
-- Score Breakdown (Developer Mode & Live Verification Suite)
--
-- Every named term ComputeScore actually applied, in the order it applied
-- them -- reads `recommendation.scoreBreakdown`, which RecommendationEngine
-- already computes and stores on every recommendation (see ComputeScore's
-- own comment); this section renders it, it never recomputes or
-- re-derives a single number. Only shown while Developer Mode is on --
-- gated here, in the Inspector's own presentation layer, not in
-- RecommendationEngine (which always computes the breakdown regardless of
-- who's looking, the same way it always computes `score`/`confidence`).
-------------------------------------------------------------------------------

function RecommendationInspector:LayoutScoreBreakdown(recommendation, yOffset, contentWidth)

    self.Pools.ScoreBreakdown = self.Pools.ScoreBreakdown or {}

    if not self.ScoreBreakdownHeader then

        local header = self.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetJustifyH("LEFT")
        header:SetText(AC.L:Get("Inspector.ScoreBreakdown"))
        AC.DashboardFormat.SetHighlightColor(header)

        self.ScoreBreakdownHeader = header

    end

    if not AC.DeveloperModeService or not AC.DeveloperModeService:IsEnabled() then

        self.ScoreBreakdownHeader:Hide()

        for _, row in ipairs(self.Pools.ScoreBreakdown) do
            row:Hide()
        end

        return yOffset

    end

    local Layout = AC.DashboardLayout

    self.ScoreBreakdownHeader:ClearAllPoints()
    self.ScoreBreakdownHeader:SetPoint("TOPLEFT", 0, yOffset)
    self.ScoreBreakdownHeader:Show()

    yOffset = yOffset - Layout.SECTION_HEADER_GAP

    local breakdown = recommendation.scoreBreakdown or {}

    yOffset = AC.Dashboard:LayoutTextLines(self.ScrollChild, self.Pools.ScoreBreakdown, breakdown, yOffset, contentWidth, "Inspector.NoScoreBreakdown", function(term)

        local sign = (term.value or 0) >= 0 and "+" or ""

        return string.format("%s%d   %s", sign, term.value or 0, AC.L:Get(term.label))

    end)

    return yOffset - Layout.SECTION_GROUP_GAP

end

-------------------------------------------------------------------------------
-- Recommendation History (Companion Intelligence vNext)
--
-- Reads RecommendationHistoryService's own already-real, already-computed
-- record for this recommendation's id -- this section computes nothing
-- itself, it only renders what that service tracked. Hides entirely (via
-- the same LayoutField/LayoutNote nil-guards every other optional field
-- above already uses) when there's no history yet (a brand-new
-- recommendation type, or RecommendationHistoryService unavailable) --
-- never a fabricated "0 times" placeholder for something that's simply
-- never been measured.
--
-- Honesty requirement (see RecommendationHistoryService.lua's own header):
-- "Likely Completed" / "Not Acknowledged" are INFERRED from the
-- recommendation disappearing between refreshes, never proof the
-- underlying gameplay action happened -- worded accordingly, never a bare
-- "Completed" claim. Only "Dismissed" is a certain, explicit signal (the
-- player clicked Dismiss).
-------------------------------------------------------------------------------

function RecommendationInspector:LayoutRecommendationHistory(recommendation, yOffset, contentWidth)

    local history = recommendation.id and AC.RecommendationHistoryService and AC.RecommendationHistoryService:GetHistoryFor(recommendation.id)

    self.Pools.ScoreHistory = self.Pools.ScoreHistory or {}

    if not history then

        yOffset = self:LayoutField("HistoryLastGenerated", "Inspector.LastGenerated", nil, yOffset, contentWidth)
        yOffset = self:LayoutField("HistoryTimesShown", "Inspector.TimesGenerated", nil, yOffset, contentWidth)
        yOffset = self:LayoutField("HistoryCompletion", "Inspector.CompletionHistory", nil, yOffset, contentWidth)
        yOffset = self:LayoutField("HistoryCompletionRate", "Inspector.CompletionRate", nil, yOffset, contentWidth)

        for _, row in ipairs(self.Pools.ScoreHistory) do
            row:Hide()
        end

        return yOffset

    end

    yOffset = self:LayoutField("HistoryLastGenerated", "Inspector.LastGenerated", history.lastShown and AC.Presentation.FormatDate(history.lastShown, "shortTime") or nil, yOffset, contentWidth)
    yOffset = self:LayoutField("HistoryTimesShown", "Inspector.TimesGenerated", tostring(history.timesShown or 0), yOffset, contentWidth)

    local completionText = AC.L:Format("Inspector.CompletionHistoryFormat", history.timesCompleted or 0, history.timesDismissed or 0, history.timesNotAcknowledged or 0)

    yOffset = self:LayoutField("HistoryCompletion", "Inspector.CompletionHistory", completionText, yOffset, contentWidth)

    local completionRateText = nil

    if (history.timesShown or 0) > 0 then
        completionRateText = string.format("%.0f%%", ((history.timesCompleted or 0) / history.timesShown) * 100)
    end

    yOffset = self:LayoutField("HistoryCompletionRate", "Inspector.CompletionRate", completionRateText, yOffset, contentWidth)

    if #(history.scoreHistory or {}) > 0 then

        yOffset = AC.Dashboard:BeginSection(self.ScrollChild, "Inspector.ScoreHistory", yOffset)

        yOffset = AC.Dashboard:LayoutTextLines(self.ScrollChild, self.Pools.ScoreHistory, history.scoreHistory, yOffset, contentWidth, "Inspector.NoScoreHistory", function(sample)
            return string.format("%s   %s %d", AC.Presentation.FormatDate(sample.timestamp, "shortTime"), AC.L:Get("Inspector.ScoreHistoryScoreLabel"), sample.score or 0)
        end)

        yOffset = AC.Dashboard:EndSection(yOffset)

    else

        for _, row in ipairs(self.Pools.ScoreHistory) do
            row:Hide()
        end

        -- Accordion Polish Pass -- BeginSection is now pooled (Sections.lua),
        -- so this is the one BeginSection call site in the whole codebase
        -- that's conditional: a recommendation with no score history must
        -- also hide the header a PRIOR recommendation (which did have
        -- history) may have already created and cached on this same
        -- persistent ScrollChild, or it would stay stuck on screen.
        if self.ScrollChild.SectionHeaders and self.ScrollChild.SectionHeaders["Inspector.ScoreHistory"] then
            self.ScrollChild.SectionHeaders["Inspector.ScoreHistory"]:Hide()
        end

    end

    return yOffset

end

-------------------------------------------------------------------------------
-- Rebuild -- lays out every field for self.Current. Called once per
-- Show(), never on a timer -- a Recommendation is a snapshot captured at
-- click time, not something this window watches for live changes.
-------------------------------------------------------------------------------

function RecommendationInspector:Rebuild()

    local recommendation = self.Current

    if not recommendation then
        return
    end

    local scrollChild = self.ScrollChild
    local contentWidth = CONTENT_WIDTH

    local yOffset = -4

    -----------------------------------------------------------------------
    -- Header -- title + description, exactly as every other page/card
    -- renders a recommendation's own already-localized text.
    -----------------------------------------------------------------------

    if not self.HeaderTitle then

        self.HeaderTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.HeaderTitle:SetJustifyH("LEFT")
        self.HeaderTitle:SetWordWrap(true)

        self.HeaderDescription = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.HeaderDescription:SetJustifyH("LEFT")
        self.HeaderDescription:SetWordWrap(true)
        self.HeaderDescription:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    end

    self.HeaderTitle:ClearAllPoints()
    self.HeaderTitle:SetPoint("TOPLEFT", 0, yOffset)
    self.HeaderTitle:SetWidth(contentWidth)
    self.HeaderTitle:SetText(recommendation.title or AC.L:Get("Common.Unknown"))

    yOffset = yOffset - self.HeaderTitle:GetStringHeight() - 6

    self.HeaderDescription:ClearAllPoints()
    self.HeaderDescription:SetPoint("TOPLEFT", 0, yOffset)
    self.HeaderDescription:SetWidth(contentWidth)
    self.HeaderDescription:SetText(recommendation.description or "")

    if recommendation.description and recommendation.description ~= "" then
        yOffset = yOffset - self.HeaderDescription:GetStringHeight() - 16
    else
        yOffset = yOffset - 6
    end

    -----------------------------------------------------------------------
    -- Priority / Confidence / Opportunity Score / Estimated Time
    -----------------------------------------------------------------------

    local priorityLabel, priorityColor = AC.DashboardFormat.GetPriorityLabel(recommendation.priority)

    yOffset = self:LayoutField("Priority", "Inspector.Priority", priorityLabel, yOffset, contentWidth, priorityColor)

    if recommendation.confidence then

        yOffset = self:LayoutField("Confidence", "Dashboard.SectionConfidence", AC.L:Get("Dashboard.Confidence" .. recommendation.confidence), yOffset, contentWidth, AC.DashboardFormat.GetConfidenceColor(recommendation.confidence))
        yOffset = self:LayoutNote("ConfidenceNote", AC.L:Get("Inspector.ConfidenceExplanation" .. recommendation.confidence), yOffset, contentWidth)

    else

        yOffset = self:LayoutField("Confidence", "Dashboard.SectionConfidence", nil, yOffset, contentWidth)
        yOffset = self:LayoutNote("ConfidenceNote", nil, yOffset, contentWidth)

    end

    yOffset = self:LayoutField("Score", "Inspector.OpportunityScore", recommendation.score and tostring(math.floor(recommendation.score + 0.5)) or nil, yOffset, contentWidth)
    yOffset = self:LayoutField("EstimatedTime", "Dashboard.SectionEstimatedTime", recommendation.estimatedTime, yOffset, contentWidth)

    -----------------------------------------------------------------------
    -- Reason / Expected Benefit
    -----------------------------------------------------------------------

    yOffset = self:LayoutField("Reason", "Dashboard.SectionReason", recommendation.reason, yOffset, contentWidth)
    yOffset = self:LayoutField("ExpectedBenefit", "Dashboard.SectionExpectedBenefit", recommendation.expectedBenefit, yOffset, contentWidth)

    -----------------------------------------------------------------------
    -- Supporting Evidence / Contributing Modules
    -----------------------------------------------------------------------

    yOffset = self:LayoutSupportingEvidence(recommendation, yOffset, contentWidth)
    yOffset = self:LayoutContributingModules(recommendation, yOffset, contentWidth)

    -----------------------------------------------------------------------
    -- Score Breakdown (Developer Mode only)
    -----------------------------------------------------------------------

    yOffset = self:LayoutScoreBreakdown(recommendation, yOffset, contentWidth)

    -----------------------------------------------------------------------
    -- Recommendation History (Companion Intelligence vNext)
    -----------------------------------------------------------------------

    yOffset = self:LayoutRecommendationHistory(recommendation, yOffset, contentWidth)

    -----------------------------------------------------------------------
    -- Timestamp
    -----------------------------------------------------------------------

    local timestampText = recommendation.timestamp and AC.Presentation.FormatDate(recommendation.timestamp, "shortTime") or nil

    yOffset = self:LayoutField("Timestamp", "Inspector.Timestamp", timestampText, yOffset, contentWidth)

    scrollChild:SetHeight(math.max((-yOffset) + 16, 1))

end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------

function RecommendationInspector:Show(recommendation)

    if not recommendation then
        return
    end

    self.Current = recommendation

    -- Companion Intelligence vNext -- opening the Inspector is the one
    -- real, observable signal this addon has that the player actually
    -- looked at this recommendation, short of proving the underlying
    -- gameplay action happened (see RecommendationHistoryService.lua).
    if recommendation.id and AC.RecommendationHistoryService then
        AC.RecommendationHistoryService:MarkAcknowledged(recommendation.id)
    end

    self:Rebuild()

    self.ScrollFrame:SetVerticalScroll(0)
    self.Frame:Show()

end

function RecommendationInspector:Hide()

    self.Frame:Hide()

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("RecommendationInspector", RecommendationInspector)

return RecommendationInspector
