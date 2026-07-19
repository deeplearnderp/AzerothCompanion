-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Character Journey
--
-- A curated, chronological "museum" of this character's meaningful
-- lifetime moments -- not another activity log. Answers "who has this
-- character become," not "what happened yesterday." Named and built as
-- the natural continuation of the Accomplishments accordion redesign,
-- whose own file header already called itself "the first step toward a
-- longer-term Character Journey direction."
--
-- ZERO NEW TRACKING. This page computes and stores nothing itself (Rule
-- 2) and introduces no new persisted state, no new Blizzard API calls,
-- and no new service. It is pure aggregation and presentation over two
-- already-public, already-durable read APIs:
--   - AccomplishmentsModule:GetAccomplishments() -- Blizzard's own earned
--     date, re-derived live every refresh, no pruning, no backfill gap.
--   - MilestoneService:GetAllAchieved() -- 12 achieve-once personal
--     milestones, permanent timestamp, never re-fires, never pruned.
-- AccomplishmentsModule already did the "curate down to what defines this
-- character" work (Pages/Accomplishments.lua shows every classified
-- accomplishment unconditionally) -- Journey does not apply a second,
-- stricter filter on top; doing so would make the same fact "signature
-- enough" on one page and not the other.
--
-- EXPLICITLY EXCLUDED THIS PASS -- real fabrication risk, not oversights:
--   - Player Journal ("first met a favorite player," "50 runs together")
--     -- PlayerJournalModule's storage is account-wide with no field
--     recording WHICH character met a companion or logged a run.
--     Attributing an account-wide fact to "this character's journey"
--     without that field would be a guess, not a recorded fact.
--   - Recommendation History / Community Notes -- neither has any
--     "notable moment" concept today, only routine engagement counters.
--   - "Highest Mythic+ ever, with a date" -- a genuinely different
--     "record can be broken again" pattern, structurally incompatible
--     with MilestoneService's achieve-once model; belongs to
--     MythicPlusModule (Rule 1) in a future pass, not force-fit here.
-- See docs/DEVELOPMENT_BACKLOG.md's "Character Journey" section for the
-- full phased roadmap these exclusions unblock.
--
-- ORDERING -- oldest-to-newest, grouped by year. A deliberate, explicit
-- departure from every other Dashboard list (all newest-first): this page
-- tells a story arc, not "what's new." Grouped by YEAR only, not expansion
-- -- year is the one axis
-- every entry can honestly provide (MilestoneService entries have no
-- expansion concept at all); expansion stays a per-entry field in the
-- expanded detail instead, mirroring Accomplishments' own honest-omission
-- pattern for it.
--
-- A HONESTY NUANCE carried from MilestoneService: its achieved timestamp
-- is when the ADDON DETECTED the crossing, not necessarily when the
-- player first crossed it (a fresh install on a veteran character
-- backfill-stamps every already-true milestone at "now"). Not new to
-- Journey -- Progress's "Recent Milestones" card already has this
-- property, unflagged -- but Journey makes the date prominent enough that
-- its detail view labels it "Recorded," not "Earned," for milestone-
-- sourced entries.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

-------------------------------------------------------------------------------
-- Entry Normalization
--
-- Kept page-local, not promoted to a shared module -- matches how
-- Pages/Accomplishments.lua keeps its own formatting helpers page-local
-- until a second real caller needs the identical shape (none does yet).
-------------------------------------------------------------------------------

local function BuildAccomplishmentJourneyEntry(accomplishment)

    local timestamp, dateUnknown = 0, true

    if accomplishment.year and accomplishment.year > 0 then

        -- Same construction Pages/Accomplishments.lua's own FormatEarnedDate
        -- already uses: Blizzard's year field is a documented 2-digit
        -- offset (e.g. 24 for 2024).
        timestamp = time({ year = 2000 + accomplishment.year, month = accomplishment.month or 1, day = accomplishment.day or 1 })
        dateUnknown = false

    end

    return
    {
        timestamp = timestamp,
        dateUnknown = dateUnknown,
        title = accomplishment.name ~= "" and accomplishment.name or AC.L:Get("Common.Unknown"),
        description = accomplishment.description or "",
        category = accomplishment.category,
        expansion = accomplishment.expansion,
        sourceType = "Accomplishment",
        recordID = "Accomplishment:" .. tostring(accomplishment.id),
    }

end

