-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Page: Delves
--
-- A progression-focused companion to Blizzard's Delves UI. DelvesModule owns
-- live Journey/companion state and tracked completion history; WeeklyModule
-- owns the Great Vault projection. This page only composes those facts.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Dashboard = AC.Dashboard
local Layout = AC.DashboardLayout

-- Home's existing Dungeons activity card still consumes this presentation
-- query. The Delves page itself deliberately does not render the mixed feed.
local function IsGeneralDungeonActivity(record)

    if record.Module == "Delves" then
        return true
    end

    return record.ActivityType == "Dungeon" and record.Module ~= "MythicPlus"

end

function Dashboard:GetRecentDungeonActivities(count)

    local records = {}
    local history = AC.ActivityHistoryService

    if not history then
        return records
    end

    for _, record in ipairs(history:GetRecent(history:Count())) do

        if IsGeneralDungeonActivity(record) then

            table.insert(records, record)

            if #records >= count then
                break
            end

        end

    end

    return records

end

local function HideSectionHeader(scrollChild, titleKey)

    local header = scrollChild.SectionHeaders and scrollChild.SectionHeaders[titleKey]

    if header then
        header:Hide()
    end

end


local function FormatActiveDelve(activeDelve)

    if not activeDelve then
        return nil
    end

    local name = activeDelve.area

    if type(name) ~= "string" or not name:match("%S") then
        name = activeDelve.name
    end

    if type(name) ~= "string" or not name:match("%S") then
        return nil
    end

    if activeDelve.tier then
        return AC.L:Format("Dungeons.DelveTierFormat", name, activeDelve.tier)
    end

    return name

end


local function BuildRecentDelves(records)

    local results = {}

    for _, record in ipairs(records or {}) do

        local name = record.ActivityName

        if type(name) == "string" and name:match("%S") then
            table.insert(results, record)
        end

    end

    return results

end


local function FormatRecentDelve(record)

    local tier = tonumber(record.Data and record.Data.tier)
    local completed = record.Ended or record.Timestamp
    local dateText = completed and AC.Presentation.FormatDate(completed, "monthDay") or ""

    if tier and tier > 0 then
        return AC.L:Format("Delves.RecentRunTierFormat", record.ActivityName, tier, dateText)
    end

    return AC.L:Format("Delves.RecentRunFormat", record.ActivityName, dateText)

end


local VAULT_CHEST_WIDTH = 48
local VAULT_CHEST_HEIGHT = 36
local VAULT_CHEST_GAP = 7

local function ShowVaultSlotTooltip(frame)

    local slot = frame.Slot

    if not slot then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(AC.L:Format("Delves.VaultRewardTitleFormat", AC.L:Get(frame.CategoryKey)), 1, 0.82, 0)
    GameTooltip:AddLine(slot.unlocked and AC.L:Get("Delves.VaultUnlocked") or AC.L:Get("Delves.VaultLocked"),
        slot.unlocked and 0.35 or 0.55,
        slot.unlocked and 1 or 0.55,
        slot.unlocked and 0.35 or 0.55)

    if slot.rewardItemLevel then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(AC.L:Get("Delves.VaultItemLevel"), tostring(slot.rewardItemLevel), 0.75, 0.75, 0.75, 1, 1, 1)
    end

    if slot.threshold and slot.threshold > 0 then
        GameTooltip:AddDoubleLine(
            AC.L:Get("Delves.VaultProgress"),
            AC.L:Format("Dashboard.DelvesProgressFormat", slot.progress or 0, slot.threshold),
            0.75, 0.75, 0.75, 1, 1, 1)
    end

    if slot.level and slot.level > 0 then
        local levelKey = frame.CategoryKey == "Delves.VaultDungeons"
            and "Delves.VaultDungeonLevelFormat"
            or "Delves.VaultWorldTierFormat"

        GameTooltip:AddDoubleLine(
            AC.L:Get("Delves.VaultQualifyingLevel"),
            AC.L:Format(levelKey, slot.level),
            0.75, 0.75, 0.75, 1, 1, 1)
    end

    GameTooltip:Show()

end


local function CreateVaultSlot(parent)

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(VAULT_CHEST_WIDTH, VAULT_CHEST_HEIGHT)
    frame:EnableMouse(true)

    frame.Artwork = frame:CreateTexture(nil, "ARTWORK")
    frame.Artwork:SetAllPoints()

    frame.ItemLevel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.ItemLevel:SetPoint("CENTER", 0, -1)
    frame.ItemLevel:SetJustifyH("CENTER")

    frame:SetScript("OnEnter", function(self)
        self.Artwork:SetAlpha(1)
        ShowVaultSlotTooltip(self)
    end)

    frame:SetScript("OnLeave", function(self)
        self.Artwork:SetAlpha(self.Slot and self.Slot.unlocked and 0.92 or 0.62)
        GameTooltip:Hide()
    end)

    return frame

