-------------------------------------------------------------------------------
-- Azeroth Companion
-- Notification Toast
--
-- Companion Intelligence V4. Pure presentation over AC.NotificationService
-- -- this file never decides which notification to show, when to show
-- it, or when to dismiss it; it only renders whatever
-- AC.NotificationService:GetActive() currently is, and asks the service
-- to dismiss early on click. Event-driven (listens for
-- "NOTIFICATION_CHANGED", fired by NotificationService:PromoteNext())
-- rather than polling, so this costs nothing between notifications.
--
-- Deliberately standalone from AC.Dashboard -- a toast needs to be
-- visible whether or not the player currently has the Dashboard window
-- open (the same reasoning MinimapIcon.lua's standalone, always-present
-- launcher already follows), so this registers itself as its own
-- Core-managed UI component instead of living inside Dashboard's
-- per-page Create()/Show() lifecycle.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local NotificationToast = {}
AC.NotificationToast = NotificationToast

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local TOAST_WIDTH = 280
local TOAST_PADDING = 10
local TOAST_TITLE_TOP = 10
local TOAST_TITLE_MESSAGE_GAP = 4
local TOAST_BOTTOM_PADDING = 10
local INDICATOR_WIDTH = 4
local TOP_OFFSET = -80 -- below the default minimap/objective tracker area

-- One fixed, documented color per notification type -- the same
-- "type-keyed table, not a guess" pattern already used throughout this
-- codebase (RecommendationEngine's title-keyed branches, NotificationService's
-- own NOTIFICATION_TYPE_BY_INSIGHT_TITLE).
local TYPE_COLORS =
{
    Info = { 0.6, 0.6, 0.6 },
    Success = AC.Presentation.GetSemanticColor("success"),
    Warning = AC.Presentation.GetSemanticColor("warning"),
    Achievement = AC.Presentation.HIGHLIGHT_COLOR,
    Milestone = { 0.65, 0.45, 0.9 },
}

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function NotificationToast:Initialize()

    local frame = CreateFrame("Frame", "AzerothCompanionNotificationToast", UIParent)
    frame:SetWidth(TOAST_WIDTH)
    frame:SetHeight(60)
    frame:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.92)

    local indicator = frame:CreateTexture(nil, "ARTWORK")
    indicator:SetPoint("TOPLEFT", 0, 0)
    indicator:SetPoint("BOTTOMLEFT", 0, 0)
    indicator:SetWidth(INDICATOR_WIDTH)
    indicator:SetColorTexture(0.6, 0.6, 0.6, 1)

    frame.Indicator = indicator

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", INDICATOR_WIDTH + TOAST_PADDING, -TOAST_TITLE_TOP)
    titleText:SetPoint("TOPRIGHT", -TOAST_PADDING, -TOAST_TITLE_TOP)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(true)

    frame.TitleText = titleText

    local messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    messageText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -TOAST_TITLE_MESSAGE_GAP)
    messageText:SetPoint("RIGHT", -TOAST_PADDING, 0)
    messageText:SetJustifyH("LEFT")
    messageText:SetWordWrap(true)
    messageText:SetTextColor(0.85, 0.85, 0.85)

    frame.MessageText = messageText

    -- Dynamic height, same "grow to fit real content" pattern as
    -- DashboardCard:UpdateHeight -- a short title-only notification
    -- doesn't reserve blank space for a message it isn't showing.
    function frame:UpdateHeight()

        local height = TOAST_TITLE_TOP + TOAST_BOTTOM_PADDING

        if self.TitleText:GetText() and self.TitleText:GetText() ~= "" then
            height = height + self.TitleText:GetStringHeight()
        end

        if self.MessageText:GetText() and self.MessageText:GetText() ~= "" then
            height = height + TOAST_TITLE_MESSAGE_GAP + self.MessageText:GetStringHeight()
        end

        self:SetHeight(math.max(height, 40))

    end

    frame:EnableMouse(true)

    frame:SetScript("OnMouseUp", function()

        if AC.NotificationService then
            AC.NotificationService:Dismiss()
        end

    end)

    self.Frame = frame

    if AC.Events then
        AC.Events:Register("NOTIFICATION_CHANGED", self, "OnNotificationChanged")
    end

end

-------------------------------------------------------------------------------
-- Enable
--
-- Syncs to whatever is already Active, in case NotificationService fired
-- a notification before this widget finished registering its listener
-- (both are enabled during the same Core:Initialize() pass -- defensive,
-- not expected in practice).
-------------------------------------------------------------------------------

function NotificationToast:Enable()

    if AC.NotificationService then
        self:OnNotificationChanged(AC.NotificationService:GetActive())
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function NotificationToast:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

    if self.Frame then
        self.Frame:Hide()
    end

end

-------------------------------------------------------------------------------
-- On Notification Changed
-------------------------------------------------------------------------------

function NotificationToast:OnNotificationChanged(notification)

    if not self.Frame then
        return
    end

    if not notification then
        self.Frame:Hide()
        return
    end

    local color = TYPE_COLORS[notification.type] or TYPE_COLORS.Info

    self.Frame.Indicator:SetColorTexture(color[1], color[2], color[3], 1)
    self.Frame.TitleText:SetText(notification.title or "")
    self.Frame.TitleText:SetTextColor(color[1], color[2], color[3])
    self.Frame.MessageText:SetText(notification.message or "")

    self.Frame:UpdateHeight()
    self.Frame:Show()

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("NotificationToast", NotificationToast)

return NotificationToast
