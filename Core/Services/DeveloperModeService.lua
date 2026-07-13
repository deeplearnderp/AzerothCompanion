-------------------------------------------------------------------------------
-- Azeroth Companion
-- Developer Mode Service
--
-- The isolated backbone every Developer Panel tab reads from. Owns exactly
-- three things: the Developer Mode on/off flag itself (persisted per
-- profile, the same DatabaseService-backed pattern Logger:IsDebugEnabled()
-- already uses for its own Debug flag), a bounded Blizzard event log, and
-- lightweight Refresh() timing/error instrumentation on every registered
-- Service/Module -- plus a couple of generic, data-shape-agnostic
-- serializers (ToJSON/ToIndentedText) every Developer Panel tab's Copy
-- buttons share instead of each writing its own.
--
-- "Production behavior must remain unchanged when Developer Mode is
-- disabled" is the one rule everything here answers to: event registration
-- and Refresh() wrapping are only ever INSTALLED while enabled and fully
-- REMOVED (unregistered / originals restored) the moment it's disabled --
-- there is no always-on background cost, not even a disabled-but-present
-- hook. This service adds no gameplay logic anywhere -- it only observes
-- (reads public getters, wraps existing functions to time them) and
-- reports; RecommendationEngine/InsightEngine/every gameplay module remain
-- completely unaware this service exists.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local pairs = pairs
local ipairs = ipairs
local type = type
local time = time
local tostring = tostring

local DeveloperModeService =
{
    Name = "DeveloperModeService",
}

AC.DeveloperModeService = DeveloperModeService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local MAX_EVENT_LOG = 200