local function BuildMilestoneJourneyEntry(milestone)

    return
    {
        timestamp = milestone.achievedAt,
        dateUnknown = false,
        title = AC.L:Get(milestone.titleKey),
        description = AC.L:Get(milestone.descriptionKey),
        category = "PersonalMilestone",
        expansion = nil,
        sourceType = "Milestone",
        recordID = "Milestone:" .. tostring(milestone.id),
    }

end

-- newestFirst is presentation only -- the same entries, same fields,
-- just walked the other direction. This is the one and only place sort
-- direction is decided; GroupEntriesByYear and every layout function below
-- already just render whatever order they're handed, so nothing else
-- needs to change for either direction. Defaults to false (omitted
-- argument), preserving today's oldest-first behavior for every existing
-- caller -- GetJourneySummary below calls this with no argument and must
-- keep doing so, since Home's teaser card is a separate consumer,
-- unaffected by whatever sort direction the Journey page itself has
-- toggled to.
local function BuildJourneyEntries(newestFirst)

    local entries = {}

    local accomplishmentsModule = AC.Core and AC.Core:GetModule("Accomplishments")

    if accomplishmentsModule then

        for _, accomplishment in ipairs(accomplishmentsModule:GetAccomplishments()) do
            table.insert(entries, BuildAccomplishmentJourneyEntry(accomplishment))
        end

    end

    if AC.MilestoneService then

        for _, milestone in ipairs(AC.MilestoneService:GetAllAchieved()) do
            table.insert(entries, BuildMilestoneJourneyEntry(milestone))
        end

    end

    if newestFirst then
        table.sort(entries, function(a, b) return a.timestamp > b.timestamp end)
    else
        table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
    end

    return entries

end

-- Buckets already-sorted entries into ordered year groups (undated
-- entries, if any, form their own bucket first -- sorts first since
-- their timestamp is 0). Relies on `entries` already being sorted
-- ascending -- a bucket's first-seen order is therefore already correct.
local function GroupEntriesByYear(entries)

    local buckets = {}
    local bucketByLabel = {}

    for _, entry in ipairs(entries) do

        local label

        if entry.dateUnknown then
            label = AC.L:Get("Journey.UndatedSectionLabel")
        else
            label = date("%Y", entry.timestamp)
        end

        local bucket = bucketByLabel[label]

        if not bucket then

            bucket = { label = label, entries = {} }
            bucketByLabel[label] = bucket
            table.insert(buckets, bucket)

        end

        table.insert(bucket.entries, entry)

    end

    return buckets

end

-------------------------------------------------------------------------------
-- Year Separators
--
-- A lighter-weight divider than a full BeginSection/EndSection (the
-- wrong tool for a per-year runtime string, and visually heavy repeated
-- once per year on a long-lived character). Pooled by year label since
-- the set of years is genuinely dynamic across a character's lifetime,
-- unlike a page's fixed set of section titleKeys.
-------------------------------------------------------------------------------

