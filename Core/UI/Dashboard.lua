-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard
--
-- Primary presentation layer for Azeroth Companion. A single window with
-- in-window page navigation -- cards navigate to pages inside this frame
-- rather than opening separate popup windows. Home is the landing page;
-- every other feature gets its own Dashboard page over time.
--
-- The Dashboard never owns player data and never touches Blizzard APIs
-- directly. Every value shown here is read through a gameplay module's
-- public API -- it is purely presentation. All visible text goes through
-- AC.L:Get()/AC.L:Format() rather than literal strings, per the
-- Localization system -- nothing in here reads a locale table directly.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = {}

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local WINDOW_WIDTH = 420
local WINDOW_HEIGHT = 600

local CARD_WIDTH = 360
local RECOMMENDATION_HEIGHT = 130
local CARD_HEIGHT = 100

local SECTION_GAP = 14
local CONTENT_TOP_OFFSET = -50

local DATA_PAGE_CONTENT_WIDTH = 380

-------------------------------------------------------------------------------
-- Navigation
--
-- "Settings" is intentionally not part of this in-window page stack.
-- It already has a fully working, standalone SettingsWindow, and folding
-- it into a "page" here would mean either duplicating that functionality
-- or temporarily replacing it with a placeholder -- neither of which is
-- an improvement. The Settings button keeps opening the real window, as
-- it always has.
-------------------------------------------------------------------------------

local VALID_PAGES =
{
    Home = true,
    Recommendations = true,
    Profile = true,
    Inventory = true,
    Achievements = true,
}

-------------------------------------------------------------------------------
-- Data Page Schemas
--
-- Purely presentation layouts. Every "label"/"title" here is a
-- Localization key, not display text -- it is resolved through
-- AC.L:Get() when the rows are built in Create(), which runs after
-- LocalizationService has already loaded the active locale. The actual
-- field VALUES are resolved separately from a gameplay module's public
-- API in the matching GetXFieldValues() function below.
-------------------------------------------------------------------------------

local PROFILE_SECTIONS =
{
    {
        title = "Profile.SectionCharacter",
        fields =
        {
            { key = "name", label = "Profile.Name" },
            { key = "level", label = "Profile.Level" },
            { key = "race", label = "Profile.Race" },
            { key = "class", label = "Profile.Class" },
            { key = "spec", label = "Profile.Specialization" },
        },
    },
    {
        title = "Profile.SectionEquipment",
        fields =
        {
            { key = "equippedItemLevel", label = "Profile.EquippedItemLevel" },
            { key = "averageItemLevel", label = "Profile.AverageItemLevel" },
        },
    },
    {
        title = "Profile.SectionLocation",
        fields =
        {
            { key = "zone", label = "Profile.Zone" },
            { key = "subZone", label = "Profile.Subzone" },
            { key = "bindLocation", label = "Profile.BindLocation" },
        },
    },
    {
        title = "Profile.SectionCharacter",
        fields =
        {
            { key = "guild", label = "Profile.Guild" },
            { key = "faction", label = "Profile.Faction" },
            { key = "money", label = "Profile.Money" },
            { key = "playedTime", label = "Profile.PlayedTime" },
        },
    },
    {
        title = "Profile.SectionSession",
        fields =
        {
            { key = "loginTime", label = "Profile.LoginTime" },
            { key = "sessionDuration", label = "Profile.SessionDuration" },
            { key = "itemLevelGained", label = "Profile.ItemLevelGainedSession" },
            { key = "levelsGained", label = "Profile.LevelsGainedSession" },
        },
    },
}

local INVENTORY_SECTIONS =
{
    {
        title = "Inventory.SectionBagSummary",
        fields =
        {
            { key = "usedSlots", label = "Inventory.UsedSlots" },
            { key = "freeSlots", label = "Inventory.FreeSlots" },
            { key = "totalSlots", label = "Inventory.TotalSlots" },
            { key = "percentFull", label = "Inventory.PercentFull" },
        },
    },
    {
        title = "Inventory.SectionEquipment",
        fields =
        {
            { key = "equippedSlots", label = "Inventory.EquippedSlots" },
            { key = "emptyEquipmentSlots", label = "Inventory.EmptyEquipmentSlots" },
            { key = "averageItemLevel", label = "Inventory.AverageItemLevel" },
        },
    },
    {
        title = "Inventory.SectionImportantItems",
        fields =
        {
            { key = "hearthstone", label = "Inventory.Hearthstone" },
            { key = "repairStatus", label = "Inventory.RepairStatus" },
        },
    },
    {
        title = "Inventory.SectionSession",
        fields =
        {
            { key = "itemsAdded", label = "Inventory.ItemsAdded" },
            { key = "itemsRemoved", label = "Inventory.ItemsRemoved" },
            { key = "bagUsageChange", label = "Inventory.BagUsageChange" },
        },
    },
}

