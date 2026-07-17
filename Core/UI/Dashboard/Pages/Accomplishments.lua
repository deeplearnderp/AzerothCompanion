-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Accomplishments (formerly Achievements)
--
-- A curated "what defines this character" view -- not every achievement in
-- the game (Blizzard's own Achievement UI already represents that
-- exhaustively). Every number/line here comes from AccomplishmentsModule's
-- own already-classified, already-curated cache; this page computes
-- nothing itself (Rule 2), same discipline every other Dashboard page
-- follows. Fully dynamic, same measure-at-full-width-then-narrow-if-needed
-- shape as Progress.lua/MythicPlus.lua.
--
-- Section order matches the feature's own brief: Expansion Progress
-- (Campaign + Renown as plain lines, plus real ExpansionProgress-category
-- accomplishments as accordion rows) -> Raiding -> Mythic+ (completion
-- facts only -- MythicPlusModule remains the sole owner of run/rating
-- data) -> Feats of Strength (given prominence, a primary section per the
-- brief) -> Character Milestones -> Legacy Accomplishments (honest empty
-- state, "coming in a future update" -- no Blizzard signal exists to
-- auto-populate it, see AccomplishmentsModule.lua's own header) -> Recent
-- History -> Recommendations/Insights.
--
-- ACCORDION REDESIGN -- collapsed rows in the five accomplishment sections
-- above show ONLY the accomplishment name (via Dashboard:LayoutAccordionRows/
-- BuildAccomplishmentRow, Rows.lua) -- the earned date is no longer baked
-- into the collapsed line. Clicking a row expands it in place with Earned/
-- Category/Expansion (when honestly resolvable)/Description; only one
-- accomplishment is expanded at a time, PAGE-WIDE (a single shared
-- page.ExpandedAccomplishmentID, not one per section) -- expanding a new
-- one anywhere on the page collapses whatever was previously expanded.
-- Campaign/Renown lines are NOT achievements (no id/description/earned
-- date) and stay plain text. Recent History is deliberately UNCHANGED
-- this pass -- its stored records don't carry description/expansion
-- inline (a per-row module lookup would be needed) -- a real Phase 2
-- follow-up, not an oversight. This is the first step toward a longer-term
-- "Character Journey" direction; the expanded section is where future
-- Timeline/Player Journal/related-accomplishment links would naturally
-- live, none of which are built this pass.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

-------------------------------------------------------------------------------
-- Formatting Helpers
-------------------------------------------------------------------------------

local CAMPAIGN_STATE_LABEL_KEY =
{
    [1] = "Accomplishments.CampaignStateComplete",  -- Enum.CampaignState.Complete
    [2] = "Accomplishments.CampaignStateInProgress", -- Enum.CampaignState.InProgress
    [3] = "Accomplishments.CampaignStateStalled",    -- Enum.CampaignState.Stalled
}

local function FormatCampaignState(state)

    local labelKey = CAMPAIGN_STATE_LABEL_KEY[state]

    if not labelKey then
        return AC.L:Get("Common.Unknown")
    end

    return AC.L:Get(labelKey)

end

local function FormatEarnedDate(accomplishment)

    if not accomplishment.year or accomplishment.year == 0 then
        return AC.L:Get("Common.Unknown")
    end

    -- Presentation bug fix (Canonical Absolute Date Format Sweep) -- this
    -- used to show only "%02d/%02d" (month/day, no year at all),
    -- inconsistent with the addon's canonical "Mon DD, YYYY" date format.
    -- Blizzard's own achievement year field is a documented 2-digit offset
    -- (e.g. 24 for 2024, see GetAchievementInfo on Warcraft Wiki) -- real
    -- year = 2000 + field, reliable enough to build a real timestamp and
    -- route through Presentation.FormatDate like every other date in the
    -- addon.
    local timestamp = time({ year = 2000 + accomplishment.year, month = accomplishment.month or 1, day = accomplishment.day or 1 })

    return AC.Presentation.FormatDate(timestamp, "short")

end

-- Maps an accomplishment's own classification category to its existing
-- section-header loc key -- reused as the "Category" field's display
-- value in the expanded accordion view rather than a duplicate string.
local CATEGORY_LABEL_KEY =
{
    ExpansionProgress = "Accomplishments.SectionExpansionProgress",
    Raiding = "Accomplishments.SectionRaiding",
    MythicPlus = "Accomplishments.SectionMythicPlus",
    FeatsOfStrength = "Accomplishments.SectionFeatsOfStrength",
    CharacterMilestones = "Accomplishments.SectionCharacterMilestones",
}

-------------------------------------------------------------------------------
-- Build Campaign / Renown Lines
--
-- Campaign completion (C_CampaignInfo) and Renown (C_MajorFactions) are
-- NOT achievement data -- kept as plain text lines (no id/description/
-- earned date, so they can't become accordion rows). AccomplishmentsModule
-- keeps them in structurally separate tables (Rule 1) -- only this page's
-- own rendering choice groups them under the same "Expansion Progress"
-- section header as the real ExpansionProgress-category accomplishments,
-- which render separately below as accordion rows.
-------------------------------------------------------------------------------

local function BuildCampaignAndRenownLines(accomplishmentsModule)

    local lines = {}

    for _, campaign in pairs(accomplishmentsModule:GetCampaignProgress()) do

        local name = campaign.name ~= "" and campaign.name or AC.L:Get("Common.Unknown")

        table.insert(lines, AC.L:Format("Accomplishments.CampaignLineFormat", name, FormatCampaignState(campaign.state)))

    end

    for _, renown in pairs(accomplishmentsModule:GetRenownProgress()) do

        local name = renown.name ~= "" and renown.name or AC.L:Get("Common.Unknown")
        local line = AC.L:Format("Accomplishments.RenownLineFormat", name, renown.currentRenownLevel or 0)

        if renown.hasMaximumRenown then
            line = line .. AC.L:Get("Accomplishments.RenownMaxSuffix")
        elseif renown.isWeeklyCapped then
            line = line .. AC.L:Get("Accomplishments.RenownCappedSuffix")
        end

        table.insert(lines, line)

    end

    return lines

end

local function IdentityLine(line)
    return line
end

-------------------------------------------------------------------------------
-- Accordion Row Helpers
-------------------------------------------------------------------------------

-- Collapsed row: name only, higher-weight font (Rows.lua's
-- BuildAccomplishmentRow already applies GameFontNormal + the gold
-- highlight color) -- no baked-in date, the core of this redesign.
-- Accordion Polish Pass -- shifted right by Layout.ACCORDION_DISCLOSURE_WIDTH
-- to make room for LayoutAccordionRows' own disclosure icon; returns the
-- real measured height (with a safe fallback) instead of always assuming
-- one line, so a long accomplishment name that wraps no longer clips the
-- section that follows it.
local function LayoutAccomplishmentCollapsed(row, accomplishment, width)

    local baseX = Layout.ACCORDION_DISCLOSURE_WIDTH + Layout.ROW_INDENT

    row.NameText:ClearAllPoints()
    row.NameText:SetPoint("TOPLEFT", baseX, 0)
    row.NameText:SetWidth(width - baseX)
    row.NameText:SetText(accomplishment.name ~= "" and accomplishment.name or AC.L:Get("Common.Unknown"))

    return math.max(row.NameText:GetStringHeight() or Layout.ROW_HEIGHT, Layout.ROW_HEIGHT)

end

-- Expanded view: Earned / Category / Expansion (honest omission if
-- unresolved, never a fabricated "Unknown") / Description (Blizzard's
-- own achievement text, unlabeled wrapped body copy -- same convention
-- BuildRecommendationRow's own DescriptionText already uses, a deliberate
-- choice for a calmer, less "form-like" expanded view rather than an
-- oversight).
--
-- Character Journey pass -- the cached label/value field mechanic this
-- used to keep page-local (SetAccomplishmentDetailField/
-- HideAccomplishmentDetailField) is now Dashboard:SetAccordionDetailField/
-- HideAccordionDetailField (Rows.lua), promoted the moment Pages/Journey.lua
-- needed the identical shape. Byte-identical behavior, just shared.
local function BuildAccomplishmentDetail(row, accomplishment, width, detailYOffset)

    local yOffset = detailYOffset

    yOffset = Dashboard:SetAccordionDetailField(row, "Earned", "Accomplishments.FieldEarned", FormatEarnedDate(accomplishment), yOffset, width)
    yOffset = Dashboard:SetAccordionDetailField(row, "Category", "Accomplishments.FieldCategory", AC.L:Get(CATEGORY_LABEL_KEY[accomplishment.category] or "Common.Unknown"), yOffset, width)

    if accomplishment.expansion then
        yOffset = Dashboard:SetAccordionDetailField(row, "Expansion", "Accomplishments.FieldExpansion", accomplishment.expansion, yOffset, width)
    else
        Dashboard:HideAccordionDetailField(row, "Expansion")
    end

    yOffset = Dashboard:SetAccordionDetailDescription(row, accomplishment.description, yOffset, width)

    return detailYOffset - yOffset

end

local function HideAccomplishmentDetail(row)

    Dashboard:HideAccordionDetailField(row, "Earned")
    Dashboard:HideAccordionDetailField(row, "Category")
    Dashboard:HideAccordionDetailField(row, "Expansion")

    Dashboard:HideAccordionDetailDescription(row)

end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function Dashboard:UpdateAccomplishmentsPage(frame)

    local page = frame.Pages and frame.Pages.Accomplishments

    if not page then
        return
    end

    local accomplishmentsModule = AC.Core and AC.Core:GetModule("Accomplishments")

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    local campaignAndRenownLines = accomplishmentsModule and BuildCampaignAndRenownLines(accomplishmentsModule) or {}
    local expansionAccomplishments = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentsByCategory("ExpansionProgress") or {}
    local raiding = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentsByCategory("Raiding") or {}
    local mythicPlus = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentsByCategory("MythicPlus") or {}
    local featsOfStrength = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentsByCategory("FeatsOfStrength") or {}
    local characterMilestones = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentsByCategory("CharacterMilestones") or {}
    local recentHistory = accomplishmentsModule and accomplishmentsModule.GetRecentAccomplishments and accomplishmentsModule:GetRecentAccomplishments(10) or {}

    local recommendations, insights = self:GetCategorizedRecommendationsAndInsights("Accomplishments")

    -- Page-wide accordion: one shared expanded-ID field, one shared
    -- toggle, passed identically into every section below. Achievement
    -- IDs are globally unique across categories, so "only the matching
    -- row anywhere on the page shows expanded" falls out automatically --
    -- no per-section coordination needed.
    local function ToggleAccomplishment(accomplishmentID)

        if page.ExpandedAccomplishmentID == accomplishmentID then
            page.ExpandedAccomplishmentID = nil
        else
            page.ExpandedAccomplishmentID = accomplishmentID
        end

        self:UpdateAccomplishmentsPage(frame)

    end

    local function LayoutAccomplishmentSection(poolKey, records, emptyTextKey, yOffset, width)

        return self:LayoutAccordionRows(page, poolKey, scrollChild, yOffset, width, records,
        {
            expandedField = "ExpandedAccomplishmentID",
            getRecordID = function(record) return record.id end,
            rowGap = Layout.ACCORDION_ROW_GAP,
            buildRow = function(sc) return self:BuildAccomplishmentRow(sc) end,
            layoutCollapsed = LayoutAccomplishmentCollapsed,
            buildDetail = BuildAccomplishmentDetail,
            hideDetail = HideAccomplishmentDetail,
            onToggle = ToggleAccomplishment,
            emptyTextKey = emptyTextKey,
        })

    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        -----------------------------------------------------------------------
        -- Hero -- total tracked accomplishment count, with points and the
        -- real next-milestone target (AccomplishmentsModule:GetNextMilestone,
        -- this addon's own presentational round-number grouping over the
        -- real point total -- not a Blizzard concept) as the caption.
        -----------------------------------------------------------------------

        local totalCount = accomplishmentsModule and accomplishmentsModule:GetAccomplishmentCount() or 0
        local totalPoints = accomplishmentsModule and accomplishmentsModule:GetPoints() or 0
        local milestone = accomplishmentsModule and accomplishmentsModule:GetNextMilestone()

        local heroCaption = AC.L:Format("Accomplishments.HeroCaptionFormat", tostring(totalPoints), tostring(milestone and milestone.pointsRemaining or 0))

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("Accomplishments.HeroHeadline"), tostring(totalCount), heroCaption)

        yOffset = heroEndOffset

        -----------------------------------------------------------------------
        -- Expansion Progress -- Campaign/Renown as plain lines, then the
        -- real ExpansionProgress-category accomplishments as accordion
        -- rows, both under one section header.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionExpansionProgress", yOffset)

        page.Pools = page.Pools or {}
        page.Pools.ExpansionProgressLines = page.Pools.ExpansionProgressLines or {}

        yOffset = self:LayoutTextLines(scrollChild, page.Pools.ExpansionProgressLines, campaignAndRenownLines, yOffset, width, "Accomplishments.NoCampaignOrRenownProgress", IdentityLine)

        yOffset = LayoutAccomplishmentSection("ExpansionProgressAccomplishments", expansionAccomplishments, "Accomplishments.NoExpansionAccomplishments", yOffset, width)

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Raiding
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionRaiding", yOffset)

        yOffset = LayoutAccomplishmentSection("Raiding", raiding, "Accomplishments.NoRaidingAccomplishments", yOffset, width)

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Mythic+ (completion facts only -- MythicPlusModule owns
        -- everything else about Mythic+)
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionMythicPlus", yOffset)

        yOffset = LayoutAccomplishmentSection("MythicPlus", mythicPlus, "Accomplishments.NoMythicPlusAccomplishments", yOffset, width)

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Feats of Strength -- a primary section per the feature's own
        -- brief, given prominence via ordering.
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionFeatsOfStrength", yOffset)

        yOffset = LayoutAccomplishmentSection("FeatsOfStrength", featsOfStrength, "Accomplishments.NoFeatsOfStrength", yOffset, width)

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Character Milestones
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionCharacterMilestones", yOffset)

        yOffset = LayoutAccomplishmentSection("CharacterMilestones", characterMilestones, "Accomplishments.NoCharacterMilestones", yOffset, width)

        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Legacy Accomplishments -- honest empty state, no populator this
        -- pass (see AccomplishmentsModule.lua's own header).
        -----------------------------------------------------------------------

        yOffset = self:BeginSection(scrollChild, "Accomplishments.SectionLegacy", yOffset)
        yOffset = self:ShowEmptyLine(page, scrollChild, "LegacyEmptyText", yOffset, width, "Accomplishments.LegacyComingSoon")
        yOffset = self:EndSection(yOffset)

        -----------------------------------------------------------------------
        -- Recent History -- deliberately unchanged this pass (plain
        -- lines, not accordion rows -- see file header).
        -----------------------------------------------------------------------

        yOffset = self:AppendTextSection(page, "RecentHistory", "Accomplishments.SectionRecentHistory", yOffset, recentHistory, "Accomplishments.NoRecentHistory", function(record)
            return AC.L:Format("Accomplishments.RecentHistoryLineFormat", record.ActivityName or AC.L:Get("Common.Unknown"), AC.Presentation.FormatDate(record.Timestamp, "short"))
        end)

        -----------------------------------------------------------------------
        -- Recommendations / Insights -- same tail shape every dynamic
        -- page uses, included in both the full-width and (if needed)
        -- narrow-width measurement passes below.
        -----------------------------------------------------------------------

        yOffset = self:AppendDynamicSection(page, "Recommendations", "Accomplishments.SectionRecommendations", yOffset, recommendations, "Accomplishments.NoRecommendations", true)
        yOffset = self:AppendDynamicSection(page, "Insights", "Accomplishments.SectionInsights", yOffset, insights, "Accomplishments.NoInsights")

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
