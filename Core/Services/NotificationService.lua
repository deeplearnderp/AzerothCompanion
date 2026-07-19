-------------------------------------------------------------------------------
-- Azeroth Companion
-- Notification Service
--
-- Companion Intelligence V4. Owns exactly one responsibility: a queue of
-- short-lived notifications -- at most one shown at a time (never
-- overlapping), auto-dismissed after its duration, the next one promoted
-- from the queue automatically. Dashboard's toast widget
-- (Core/UI/Dashboard/Notifications.lua) only renders whatever
-- GetActive() currently returns; it never decides timing or ordering
-- itself.
--
-- Two real, deterministic ways a notification gets created, both reusing
-- data this addon already computed -- never a new gameplay judgment:
--   1. Auto-detection (Refresh(), called every engine-refresh cycle,
--      Sections.lua): diffs the current Insight title list and the
--      current highest-priority Recommendation's title against what they
--      were last refresh. A title that's newly present this refresh (and
--      is in NOTIFICATION_TYPE_BY_INSIGHT_TITLE below) becomes a real
--      notification, using that Insight's own title/description --
--      never invented wording. The very first refresh after login never
--      notifies (there is no "previous" snapshot to diff against yet --
--      everything would look "new" and spam the player with facts that
--      were already true before the addon loaded).
--   2. Direct calls: MilestoneService calls Notify() itself when a real
--      milestone unlocks -- a normal cross-service call (both are Core
--      services, same category of thing RecommendationEngine already
--      does by reading other modules' public getters), not a new
--      exception.
--
-- Deliberately NOT implemented this pass: "Preparation Complete"/
-- "Storage Ready"/"Bank Ready" notifications named as *possible*
-- examples in the brief this shipped against. None of those are
-- currently real, observable state transitions anywhere in this addon --
-- StorageModule has no session-relative "just became ready" tracking the
-- way MythicPlus/Weekly already do for their own session-relative
-- Insights (Rating Increased, Vault Slot Unlocked). Adding one properly
-- is real module work, not something this service can fabricate by
-- watching for a title that doesn't exist yet.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ipairs = ipairs
local time = time

local NotificationService =
{
    Name = "NotificationService",
}

AC.NotificationService = NotificationService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local DEFAULT_DURATION = 6 -- seconds a notification stays visible once shown
local MAX_HISTORY = 20 -- bounded, same "cap it, don't grow forever" discipline as ActivityHistoryService

-------------------------------------------------------------------------------
-- Smart Notifications (Companion Intelligence vNext) -- Defaults
--
-- notificationCooldownMinutes gates the auto-detect path only (below):
-- an Insight title that toggles off and back on within a session (e.g.
-- "Bags Almost Full" after buying then selling items) would otherwise
-- re-notify every single time it re-crosses the false->true edge, which
-- is the real spam scenario this setting exists for. First-ever Settings
-- surface for this service.
-------------------------------------------------------------------------------

local Defaults =
{
    notificationCooldownMinutes = 20,
}

local VALID_TYPES =
{
    Info = true,
    Success = true,
    Warning = true,
    Achievement = true,
    Milestone = true,
}

-- Which real Insight titles are notification-worthy, and what type of
-- notification each becomes -- a fixed, documented, title-keyed mapping,
-- the same pattern RecommendationEngine's own EvaluateInsight already
-- uses. An Insight title not listed here never auto-notifies; that is a
-- deliberate curation choice (most Insights are informational, not
-- "worth interrupting the player for"), not an oversight.
local NOTIFICATION_TYPE_BY_INSIGHT_TITLE =
{
    ["Personal Best"] = "Success",
    ["Rating Increased"] = "Success",
    ["Vault Slot Unlocked"] = "Milestone",
    ["Vault Reward Available"] = "Success",
    ["Achievement Earned"] = "Achievement",
    ["Achievement Milestone"] = "Milestone",
    ["Bags Almost Full"] = "Warning",
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function NotificationService:ResetState()

    self.Queue = {}
    self.Active = nil
    self.ActiveExpiresAt = 0
    self.History = {}
    self.Sequence = 0

    self.HasRefreshedOnce = false
    self.PreviousInsightTitles = {}
    self.PreviousTopRecommendationTitle = nil

    -- Smart Notifications (Companion Intelligence vNext) -- session-scoped
    -- only, deliberately NOT persisted and NOT derived from the bounded
    -- History above (History rolls old entries off at MAX_HISTORY, which
    -- could silently drop a same-title entry mid-session and produce a
    -- false-negative cooldown miss). A fresh map every login/reload is
    -- correct here -- there is nothing dishonest about a cooldown
    -- resetting on reload, the same way NotificationService's own
    -- HasRefreshedOnce/PreviousInsightTitles above already reset.
    self.LastNotifiedAt = {}

    self.Ticker = nil

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function NotificationService:Initialize()

    self:ResetState()

    -- Smart Notifications (Companion Intelligence vNext) -- first-ever
    -- Settings surface for this service. order = 65 -- deliberately not
    -- 60, which PlayerJournal/Storage both already used (a real,
    -- pre-existing collision fixed alongside this addition; see
    -- PlayerJournalModule.lua's own order value).
    AC.ConfigurationManager:Register("NotificationService", Defaults)

    AC.Settings:RegisterPage("NotificationService",
    {
        title = "Notifications",
        module = "NotificationService",
        order = 65,
    })

    AC.Settings:RegisterSection("NotificationService", "General",
    {
        title = "General",
    })

    AC.Settings:AddSlider("NotificationService", "General",
    {
        key = "notificationCooldownMinutes",
        text = "Notification Cooldown (Minutes)",
        default = 20,
        min = 5,
        max = 60,
        step = 5,
        tooltip = "How long before the same kind of notification (e.g. \"Bags Almost Full\") can appear again after it was last shown.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function NotificationService:Enable()

    if C_Timer and C_Timer.NewTicker then
        self.Ticker = C_Timer.NewTicker(1, function()
            self:Tick()
        end)
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function NotificationService:Disable()

    if self.Ticker then
        self.Ticker:Cancel()
        self.Ticker = nil
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function NotificationService:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Notify -- the only way a notification enters the queue.
--
-- Shown immediately if nothing is currently active; otherwise queued and
-- shown once every notification ahead of it has had its turn --
-- notifications never overlap, per the design brief.
-------------------------------------------------------------------------------

function NotificationService:Notify(notificationType, title, message, duration)

    if not VALID_TYPES[notificationType] then
        notificationType = "Info"
    end

    self.Sequence = self.Sequence + 1

    local notification =
    {
        id = self.Sequence,
        type = notificationType,
        title = title or "",
        message = message or "",
        duration = tonumber(duration) or DEFAULT_DURATION,
        timestamp = time(),
    }

    table.insert(self.Queue, notification)

    -- Smart Notifications (Companion Intelligence vNext) -- stamped for
    -- every Notify() call (auto-detect and MilestoneService's direct
    -- calls alike); only the auto-detect loop below actually consults
    -- this map before calling Notify(), but recording it unconditionally
    -- here keeps the bookkeeping in one place rather than split across
    -- every caller.
    self.LastNotifiedAt[title or ""] = time()

    if not self.Active then
        self:PromoteNext()
    end

    return notification

end

-------------------------------------------------------------------------------
-- Promote Next
--
-- Pulls the oldest queued notification into the Active slot. Never
-- called while something is already Active -- Tick() (below) is the only
-- other caller, and only once the Active one has expired.
-------------------------------------------------------------------------------

function NotificationService:PromoteNext()

    if #self.Queue == 0 then
        self.Active = nil
        self.ActiveExpiresAt = 0
    else
        self.Active = table.remove(self.Queue, 1)
        self.ActiveExpiresAt = time() + self.Active.duration
    end

    -- Event-driven rather than polled -- the toast widget listens for
    -- this instead of checking GetActive() on a timer of its own.
    if AC.Events then
        AC.Events:Fire("NOTIFICATION_CHANGED", self.Active)
    end

end

-------------------------------------------------------------------------------
-- Tick -- advances the queue once the Active notification's duration
-- has elapsed. Driven by a 1-second C_Timer.NewTicker (Enable()) rather
-- than an OnUpdate script, so this costs nothing while no notification
-- is showing and never depends on the Dashboard window being open.
-------------------------------------------------------------------------------

function NotificationService:Tick()

    if not self.Active then
        return
    end

    if time() < self.ActiveExpiresAt then
        return
    end

    self:AddToHistory(self.Active)
    self:PromoteNext()

end

-------------------------------------------------------------------------------
-- Dismiss -- lets the toast UI (or a future click-to-dismiss) end the
-- Active notification early instead of waiting out its full duration.
-------------------------------------------------------------------------------

function NotificationService:Dismiss()

    if not self.Active then
        return
    end

    self:AddToHistory(self.Active)
    self:PromoteNext()

end

-------------------------------------------------------------------------------
-- Clear All -- clears only the transient notification presentation state.
-- Detection baselines, cooldown bookkeeping, sequence identity, and the
-- service ticker remain intact so a developer action cannot restart the
-- notification lifecycle in the middle of a session.
-------------------------------------------------------------------------------

function NotificationService:ClearAll()

    self.Queue = {}
    self.Active = nil
    self.ActiveExpiresAt = 0
    self.History = {}

    if AC.Events then
        AC.Events:Fire("NOTIFICATION_CHANGED", nil)
    end

end

-------------------------------------------------------------------------------
-- History
-------------------------------------------------------------------------------

function NotificationService:AddToHistory(notification)

    table.insert(self.History, notification)

    while #self.History > MAX_HISTORY do
        table.remove(self.History, 1)
    end

end

-------------------------------------------------------------------------------
-- Refresh -- auto-detection (see file header). Called after
-- AC.InsightEngine/AC.RecommendationEngine have already refreshed this
-- cycle (Dashboard:RefreshEngines, Sections.lua) -- this service never
-- refreshes either of them itself.
-------------------------------------------------------------------------------

function NotificationService:Refresh()

    if not AC.InsightEngine then
        return
    end

    local currentInsights = AC.InsightEngine:GetInsights()
    local currentTitles = {}

    for _, insight in ipairs(currentInsights) do
        currentTitles[insight.title] = insight
    end

    if self.HasRefreshedOnce then

        local cooldownSeconds = (tonumber(AC.ConfigurationManager:GetValue("NotificationService", "notificationCooldownMinutes")) or 20) * 60

        for title, insight in pairs(currentTitles) do

            local notificationType = NOTIFICATION_TYPE_BY_INSIGHT_TITLE[title]

            if notificationType and not self.PreviousInsightTitles[title] then

                -- Smart Notifications (Companion Intelligence vNext) --
                -- the real spam case this guards: an Insight that toggles
                -- off then back on within a session (e.g. "Bags Almost
                -- Full" after buying then selling items) re-crosses this
                -- false->true edge every time, which would otherwise
                -- re-notify every time too. Still notifies the very first
                -- time (LastNotifiedAt[title] is nil, so time() - 0 is
                -- always >= any real cooldown).
                local lastNotified = self.LastNotifiedAt[title] or 0

                if time() - lastNotified >= cooldownSeconds then
                    self:Notify(notificationType, insight.title, insight.description)
                end

            end

        end

        if AC.RecommendationEngine then

            local topRecommendation = AC.RecommendationEngine:GetHighestPriority()
            local topTitle = topRecommendation and topRecommendation.title or nil

            if topTitle and topTitle ~= self.PreviousTopRecommendationTitle and self.PreviousTopRecommendationTitle ~= nil then
                self:Notify("Info", AC.L and AC.L:Get("Notification.RecommendationChanged") or "Recommendation Changed", topTitle)
            end

            self.PreviousTopRecommendationTitle = topTitle

        end

    elseif AC.RecommendationEngine then

        local topRecommendation = AC.RecommendationEngine:GetHighestPriority()
        self.PreviousTopRecommendationTitle = topRecommendation and topRecommendation.title or nil

    end

    self.PreviousInsightTitles = currentTitles
    self.HasRefreshedOnce = true

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function NotificationService:GetActive()

    return self.Active

end

function NotificationService:GetQueueLength()

    return #self.Queue

end

function NotificationService:GetHistory(count)

    count = tonumber(count) or MAX_HISTORY

    local results = {}
    local total = #self.History
    local stopAt = total - count + 1

    if stopAt < 1 then
        stopAt = 1
    end

    for i = total, stopAt, -1 do
        table.insert(results, self.History[i])
    end

    return results

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("NotificationService", NotificationService)

return NotificationService