local ACHIEVEMENTS_SECTIONS =
{
    {
        title = "Achievements.SectionSummary",
        fields =
        {
            { key = "points", label = "Achievements.Points" },
            { key = "achievementsEarned", label = "Achievements.Earned" },
            { key = "recentAchievement", label = "Achievements.Recent" },
        },
    },
    {
        title = "Achievements.SectionSession",
        fields =
        {
            { key = "achievementsEarnedThisSession", label = "Achievements.EarnedThisSession" },
            { key = "pointsEarnedThisSession", label = "Achievements.PointsThisSession" },
        },
    },
}

local INVENTORY_FUTURE_FEATURES =
{
    "Dashboard.RecentLoot",
    "Dashboard.InterestingItems",
    "Dashboard.VendorSuggestions",
}

local ACHIEVEMENTS_FUTURE_FEATURES =
{
    "Dashboard.Milestones",
    "Dashboard.ExpansionProgress",
    "Dashboard.CategoryBreakdown",
    "Dashboard.RecentHistory",
}

-------------------------------------------------------------------------------
-- Formatting Helpers
-------------------------------------------------------------------------------

local function FormatNumberWithCommas(number)

    number = tonumber(number) or 0

    local formatted = string.format("%d", number)
    local separatorCount

    repeat
        formatted, separatorCount = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until separatorCount == 0

    return formatted

end

local function FormatDuration(totalSeconds)

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

local function FormatMoney(copper)

    copper = tonumber(copper) or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    return string.format("%sg %ds %dc", FormatNumberWithCommas(gold), silver, bronze)

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Dashboard:Initialize()

    self.CurrentPage = "Home"
    self.NavigationHistory = {}

    self.Frame = self:Create()

end

-------------------------------------------------------------------------------
-- Data Page
--
-- Shared infrastructure for every real, data-backed page: a title, a
-- Back button, and a scrollable content area. Used by Profile,
-- Inventory, Achievements, and Recommendations alike.
-------------------------------------------------------------------------------

function Dashboard:CreateDataPage(parent, pageTitle)

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()

    local backButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    backButton:SetSize(70, 22)
    backButton:SetPoint("TOPLEFT", 0, 0)
    backButton:SetText(AC.L:Get("Dashboard.Back"))

    backButton:SetScript("OnClick", function()
        Dashboard:GoBack()
    end)

    local titleText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -4)
    titleText:SetText(pageTitle or "")

    local scrollFrame = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(DATA_PAGE_CONTENT_WIDTH)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    page.BackButton = backButton
    page.Title = titleText
    page.ScrollFrame = scrollFrame
    page.ScrollChild = scrollChild

    return page

end

-------------------------------------------------------------------------------
-- Field Rows
--
-- Builds the label/value rows described by a section schema (see
-- PROFILE_SECTIONS / INVENTORY_SECTIONS / ACHIEVEMENTS_SECTIONS above),
-- resolving each section title and field label through AC.L:Get().
-- Returns a lookup of key -> value FontString, plus the Y offset content
-- ended at (so callers can append more, e.g. a Future Features note)
-- before finally sizing the scroll child.
-------------------------------------------------------------------------------

function Dashboard:BuildFieldRows(scrollChild, sections, startOffset)

    local fields = {}

    local yOffset = startOffset or -4
    local rowHeight = 18
    local sectionHeaderGap = 20
    local sectionGap = 14

    for _, section in ipairs(sections) do

        local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 4, yOffset)
        header:SetText(AC.L:Get(section.title))
        header:SetTextColor(1, 0.82, 0)

        yOffset = yOffset - sectionHeaderGap

        for _, field in ipairs(section.fields) do

            local labelText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelText:SetPoint("TOPLEFT", 12, yOffset)
            labelText:SetWidth(190)
            labelText:SetJustifyH("LEFT")
            labelText:SetText(AC.L:Get(field.label))
            labelText:SetTextColor(0.7, 0.7, 0.7)

            local valueText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valueText:SetPoint("TOPLEFT", 206, yOffset)
            valueText:SetWidth(170)
            valueText:SetJustifyH("LEFT")
            valueText:SetText(AC.L:Get("Common.Unknown"))

            fields[field.key] = valueText

            yOffset = yOffset - rowHeight

        end

        yOffset = yOffset - sectionGap

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