end


local function SetVaultCategory(frame, categoryKey, category)

    frame.Label:SetText(AC.L:Get(categoryKey))

    local slots = category and category.slots or {}

    for index = 1, math.max(#slots, #frame.Slots) do

        local slot = slots[index]
        local slotFrame = frame.Slots[index]

        if slot and not slotFrame then
            slotFrame = CreateVaultSlot(frame)
            frame.Slots[index] = slotFrame
        end

        if slot and slotFrame then

            slotFrame:ClearAllPoints()
            slotFrame:SetPoint("TOPLEFT", (index - 1) * (VAULT_CHEST_WIDTH + VAULT_CHEST_GAP), -18)

            slotFrame.Artwork:SetAtlas("BonusLoot-Chest", false)
            slotFrame.Artwork:SetDesaturated(not slot.unlocked)
            slotFrame.Artwork:SetAlpha(slot.unlocked and 0.92 or 0.62)
            slotFrame.ItemLevel:SetText(slot.unlocked and slot.rewardItemLevel and tostring(slot.rewardItemLevel) or "")
            slotFrame.Slot = slot
            slotFrame.CategoryKey = categoryKey
            slotFrame:Show()

        elseif slotFrame then
            slotFrame.Slot = nil
            slotFrame:Hide()
        end

    end

    frame:Show()

end


local function LayoutVaultSection(page, scrollChild, yOffset, width, dungeonVault, worldVault)

    local categories = {}

    if dungeonVault and dungeonVault.totalSlots > 0 then
        table.insert(categories, { key = "Delves.VaultDungeons", data = dungeonVault })
    end

    if worldVault and worldVault.totalSlots > 0 then
        table.insert(categories, { key = "Delves.VaultWorld", data = worldVault })
    end

    -- Retire the generic statistics cells previously used by this section.
    Dashboard:LayoutStatisticsGrid(page, "DelvesVault", scrollChild, yOffset, width, {})

    if #categories == 0 then
        HideSectionHeader(scrollChild, "Delves.SectionGreatVault")

        if page.DelvesVaultOverview then
            page.DelvesVaultOverview:Hide()
        end

        return yOffset
    end

    yOffset = Dashboard:BeginSection(scrollChild, "Delves.SectionGreatVault", yOffset)

    local holder = page.DelvesVaultOverview

    if not holder then

        holder = CreateFrame("Frame", nil, scrollChild)
        holder.Categories = {}
        page.DelvesVaultOverview = holder

        for index = 1, 2 do

            local categoryFrame = CreateFrame("Frame", nil, holder)
            categoryFrame.Label = categoryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            categoryFrame.Label:SetPoint("TOPLEFT", 0, 0)
            categoryFrame.Label:SetJustifyH("LEFT")
            categoryFrame.Label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))
            categoryFrame.Slots = {}

            holder.Categories[index] = categoryFrame

        end

    end

    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
    holder:SetSize(width - Layout.ROW_INDENT, 56)

    local categoryWidth = (width - Layout.ROW_INDENT - Layout.STAT_CELL_GAP) / 2

    for index, categoryFrame in ipairs(holder.Categories) do

        local category = categories[index]

        if category then
            categoryFrame:ClearAllPoints()
            categoryFrame:SetPoint("TOPLEFT", (index - 1) * (categoryWidth + Layout.STAT_CELL_GAP), 0)
            categoryFrame:SetSize(categoryWidth, 56)
            SetVaultCategory(categoryFrame, category.key, category.data)
        else
            categoryFrame:Hide()
        end

    end

    holder:Show()

    return Dashboard:EndSection(yOffset - 56)

end


local function CreateCurioOverview(parent)

    local frame = CreateFrame("Frame", nil, parent)

    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Label:SetPoint("TOPLEFT", 0, 0)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetTextColor(unpack(AC.Presentation.GetSemanticColor("dim")))

    frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Name:SetPoint("TOPLEFT", frame.Label, "BOTTOMLEFT", 0, -2)
    frame.Name:SetJustifyH("LEFT")

    frame.Rank = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Rank:SetPoint("TOPLEFT", frame.Name, "BOTTOMLEFT", 0, -2)
    frame.Rank:SetJustifyH("LEFT")

    frame:SetScript("OnEnter", function(self)

        if not self.Curio or not self.Curio.link then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.Curio.link)
        GameTooltip:Show()

    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return frame

end


local function SetCurioOverview(frame, labelKey, curio, width)

    if not curio or not curio.name then
        frame:Hide()
        return false
    end

    frame:SetSize(width, 46)
    frame.Label:SetWidth(width)
    frame.Name:SetWidth(width)
    frame.Rank:SetWidth(width)
    frame.Label:SetText(AC.L:Get(labelKey))
    frame.Name:SetText(curio.name)

    if curio.rank and curio.maxRank then
        frame.Rank:SetText(AC.L:Format("Delves.CurioRankFormat", curio.rank, curio.maxRank))
    else
        frame.Rank:SetText("")
    end

    frame.Curio = curio
    frame:EnableMouse(curio.link ~= nil)
    frame:Show()

    return true