local function LayoutYearSeparator(page, scrollChild, yOffset, width, labelText, cacheKey)

    page.Pools = page.Pools or {}
    page.Pools.YearSeparators = page.Pools.YearSeparators or {}

    local pool = page.Pools.YearSeparators
    local separator = pool[cacheKey]

    if not separator then

        local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetJustifyH("LEFT")
        AC.DashboardFormat.SetHighlightColor(text)

        separator = { Text = text }
        pool[cacheKey] = separator

    end

    separator.Text:ClearAllPoints()
    separator.Text:SetPoint("TOPLEFT", 0, yOffset)
    separator.Text:SetWidth(width)
    separator.Text:SetText(labelText)
    separator.Text:Show()

    yOffset = yOffset - (separator.Text:GetStringHeight() or 18) - 4

    -- Accordion Polish Pass -- pools this divider too (same cacheKey as
    -- the separator's own text), fixing the same ghost-widget leak
    -- AddDivider's other unkeyed callers no longer have.
    yOffset = Dashboard:AddDivider(scrollChild, yOffset, width, cacheKey)

    return yOffset - Layout.JOURNEY_YEAR_SEPARATOR_GAP

end

local function HideStaleYearSeparators(page, keepKeys)

    if not page.Pools or not page.Pools.YearSeparators then
        return
    end

    for key, separator in pairs(page.Pools.YearSeparators) do

        if not keepKeys[key] then
            separator.Text:Hide()
        end

    end

end

-------------------------------------------------------------------------------
-- Accordion Row Helpers
--
-- Reuses Dashboard:LayoutAccordionRows (the shared engine, called once
-- per year-bucket -- the same multi-call-per-page shape
-- Pages/Accomplishments.lua already uses across its five sections) and
-- Dashboard:BuildAccomplishmentRow unchanged for the collapsed row
-- (already documented as data-agnostic for exactly this reason).
-------------------------------------------------------------------------------

local CATEGORY_LABEL_KEY =
{
    ExpansionProgress = "Accomplishments.SectionExpansionProgress",
    Raiding = "Accomplishments.SectionRaiding",
    MythicPlus = "Accomplishments.SectionMythicPlus",
    FeatsOfStrength = "Accomplishments.SectionFeatsOfStrength",
    CharacterMilestones = "Accomplishments.SectionCharacterMilestones",
    PersonalMilestone = "Journey.CategoryPersonalMilestone",
}

-- Collapsed row -- a deliberate, explicit departure from Accomplishments'
-- name-only row: a date-forward feel fits a timeline, and
-- Presentation.lua's own header treats "always include the year" as a
-- hard-won fix, not something to quietly reopen with a new date-less
-- style just for this one row. Accordion Polish Pass -- shifted right by
-- Layout.ACCORDION_DISCLOSURE_WIDTH for the engine's own disclosure icon;
-- returns the real measured height (safe fallback) instead of always
-- assuming one line.
local function LayoutJourneyCollapsed(row, entry, width)

    local dateText = entry.dateUnknown and AC.L:Get("Journey.UndatedSectionLabel") or AC.Presentation.FormatDate(entry.timestamp, "short")

    local baseX = Layout.ACCORDION_DISCLOSURE_WIDTH + Layout.ROW_INDENT

    row.NameText:ClearAllPoints()
    row.NameText:SetPoint("TOPLEFT", baseX, 0)
    row.NameText:SetWidth(width - baseX)
    row.NameText:SetText(AC.L:Format("Journey.EntryLineFormat", dateText, entry.title))

    return math.max(row.NameText:GetStringHeight() or Layout.ROW_HEIGHT, Layout.ROW_HEIGHT)

end

-- Expanded view: Earned/Recorded (label depends on sourceType -- see file
-- header honesty nuance) / Category / Expansion (honest omission if
-- unresolved) / Description. Uses the shared Dashboard:SetAccordionDetailField/
-- HideAccordionDetailField (Rows.lua) -- the same mechanic
-- Pages/Accomplishments.lua uses, promoted the moment this page needed it
-- too.
local function BuildJourneyDetail(row, entry, width, detailYOffset)

    local yOffset = detailYOffset

    local dateLabelKey = entry.sourceType == "Milestone" and "Journey.FieldRecorded" or "Accomplishments.FieldEarned"
    local dateValue = entry.dateUnknown and AC.L:Get("Common.Unknown") or AC.Presentation.FormatDate(entry.timestamp, "short")

    yOffset = Dashboard:SetAccordionDetailField(row, "Date", dateLabelKey, dateValue, yOffset, width)
    yOffset = Dashboard:SetAccordionDetailField(row, "Category", "Accomplishments.FieldCategory", AC.L:Get(CATEGORY_LABEL_KEY[entry.category] or "Common.Unknown"), yOffset, width)

    if entry.expansion then
        yOffset = Dashboard:SetAccordionDetailField(row, "Expansion", "Accomplishments.FieldExpansion", entry.expansion, yOffset, width)
    else
        Dashboard:HideAccordionDetailField(row, "Expansion")
    end

    yOffset = Dashboard:SetAccordionDetailDescription(row, entry.description, yOffset, width)

    return detailYOffset - yOffset

end

local function HideJourneyDetail(row)

    Dashboard:HideAccordionDetailField(row, "Date")
    Dashboard:HideAccordionDetailField(row, "Category")
    Dashboard:HideAccordionDetailField(row, "Expansion")

    Dashboard:HideAccordionDetailDescription(row)

end

-------------------------------------------------------------------------------
-- Summary (for Home's teaser card)
-------------------------------------------------------------------------------

function Dashboard:GetJourneySummary()

    local entries = BuildJourneyEntries()

    return
    {
        count = #entries,
        mostRecent = entries[#entries],
    }

end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function Dashboard:UpdateJourneyPage(frame)

    local page = frame.Pages and frame.Pages.Journey

    if not page then
        return
    end

    self:RefreshEngines(page)

    local scrollChild = page.ScrollChild

    -- Timeline sort toggle -- session-only (not persisted, per explicit
    -- instruction), defaults to nil/false, i.e. today's existing
    -- oldest-first behavior, unchanged for anyone who never touches it.
    local newestFirst = page.SortNewestFirst == true

    local entries = BuildJourneyEntries(newestFirst)
    local yearBuckets = GroupEntriesByYear(entries)

    -- Page-wide accordion: one shared expanded-ID field, one shared
    -- toggle, passed identically into every year-bucket below. Record
    -- IDs are globally unique across sources, so "only the matching row
    -- anywhere on the page shows expanded" falls out automatically.
    -- Robust to sort direction by construction -- keyed by recordID, never
    -- by array position, so reordering entries never disturbs which one
    -- is expanded.
    local function ToggleJourneyEntry(recordID)

        if page.ExpandedJourneyEntryID == recordID then
            page.ExpandedJourneyEntryID = nil
        else
            page.ExpandedJourneyEntryID = recordID
        end

        self:UpdateJourneyPage(frame)

    end

    -- Same idiom as ToggleJourneyEntry above: flip a page-local field,
    -- re-run the whole page update. Changes presentation only --
    -- BuildJourneyEntries' own sort direction is the one and only thing
    -- this touches.
    local function ToggleSortDirection()

        page.SortNewestFirst = not page.SortNewestFirst

        self:UpdateJourneyPage(frame)

    end

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4

        local totalCount = #entries

        -- Whichever end of the (already correctly sorted) array holds the
        -- newest entry depends on which direction is active -- entries[1]
        -- when newest-first, entries[totalCount] (today's only case) when
        -- oldest-first. Was previously always entries[totalCount], which
        -- would have silently shown the OLDEST entry as "most recent" once
        -- Newest First became selectable.
        local mostRecent = totalCount > 0 and (newestFirst and entries[1] or entries[totalCount]) or nil

        local heroCaption = totalCount > 0 and AC.L:Format("Journey.HeroCaptionFormat", mostRecent.title) or AC.L:Get("Journey.EmptyHeroCaption")

        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("Journey.HeroHeadline"), totalCount > 0 and tostring(totalCount) or "", heroCaption)

        yOffset = heroEndOffset

        if totalCount == 0 then

            yOffset = self:ShowEmptyLine(page, scrollChild, "EmptyStateText", yOffset, width, "Journey.EmptyStateBody")

            if page.SortToggleButton then
                page.SortToggleButton:Hide()
            end

            return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

        end

        if page.EmptyStateText then
            page.EmptyStateText:Hide()
        end

        -- Sort toggle button -- pooled/created once (same "if not
        -- page.X then create" idiom every other page-local action button
        -- in this codebase already uses), only shown when there's
        -- actually a list to reorder. Label reflects the CURRENTLY active
        -- direction; clicking switches to the other.
        if not page.SortToggleButton then

            local button = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
            button:SetSize(140, 20)

            page.SortToggleButton = button

        end

        page.SortToggleButton:SetScript("OnClick", ToggleSortDirection)
        page.SortToggleButton:ClearAllPoints()
        page.SortToggleButton:SetPoint("TOPRIGHT", 0, yOffset)
        page.SortToggleButton:SetText(newestFirst and AC.L:Get("Journey.SortNewestFirst") or AC.L:Get("Journey.SortOldestFirst"))
        page.SortToggleButton:Show()

        yOffset = yOffset - Layout.ROW_HEIGHT - Layout.SECTION_GROUP_GAP

        local keepKeys = {}

        for _, bucket in ipairs(yearBuckets) do

            keepKeys[bucket.label] = true

            yOffset = LayoutYearSeparator(page, scrollChild, yOffset, width, bucket.label, bucket.label)

            yOffset = self:LayoutAccordionRows(page, "JourneyYear_" .. bucket.label, scrollChild, yOffset, width, bucket.entries,
            {
                expandedField = "ExpandedJourneyEntryID",
                getRecordID = function(entry) return entry.recordID end,
                rowGap = Layout.ACCORDION_ROW_GAP,
                buildRow = function(sc) return self:BuildAccomplishmentRow(sc) end,
                layoutCollapsed = LayoutJourneyCollapsed,
                buildDetail = BuildJourneyDetail,
                hideDetail = HideJourneyDetail,
                onToggle = ToggleJourneyEntry,
            })

            yOffset = yOffset - Layout.SECTION_GROUP_GAP

        end

        HideStaleYearSeparators(page, keepKeys)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