-- The curated event list the Event Monitor watches -- deliberately not
-- "every Blizzard event" (Blizzard fires thousands; WoW has no true
-- wildcard registration), a fixed, documented list covering framework
-- lifecycle, the systems this addon's own "Needs Live Verification" items
-- name (Weekly/Great Vault, Storage/Bank, Mythic+/Affixes), and the
-- general per-session events those systems' own modules already
-- register for. Mirrors DiagnosticsService's own curated-list precedent
-- (Core/Diagnostics/DiagnosticsService.lua), just broader than that
-- file's narrow Mythic+-investigation scope -- kept as a separate list
-- rather than merged into DiagnosticsService's, since the two tools have
-- different owners (Logger's trace buffer vs. this service's own Event
-- Monitor ring buffer) and different gates (a trace category selection
-- vs. the Developer Mode flag).
local MONITORED_EVENTS =
{
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_ALIVE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_RESET",
    "CHALLENGE_MODE_COMPLETED_REWARDS",
    "CHALLENGE_MODE_KEYSTONE_SLOTTED",
    "CHALLENGE_MODE_DEATH_COUNT_UPDATED",
    "CHALLENGE_MODE_MAPS_UPDATE",
    "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE",
    "MYTHIC_PLUS_NEW_WEEKLY_RECORD",
    "WEEKLY_REWARDS_UPDATE",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "ACHIEVEMENT_EARNED",
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function DeveloperModeService:ResetState()

    self.Enabled = false
    self.EventLog = {}
    self.EventListeners = {}
    self.OriginalRefresh = {}
    self.ModuleStats = {}

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function DeveloperModeService:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable (framework lifecycle -- restores whatever the player last left
-- Developer Mode set to, the same "persisted, restored on login" pattern
-- Logger's own Debug flag already uses).
-------------------------------------------------------------------------------

function DeveloperModeService:Enable()

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile and profile.DeveloperMode then
            self:SetEnabled(true)
        end

    end

end

function DeveloperModeService:Disable()

    self:SetEnabled(false)

end

function DeveloperModeService:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enabled Flag
-------------------------------------------------------------------------------

function DeveloperModeService:IsEnabled()

    return self.Enabled == true

end

function DeveloperModeService:SetEnabled(enabled)

    enabled = enabled and true or false

    if enabled == self.Enabled then
        return
    end

    self.Enabled = enabled

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile then
            profile.DeveloperMode = enabled
        end

    end

    if enabled then
        self:InstallEventMonitor()
        self:InstallRefreshInstrumentation()
    else
        self:RemoveEventMonitor()
        self:RemoveRefreshInstrumentation()
    end

    if AC.Events then
        AC.Events:Fire("DEVELOPER_MODE_CHANGED", enabled)
    end

    if AC.Logger then
        AC.Logger:Info("Developer Mode " .. (enabled and "enabled." or "disabled."))
    end

end

-------------------------------------------------------------------------------
-- Event Monitor
--
-- One real Blizzard event fired -> one ring buffer entry. Registration
-- (and, on disable, unregistration) goes through AC.Events -- the same
-- shared EventManager every module already uses, never a second raw
-- Blizzard frame of this service's own.
-------------------------------------------------------------------------------

local function FormatEventArgs(...)

    local count = select("#", ...)

    if count == 0 then
        return ""
    end

    local parts = {}

    for i = 1, count do
        table.insert(parts, tostring((select(i, ...))))
    end

    return table.concat(parts, ", ")

end

function DeveloperModeService:RecordEvent(eventName, ...)

    local entry =
    {
        event = eventName,
        timestamp = AC.Logger:GetPreciseTimestamp(),
        time = time(),
        args = FormatEventArgs(...),
    }

    table.insert(self.EventLog, entry)

    while #self.EventLog > MAX_EVENT_LOG do
        table.remove(self.EventLog, 1)
    end

    self.LastEvent = entry

end

function DeveloperModeService:InstallEventMonitor()

    self.EventLog = {}
    self.EventListeners = {}

    if not AC.Events then
        return
    end

    for _, eventName in ipairs(MONITORED_EVENTS) do

        local listener = function(...)
            self:RecordEvent(eventName, ...)
        end

        local ok = pcall(AC.Events.Register, AC.Events, eventName, listener)

        if ok then
            self.EventListeners[eventName] = listener
        end

    end

end

function DeveloperModeService:RemoveEventMonitor()

    if AC.Events then

        for eventName, listener in pairs(self.EventListeners) do
            AC.Events:Unregister(eventName, listener)
        end

    end

    self.EventListeners = {}

end

function DeveloperModeService:GetEventLog()

    return self.EventLog

end

function DeveloperModeService:ClearEventLog()

    self.EventLog = {}

end

function DeveloperModeService:GetLastEvent()

    return self.LastEvent

end

-------------------------------------------------------------------------------
-- Refresh Instrumentation
--
-- Wraps -- only while enabled -- the Refresh() method of every registered
-- Service and Module that has one, timing each call and recording its
-- outcome. The wrapper still calls the real Refresh() (via pcall, so an
-- error is observed and recorded rather than silently swallowed) --
-- nothing about WHEN or WHY a module refreshes changes, this only
-- observes it. Disabling restores every original function exactly,
-- leaving zero trace.
-------------------------------------------------------------------------------

local function GetTimingClock()
    return debugprofilestop and debugprofilestop() or (GetTime() * 1000)
end

function DeveloperModeService:WrapRefresh(name, object)

    if type(object) ~= "table" or type(object.Refresh) ~= "function" then
        return
    end

    if self.OriginalRefresh[name] then
        return
    end

    local original = object.Refresh
    self.OriginalRefresh[name] = { object = object, fn = original }

    object.Refresh = function(selfObject, ...)

        local startedAt = GetTimingClock()
        local ok, err = pcall(original, selfObject, ...)
        local duration = GetTimingClock() - startedAt

        self.ModuleStats[name] = self.ModuleStats[name] or {}

        local stats = self.ModuleStats[name]

        stats.lastRefresh = time()
        stats.duration = duration
        stats.lastError = (not ok) and tostring(err) or stats.lastError

        if not ok and AC.Logger then
            AC.Logger:Error(("%s:Refresh() failed: %s"):format(name, tostring(err)))
        end

    end

end

function DeveloperModeService:InstallRefreshInstrumentation()

    self.OriginalRefresh = {}
    self.ModuleStats = {}

    if AC.ServiceManager then

        for _, service in ipairs(AC.ServiceManager:GetAll()) do
            self:WrapRefresh(service.Name, service)
        end

    end

    if AC.ModuleManager then

        for _, module in ipairs(AC.ModuleManager:GetAll()) do
            self:WrapRefresh(module.Name, module)
        end

    end

end

function DeveloperModeService:RemoveRefreshInstrumentation()

    for name, original in pairs(self.OriginalRefresh) do
        original.object.Refresh = original.fn
    end

    self.OriginalRefresh = {}

end

function DeveloperModeService:GetModuleStats(name)

    return self.ModuleStats[name]

end

-------------------------------------------------------------------------------
-- Force Refresh (Quality of Life)
--
-- Calls a named Service/Module's own real Refresh() directly -- through
-- the (possibly instrumented) method already on the object, never a
-- reimplementation of what refreshing means for that object.
-------------------------------------------------------------------------------

function DeveloperModeService:RefreshOne(name)

    local object = (AC.ServiceManager and AC.ServiceManager:Get(name)) or (AC.ModuleManager and AC.ModuleManager:Get(name))

    if object and type(object.Refresh) == "function" then
        object:Refresh()
        return true
    end

    return false

end

-------------------------------------------------------------------------------
-- Generic Serialization (Copy JSON / Copy Text)
--
-- Data-shape-agnostic -- every Developer Panel tab hands its own already-
-- gathered data table to these instead of writing its own encoder.
-------------------------------------------------------------------------------

local function IsArray(value)

    local count = 0

    for _ in pairs(value) do
        count = count + 1
    end

    return count == #value, count

end

local function EscapeJSONString(text)

    text = tostring(text)
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\"", "\\\"")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")

    return text

end

function DeveloperModeService:ToJSON(value)

    local valueType = type(value)

    if value == nil then
        return "null"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return "\"" .. EscapeJSONString(value) .. "\""
    elseif valueType ~= "table" then
        return "\"" .. EscapeJSONString(tostring(value)) .. "\""
    end

    local isArray = IsArray(value)
    local parts = {}

    if isArray then

        for _, item in ipairs(value) do
            table.insert(parts, self:ToJSON(item))
        end

        return "[" .. table.concat(parts, ",") .. "]"

    end

    local keys = {}

    for key in pairs(value) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, key in ipairs(keys) do
        table.insert(parts, "\"" .. EscapeJSONString(key) .. "\":" .. self:ToJSON(value[key]))
    end

    return "{" .. table.concat(parts, ",") .. "}"

end

function DeveloperModeService:ToIndentedText(value, depth)

    depth = depth or 0

    local valueType = type(value)

    if valueType ~= "table" then
        return tostring(value)
    end

    local indent = string.rep("  ", depth)
    local isArray = IsArray(value)
    local lines = {}

    if isArray then

        for index, item in ipairs(value) do

            if type(item) == "table" then
                table.insert(lines, indent .. "- [" .. index .. "]\n" .. self:ToIndentedText(item, depth + 1))
            else
                table.insert(lines, indent .. "- " .. tostring(item))
            end

        end

        return table.concat(lines, "\n")

    end

    local keys = {}

    for key in pairs(value) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, key in ipairs(keys) do

        local fieldValue = value[key]

        if type(fieldValue) == "table" then
            table.insert(lines, indent .. tostring(key) .. ":\n" .. self:ToIndentedText(fieldValue, depth + 1))
        else
            table.insert(lines, indent .. tostring(key) .. ": " .. tostring(fieldValue))
        end

    end

    return table.concat(lines, "\n")

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("DeveloperModeService", DeveloperModeService)

return DeveloperModeService