end


local function LayoutCompanion(page, scrollChild, yOffset, width, companion)

    if not companion then

        HideSectionHeader(scrollChild, "Delves.SectionCompanion")

        if page.CompanionOverview then
            page.CompanionOverview:Hide()
        end

        return yOffset

    end

    yOffset = Dashboard:BeginSection(scrollChild, "Delves.SectionCompanion", yOffset)

    local holder = page.CompanionOverview

    if not holder then

        holder = CreateFrame("Frame", nil, scrollChild)

        holder.Portrait = holder:CreateTexture(nil, "ARTWORK")
        holder.Portrait:SetSize(56, 56)

        holder.Name = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        holder.Name:SetJustifyH("LEFT")

        holder.Meta = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        holder.Meta:SetJustifyH("LEFT")

        holder.XPBarHolder = CreateFrame("Frame", nil, holder)
        holder.XPBarHolder:SetHeight(7)

        holder.XPBarBackground = holder.XPBarHolder:CreateTexture(nil, "BACKGROUND")
        holder.XPBarBackground:SetAllPoints()
        holder.XPBarBackground:SetColorTexture(0, 0, 0, 0.45)

        holder.XPBar = CreateFrame("StatusBar", nil, holder.XPBarHolder)
        holder.XPBar:SetPoint("TOPLEFT", 1, -1)
        holder.XPBar:SetPoint("BOTTOMRIGHT", -1, 1)
        holder.XPBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        holder.XPBar:SetStatusBarColor(0.30, 0.60, 0.90)

        holder.XPText = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        holder.XPText:SetJustifyH("LEFT")

        holder.CombatCurio = CreateCurioOverview(holder)
        holder.UtilityCurio = CreateCurioOverview(holder)

        page.CompanionOverview = holder

    end

    holder:SetSize(width, 58)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", 0, yOffset)

    local textOffset = 0

    if companion.displayID and SetPortraitTextureFromCreatureDisplayID then
        holder.Portrait:ClearAllPoints()
        holder.Portrait:SetPoint("TOPLEFT", Layout.ROW_INDENT, 0)
        SetPortraitTextureFromCreatureDisplayID(holder.Portrait, companion.displayID)
        holder.Portrait:Show()
        textOffset = Layout.ROW_INDENT + 68
    else
        holder.Portrait:Hide()
        textOffset = Layout.ROW_INDENT
    end

    local textWidth = width - textOffset

    holder.Name:ClearAllPoints()
    holder.Name:SetPoint("TOPLEFT", textOffset, 0)
    holder.Name:SetWidth(textWidth)
    holder.Name:SetText(companion.name)

    local meta = {}

    if companion.level then
        table.insert(meta, AC.L:Format("Delves.CompanionLevelFormat", companion.level))
    end

    if companion.role then
        table.insert(meta, companion.role)
    end

    holder.Meta:ClearAllPoints()
    holder.Meta:SetPoint("TOPLEFT", holder.Name, "BOTTOMLEFT", 0, -3)
    holder.Meta:SetWidth(textWidth)
    holder.Meta:SetText(table.concat(meta, "   "))

    local hasCompanionProgress = companion.isMaximumLevel
        or (companion.currentXP ~= nil and companion.requiredXP ~= nil and companion.requiredXP > 0)

    if hasCompanionProgress then

        holder.XPBarHolder:ClearAllPoints()
        holder.XPBarHolder:SetPoint("TOPLEFT", holder.Meta, "BOTTOMLEFT", 0, -6)
        holder.XPBarHolder:SetWidth(textWidth)

        holder.XPText:ClearAllPoints()
        holder.XPText:SetPoint("TOPLEFT", holder.XPBarHolder, "BOTTOMLEFT", 0, -3)
        holder.XPText:SetWidth(textWidth)

        if companion.isMaximumLevel then
            holder.XPBar:SetMinMaxValues(0, 1)
            holder.XPBar:SetValue(1)
            holder.XPText:SetText(AC.L:Get("Delves.CompanionMaximumLevel"))
        else
            holder.XPBar:SetMinMaxValues(0, companion.requiredXP)
            holder.XPBar:SetValue(companion.currentXP)
            holder.XPText:SetText(AC.L:Format("Delves.CompanionXPFormat", companion.currentXP, companion.requiredXP))
        end

        holder.XPBarHolder:Show()
        holder.XPText:Show()

    else
        holder.XPBarHolder:Hide()
        holder.XPText:Hide()
    end

    local curioWidth = (width - Layout.ROW_INDENT - Layout.STAT_CELL_GAP) / 2
    local hasCombatCurio = SetCurioOverview(holder.CombatCurio, "Delves.CombatCurio", companion.combatCurio, curioWidth)
    local hasUtilityCurio = SetCurioOverview(holder.UtilityCurio, "Delves.UtilityCurio", companion.utilityCurio, curioWidth)
    local hasCurios = hasCombatCurio or hasUtilityCurio

    holder.CombatCurio:ClearAllPoints()
    local curioOffset = hasCompanionProgress and -86 or -64

    holder.CombatCurio:SetPoint("TOPLEFT", Layout.ROW_INDENT, curioOffset)

    holder.UtilityCurio:ClearAllPoints()
    holder.UtilityCurio:SetPoint("TOPLEFT", Layout.ROW_INDENT + curioWidth + Layout.STAT_CELL_GAP, curioOffset)

    local holderHeight = hasCurios and (hasCompanionProgress and 132 or 110) or (hasCompanionProgress and 80 or 58)
    holder:SetHeight(holderHeight)
    holder:Show()

    return Dashboard:EndSection(yOffset - holderHeight)