function Dashboard:AppendFutureFeatures(scrollChild, yOffset, items)

    local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 4, yOffset)
    header:SetText(AC.L:Get("Dashboard.FutureFeatures"))
    header:SetTextColor(1, 0.82, 0)

    yOffset = yOffset - 20

    local bulletLines = {}

    for _, itemKey in ipairs(items or {}) do
        table.insert(bulletLines, "\226\128\162 " .. AC.L:Get(itemKey)) -- "• "
    end

    local bulletText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bulletText:SetPoint("TOPLEFT", 12, yOffset)
    bulletText:SetWidth(DATA_PAGE_CONTENT_WIDTH - 20)
    bulletText:SetJustifyH("LEFT")
    bulletText:SetWordWrap(true)
    bulletText:SetSpacing(4)
    bulletText:SetTextColor(0.75, 0.75, 0.75)
    bulletText:SetText(table.concat(bulletLines, "\n"))

    local lineHeight = 14
    local blockHeight = (#(items or {}) * lineHeight) + 10

    yOffset = yOffset - blockHeight

    return yOffset

end

-------------------------------------------------------------------------------
-- Recommendation Row
--
-- Recommendations are a dynamic, session-dependent list rather than a
-- fixed set of fields, so they get their own row builder instead of the
-- label/value schema above. Rows are pooled on the page and reused
-- across refreshes rather than recreated every time.
-------------------------------------------------------------------------------

function Dashboard:BuildRecommendationRow(scrollChild)

    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetWidth(DATA_PAGE_CONTENT_WIDTH)

    local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 4, 0)
    titleText:SetWidth(DATA_PAGE_CONTENT_WIDTH - 8)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(1, 0.82, 0)

    local descriptionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descriptionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    descriptionText:SetWidth(DATA_PAGE_CONTENT_WIDTH - 8)
    descriptionText:SetJustifyH("LEFT")
    descriptionText:SetWordWrap(true)
    descriptionText:SetTextColor(0.85, 0.85, 0.85)

    local metaText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaText:SetPoint("TOPLEFT", 4, 0)
    metaText:SetJustifyH("LEFT")

    row.TitleText = titleText
    row.DescriptionText = descriptionText
    row.MetaText = metaText

    return row

end

-------------------------------------------------------------------------------
-- Profile Page Data
--
-- The only place the Dashboard reads character data. Everything here
-- comes from the Character module's public API.
-------------------------------------------------------------------------------

function Dashboard:GetProfileFieldValues()

    local values = {}

    local characterModule = AC.Core and AC.Core:GetModule("Character")

    if not characterModule then
        return values
    end

    local profile = characterModule:GetProfile()

    if profile then

        if profile.name and profile.name ~= "" then
            values.name = profile.name
        end

        if profile.level and profile.level > 0 then
            values.level = tostring(profile.level)
        end

        if profile.race and profile.race ~= "" then
            values.race = profile.race
        end

        if profile.class and profile.class ~= "" then
            values.class = profile.class
        end

        if profile.specName and profile.specName ~= "" then
            values.spec = profile.specName
        end

        if profile.equippedItemLevel and profile.equippedItemLevel > 0 then
            values.equippedItemLevel = string.format("%.0f", profile.equippedItemLevel)
        end

        if profile.averageItemLevel and profile.averageItemLevel > 0 then
            values.averageItemLevel = string.format("%.0f", profile.averageItemLevel)
        end

        if profile.zone and profile.zone ~= "" then
            values.zone = profile.zone
        end

        if profile.subZone and profile.subZone ~= "" then
            values.subZone = profile.subZone
        end

        if profile.bindLocation and profile.bindLocation ~= "" then
            values.bindLocation = profile.bindLocation
        end

        if profile.guildName and profile.guildName ~= "" then
            values.guild = profile.guildName
        end

        if profile.faction and profile.faction ~= "" then
            values.faction = profile.faction
        end

        if profile.money then
            values.money = FormatMoney(profile.money)
        end

        if profile.playedTimeAvailable and profile.playedTimeTotal and profile.playedTimeTotal > 0 then
            values.playedTime = FormatDuration(profile.playedTimeTotal)
        end

    end

    if characterModule.GetSessionInfo then

        local session = characterModule:GetSessionInfo()

        if session then

            if session.loginTimestamp and session.loginTimestamp > 0 then
                values.loginTime = date("%b %d, %H:%M", session.loginTimestamp)
                values.sessionDuration = FormatDuration(session.sessionDuration)
            end

            if session.itemLevelGained then

                if session.itemLevelGained > 0 then
                    values.itemLevelGained = string.format("+%.1f", session.itemLevelGained)
                else
                    values.itemLevelGained = string.format("%.1f", session.itemLevelGained)
                end

            end

            if session.levelsGained then
                values.levelsGained = tostring(session.levelsGained)
            end

        end

    end

    return values

