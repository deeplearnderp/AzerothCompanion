-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard: Home
--
-- The window shell (Create) and the player's daily briefing (UpdateContent)
-- -- the flagship experience of the addon (Home Dashboard Evolution).
-- Every card exists to answer one question -- "what should I do next?" --
-- ordered so the player's attention lands where it matters most first:
-- the single highest-priority recommendation (with its full reasoning),
-- then the supporting facts behind it (character, current keystone, vault
-- progress), then a real chronological feed of what actually happened
-- recently. Inventory, Accomplishments, and Storage are still real
-- navigation entry points into their own pages (there is no separate
-- sidebar nav in this window), so they stay on Home, just de-emphasized
-- to the bottom rather than removed.
--
-- Every card's numbers/wording come from a real module getter -- nothing
-- here is fabricated to fill out the illustrative mockups this feature
-- was designed against. Two deliberate departures from that mockup, both
-- because the underlying data doesn't exist anywhere in this addon:
--   - Recent Activity shows only Mythic+ runs and Accomplishments, the only
--     two record types anything actually writes to ActivityHistoryService
--     today -- no "Bought N Potions" or "Weekly Completed" entries, since
--     nothing records purchases or discrete weekly-completion events.
--   - Highest Priority's "Supporting Evidence" renders the real
--     `label: value` facts RecommendationEngine attached (rating,
--     historical success rate, ...), not narrative phrases like
--     "Historically successful" -- those aren't things any module
--     computes as a discrete fact today.
--
-- Create() also builds every other page's shell (Profile/Inventory/
-- Accomplishments/MythicPlus/Storage/Weekly/Recommendations) -- this is the
-- one file that assembles the whole window, even though each page's own
-- refresh logic lives in Pages/*.lua.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout
local Format = AC.DashboardFormat
local Schemas = AC.DashboardSchemas

-------------------------------------------------------------------------------
-- Greeting
--
-- Real local system time (date("%H")), not fabricated data -- just a
-- friendlier daily-briefing framing than a bare "Home" title.
-------------------------------------------------------------------------------

local function GetGreetingKey()

    local hour = tonumber(date("%H"))

    if not hour then
        return "Dashboard.GreetingGeneric"
    elseif hour >= 5 and hour < 12 then
        return "Dashboard.GreetingMorning"
    elseif hour >= 12 and hour < 17 then
        return "Dashboard.GreetingAfternoon"
    elseif hour >= 17 and hour < 22 then
        return "Dashboard.GreetingEvening"
    else
        return "Dashboard.GreetingNight"
    end

end

-------------------------------------------------------------------------------
-- Recent Activity Feed
--
-- A real chronological feed merging every module that actually records
-- discrete events to ActivityHistoryService today -- MythicPlus
-- (GetRecentRuns) and Accomplishments (GetRecentAccomplishments), both already
-- public getters those modules exposed for their own history pages, not
-- a new read path into ActivityHistoryService itself (Dashboard still
-- never talks to that service directly for gameplay records -- see
-- docs/GameplayModuleArchitecture.md Rule 2/4). Sorting a list this
-- module didn't generate is presentation, not a new gameplay judgment --
-- the same category of thing RecommendationEngine already does when it
-- sorts recommendations by score.
-------------------------------------------------------------------------------

local function BuildActivityFeedLine(record)

    if record.Module == "MythicPlus" then

        local data = record.Data or {}
        local level = data.level or 0
        local name = record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown")

        if record.Success then
            return AC.L:Format("Dashboard.FeedMythicPlusTimedFormat", level, name)
        else
            return AC.L:Format("Dashboard.FeedMythicPlusFailedFormat", level, name)
        end

    elseif record.Module == "Achievements" then

        local name = record.ActivityName ~= "" and record.ActivityName or AC.L:Get("Common.Unknown")

        return AC.L:Format("Dashboard.FeedAchievementFormat", name)

    end

    return nil

end

local function GetRecentActivityFeed(count)

    local entries = {}

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")

    if mythicPlusModule and mythicPlusModule.GetRecentRuns then

        for _, record in ipairs(mythicPlusModule:GetRecentRuns(count)) do
            table.insert(entries, record)
        end

    end

    local accomplishmentsModule = AC.Core and AC.Core:GetModule("Accomplishments")

    if accomplishmentsModule and accomplishmentsModule.GetRecentAccomplishments then

        for _, record in ipairs(accomplishmentsModule:GetRecentAccomplishments(count)) do
            table.insert(entries, record)
        end

    end

    table.sort(entries, function(a, b)
        return (a.Timestamp or 0) > (b.Timestamp or 0)
    end)

    local trimmed = {}

    for i = 1, math.min(count, #entries) do
        trimmed[i] = entries[i]
    end

    return trimmed

end

-------------------------------------------------------------------------------
-- Create Home Card
--
-- The repeated "create, anchor below the previous card, seed the loading
-- state" shape every Home card shared verbatim -- extracted once it had
-- been copy-pasted 8 times (Home Dashboard Evolution). Per-card specifics
-- (width/height/showBar/fonts/tooltip/onClick) still live at each call
-- site via `options`, since those genuinely differ card to card and
-- collapsing them further would obscure more than it would save.
-------------------------------------------------------------------------------

local function CreateHomeCard(parent, titleKey, options, anchorFrame, gap)

    local card = AC.DashboardCard:Create(parent, AC.L:Get(titleKey), options)

    card:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -(gap or Layout.HOME_SECTION_GAP))
    card:SetPrimaryValue(AC.L:Get("Dashboard.Loading"))
    card:SetSecondaryText("")

    return card

end

-------------------------------------------------------------------------------
-- Apply Lines To Card
--
-- The "most recent/most important line gets the card's headline
-- treatment (PrimaryValue), the rest render as a compact list below it"
-- shape shared by every Home card backed by an ordered list of strings
-- (Recent Activity's feed, Companion Intelligence V4's Briefing/
-- Milestones/Notifications cards) -- written once here instead of once
-- per card.
-------------------------------------------------------------------------------

local function ApplyLinesToCard(card, lines, emptyTextKey)

    if not lines or #lines == 0 then

        card:SetPrimaryValue(AC.L:Get(emptyTextKey))
        card:SetSecondaryText("")
        card:SetDetailSections({})

        return

    end

    card:SetPrimaryValue(lines[1])
    card:SetSecondaryText("")

    if #lines > 1 then

        local rest = {}

        for i = 2, #lines do
            table.insert(rest, lines[i])
        end

        card:SetDetailSections({ { text = table.concat(rest, "\n") } })

    else
        card:SetDetailSections({})
    end

end

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function Dashboard:Create()

    local frame = AC.BaseWindow:Create("AzerothCompanionDashboard", AC.L:Get("App.Title"), Layout.WINDOW_WIDTH, Layout.WINDOW_HEIGHT)

    frame:SetSize(Layout.WINDOW_WIDTH, Layout.WINDOW_HEIGHT)

    -----------------------------------------------------------------------
    -- Shared Decorative Background (Dashboard Background Polish Pass)
    --
    -- One CreateTexture, one owner (frame itself -- the single frame every
    -- page/card is already a descendant of via ContentArea/CreateDataPage),
    -- one SetTexture, one texture constant, one alpha constant. Drawn at
    -- the BACKGROUND layer directly on frame -- every page and every card
    -- is a CHILD frame of this one, so it renders behind all of them
    -- automatically; a future page added the same way (CreateDataPage,
    -- parented through ContentArea) inherits this with zero new code,
    -- since nothing here is keyed to which pages currently exist. Created
    -- once here, never touched by ShowPage/page-switching, so it stays
    -- fixed while navigating -- not special-cased, simply never hidden,
    -- moved, or recreated by anything else.
    --
    -- Uniform "cover" scale, centered, computed from
    -- DASHBOARD_BACKGROUND_ASPECT_RATIO -- not SetAllPoints(frame). The
    -- artwork's real pixel size (957x1643, read from the PNG header) is
    -- portrait and very close to this frame's own ratio, so this comes
    -- out to roughly 420x721 -- effectively edge-to-edge with negligible
    -- overflow, not the previous SetAllPoints approach's independent-axis
    -- stretch (which was fine only because the earlier, now-replaced
    -- artwork was landscape). One hardcoded ratio is required here since
    -- there is no runtime API to ask a texture file for its native pixel
    -- dimensions -- see DASHBOARD_BACKGROUND_ASPECT_RATIO's own comment in
    -- Presentation.lua for where that number comes from and why it's not
    -- a magic literal.
    --
    -- Explicit instruction this pass: do NOT touch the Dashboard's own
    -- backdrop alpha -- it stays exactly whatever BaseWindow:Create()
    -- already set it to (WINDOW_BACKDROP's shared 0.95).
    -----------------------------------------------------------------------

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(AC.Presentation.DASHBOARD_BACKGROUND_TEXTURE)
    background:SetAlpha(AC.Presentation.DASHBOARD_BACKGROUND_ALPHA)

    local backgroundAspectRatio = AC.Presentation.DASHBOARD_BACKGROUND_ASPECT_RATIO
    local backgroundWidth, backgroundHeight

    if (Layout.WINDOW_WIDTH / Layout.WINDOW_HEIGHT) < backgroundAspectRatio then
        backgroundHeight = Layout.WINDOW_HEIGHT
        backgroundWidth = backgroundHeight * backgroundAspectRatio
    else
        backgroundWidth = Layout.WINDOW_WIDTH
        backgroundHeight = backgroundWidth / backgroundAspectRatio
    end

    background:SetSize(backgroundWidth, backgroundHeight)
    background:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.Background = background

    -----------------------------------------------------------------------
    -- Header
    --
    -- BaseWindow already creates frame.Title. Reposition it to the left
    -- and place a Settings button on the same row, rather than layering
    -- a second title on top of it. The header stays visible across every
    -- page.
    -----------------------------------------------------------------------

    frame.Title:ClearAllPoints()
    frame.Title:SetPoint("TOPLEFT", 16, -16)
    frame.Title:SetJustifyH("LEFT")

    local settingsButton = CreateFrame("Button", "AzerothCompanionDashboardSettings", frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(80, 22)
    settingsButton:SetPoint("TOPRIGHT", -16, -14)
    settingsButton:SetText(AC.L:Get("Dashboard.Settings"))

    settingsButton:SetScript("OnClick", function()

        local window = AC.Core:GetModule("SettingsWindow")

        if window then
            window:Toggle()
        end

    end)

    frame.SettingsButton = settingsButton

    -----------------------------------------------------------------------
    -- Keyboard Navigation (Navigation UX Sprint)
    --
    -- EnableKeyboard(true) is set once, here, for the lifetime of this
    -- frame -- it does NOT globally capture keys: WoW does not dispatch
    -- OnKeyDown to a hidden frame, so this only ever intercepts anything
    -- while the Dashboard itself is actually shown, which is exactly
    -- "only while Azeroth Companion has focus." Every key this handler
    -- doesn't explicitly recognize is propagated (SetPropagateKeyboardInput(true))
    -- so normal keybinds/movement/chat are never affected while the
    -- Dashboard happens to be open.
    --
    -- Both branches call the exact same Dashboard:GoBack()/CanGoBack()
    -- the Back button itself calls (Sections.lua's CreateDataPage) -- no
    -- second copy of "is there anywhere to go back to."
    --
    -- NOT independently verified against a live client this pass: whether
    -- an open chat EditBox's own keyboard focus takes priority over this
    -- frame's EnableKeyboard for Backspace while both are active at once
    -- (e.g. Dashboard open, player typing a chat message). WoW's EditBox
    -- focus and plain-Frame EnableKeyboard are understood to be separate
    -- mechanisms, but this specific interaction needs an in-game check,
    -- not an assumption -- see the live verification checklist.
    -----------------------------------------------------------------------

    frame:EnableKeyboard(true)

    frame:SetScript("OnKeyDown", function(self, key)

        if key == "ESCAPE" then

            if Dashboard:CanGoBack() then
                Dashboard:GoBack()
            else
                Dashboard:Hide()
            end

            self:SetPropagateKeyboardInput(false)

        elseif key == "BACKSPACE" and Dashboard:CanGoBack() then

            -- Backspace has no defined action when there's nowhere to go
            -- back to (unlike Escape, which always does something) --
            -- propagate in that case rather than silently swallowing a
            -- key that did nothing.
            Dashboard:GoBack()
            self:SetPropagateKeyboardInput(false)

        else
            self:SetPropagateKeyboardInput(true)
        end

    end)

    -----------------------------------------------------------------------
    -- Content Area
    --
    -- Everything below the header lives inside here. Pages are children
    -- of this frame and are shown/hidden as a unit -- no separate
    -- windows are created.
    -----------------------------------------------------------------------

    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, Layout.CONTENT_TOP_OFFSET)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame.ContentArea = contentArea
    frame.Pages = {}

    -----------------------------------------------------------------------
    -- Home Page -- the player's daily briefing.
    --
    -- Stacking all 12 Home cards at their real heights runs to roughly
    -- 1,600px -- well past this window's ~670px usable viewport. WoW does
    -- not clip a plain Frame's children to its own bounds, so without a
    -- real ScrollFrame the cards below Recent Activity would render past
    -- the window's bottom edge, unclipped and completely unreachable
    -- (v1.0 Polish Sprint audit -- a real, confirmed bug, not a cosmetic
    -- gap). Home gets its ScrollFrame from the exact same
    -- Dashboard:CreatePageScrollFrame every other page uses (Dashboard
    -- Scrollbar Standardization -- previously Home built its own inline
    -- copy, which is why its scrollbar used to sit in a different place,
    -- and never had its arrow buttons hidden, unlike every other page).
    -- topInset 0 (no Back/Title/Updated header sits above Home's content)
    -- and leftInset 0 (card width is fixed at 360 regardless of scrollbar,
    -- centered off an absolute WINDOW_WIDTH-based formula below, not a
    -- page-relative one) are both genuine, permanent differences from a
    -- data page's shape, not scrollbar-position drift -- see
    -- CreatePageScrollFrame's own comment (Sections.lua).
    -----------------------------------------------------------------------

    local homePage = CreateFrame("Frame", nil, contentArea)
    homePage:SetAllPoints(contentArea)

    local homeScrollFrame = Dashboard:CreatePageScrollFrame(homePage, 0, 0)

    local homeScrollChild = CreateFrame("Frame", nil, homeScrollFrame)
    homeScrollChild:SetWidth(Layout.WINDOW_WIDTH - Layout.SCROLLBAR_RESERVE)
    homeScrollChild:SetHeight(1)

    homeScrollFrame:SetScrollChild(homeScrollChild)

    homePage.ScrollFrame = homeScrollFrame
    homePage.ScrollChild = homeScrollChild

    frame.Pages.Home = homePage

    -- Greeting ---------------------------------------------------------
    --
    -- Real, local system time (date("%H")) -- not fabricated data, just a
    -- friendlier framing than a bare page title. GetGreetingKey (above)
    -- picks the bracket.

    local greetingText = homeScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    greetingText:SetPoint("TOP", homeScrollChild, "TOP", 0, -6)
    greetingText:SetJustifyH("CENTER")
    greetingText:SetWidth(Layout.CARD_WIDTH)

    frame.GreetingText = greetingText

    -- Today's Briefing Card (Companion Intelligence V4) --------------------
    --
    -- A short, real, curated list -- BriefingService's own selection of
    -- the highest-value recommendation plus a few of the highest-priority
    -- Insights across other modules. This card only renders whatever
    -- BriefingService already decided; it computes nothing.

    local briefingCard = CreateHomeCard(homeScrollChild, "Dashboard.TodaysBriefing",
    {
        width = Layout.CARD_WIDTH,
        tooltip = AC.L:Get("Dashboard.TooltipTodaysBriefing"),
        onClick = function()
            Dashboard:Navigate("Recommendations")
        end,
    }, greetingText, 8)

    frame.BriefingCard = briefingCard

    -- Today's Companion Notes Card (Companion Intelligence vNext) ----------
    --
    -- SessionNotesService's own real, session-relative facts (this
    -- session's runs/achievements/vault gains, a one-time "Welcome back")
    -- -- distinct from the Briefing card above, which is a curated view of
    -- CURRENT recommendations/insights, not session history.

    local companionNotesCard = CreateHomeCard(homeScrollChild, "Dashboard.TodaysCompanionNotes",
    {
        width = Layout.CARD_WIDTH,
        tooltip = AC.L:Get("Dashboard.TooltipTodaysCompanionNotes"),
    }, briefingCard)

    frame.CompanionNotesCard = companionNotesCard

    -- Recent Milestones Card (Companion Intelligence V4) -------------------
    --
    -- MilestoneService's own recently-achieved list -- personal, account-
    -- history milestones independent of Blizzard's achievement system.

    local milestonesCard = CreateHomeCard(homeScrollChild, "Dashboard.RecentMilestones",
    {
        width = Layout.CARD_WIDTH,
        tooltip = AC.L:Get("Dashboard.TooltipRecentMilestones"),
    }, companionNotesCard)

    frame.MilestonesCard = milestonesCard

    -- Recent Notifications Card (Companion Intelligence V4) ----------------
    --
    -- NotificationService's bounded history -- what recently popped up as
    -- a toast, for a player who glances at Home instead of catching it
    -- live.

    local notificationsCard = CreateHomeCard(homeScrollChild, "Dashboard.RecentNotifications",
    {
        width = Layout.CARD_WIDTH,
        tooltip = AC.L:Get("Dashboard.TooltipRecentNotifications"),
    }, milestonesCard)

    frame.NotificationsCard = notificationsCard

    -- Recommendation Card ("Highest Priority") --------------------------
    --
    -- The flagship card -- a real, explainable "what should I do next"
    -- with its full reasoning attached via SetDetailSections (Reason /
    -- Expected Benefit / Estimated Time / Supporting Evidence), not a
    -- single dim summary line.

    local recommendationCard = CreateHomeCard(homeScrollChild, "Dashboard.HighestPriority",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.RECOMMENDATION_HEIGHT,
        titleFont = "GameFontNormalLarge",
        primaryFont = "GameFontHighlightLarge",
        emphasized = true,
        hideIndicator = true, -- UI Polish Pass -- Dismiss/Why? already occupy this card's top-right corner; a second, generic click-navigation chevron there read as redundant and disconnected from the actual action buttons. The card body stays clickable (onClick below still fires).
        tooltip = AC.L:Get("Dashboard.TooltipRecommendations"),
        onClick = function()
            Dashboard:Navigate("Recommendations")
        end,
    }, notificationsCard)

    recommendationCard:SetPrimaryValue(AC.L:Get("Dashboard.CaughtUp"))

    frame.RecommendationCard = recommendationCard

    -- "Why?" Button (Recommendation Inspector) -----------------------------
    --
    -- Opens the Inspector for whatever the top recommendation currently
    -- is -- read from CurrentRecommendation (set fresh every UpdateContent
    -- call below), never captured at button-creation time, since this
    -- button is built once but the recommendation it points at changes
    -- every refresh. Hidden entirely when there's nothing to inspect
    -- (the player is caught up).
    --
    -- UI Polish Pass -- anchored at the card's own shared padding
    -- constants (CARD_PADDING_RIGHT/TOP) instead of independent hand-typed
    -- offsets (-10/-10), so this stays aligned with the title row if that
    -- padding ever changes again, and nudged up 3px from the title's own
    -- baseline to center against GameFontNormalLarge's taller line height.

    local whyButton = CreateFrame("Button", nil, recommendationCard, "UIPanelButtonTemplate")
    whyButton:SetSize(56, 20)
    whyButton:SetPoint("TOPRIGHT", -Layout.CARD_PADDING_RIGHT, -(Layout.CARD_PADDING_TOP - 3))
    whyButton:SetText(AC.L:Get("Inspector.WhyButton"))

    -- Sits on top of the card's own onClick (which navigates to the
    -- Recommendations page on any click elsewhere on the card) -- bumped
    -- explicitly above it so this button's own click is never swallowed
    -- by the card underneath it.
    whyButton:SetFrameLevel(recommendationCard:GetFrameLevel() + 1)

    whyButton:Hide()

    whyButton:SetScript("OnClick", function()

        -- Navigation UX Sprint -- was AC.RecommendationInspector:Show(...)
        -- (a standalone popup); Recommendation Details is a real Dashboard
        -- page now, navigated to exactly like any other page.
        if recommendationCard.CurrentRecommendation then
            Dashboard:ShowRecommendationDetails(recommendationCard.CurrentRecommendation)
        end

    end)

    recommendationCard.WhyButton = whyButton

    -- Dismiss Button (Companion Intelligence vNext) -----------------------
    --
    -- Same capture-at-click pattern as WhyButton above -- reads
    -- CurrentRecommendation fresh every click, never captured at
    -- creation time. Hidden entirely when there's nothing to dismiss.

    local dismissButton = CreateFrame("Button", nil, recommendationCard, "UIPanelButtonTemplate")
    dismissButton:SetSize(20, 20)
    dismissButton:SetPoint("TOPRIGHT", whyButton, "TOPLEFT", -Layout.CARD_ACTION_BUTTON_GAP, 0)
    dismissButton:SetText(AC.L:Get("Dashboard.DismissButtonGlyph"))
    dismissButton:SetFrameLevel(recommendationCard:GetFrameLevel() + 1)
    dismissButton:Hide()

    dismissButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(AC.L:Get("Dashboard.DismissButtonTooltip"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    dismissButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    dismissButton:SetScript("OnClick", function()

        if recommendationCard.CurrentRecommendation and AC.RecommendationHistoryService then
            AC.RecommendationHistoryService:DismissRecommendation(recommendationCard.CurrentRecommendation.id)
            Dashboard:UpdateContent(frame)
        end

    end)

    recommendationCard.DismissButton = dismissButton

    -- Profile Card ("Current Character") --------------------------------

    local profileCard = CreateHomeCard(homeScrollChild, "Dashboard.Profile",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipProfile"),
        onClick = function()
            Dashboard:Navigate("Profile")
        end,
    }, recommendationCard)

    frame.ProfileCard = profileCard

    -- Mythic+ Card ("Current Keystone") ----------------------------------

    local mythicPlusCard = CreateHomeCard(homeScrollChild, "Dashboard.MythicPlus",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT_WITH_BAR,
        showBar = true,
        tooltip = AC.L:Get("Dashboard.TooltipMythicPlus"),
        onClick = function()
            Dashboard:Navigate("MythicPlus")
        end,
    }, profileCard)

    mythicPlusCard:SetStatus("Normal", "")

    frame.MythicPlusCard = mythicPlusCard

    -- Vault Card ("Vault Progress") ---------------------------------------
    --
    -- Reads WeeklyModule directly, the same way every other Home card
    -- reads its own module directly. Now shows a real progress bar (Home
    -- Dashboard Evolution) -- it always had "Progress" in its name but
    -- never actually had one.

    local vaultCard = CreateHomeCard(homeScrollChild, "Dashboard.VaultProgress",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT_WITH_BAR,
        showBar = true,
        tooltip = AC.L:Get("Dashboard.TooltipVaultProgress"),
        onClick = function()
            Dashboard:Navigate("Weekly")
        end,
    }, mythicPlusCard)

    frame.VaultCard = vaultCard

    -- Recent Activity Card ------------------------------------------------
    --
    -- A real chronological feed (GetRecentActivityFeed above) across
    -- every module that actually records to ActivityHistoryService today.

    local recentActivityCard = CreateHomeCard(homeScrollChild, "Dashboard.RecentActivity",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipRecentActivity"),
        onClick = function()

            -- Routes to whichever page the newest feed entry is actually
            -- about (set fresh every UpdateContent below, since the feed
            -- itself merges MythicPlus runs and Accomplishments records) --
            -- defaults to MythicPlus before the first refresh has run.
            Dashboard:Navigate(recentActivityCard.TargetPage or "MythicPlus")

        end,
    }, vaultCard)

    frame.RecentActivityCard = recentActivityCard

    -- Progress Card ("How am I improving?") --------------------------------
    --
    -- The one compact entry point into the Progress Dashboard from Home --
    -- deliberately a season-level trend summary, not a duplicate of what
    -- the Mythic+ Card (current keystone/live rating) or Recent Activity
    -- Card (chronological run feed) already show.

    local progressCard = CreateHomeCard(homeScrollChild, "Dashboard.Progress",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipProgress"),
        onClick = function()
            Dashboard:Navigate("Progress")
        end,
    }, recentActivityCard)

    frame.ProgressCard = progressCard

    -- Statistics Card (Companion Intelligence vNext) -----------------------
    --
    -- A compact entry point into the new Statistics page, mirroring the
    -- Progress card above -- how effective the Companion's own
    -- recommendations have actually been, not a duplicate of Progress
    -- (which is about the PLAYER's own Mythic+ improvement).

    local statisticsCard = CreateHomeCard(homeScrollChild, "Dashboard.Statistics",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipStatistics"),
        onClick = function()
            Dashboard:Navigate("Statistics")
        end,
    }, progressCard)

    frame.StatisticsCard = statisticsCard

    -- Inventory Card ---------------------------------------------------------

    local inventoryCard = CreateHomeCard(homeScrollChild, "Dashboard.Inventory",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT_WITH_BAR,
        showBar = true,
        tooltip = AC.L:Get("Dashboard.TooltipInventory"),
        onClick = function()
            Dashboard:Navigate("Inventory")
        end,
    }, statisticsCard)

    inventoryCard:SetStatus("Normal", "")

    frame.InventoryCard = inventoryCard

    -- Accomplishments Card ---------------------------------------------------------

    local accomplishmentsCard = CreateHomeCard(homeScrollChild, "Dashboard.Accomplishments",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipAccomplishments"),
        onClick = function()
            Dashboard:Navigate("Accomplishments")
        end,
    }, inventoryCard)

    frame.AccomplishmentsCard = accomplishmentsCard

    -- Journey Card -----------------------------------------------------------
    --
    -- A compact entry point into the new Character Journey page -- the
    -- curated timeline this card summarizes, not a duplicate of
    -- Accomplishments (which lists everything classified; Journey tells
    -- the chronological story built from it plus personal milestones).

    local journeyCard = CreateHomeCard(homeScrollChild, "Dashboard.Journey",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT,
        tooltip = AC.L:Get("Dashboard.TooltipJourney"),
        onClick = function()
            Dashboard:Navigate("Journey")
        end,
    }, accomplishmentsCard)

    frame.JourneyCard = journeyCard

    -- Storage Card ---------------------------------------------------------

    local storageCard = CreateHomeCard(homeScrollChild, "Dashboard.Storage",
    {
        width = Layout.CARD_WIDTH,
        height = Layout.CARD_HEIGHT_WITH_BAR,
        showBar = true,
        tooltip = AC.L:Get("Dashboard.TooltipStorage"),
        onClick = function()
            Dashboard:Navigate("Storage")
        end,
    }, journeyCard)

    frame.StorageCard = storageCard

    -- Footer ---------------------------------------------------------------
    --
    -- Player-facing only: version number. No implementation details.

    local footer = homeScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("TOP", storageCard, "BOTTOM", 0, -20)
    footer:SetText(AC.L:Format("Dashboard.Version", AC.Version or "0.0.1"))
    footer:SetWidth(Layout.CARD_WIDTH)
    footer:SetJustifyH("CENTER")

    frame.Footer = footer

    -----------------------------------------------------------------------
    -- Profile Page
    -----------------------------------------------------------------------

    local profilePage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Profile"))
    self:BuildDataPageContent(profilePage, Schemas.PROFILE_SECTIONS, Schemas.PROFILE_FUTURE_FEATURES)

    frame.Pages.Profile = profilePage

    -----------------------------------------------------------------------
    -- Inventory Page
    -----------------------------------------------------------------------

    local inventoryPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Inventory"))
    self:BuildDataPageContent(inventoryPage, Schemas.INVENTORY_SECTIONS, Schemas.INVENTORY_FUTURE_FEATURES)

    frame.Pages.Inventory = inventoryPage

    -----------------------------------------------------------------------
    -- Accomplishments Page
    --
    -- Fully dynamic (no static schema) -- one section per curated
    -- category, same reasoning as MythicPlus/Storage/Weekly/Progress/
    -- Statistics above. See Pages/Accomplishments.lua.
    -----------------------------------------------------------------------

    local accomplishmentsPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Accomplishments"))

    frame.Pages.Accomplishments = accomplishmentsPage

    -----------------------------------------------------------------------
    -- MythicPlus Page
    --
    -- The flagship page -- no static schema to build here. Its content
    -- (owned keystone state, run history, season stats, recommendations,
    -- insights) is entirely dynamic, so Pages/MythicPlus.lua's
    -- UpdateMythicPlusPage builds it fresh every time ShowPage("MythicPlus")
    -- runs, the same way the Recommendations page already works. Nothing
    -- to build at Create() time beyond the page shell itself.
    -----------------------------------------------------------------------

    local mythicPlusPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.MythicPlus"))

    frame.Pages.MythicPlus = mythicPlusPage

    -----------------------------------------------------------------------
    -- Storage Page
    --
    -- Fully dynamic, same reasoning as MythicPlus above -- bank
    -- accessibility, the active profile, and restock analysis all change
    -- from one page view to the next.
    -----------------------------------------------------------------------

    local storagePage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Storage"))

    frame.Pages.Storage = storagePage

    -----------------------------------------------------------------------
    -- Weekly Page
    --
    -- Small and fully dynamic (vault slot progress + Insights/
    -- Recommendations), same reasoning as MythicPlus/Storage above.
    -----------------------------------------------------------------------

    local weeklyPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Weekly"))

    frame.Pages.Weekly = weeklyPage

    -----------------------------------------------------------------------
    -- Recommendations Page
    --
    -- A dynamic list rather than fixed fields -- rows are built and
    -- pooled by UpdateRecommendationsPage the first time it runs, which
    -- also decides width and calls ApplyPageScrolling itself on every
    -- refresh since this page's content size is not known until then.
    -----------------------------------------------------------------------

    local recommendationsPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Recommendations"))
    recommendationsPage.Rows = {}

    frame.Pages.Recommendations = recommendationsPage

    -----------------------------------------------------------------------
    -- Progress Page (Progress Dashboard)
    --
    -- Fully dynamic, same reasoning as MythicPlus/Storage/Weekly above --
    -- every section (window statistics, trends, recent milestones)
    -- changes from one page view to the next.
    -----------------------------------------------------------------------

    local progressPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Progress"))

    frame.Pages.Progress = progressPage

    -----------------------------------------------------------------------
    -- Statistics Page (Companion Intelligence vNext)
    --
    -- Fully dynamic, same reasoning as Progress above -- every number is
    -- aggregated fresh from RecommendationHistoryService on each view.
    -----------------------------------------------------------------------

    local statisticsPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Statistics"))

    frame.Pages.Statistics = statisticsPage

    -----------------------------------------------------------------------
    -- Journey Page
    --
    -- Fully dynamic (no static schema) -- a curated, chronological
    -- timeline built fresh from AccomplishmentsModule + MilestoneService
    -- on each view, same reasoning as Accomplishments above. See
    -- Pages/Journey.lua.
    -----------------------------------------------------------------------

    local journeyPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Journey"))

    frame.Pages.Journey = journeyPage

    -----------------------------------------------------------------------
    -- Recommendation Details Page (Navigation UX Sprint)
    --
    -- Replaces the standalone RecommendationInspector popup -- the exact
    -- same shared page shell every other page above uses, not a special
    -- case. Fully dynamic (no static schema), same reasoning as
    -- Journey/Accomplishments above. See Pages/RecommendationDetails.lua.
    -- Reads Dashboard.CurrentRecommendationDetails (Navigation.lua's
    -- ShowRecommendationDetails), the one piece of state this page needs
    -- that no other page does, since a Recommendation has no stable
    -- persisted identity to look up by page name alone.
    -----------------------------------------------------------------------

    local recommendationDetailsPage = self:CreateDataPage(contentArea, AC.L:Get("Inspector.Title"))

    frame.Pages.RecommendationDetails = recommendationDetailsPage

    -----------------------------------------------------------------------
    -- Refresh Function
    -----------------------------------------------------------------------

    function frame:Refresh()

        Dashboard:UpdateContent(frame)

    end

    return frame

end

-------------------------------------------------------------------------------
-- Update Content (Home page data)
-------------------------------------------------------------------------------

function Dashboard:UpdateContent(frame)

    -- Home has no LastUpdatedText field (it isn't a CreateDataPage page),
    -- so this just refreshes the engines -- UpdateLastUpdatedText's own
    -- nil-guard makes passing no page a safe, explicit no-op rather than
    -- referencing an undefined page local (a leftover bug from before the
    -- Dashboard Refactor, harmless since it always resolved to the exact
    -- same no-op, but worth not carrying forward).
    self:RefreshEngines(nil)

    -----------------------------------------------------------------------
    -- Greeting
    -----------------------------------------------------------------------

    frame.GreetingText:SetText(AC.L:Get(GetGreetingKey()))

    -----------------------------------------------------------------------
    -- Recommendation Card ("Highest Priority")
    --
    -- Stars + title + description are the same one-item preview of
    -- RecommendationEngine's top result the Recommendations page itself
    -- renders. Detail Sections now separate Reason / Expected Benefit /
    -- Estimated Time / Supporting Evidence into their own labeled blocks
    -- instead of one merged, undifferentiated line.
    -----------------------------------------------------------------------

    -- Companion Intelligence vNext -- filtered through
    -- FilterDismissedRecommendations (Sections.lua) rather than reading
    -- GetHighestPriority() directly, so a recommendation the player just
    -- dismissed doesn't reappear here as "the" highest priority again
    -- until its underlying situation genuinely changes.
    local recommendation = nil

    if AC.RecommendationEngine then

        local filteredRecommendations = self:FilterDismissedRecommendations(AC.RecommendationEngine:GetRecommendations())
        recommendation = filteredRecommendations[1]

    end

    if recommendation then

        frame.RecommendationCard:SetPrimaryValue(recommendation.title)
        frame.RecommendationCard:SetSecondaryText(recommendation.description)

        local sections = {}

        -- Priority + Confidence ONLY (Home Dashboard Evolution, Highest
        -- Priority card pass). Reason/Expected Benefit/Estimated Time/
        -- Supporting Evidence removed from this card -- not deleted, they
        -- already live in full via the Why? button/RecommendationInspector
        -- (LayoutSupportingEvidence etc.), so nothing is lost, only moved
        -- behind a deliberate click. This is the exact same progressive-
        -- disclosure resolution the Recommendations page's own list rows
        -- already went through (Rows.lua's BuildRecommendationRow --
        -- Title/Description/one compact Meta line, everything else
        -- Inspector-only) -- previously flagged in
        -- docs/DEVELOPMENT_BACKLOG.md as "a real candidate for the same
        -- audit in a future pass" and left alone at the time since that
        -- pass was scoped to the Recommendations page only. This is that
        -- future pass. A card meant to be read in seconds shouldn't be
        -- able to grow to six stacked sections -- Priority and Confidence
        -- are the two facts worth an at-a-glance read without a click;
        -- everything else is reasoning, which belongs on demand.
        local priorityLabel, priorityColor = Format.GetPriorityLabel(recommendation.priority)
        table.insert(sections, { label = AC.L:Get("Dashboard.SectionPriority"), text = priorityLabel, emphasized = true, color = priorityColor })

        if recommendation.confidence then
            table.insert(sections, { label = AC.L:Get("Dashboard.SectionConfidence"), text = AC.L:Get("Dashboard.Confidence" .. recommendation.confidence), emphasized = true, color = Format.GetConfidenceColor(recommendation.confidence) })
        end

        frame.RecommendationCard:SetDetailSections(sections)

        frame.RecommendationCard.CurrentRecommendation = recommendation
        frame.RecommendationCard.WhyButton:Show()
        frame.RecommendationCard.DismissButton:Show()

    else

        frame.RecommendationCard:SetPrimaryValue(AC.L:Get("Dashboard.CaughtUp"))
        frame.RecommendationCard:SetSecondaryText("")
        frame.RecommendationCard:SetDetailSections({})

        frame.RecommendationCard.CurrentRecommendation = nil
        frame.RecommendationCard.WhyButton:Hide()
        frame.RecommendationCard.DismissButton:Hide()

    end

    -----------------------------------------------------------------------
    -- Profile Card
    --
    -- PrimaryValue/SecondaryText still carry identity (name, then level/
    -- spec/class). Detail Sections now separate the one "important
    -- number" (equipped item level, emphasized -- bigger, brighter font)
    -- from the supporting facts (guild, current zone) instead of merging
    -- everything into one dim line.
    -----------------------------------------------------------------------

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local profile = characterModule and characterModule:GetProfile()

    if profile and profile.name and profile.name ~= "" then

        local level = profile.level or 0
        local specName = profile.specName
        local className = profile.class or AC.L:Get("Common.Unknown")

        local levelLine

        if specName and specName ~= "" then
            levelLine = AC.L:Format("Dashboard.LevelSpecClassFormat", level, specName, className)
        else
            levelLine = AC.L:Format("Dashboard.LevelClassFormat", level, className)
        end

        frame.ProfileCard:SetPrimaryValue(profile.name)
        frame.ProfileCard:SetSecondaryText(levelLine)
        frame.ProfileCard:SetClassIcon(profile.classFile)

        local sections = {}

        if profile.equippedItemLevel and profile.equippedItemLevel > 0 then
            table.insert(sections, { label = AC.L:Get("Dashboard.SectionItemLevel"), text = AC.Presentation.FormatItemLevel(profile.equippedItemLevel), emphasized = true })
        end

        local factLines = {}

        if profile.guildName and profile.guildName ~= "" then
            table.insert(factLines, profile.guildName)
        end

        if profile.zone and profile.zone ~= "" then

            if profile.subZone and profile.subZone ~= "" and profile.subZone ~= profile.zone then
                table.insert(factLines, AC.L:Format("Dashboard.LocationFormat", profile.zone, profile.subZone))
            else
                table.insert(factLines, profile.zone)
            end

        end

        if #factLines > 0 then
            table.insert(sections, { text = table.concat(factLines, "\n") })
        end

        -- This Session (Home Dashboard Evolution, Profile card pass) --
        -- the "trend that naturally belongs here" the Product Vision
        -- asked for: CharacterModule already computes this via
        -- GetSessionInfo() (the same getter the Profile page's own
        -- session fields already read) -- no new system, just a card that
        -- wasn't showing a fact its own module already tracked. Omitted
        -- entirely when nothing changed this session, never a fabricated
        -- "no change" line.
        local sessionInfo = characterModule.GetSessionInfo and characterModule:GetSessionInfo()

        if sessionInfo then

            local sessionLines = {}

            if sessionInfo.levelsGained and sessionInfo.levelsGained > 0 then
                table.insert(sessionLines, AC.L:Format("Dashboard.LevelsGainedSessionFormat", profile.level))
            end

            if sessionInfo.itemLevelGained and sessionInfo.itemLevelGained ~= 0 then
                table.insert(sessionLines, AC.L:Format("Dashboard.ItemLevelGainedSessionFormat", AC.Presentation.FormatSignedNumber(sessionInfo.itemLevelGained, 1)))
            end

            if #sessionLines > 0 then
                table.insert(sections, { label = AC.L:Get("Dashboard.SectionSessionChange"), text = table.concat(sessionLines, "\n"), color = "success" })
            end

        end

        frame.ProfileCard:SetDetailSections(sections)

        -- Rested status: the Status corner, otherwise unused on this card.
        if profile.restedXP and profile.restedXP > 0 then
            frame.ProfileCard:SetStatus("Normal", AC.L:Get("Dashboard.StatusRested"))
        else
            frame.ProfileCard:SetStatus("Normal", "")
        end

    else
        frame.ProfileCard:SetPrimaryValue(AC.L:Get("Dashboard.NoCharacterData"))
        frame.ProfileCard:SetSecondaryText("")
        frame.ProfileCard:SetDetailSections({})
        frame.ProfileCard:SetStatus("Normal", "")
        frame.ProfileCard:SetIcon(nil)
    end

    -----------------------------------------------------------------------
    -- Inventory Card
    -----------------------------------------------------------------------

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local bagSummary = inventoryModule and inventoryModule.GetBagSummary and inventoryModule:GetBagSummary()

    if bagSummary then

        local usedSlots = bagSummary.usedSlots or 0
        local totalSlots = bagSummary.totalSlots or 0
        local percentage = bagSummary.percentage or 0

        local status = "Normal"
        local statusText = AC.L:Get("Dashboard.StatusHealthy")
        local barR, barG, barB = unpack(AC.Presentation.GetSemanticColor("success"))

        if percentage >= 90 then
            status = "Important"
            statusText = AC.L:Get("Dashboard.StatusFull")
            barR, barG, barB = unpack(AC.Presentation.GetSemanticColor("critical"))
        elseif percentage >= 75 then
            status = "Warning"
            statusText = AC.L:Get("Dashboard.StatusFilling")
            barR, barG, barB = unpack(AC.Presentation.GetSemanticColor("warning"))
        end

        local freeSlots = totalSlots - usedSlots

        frame.InventoryCard:SetPrimaryValue(AC.L:Format("Dashboard.SlotsUsedFormat", usedSlots, totalSlots))
        frame.InventoryCard:SetSecondaryText(AC.L:Format("Dashboard.PercentFullFreeFormat", percentage, freeSlots))
        frame.InventoryCard:SetStatus(status, statusText)
        frame.InventoryCard:SetBarValue(percentage, barR, barG, barB)

        local detailLines = {}

        local equipmentSummary = inventoryModule.GetEquipmentSummary and inventoryModule:GetEquipmentSummary()

        if equipmentSummary and equipmentSummary.averageItemLevel and equipmentSummary.averageItemLevel > 0 then
            table.insert(detailLines, AC.L:Format("Dashboard.EquippedItemLevelFormat", AC.Presentation.FormatItemLevel(equipmentSummary.averageItemLevel)))
        end

        -- Storage Status -- read directly, the same cross-module pattern
        -- already used elsewhere on Home.
        local storageModuleForInventory = AC.Core and AC.Core:GetModule("Storage")

        if storageModuleForInventory and storageModuleForInventory.IsModuleEnabled and storageModuleForInventory:IsModuleEnabled() then

            local storageProfileForInventory = storageModuleForInventory:GetActiveProfile()

            if storageProfileForInventory then

                local storagePreparation = storageModuleForInventory:GetPreparationStatus(storageProfileForInventory.id)

                if storagePreparation.ready then
                    table.insert(detailLines, AC.L:Get("Dashboard.StorageStatusReady"))
                else
                    table.insert(detailLines, AC.L:Get("Dashboard.StorageStatusNeedsRestock"))
                end

            end

        end

        frame.InventoryCard:SetDetailText(table.concat(detailLines, "\n"))

    else
        frame.InventoryCard:SetPrimaryValue(AC.L:Get("Dashboard.InventoryUnavailable"))
        frame.InventoryCard:SetSecondaryText("")
        frame.InventoryCard:SetDetailText("")
        frame.InventoryCard:SetStatus("Normal", "")
        frame.InventoryCard:SetBarValue(0)
    end

    -----------------------------------------------------------------------
    -- Accomplishments Card
    -----------------------------------------------------------------------

    local accomplishmentsModuleForCard = AC.Core and AC.Core:GetModule("Accomplishments")

    if accomplishmentsModuleForCard then

        local points = Format.FormatNumberWithCommas(accomplishmentsModuleForCard:GetPoints())
        frame.AccomplishmentsCard:SetPrimaryValue(AC.L:Format("Dashboard.AccomplishmentPointsFormat", points))
        frame.AccomplishmentsCard:SetSecondaryText("")

        local recent = accomplishmentsModuleForCard.GetMostRecentAccomplishment and accomplishmentsModuleForCard:GetMostRecentAccomplishment()

        if recent and recent.name and recent.name ~= "" then
            frame.AccomplishmentsCard:SetDetailText(AC.L:Format("Dashboard.RecentAccomplishmentFormat", recent.name))
            frame.AccomplishmentsCard:SetIcon(recent.icon)
        else
            frame.AccomplishmentsCard:SetDetailText("")
            frame.AccomplishmentsCard:SetIcon(nil)
        end

    else
        frame.AccomplishmentsCard:SetPrimaryValue(AC.L:Get("Dashboard.AccomplishmentsUnavailable"))
        frame.AccomplishmentsCard:SetSecondaryText("")
        frame.AccomplishmentsCard:SetDetailText("")
        frame.AccomplishmentsCard:SetIcon(nil)
    end

    -----------------------------------------------------------------------
    -- Journey Card
    -----------------------------------------------------------------------

    local journeySummary = self.GetJourneySummary and self:GetJourneySummary()

    if journeySummary then

        frame.JourneyCard:SetPrimaryValue(AC.L:Format("Dashboard.JourneyEntryCountFormat", journeySummary.count))
        frame.JourneyCard:SetSecondaryText("")

        if journeySummary.mostRecent then
            frame.JourneyCard:SetDetailText(AC.L:Format("Dashboard.RecentJourneyEntryFormat", journeySummary.mostRecent.title))
        else
            frame.JourneyCard:SetDetailText("")
        end

    else
        frame.JourneyCard:SetPrimaryValue(AC.L:Get("Dashboard.JourneyUnavailable"))
        frame.JourneyCard:SetSecondaryText("")
        frame.JourneyCard:SetDetailText("")
    end

    -----------------------------------------------------------------------
    -- Storage Card
    --
    -- "Items Missing" and "Shopping List" are two genuinely different,
    -- real numbers from StorageModule's own analysis, not one count
    -- shown twice: withdrawals are items already owned (in the bank,
    -- just need moving to bags), missing are items not owned anywhere
    -- (need to be acquired). Execute Available mirrors the exact
    -- readiness check the Storage page's own Execute button uses.
    -----------------------------------------------------------------------

    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if storageModule and storageModule.IsModuleEnabled and storageModule:IsModuleEnabled() then

        local storageProfile = storageModule:GetActiveProfile()

        if storageProfile then

            local analysis = storageModule:AnalyzeProfile(storageProfile.id)
            local bankSummary = storageModule:GetBankSummary()
            local ready = #analysis.missing == 0 and #analysis.withdrawals == 0

            frame.StorageCard:SetPrimaryValue(AC.L:Get(storageProfile.label))

            if ready then
                frame.StorageCard:SetSecondaryText(AC.L:Get("Dashboard.StorageReady"))
                frame.StorageCard:SetStatus("Normal", AC.L:Get("Dashboard.StatusHealthy"))
                frame.StorageCard:SetBarValue(analysis.readinessPercent or 100, unpack(AC.Presentation.GetSemanticColor("success")))
            else
                frame.StorageCard:SetSecondaryText(AC.L:Format("Dashboard.StorageMissingFormat", #analysis.missing + #analysis.withdrawals))
                frame.StorageCard:SetStatus("Warning", "")
                frame.StorageCard:SetBarValue(analysis.readinessPercent or 0, unpack(AC.Presentation.GetSemanticColor("warning")))
            end

            local sections = {}

            if #analysis.withdrawals > 0 then
                table.insert(sections, { label = AC.L:Get("Dashboard.SectionItemsMissing"), text = AC.L:Format("Dashboard.StorageWithdrawCountFormat", #analysis.withdrawals) })
            end

            if #analysis.missing > 0 then
                table.insert(sections, { label = AC.L:Get("Dashboard.SectionShoppingList"), text = AC.L:Format("Dashboard.StorageShoppingCountFormat", #analysis.missing) })
            end

            if bankSummary.accessible and (#analysis.withdrawals > 0 or #analysis.deposits > 0) then
                table.insert(sections, { label = AC.L:Get("Dashboard.SectionExecute"), text = AC.L:Get("Dashboard.StorageExecuteAvailable") })
            end

            frame.StorageCard:SetDetailSections(sections)

        else
            frame.StorageCard:SetPrimaryValue(AC.L:Get("Dashboard.StorageNoProfile"))
            frame.StorageCard:SetSecondaryText("")
            frame.StorageCard:SetStatus("Normal", "")
            frame.StorageCard:SetBarValue(0)
            frame.StorageCard:SetDetailSections({})
        end

    else
        frame.StorageCard:SetPrimaryValue(AC.L:Get("Dashboard.StorageUnavailable"))
        frame.StorageCard:SetSecondaryText("")
        frame.StorageCard:SetStatus("Normal", "")
        frame.StorageCard:SetBarValue(0)
        frame.StorageCard:SetDetailSections({})
    end

    -----------------------------------------------------------------------
    -- Vault Progress (read once here, shared by the Mythic+ Card's
    -- cross-module context below and the Vault Card further down -- the
    -- same cross-module read-only pattern already used everywhere on
    -- Home, just no longer looked up twice).
    -----------------------------------------------------------------------

    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
    local vaultProgress = weeklyModule and weeklyModule.GetVaultProgress and weeklyModule:GetVaultProgress()

    -----------------------------------------------------------------------
    -- Mythic+ Card
    --
    -- Now a real quick-status dashboard: current key/dungeon/rating (as
    -- before) plus Vault Progress (cross-read from Weekly) and, when
    -- Storage's "MythicPlus" preparation preset isn't ready, exactly WHY
    -- -- the real missing item categories Storage already computed, plus
    -- a real repair check read from Inventory's own public getter.
    -----------------------------------------------------------------------

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local mpProfile = mythicPlusModule and mythicPlusModule:GetProfile()

    if mpProfile then

        local bestLevel = (mythicPlusModule.GetBestOverallLevel and mythicPlusModule:GetBestOverallLevel()) or 0
        local status = "Normal"
        local statusText = ""

        if bestLevel > 0 then
            statusText = AC.L:Format("Dashboard.MythicPlusBestFormat", bestLevel)
        end

        local primaryText

        if mpProfile.activeRun then
            primaryText = AC.L:Format("Dashboard.MythicPlusActiveRunFormat", mpProfile.activeRun.keystoneLevel or 0)
            status = "Important"
            statusText = AC.L:Get("Dashboard.StatusActive")
        elseif mpProfile.hasKeystone then

            local dungeonLabel = mpProfile.currentDungeonName

            if not dungeonLabel or dungeonLabel == "" then
                dungeonLabel = "#" .. tostring(mpProfile.currentDungeonID or 0)
            end

            primaryText = AC.L:Format("Dashboard.MythicPlusKeystoneFormat", dungeonLabel, mpProfile.currentLevel or 0)

        else
            primaryText = AC.L:Get("Dashboard.MythicPlusNoKeystone")
        end

        frame.MythicPlusCard:SetPrimaryValue(primaryText)
        frame.MythicPlusCard:SetSecondaryText(AC.L:Format("Dashboard.MythicPlusRatingFormat", AC.Presentation.FormatRating(mpProfile.rating)))
        frame.MythicPlusCard:SetStatus(status, statusText)

        local infoLines = {}

        -- Blizzard's GetCurrentSeason() returns -1 when no season is
        -- active -- omitted entirely rather than showing "Season -1".
        if mpProfile.currentSeason and mpProfile.currentSeason >= 0 then
            table.insert(infoLines, AC.L:Format("Dashboard.MythicPlusSeasonFormat", mpProfile.currentSeason))
        end

        if vaultProgress and vaultProgress.totalSlots and vaultProgress.totalSlots > 0 then
            table.insert(infoLines, AC.L:Format("Dashboard.VaultSlotsFormat", vaultProgress.unlockedSlots or 0, vaultProgress.totalSlots))
        end

        local sections = {}

        if #infoLines > 0 then
            table.insert(sections, { text = table.concat(infoLines, "\n") })
        end

        -- Preparation: readiness for Mythic+ specifically, read from
        -- Storage's "MythicPlus" preset -- the same cross-module
        -- read-only fact lookup RecommendationEngine's "Complete Your
        -- Keystone" already performs. Absent entirely (bar at 0, no
        -- override to the status line above) if Storage isn't available.
        local storageModuleForMP = AC.Core and AC.Core:GetModule("Storage")
        local mpPreparation = storageModuleForMP and storageModuleForMP.GetPreparationStatus and storageModuleForMP:GetPreparationStatus("MythicPlus")

        if mpPreparation then

            frame.MythicPlusCard:SetBarValue(mpPreparation.readinessPercent or 0, unpack(AC.Presentation.GetSemanticColor("success")))

            if not mpPreparation.ready then

                if status == "Normal" then
                    frame.MythicPlusCard:SetStatus("Warning", AC.L:Get("Dashboard.PreparationNotReady"))
                end

                local missingLines = {}

                for _, missing in ipairs(mpPreparation.missing) do
                    table.insert(missingLines, Format.BULLET .. " " .. AC.L:Get(missing.label))
                end

                -- Equipment Health feature -- reads GetEquipmentHealthSummary
                -- directly (GetImportantItemsSummary is hearthstone-only now).
                local inventoryModuleForMP = AC.Core and AC.Core:GetModule("Inventory")
                local equipmentHealthForMP = inventoryModuleForMP and inventoryModuleForMP.GetEquipmentHealthSummary and inventoryModuleForMP:GetEquipmentHealthSummary()

                if equipmentHealthForMP and equipmentHealthForMP.needsRepair then
                    local repairLineKey = (equipmentHealthForMP.brokenItems or 0) > 0 and "Inventory.EquipmentBroken" or "Inventory.RepairsNeeded"
                    table.insert(missingLines, Format.BULLET .. " " .. AC.L:Get(repairLineKey))
                end

                if #missingLines > 0 then
                    table.insert(sections, { label = AC.L:Get("Dashboard.SectionMissing"), text = table.concat(missingLines, "\n") })
                end

            end

        else
            frame.MythicPlusCard:SetBarValue(0)
        end

        frame.MythicPlusCard:SetDetailSections(sections)

    else
        frame.MythicPlusCard:SetPrimaryValue(AC.L:Get("Dashboard.MythicPlusUnavailable"))
        frame.MythicPlusCard:SetSecondaryText("")
        frame.MythicPlusCard:SetDetailSections({})
        frame.MythicPlusCard:SetStatus("Normal", "")
        frame.MythicPlusCard:SetBarValue(0)
    end

    -----------------------------------------------------------------------
    -- Vault Card ("Vault Progress")
    --
    -- Reads WeeklyModule directly (same pattern as every other Home
    -- card). No fabricated "X / 3" when Weekly couldn't read
    -- C_WeeklyRewards this session -- totalSlots stays 0 and the
    -- unavailable message shows. Highest Reward is the highest REAL item
    -- level among slots already unlocked -- `slot.rewardItemLevel`,
    -- resolved by WeeklyModule via the same reward-hyperlink lookup
    -- Blizzard's own Great Vault UI uses (Blizzard API Verification pass
    -- -- `slot.level` is the Mythic+ KEY level, e.g. "15" for a +15, and
    -- was wrongly displayed here as an item level before this pass;
    -- confirmed against Blizzard's own Blizzard_WeeklyRewards.lua that
    -- these are two different facts). Omitted entirely, not shown as a
    -- guessed number, on any refresh where that resolution didn't
    -- succeed yet (e.g. Blizzard's own item cache hasn't populated this
    -- session) -- Remaining is the real count of slots not yet unlocked.
    -----------------------------------------------------------------------

    if vaultProgress and vaultProgress.totalSlots and vaultProgress.totalSlots > 0 then

        frame.VaultCard:SetPrimaryValue(AC.L:Format("Dashboard.VaultSlotsFormat", vaultProgress.unlockedSlots or 0, vaultProgress.totalSlots))
        frame.VaultCard:SetBarValue((vaultProgress.unlockedSlots or 0) / vaultProgress.totalSlots * 100, unpack(AC.Presentation.GetSemanticColor("success")))

        if vaultProgress.hasAvailableRewards then
            frame.VaultCard:SetSecondaryText(AC.L:Get("Dashboard.VaultRewardReady"))
        else
            frame.VaultCard:SetSecondaryText("")
        end

        local highestRewardItemLevel = nil

        for _, slot in ipairs(vaultProgress.slots or {}) do

            if slot.unlocked and slot.rewardItemLevel and (not highestRewardItemLevel or slot.rewardItemLevel > highestRewardItemLevel) then
                highestRewardItemLevel = slot.rewardItemLevel
            end

        end

        local sections = {}

        if highestRewardItemLevel then
            table.insert(sections, { label = AC.L:Get("Dashboard.SectionHighestReward"), text = AC.L:Format("Dashboard.HighestRewardFormat", highestRewardItemLevel), emphasized = true })
        end

        local remaining = vaultProgress.totalSlots - (vaultProgress.unlockedSlots or 0)

        if remaining > 0 then
            table.insert(sections, { label = AC.L:Get("Dashboard.SectionRemaining"), text = AC.L:Format("Dashboard.VaultRemainingFormat", remaining) })
        end

        frame.VaultCard:SetDetailSections(sections)

    else
        frame.VaultCard:SetPrimaryValue(AC.L:Get("Dashboard.VaultUnavailable"))
        frame.VaultCard:SetSecondaryText("")
        frame.VaultCard:SetDetailSections({})
        frame.VaultCard:SetBarValue(0)
    end

    -----------------------------------------------------------------------
    -- Recent Activity Card
    --
    -- A real chronological feed (GetRecentActivityFeed above) rather
    -- than only the single most recent Mythic+ run -- the most recent
    -- entry gets the card's headline treatment (PrimaryValue), the rest
    -- render as a compact list below it.
    -----------------------------------------------------------------------

    local feed = GetRecentActivityFeed(4)
    local feedLines = {}

    for _, record in ipairs(feed) do

        local line = BuildActivityFeedLine(record)

        if line then

            local icon = record.Success and Format.CHECK_SUCCESS or Format.CHECK_FAILURE
            table.insert(feedLines, icon .. " " .. line)

        end

    end

    ApplyLinesToCard(frame.RecentActivityCard, feedLines, "Dashboard.NoRecentActivity")

    -- The card's own onClick (above) reads this every click -- routes to
    -- whichever page the newest feed entry is actually about, rather
    -- than always assuming MythicPlus. `feed[1].Module` is
    -- ActivityHistoryService's STORED tag, still literally "Achievements"
    -- (see AccomplishmentsModule.lua's own header) -- only the resulting
    -- PAGE NAME below is the renamed "Accomplishments".
    frame.RecentActivityCard.TargetPage = (feed[1] and feed[1].Module == "Achievements") and "Accomplishments" or "MythicPlus"

    -----------------------------------------------------------------------
    -- Progress Card ("How am I improving?")
    --
    -- A season-level trend summary -- reads the same
    -- ProgressSummaryService the Progress page itself uses (Progress
    -- Dashboard); this card computes nothing, it only renders the top
    -- line of what that page shows in full.
    -----------------------------------------------------------------------

    if mpProfile then

        frame.ProgressCard:SetPrimaryValue(AC.L:Format("Dashboard.ProgressRatingFormat", AC.Presentation.FormatRating(mpProfile.rating)))

        local progressTrends = AC.ProgressSummaryService and AC.ProgressSummaryService:GetTrends()
        local timedRateTrend = progressTrends and progressTrends.last7Days and progressTrends.last7Days.timedRate

        if timedRateTrend and timedRateTrend ~= "Unknown" then
            frame.ProgressCard:SetSecondaryText(Format.GetTrendArrow(timedRateTrend) .. " " .. AC.L:Get("Progress.TrendDirection" .. timedRateTrend))
        else
            frame.ProgressCard:SetSecondaryText("")
        end

        local progressSummary = AC.ProgressSummaryService and AC.ProgressSummaryService:GetSummary()
        local seasonStatsForCard = progressSummary and progressSummary.season

        if seasonStatsForCard and seasonStatsForCard.runsCompleted and seasonStatsForCard.runsCompleted > 0 then
            frame.ProgressCard:SetDetailSections({ { text = AC.L:Format("Dashboard.ProgressSeasonSummaryFormat", seasonStatsForCard.highestCompletedLevel or 0, seasonStatsForCard.successRate or 0) } })
        else
            frame.ProgressCard:SetDetailSections({})
        end

    else
        frame.ProgressCard:SetPrimaryValue(AC.L:Get("Dashboard.MythicPlusUnavailable"))
        frame.ProgressCard:SetSecondaryText("")
        frame.ProgressCard:SetDetailSections({})
    end

    -----------------------------------------------------------------------
    -- Statistics Card (Companion Intelligence vNext)
    --
    -- A compact rollup of RecommendationHistoryService's own already-real
    -- counters -- this card computes nothing, same discipline as the
    -- Progress card above.
    -----------------------------------------------------------------------

    if AC.RecommendationHistoryService then

        local totalGenerated, totalCompleted = 0, 0

        for _, record in pairs(AC.RecommendationHistoryService:GetAllHistory()) do
            totalGenerated = totalGenerated + (record.timesShown or 0)
            totalCompleted = totalCompleted + (record.timesCompleted or 0)
        end

        if totalGenerated > 0 then

            local completionRate = (totalCompleted / totalGenerated) * 100

            frame.StatisticsCard:SetPrimaryValue(AC.L:Format("Dashboard.StatisticsGeneratedFormat", totalGenerated))
            frame.StatisticsCard:SetSecondaryText(AC.L:Format("Statistics.HeroCaptionFormat", AC.Presentation.FormatNumber(completionRate)))

        else

            frame.StatisticsCard:SetPrimaryValue(AC.L:Get("Dashboard.StatisticsNoDataYet"))
            frame.StatisticsCard:SetSecondaryText("")

        end

        frame.StatisticsCard:SetDetailSections({})

    else
        frame.StatisticsCard:SetPrimaryValue(AC.L:Get("Dashboard.StatisticsNoDataYet"))
        frame.StatisticsCard:SetSecondaryText("")
        frame.StatisticsCard:SetDetailSections({})
    end

    -----------------------------------------------------------------------
    -- Today's Briefing Card (Companion Intelligence V4)
    --
    -- BriefingService already selected and ordered these lines; this
    -- card only renders them.
    -----------------------------------------------------------------------

    local briefingLines = {}

    if AC.BriefingService then

        for _, line in ipairs(AC.BriefingService:GetBriefing()) do
            table.insert(briefingLines, line.text)
        end

    end

    ApplyLinesToCard(frame.BriefingCard, briefingLines, "Dashboard.NoBriefing")

    -----------------------------------------------------------------------
    -- Today's Companion Notes Card (Companion Intelligence vNext)
    --
    -- SessionNotesService already selected and ordered these lines; this
    -- card only renders them, same as the Briefing card above.
    -----------------------------------------------------------------------

    local companionNotesLines = {}

    if AC.SessionNotesService then

        for _, line in ipairs(AC.SessionNotesService:GetNotes()) do
            table.insert(companionNotesLines, line)
        end

    end

    ApplyLinesToCard(frame.CompanionNotesCard, companionNotesLines, "Dashboard.NoCompanionNotes")

    -----------------------------------------------------------------------
    -- Recent Milestones Card (Companion Intelligence V4)
    -----------------------------------------------------------------------

    local milestoneLines = {}

    if AC.MilestoneService then

        for _, milestone in ipairs(AC.MilestoneService:GetRecent(3)) do
            table.insert(milestoneLines, AC.L:Get(milestone.titleKey))
        end

    end

    ApplyLinesToCard(frame.MilestonesCard, milestoneLines, "Dashboard.NoMilestones")

    -----------------------------------------------------------------------
    -- Recent Notifications Card (Companion Intelligence V4)
    -----------------------------------------------------------------------

    local notificationLines = {}

    if AC.NotificationService then

        for _, notification in ipairs(AC.NotificationService:GetHistory(3)) do
            table.insert(notificationLines, notification.title)
        end

    end

    ApplyLinesToCard(frame.NotificationsCard, notificationLines, "Dashboard.NoNotifications")

    -----------------------------------------------------------------------
    -- Scroll Height
    --
    -- Every card above may have grown past its MinHeight (SetDetailSections
    -- content, word-wrapped text, ...), so Home's true content height
    -- isn't knowable until all of them have been sized -- measured here as
    -- the real rendered span from the greeting to the footer, the same
    -- "measure what actually got built" discipline BuildDataPageContent
    -- uses for static pages, just computed after the fact since every
    -- card on Home is dynamic. See the Create() comment above the Home
    -- page's ScrollFrame for why this exists at all.
    -----------------------------------------------------------------------

    local homeContentHeight = (frame.GreetingText:GetTop() or 0) - (frame.Footer:GetBottom() or 0) + Layout.PAGE_BOTTOM_PADDING

    self:ApplyPageScrolling(frame.Pages.Home, homeContentHeight)

end

return Dashboard