end


function Dashboard:UpdateDungeonsPage(frame)

    local page = frame.Pages and frame.Pages.Dungeons

    if not page then
        return
    end

    local delvesModule = AC.Core and AC.Core:GetModule("Delves")
    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
    local summary = delvesModule and delvesModule.GetProgressionSummary and delvesModule:GetProgressionSummary() or {}
    local activeDelve = delvesModule and delvesModule.GetActiveDelveInfo and delvesModule:GetActiveDelveInfo()
    local recentDelves = BuildRecentDelves(delvesModule and delvesModule.GetRecentDelves and delvesModule:GetRecentDelves(6) or {})
    local dungeonVault = weeklyModule and weeklyModule.GetVaultCategoryProgress and weeklyModule:GetVaultCategoryProgress("Dungeons")
    local worldVault = weeklyModule and weeklyModule.GetVaultCategoryProgress and weeklyModule:GetVaultCategoryProgress("World")
    local statistics = summary.statistics or { completionCount = 0 }
    local scrollChild = page.ScrollChild

    local function Layout_(width)

        page.ContentWidth = width

        local yOffset = -4
        local heroValue = summary.journey and tostring(summary.journey.rank) or ""
        local heroCaption = summary.journey and AC.L:Get("Delves.JourneyRank") or AC.L:Get("Delves.JourneyOnboarding")
        local _, _, _, heroEndOffset = self:BuildHeroSection(page, scrollChild, yOffset, width, AC.L:Get("Dashboard.Delves"), heroValue, heroCaption)
        local heroStats = {}

        if summary.journey and summary.journey.progress and summary.journey.threshold then
            table.insert(heroStats, { label = "Delves.JourneyProgress", value = AC.L:Format("Dashboard.DelvesProgressFormat", summary.journey.progress, summary.journey.threshold) })
        end

        local activeDelveText = FormatActiveDelve(activeDelve)

        if activeDelveText then
            table.insert(heroStats, { label = "Dungeons.StatActiveDelve", value = activeDelveText })
        end

        if #heroStats > 0 then
            yOffset = self:LayoutStatisticsGrid(page, "DelvesHeroStats", scrollChild, heroEndOffset, width, heroStats)
        else
            self:LayoutStatisticsGrid(page, "DelvesHeroStats", scrollChild, heroEndOffset, width, {})
            yOffset = heroEndOffset
        end

        yOffset = LayoutCompanion(page, scrollChild, yOffset, width, summary.companion)

        local progressStats = {}

        if statistics.highestTier then
            table.insert(progressStats, { label = "Delves.HighestTier", value = tostring(statistics.highestTier) })
        end

        if statistics.completionCount and statistics.completionCount > 0 then
            table.insert(progressStats, { label = "Delves.Completed", value = tostring(statistics.completionCount) })
        end

        if #progressStats > 0 then
            yOffset = self:AppendStatisticsSection(page, "DelvesProgress", "Delves.SectionProgress", yOffset, progressStats)
        else
            HideSectionHeader(scrollChild, "Delves.SectionProgress")
            self:LayoutStatisticsGrid(page, "DelvesProgress", scrollChild, yOffset, width, {})
        end

        yOffset = LayoutVaultSection(page, scrollChild, yOffset, width, dungeonVault, worldVault)

        yOffset = self:AppendTextSection(page, "RecentDelves", "Delves.SectionRecentDelves", yOffset, recentDelves, "Delves.NoDelvesRecorded", FormatRecentDelve)

        return (-yOffset) + Layout.PAGE_BOTTOM_PADDING

    end

    self:MeasureAndApplyScrolling(page, scrollChild, Layout_)

end

return Dashboard