end

function Dashboard:UpdateProfilePage(frame)

    local page = frame.Pages and frame.Pages.Profile

    if not page or not page.Fields then
        return
    end

    local values = self:GetProfileFieldValues()
    local unknown = AC.L:Get("Common.Unknown")

    for key, fontString in pairs(page.Fields) do
        fontString:SetText(values[key] or unknown)
    end

end

-------------------------------------------------------------------------------
-- Inventory Page Data
--
-- The only place the Dashboard reads inventory data. Everything here
-- comes from the Inventory module's public API. Any wording (hearthstone
-- present/missing, repair needed) is decided here, not in the module --
-- the module only ever returns plain booleans/numbers.
-------------------------------------------------------------------------------

function Dashboard:GetInventoryFieldValues()

    local values = {}

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not inventoryModule then
        return values
    end

    if inventoryModule.GetBagSummary then

        local bagSummary = inventoryModule:GetBagSummary()

        if bagSummary then
            values.usedSlots = tostring(bagSummary.usedSlots or 0)
            values.freeSlots = tostring(bagSummary.freeSlots or 0)
            values.totalSlots = tostring(bagSummary.totalSlots or 0)
            values.percentFull = AC.L:Format("Dashboard.PercentFullFormat", bagSummary.percentage or 0)
        end

    end

    if inventoryModule.GetEquipmentSummary then

        local equipmentSummary = inventoryModule:GetEquipmentSummary()

        if equipmentSummary then

            values.equippedSlots = tostring(equipmentSummary.equippedSlots or 0)
            values.emptyEquipmentSlots = tostring(equipmentSummary.emptySlots or 0)

            if equipmentSummary.averageItemLevel and equipmentSummary.averageItemLevel > 0 then
                values.averageItemLevel = string.format("%.0f", equipmentSummary.averageItemLevel)
            end

        end

    end

    if inventoryModule.GetImportantItemsSummary then

        local importantItems = inventoryModule:GetImportantItemsSummary()

        if importantItems then

            if importantItems.hasHearthstone ~= nil then

                if importantItems.hasHearthstone then
                    values.hearthstone = AC.L:Get("Inventory.HearthstoneInBags")
                else
                    values.hearthstone = AC.L:Get("Inventory.HearthstoneMissing")
                end

            end

            if importantItems.needsRepair ~= nil then

                if importantItems.needsRepair then
                    values.repairStatus = AC.L:Get("Inventory.RepairsNeeded")
                else
                    values.repairStatus = AC.L:Get("Inventory.NoRepairsNeeded")
                end

            end

        end

    end

    if inventoryModule.GetSessionSummary then

        local sessionSummary = inventoryModule:GetSessionSummary()

        if sessionSummary then

            values.itemsAdded = tostring(sessionSummary.itemsAdded or 0)
            values.itemsRemoved = tostring(sessionSummary.itemsRemoved or 0)

            local change = sessionSummary.bagUsageChange or 0

            if change > 0 then
                values.bagUsageChange = string.format("+%.0f%%", change)
            else
                values.bagUsageChange = string.format("%.0f%%", change)
            end

        end

    end

    return values

end

