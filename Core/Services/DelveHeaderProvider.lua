-------------------------------------------------------------------------------
-- Azeroth Companion
-- Delve Header Provider
--
-- Owns discovery and normalization of Blizzard's live Delve scenario-header
-- widget data. Presentation consumers read GetCurrentRun() and never call
-- C_UIWidgetManager directly.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local WIDGET_SET_ID = 842
local WIDGET_TYPE = Enum.UIWidgetVisualizationType.ScenarioHeaderDelves

local DelveHeaderProvider = {}
AC.DelveHeaderProvider = DelveHeaderProvider

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function DelveHeaderProvider:Initialize()

    self.WidgetID = nil
    self.CurrentRun = nil

end


function DelveHeaderProvider:Enable()

    AC.Events:Register("UPDATE_UI_WIDGET", self, "OnUpdateUIWidget")
    AC.Events:Register("UPDATE_ALL_UI_WIDGETS", self, "OnUpdateAllUIWidgets")
    self:Refresh()

end


function DelveHeaderProvider:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

    self.WidgetID = nil
    self.CurrentRun = nil

end


function DelveHeaderProvider:Shutdown()

    self:Disable()

end

-------------------------------------------------------------------------------
-- Discovery
-------------------------------------------------------------------------------

function DelveHeaderProvider:DiscoverWidgetID()

    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(WIDGET_SET_ID)

    for _, widget in ipairs(widgets) do
        if widget.widgetType == WIDGET_TYPE then
            return widget.widgetID
        end
    end

    return nil

end


local function BuildResourceModel(currencyInfo)

    return
    {
        iconFileID = currencyInfo.iconFileID,
        leadingText = currencyInfo.leadingText,
        text = currencyInfo.text,
        tooltip = currencyInfo.tooltip,
        enabledState = currencyInfo.textEnabledState,
    }

end


local function BuildAffixModel(spellInfo)

    if spellInfo.shownState == Enum.WidgetShownState.Hidden then
        return nil
    end

    local spellData = C_Spell.GetSpellInfo(spellInfo.spellID)
    local name = spellInfo.text

    if name == "" and spellData then
        name = spellData.name
    end

    return
    {
        spellID = spellInfo.spellID,
        name = name,
        iconFileID = spellData and spellData.iconID,
        tooltip = spellInfo.tooltip,
        stackDisplay = spellInfo.stackDisplay,
        enabledState = spellInfo.enabledState,
        showAsEarned = spellInfo.showAsEarned,
    }

end


local function BuildRewardModel(rewardInfo)

    if rewardInfo.shownState == Enum.UIWidgetRewardShownState.Hidden then
        return nil
    end

    local isEarned = rewardInfo.shownState == Enum.UIWidgetRewardShownState.ShownEarned

    return
    {
        shownState = rewardInfo.shownState,
        isEarned = isEarned,
        tooltip = isEarned and rewardInfo.earnedTooltip or rewardInfo.unearnedTooltip,
    }

end


function DelveHeaderProvider:BuildCurrentRun(widgetID, widgetInfo)

    local resources = {}
    local affixes = {}

    for _, currencyInfo in ipairs(widgetInfo.currencies) do
        table.insert(resources, BuildResourceModel(currencyInfo))
    end

    for _, spellInfo in ipairs(widgetInfo.spells) do
        local affix = BuildAffixModel(spellInfo)

        if affix then
            table.insert(affixes, affix)
        end
    end

    return
    {
        widgetID = widgetID,
        name = widgetInfo.headerText,
        tierText = widgetInfo.tierText,
        tooltip = widgetInfo.tooltip,
        tooltipLocation = widgetInfo.tooltipLoc,
        tierTooltipSpellID = widgetInfo.tierTooltipSpellID,
        resources = resources,
        affixes = affixes,
        reward = BuildRewardModel(widgetInfo.rewardInfo),

        -- Future elapsed-time support belongs here after ActivityHistory owns
        -- a trustworthy run start and duration. Widget data does not provide it.
        elapsedSeconds = nil,
    }

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function DelveHeaderProvider:Refresh()

    local widgetID = self:DiscoverWidgetID()
    local currentRun

    if widgetID then
        local widgetInfo = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)

        if widgetInfo and widgetInfo.shownState ~= Enum.WidgetShownState.Hidden then
            currentRun = self:BuildCurrentRun(widgetID, widgetInfo)
        end
    end

    self.WidgetID = widgetID
    self.CurrentRun = currentRun

    AC.Events:Fire("DELVE_HEADER_UPDATED", currentRun)

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function DelveHeaderProvider:OnUpdateUIWidget(widget)

    if not widget then
        return
    end

    local isCurrentWidget = self.WidgetID and widget.widgetID == self.WidgetID
    local isDelveHeader = widget.widgetSetID == WIDGET_SET_ID and widget.widgetType == WIDGET_TYPE

    if isCurrentWidget or isDelveHeader then
        self:Refresh()
    end

end


function DelveHeaderProvider:OnUpdateAllUIWidgets()

    self:Refresh()

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function DelveHeaderProvider:GetCurrentRun()

    return self.CurrentRun

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DelveHeaderProvider", DelveHeaderProvider)

return DelveHeaderProvider