function Dashboard:UpdateInventoryPage(frame)

    local page = frame.Pages and frame.Pages.Inventory

    if not page or not page.Fields then
        return
    end

    local values = self:GetInventoryFieldValues()
    local unknown = AC.L:Get("Common.Unknown")

    for key, fontString in pairs(page.Fields) do
        fontString:SetText(values[key] or unknown)
    end

end

-------------------------------------------------------------------------------
-- Achievements Page Data
--
-- The only place the Dashboard reads achievement data. Everything here
-- comes from the Achievements module's public API. Achievement names
-- themselves are Blizzard-provided and already localized -- they are
-- never routed through AC.L.
-------------------------------------------------------------------------------

function Dashboard:GetAchievementsFieldValues()

    local values = {}

    local achievementsModule = AC.Core and AC.Core:GetModule("Achievements")

    if not achievementsModule then
        return values
    end

    local points = achievementsModule:GetPoints()

    if points and points > 0 then
        values.points = FormatNumberWithCommas(points)
    end

    if achievementsModule.GetAchievementCount then

        local count = achievementsModule:GetAchievementCount()

        if count and count > 0 then
            values.achievementsEarned = FormatNumberWithCommas(count)
        end

    end

    if achievementsModule.GetMostRecentAchievement then

        local recent = achievementsModule:GetMostRecentAchievement()

        if recent and recent.name and recent.name ~= "" then
            values.recentAchievement = recent.name
        end

    end

    if achievementsModule.GetSessionSummary then

        local sessionSummary = achievementsModule:GetSessionSummary()

        if sessionSummary then
            values.achievementsEarnedThisSession = tostring(sessionSummary.achievementsEarnedThisSession or 0)
            values.pointsEarnedThisSession = tostring(sessionSummary.pointsEarnedThisSession or 0)
        end

    end

    return values

end

function Dashboard:UpdateAchievementsPage(frame)

    local page = frame.Pages and frame.Pages.Achievements

    if not page or not page.Fields then
        return
    end

    local values = self:GetAchievementsFieldValues()
    local unknown = AC.L:Get("Common.Unknown")

    for key, fontString in pairs(page.Fields) do
        fontString:SetText(values[key] or unknown)
    end

end

-------------------------------------------------------------------------------
-- Recommendations Page Data
--
-- The only place the Dashboard reads recommendation data. Titles and
-- descriptions arrive already localized from the Recommendation Engine
-- -- the Dashboard only localizes its own chrome (the meta line, the
-- empty state).
-------------------------------------------------------------------------------

function Dashboard:UpdateRecommendationsPage(frame)

    local page = frame.Pages and frame.Pages.Recommendations

    if not page then
        return
    end

    -- Keep the list current even if this page is visited without Home
    -- having refreshed the engines first.
    if AC.InsightEngine then
        AC.InsightEngine:Refresh()
    end

    if AC.RecommendationEngine then
        AC.RecommendationEngine:Refresh()
    end

    local recommendations = {}

    if AC.RecommendationEngine then
        recommendations = AC.RecommendationEngine:GetRecommendations() or {}
    end

    page.Rows = page.Rows or {}

    local scrollChild = page.ScrollChild

    if #recommendations == 0 then

        for _, row in ipairs(page.Rows) do
            row:Hide()
        end

        if not page.EmptyText then

            local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            emptyText:SetPoint("TOP", 0, -10)
            emptyText:SetWidth(DATA_PAGE_CONTENT_WIDTH)
            emptyText:SetJustifyH("CENTER")
            emptyText:SetTextColor(0.85, 0.85, 0.85)

            page.EmptyText = emptyText

        end

        page.EmptyText:SetText(AC.L:Get("Dashboard.CaughtUp"))
        page.EmptyText:Show()

        scrollChild:SetHeight(60)

        return

    end

    if page.EmptyText then
        page.EmptyText:Hide()
    end

    local yOffset = -4
    local rowGap = 14

    for index, recommendation in ipairs(recommendations) do

        local row = page.Rows[index]

        if not row then
            row = self:BuildRecommendationRow(scrollChild)
            page.Rows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        row.TitleText:SetText(recommendation.title or AC.L:Get("Common.Unknown"))
        row.DescriptionText:SetText(recommendation.description or "")

        local titleHeight = row.TitleText:GetStringHeight() or 14
        local descriptionHeight = row.DescriptionText:GetStringHeight() or 12

        row.MetaText:ClearAllPoints()
        row.MetaText:SetPoint("TOPLEFT", row.DescriptionText, "BOTTOMLEFT", 0, -4)
        row.MetaText:SetText(AC.L:Format("Dashboard.RecommendationMetaFormat",
            tostring(recommendation.priority or AC.L:Get("Common.Unknown")),
            recommendation.category or AC.L:Get("Common.Unknown")))

        local metaHeight = row.MetaText:GetStringHeight() or 12

        local rowHeight = titleHeight + 4 + descriptionHeight + 4 + metaHeight

        row:SetHeight(rowHeight)

        yOffset = yOffset - rowHeight - rowGap

    end

    for index = #recommendations + 1, #page.Rows do
        page.Rows[index]:Hide()
    end

    scrollChild:SetHeight((-yOffset) + 10)

end

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function Dashboard:Create()

    local frame = AC.BaseWindow:Create("AzerothCompanionDashboard", AC.L:Get("App.Title"), WINDOW_WIDTH, WINDOW_HEIGHT)

    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)

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
    -- Content Area
    --
    -- Everything below the header lives inside here. Pages are children
    -- of this frame and are shown/hidden as a unit -- no separate
    -- windows are created.
    -----------------------------------------------------------------------

    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, CONTENT_TOP_OFFSET)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame.ContentArea = contentArea
    frame.Pages = {}

    -----------------------------------------------------------------------
    -- Home Page
    --
    -- The application's landing page. Every card here is an entry point
    -- into the rest of the addon -- nothing on it is static except the
    -- window title.
    -----------------------------------------------------------------------

    local homePage = CreateFrame("Frame", nil, contentArea)
    homePage:SetAllPoints(contentArea)

    frame.Pages.Home = homePage

    -- Recommendation Card ---------------------------------------------

    local recommendationCard = AC.DashboardCard:Create(homePage, AC.L:Get("Dashboard.RecommendedNextStep"),
    {
        width = CARD_WIDTH,
        height = RECOMMENDATION_HEIGHT,
        titleFont = "GameFontNormalLarge",
        primaryFont = "GameFontHighlightLarge",
        emphasized = true,
        onClick = function()
            Dashboard:Navigate("Recommendations")
        end,
    })

    recommendationCard:SetPoint("TOP", homePage, "TOP", 0, -6)
    recommendationCard:SetPrimaryValue(AC.L:Get("Dashboard.CaughtUp"))
    recommendationCard:SetSecondaryText("")

    frame.RecommendationCard = recommendationCard

    -- Profile Card ---------------------------------------------------------

    local profileCard = AC.DashboardCard:Create(homePage, AC.L:Get("Dashboard.Profile"),
    {
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        onClick = function()
            Dashboard:Navigate("Profile")
        end,
    })

    profileCard:SetPoint("TOP", recommendationCard, "BOTTOM", 0, -SECTION_GAP)
    profileCard:SetPrimaryValue(AC.L:Get("Dashboard.Loading"))
    profileCard:SetSecondaryText("")

    frame.ProfileCard = profileCard

    -- Inventory Card ---------------------------------------------------------

    local inventoryCard = AC.DashboardCard:Create(homePage, AC.L:Get("Dashboard.Inventory"),
    {
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        showBar = true,
        onClick = function()
            Dashboard:Navigate("Inventory")
        end,
    })

    inventoryCard:SetPoint("TOP", profileCard, "BOTTOM", 0, -SECTION_GAP)
    inventoryCard:SetPrimaryValue(AC.L:Get("Dashboard.Loading"))
    inventoryCard:SetSecondaryText("")
    inventoryCard:SetStatus("Normal", "")

    frame.InventoryCard = inventoryCard

    -- Achievements Card ---------------------------------------------------------

    local achievementsCard = AC.DashboardCard:Create(homePage, AC.L:Get("Dashboard.Achievements"),
    {
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        onClick = function()
            Dashboard:Navigate("Achievements")
        end,
    })

    achievementsCard:SetPoint("TOP", inventoryCard, "BOTTOM", 0, -SECTION_GAP)
    achievementsCard:SetPrimaryValue(AC.L:Get("Dashboard.Loading"))
    achievementsCard:SetSecondaryText("")

    frame.AchievementsCard = achievementsCard

    -- Footer ---------------------------------------------------------------
    --
    -- Player-facing only: version number. No implementation details.

    local footer = homePage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("TOP", achievementsCard, "BOTTOM", 0, -20)
    footer:SetText(AC.L:Format("Dashboard.Version", AC.Version or "0.0.1"))
    footer:SetWidth(CARD_WIDTH)
    footer:SetJustifyH("CENTER")

    frame.Footer = footer

    -----------------------------------------------------------------------
    -- Profile Page
    -----------------------------------------------------------------------

    local profilePage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Profile"))
    local profileFields, profileYOffset = self:BuildFieldRows(profilePage.ScrollChild, PROFILE_SECTIONS)

    profilePage.ScrollChild:SetHeight((-profileYOffset) + 10)
    profilePage.Fields = profileFields

    frame.Pages.Profile = profilePage

    -----------------------------------------------------------------------
    -- Inventory Page
    -----------------------------------------------------------------------

    local inventoryPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Inventory"))
    local inventoryFields, inventoryYOffset = self:BuildFieldRows(inventoryPage.ScrollChild, INVENTORY_SECTIONS)

    inventoryYOffset = self:AppendFutureFeatures(inventoryPage.ScrollChild, inventoryYOffset, INVENTORY_FUTURE_FEATURES)

    inventoryPage.ScrollChild:SetHeight((-inventoryYOffset) + 10)
    inventoryPage.Fields = inventoryFields

    frame.Pages.Inventory = inventoryPage

    -----------------------------------------------------------------------
    -- Achievements Page
    -----------------------------------------------------------------------

    local achievementsPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Achievements"))
    local achievementsFields, achievementsYOffset = self:BuildFieldRows(achievementsPage.ScrollChild, ACHIEVEMENTS_SECTIONS)

    achievementsYOffset = self:AppendFutureFeatures(achievementsPage.ScrollChild, achievementsYOffset, ACHIEVEMENTS_FUTURE_FEATURES)

    achievementsPage.ScrollChild:SetHeight((-achievementsYOffset) + 10)
    achievementsPage.Fields = achievementsFields

    frame.Pages.Achievements = achievementsPage

    -----------------------------------------------------------------------
    -- Recommendations Page
    --
    -- A dynamic list rather than fixed fields -- rows are built and
    -- pooled by UpdateRecommendationsPage the first time it runs.
    -----------------------------------------------------------------------

    local recommendationsPage = self:CreateDataPage(contentArea, AC.L:Get("Dashboard.Recommendations"))
    recommendationsPage.Rows = {}

    frame.Pages.Recommendations = recommendationsPage

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

    -----------------------------------------------------------------------
    -- Refresh Insight Engine
    -----------------------------------------------------------------------

    if AC.InsightEngine then
        AC.InsightEngine:Refresh()
    end

    -----------------------------------------------------------------------
    -- Refresh Recommendation Engine
    -----------------------------------------------------------------------

    if AC.RecommendationEngine then
        AC.RecommendationEngine:Refresh()
    end

    -----------------------------------------------------------------------
    -- Recommendation Card
    -----------------------------------------------------------------------

    local recommendation = AC.RecommendationEngine and AC.RecommendationEngine:GetHighestPriority()

    if recommendation then
        frame.RecommendationCard:SetPrimaryValue(recommendation.title)
        frame.RecommendationCard:SetSecondaryText(recommendation.description)
    else
        frame.RecommendationCard:SetPrimaryValue(AC.L:Get("Dashboard.CaughtUp"))
        frame.RecommendationCard:SetSecondaryText("")
    end

    -----------------------------------------------------------------------
    -- Profile Card
    -----------------------------------------------------------------------

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local profile = characterModule and characterModule:GetProfile()

    if profile and profile.name and profile.name ~= "" then

        local level = profile.level or 0
        local specName = profile.specName
        local className = profile.class or AC.L:Get("Common.Unknown")
        local itemLevel = string.format("%.0f", profile.equippedItemLevel or 0)

        local levelLine

        if specName and specName ~= "" then
            levelLine = AC.L:Format("Dashboard.LevelSpecClassFormat", level, specName, className)
        else
            levelLine = AC.L:Format("Dashboard.LevelClassFormat", level, className)
        end

        frame.ProfileCard:SetPrimaryValue(profile.name)
        frame.ProfileCard:SetSecondaryText(string.format("%s\n%s", levelLine, AC.L:Format("Dashboard.EquippedItemLevelFormat", itemLevel)))

    else
        frame.ProfileCard:SetPrimaryValue(AC.L:Get("Dashboard.NoCharacterData"))
        frame.ProfileCard:SetSecondaryText("")
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
        local barR, barG, barB = 0.3, 0.7, 0.4

        if percentage >= 90 then
            status = "Important"
            statusText = AC.L:Get("Dashboard.StatusFull")
            barR, barG, barB = 0.85, 0.3, 0.3
        elseif percentage >= 75 then
            status = "Warning"
            statusText = AC.L:Get("Dashboard.StatusFilling")
            barR, barG, barB = 0.9, 0.7, 0.2
        end

        frame.InventoryCard:SetPrimaryValue(AC.L:Format("Dashboard.SlotsUsedFormat", usedSlots, totalSlots))
        frame.InventoryCard:SetSecondaryText(AC.L:Format("Dashboard.PercentFullFormat", percentage))
        frame.InventoryCard:SetStatus(status, statusText)
        frame.InventoryCard:SetBarValue(percentage, barR, barG, barB)

    else
        frame.InventoryCard:SetPrimaryValue(AC.L:Get("Dashboard.InventoryUnavailable"))
        frame.InventoryCard:SetSecondaryText("")
        frame.InventoryCard:SetStatus("Normal", "")
        frame.InventoryCard:SetBarValue(0)
    end

    -----------------------------------------------------------------------
    -- Achievements Card
    -----------------------------------------------------------------------

    local achievementsModule = AC.Core and AC.Core:GetModule("Achievements")

    if achievementsModule then

        local points = FormatNumberWithCommas(achievementsModule:GetPoints())
        frame.AchievementsCard:SetPrimaryValue(AC.L:Format("Dashboard.AchievementPointsFormat", points))
        frame.AchievementsCard:SetSecondaryText("")

    else
        frame.AchievementsCard:SetPrimaryValue(AC.L:Get("Dashboard.AchievementsUnavailable"))
        frame.AchievementsCard:SetSecondaryText("")
    end

end

-------------------------------------------------------------------------------
-- Navigation
-------------------------------------------------------------------------------

function Dashboard:IsValidPage(pageName)

    return VALID_PAGES[pageName] == true

end

function Dashboard:ShowPage(pageName)

    local frame = self.Frame

    if not frame or not frame.Pages then
        return
    end

    for _, page in pairs(frame.Pages) do
        if page then
            page:Hide()
        end
    end

    local page = frame.Pages[pageName]

    if page then
        page:Show()
    end

    if pageName == "Home" then
        self:UpdateContent(frame)
    elseif pageName == "Profile" then
        self:UpdateProfilePage(frame)
    elseif pageName == "Inventory" then
        self:UpdateInventoryPage(frame)
    elseif pageName == "Achievements" then
        self:UpdateAchievementsPage(frame)
    elseif pageName == "Recommendations" then
        self:UpdateRecommendationsPage(frame)
    end

end

function Dashboard:Navigate(pageName)

    if not self:IsValidPage(pageName) then
        return
    end

    if pageName == self.CurrentPage then
        return
    end

    table.insert(self.NavigationHistory, self.CurrentPage)
    self.CurrentPage = pageName

    self:ShowPage(pageName)

end

function Dashboard:GoBack()

    if #self.NavigationHistory == 0 then
        return
    end

    local previousPage = table.remove(self.NavigationHistory)
    self.CurrentPage = previousPage

    self:ShowPage(previousPage)

end

-------------------------------------------------------------------------------
-- Show
-------------------------------------------------------------------------------

function Dashboard:Show()

    if not self.Frame then
        self.Frame = self:Create()
    end

    self:ShowPage(self.CurrentPage)
    self.Frame:Show()

end

-------------------------------------------------------------------------------
-- Hide
-------------------------------------------------------------------------------

function Dashboard:Hide()

    if self.Frame then
        self.Frame:Hide()
    end

end

-------------------------------------------------------------------------------
-- Toggle
-------------------------------------------------------------------------------

function Dashboard:Toggle()

    if self.Frame and self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Dashboard = Dashboard

AC.ServiceManager:Register("Dashboard", Dashboard)

return Dashboard
