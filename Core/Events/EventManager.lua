-------------------------------------------------------------------------------
-- Azeroth Companion
-- Event Manager
--
-- Centralized event routing for Blizzard and framework events.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local pcall = pcall
local tinsert = table.insert
local tremove = table.remove
local strbyte = string.byte
local strsub = string.sub
local strupper = string.upper
local strlower = string.lower

local EventManager = {}
AC.EventManager = EventManager
AC.Events = EventManager

-------------------------------------------------------------------------------
-- Framework Events
-------------------------------------------------------------------------------

EventManager.FrameworkEvents =
{
    "FRAMEWORK_INITIALIZED",
    "PROFILE_CHANGED",
    "MODULE_ENABLED",
    "MODULE_DISABLED",
    "SETTINGS_CHANGED",
}

local FrameworkEventSet = {}

for i = 1, #EventManager.FrameworkEvents do
    FrameworkEventSet[EventManager.FrameworkEvents[i]] = true
end

EventManager.FrameworkEventSet = FrameworkEventSet

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

EventManager.Listeners = {}
EventManager.ListenerIndex = {}
EventManager.BlizzardRegistered = {}
EventManager.IsDispatching = false
EventManager.DispatchDepth = 0
EventManager.Enabled = false

local Frame

-------------------------------------------------------------------------------
-- Utilities
-------------------------------------------------------------------------------

local function EventToMethod(event)

    local method = "On"
    local partStart = 1
    local length = #event

    for i = 1, length + 1 do

        local byte = i <= length and strbyte(event, i) or 95

        if byte == 95 then

            if i > partStart then

                local part = strsub(event, partStart, i - 1)
                local first = strupper(strsub(part, 1, 1))
                local rest = strlower(strsub(part, 2))

                method = method .. first .. rest

            end

            partStart = i + 1

        end

    end

    return method

end

local function GetListeners(self, event)

    local listeners = self.Listeners[event]

    if not listeners then
        listeners = {}
        self.Listeners[event] = listeners
    end

    return listeners

end

local function TrackListener(self, listener, entry)

    local index = self.ListenerIndex[listener]

    if not index then
        index = {}
        self.ListenerIndex[listener] = index
    end

    tinsert(index, entry)

end

local function UntrackListener(self, listener, entry)

    local index = self.ListenerIndex[listener]

    if not index then
        return
    end

    for i = 1, #index do

        if index[i] == entry then
            tremove(index, i)
            break
        end

    end

    if #index == 0 then
        self.ListenerIndex[listener] = nil
    end

end

local function RemoveEntry(self, event, entry)

    local listeners = self.Listeners[event]

    if not listeners then
        return
    end

    local index = entry.index
    local lastIndex = #listeners

    if index < 1 or index > lastIndex then
        return
    end

    if index ~= lastIndex then

        local lastEntry = listeners[lastIndex]

        listeners[index] = lastEntry
        lastEntry.index = index

    end

    listeners[lastIndex] = nil

    UntrackListener(self, entry.listener, entry)

    if #listeners == 0 then

        self.Listeners[event] = nil

        if not FrameworkEventSet[event]
        and self.BlizzardRegistered[event]
        and Frame then

            Frame:UnregisterEvent(event)
            self.BlizzardRegistered[event] = nil

        end

    end

end

local function RegisterBlizzardEvent(self, event)

    if FrameworkEventSet[event] then
        return
    end

    if self.BlizzardRegistered[event] then
        return
    end

    if not Frame then
        return
    end

    Frame:RegisterEvent(event)
    self.BlizzardRegistered[event] = true

end

local function DispatchEntry(self, entry, ...)

    if entry.isFunction then

        local ok, err = pcall(entry.listener, ...)

        if not ok and AC.Logger then
            AC.Logger:Error(("Event callback failed for '%s': %s"):format(entry.event, tostring(err)))
        end

        return

    end

    local handler = entry.listener[entry.method]

    if not handler then
        return
    end

    local ok, err = pcall(handler, entry.listener, ...)

    if not ok and AC.Logger then
        AC.Logger:Error(("Event handler '%s' failed for '%s': %s"):format(entry.method, entry.event, tostring(err)))
    end

end

-------------------------------------------------------------------------------
-- Blizzard Dispatch
-------------------------------------------------------------------------------

function EventManager:DispatchBlizzard(event, ...)

    local listeners = self.Listeners[event]

    if not listeners then
        return
    end

    self.DispatchDepth = self.DispatchDepth + 1
    self.IsDispatching = true

    local count = #listeners

    for i = 1, count do
        DispatchEntry(self, listeners[i], ...)
    end

    self.DispatchDepth = self.DispatchDepth - 1

    if self.DispatchDepth == 0 then
        self.IsDispatching = false
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

function EventManager:Register(event, listener, method)

    if type(event) ~= "string" or event == "" then
        error("Events:Register() requires a valid event name.")
    end

    if self.IsDispatching then

        if AC.Logger then
            AC.Logger:Error(("Events:Register() called during dispatch for '%s'."):format(event))
        end

        return false

    end

    local listenerType = type(listener)

    if listenerType ~= "table" and listenerType ~= "function" then
        error("Events:Register() requires a table or function listener.")
    end

    local listeners = GetListeners(self, event)
    local resolvedMethod
    local isFunction = listenerType == "function"

    if isFunction then

        if method ~= nil then
            error("Events:Register() method argument is invalid for function listeners.")
        end

    elseif type(method) == "string" then

        resolvedMethod = method

    else

        resolvedMethod = EventToMethod(event)

    end

    for i = 1, #listeners do

        local entry = listeners[i]

        if entry.listener == listener and entry.method == resolvedMethod and entry.isFunction == isFunction then
            return false
        end

    end

    local entry =
    {
        listener = listener,
        method = resolvedMethod,
        isFunction = isFunction,
        event = event,
        index = #listeners + 1,
    }

    tinsert(listeners, entry)
    TrackListener(self, listener, entry)

    if not FrameworkEventSet[event] and self.Enabled then
        RegisterBlizzardEvent(self, event)
    end

    return true

end

-------------------------------------------------------------------------------
-- Unregister
-------------------------------------------------------------------------------

function EventManager:Unregister(event, listener, method)

    if type(event) ~= "string" or event == "" then
        return false
    end

    if self.IsDispatching then

        if AC.Logger then
            AC.Logger:Error(("Events:Unregister() called during dispatch for '%s'."):format(event))
        end

        return false

    end

    local listeners = self.Listeners[event]

    if not listeners then
        return false
    end

    local listenerType = type(listener)
    local isFunction = listenerType == "function"
    local resolvedMethod

    if not isFunction and listenerType == "table" and type(method) == "string" then
        resolvedMethod = method
    end

    local removed = false

    for i = #listeners, 1, -1 do

        local entry = listeners[i]

        if entry.listener ~= listener then
            -- continue
        elseif isFunction and entry.isFunction then

            RemoveEntry(self, event, entry)
            removed = true
            break

        elseif not isFunction and not entry.isFunction then

            if resolvedMethod == nil or entry.method == resolvedMethod then
                RemoveEntry(self, event, entry)
                removed = true

                if resolvedMethod ~= nil then
                    break
                end
            end

        end

    end

    return removed

end

-------------------------------------------------------------------------------
-- Unregister All
-------------------------------------------------------------------------------

function EventManager:UnregisterAll(listener)

    if listener == nil then
        return false
    end

    if self.IsDispatching then

        if AC.Logger then
            AC.Logger:Error("Events:UnregisterAll() called during dispatch.")
        end

        return false

    end

    local index = self.ListenerIndex[listener]

    if not index then
        return false
    end

    while #index > 0 do
        RemoveEntry(self, index[1].event, index[1])
    end

    return true

end

-------------------------------------------------------------------------------
-- Has Subscribers
-------------------------------------------------------------------------------

function EventManager:HasSubscribers(event)

    local listeners = self.Listeners[event]

    return listeners ~= nil and #listeners > 0

end

-------------------------------------------------------------------------------
-- Fire
-------------------------------------------------------------------------------

function EventManager:Fire(event, ...)

    if not FrameworkEventSet[event] then

        if AC.Logger then
            AC.Logger:Warn(("Events:Fire() called with non-framework event '%s'."):format(event))
        end

        return false

    end

    local listeners = self.Listeners[event]

    if not listeners then
        return false
    end

    self.DispatchDepth = self.DispatchDepth + 1
    self.IsDispatching = true

    local count = #listeners

    for i = 1, count do
        DispatchEntry(self, listeners[i], ...)
    end

    self.DispatchDepth = self.DispatchDepth - 1

    if self.DispatchDepth == 0 then
        self.IsDispatching = false
    end

    return true

end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function EventManager:Initialize()

    if self.Initialized then
        return
    end

    Frame = CreateFrame("Frame")
    Frame:Hide()

    Frame:SetScript("OnEvent", function(_, event, ...)
        EventManager:DispatchBlizzard(event, ...)
    end)

    self.Frame = Frame
    self.Initialized = true

    if AC.Logger then
        AC.Logger:Debug("EventManager initialized.")
    end

end

function EventManager:Enable()

    self.Enabled = true

    for event, listeners in pairs(self.Listeners) do

        if not FrameworkEventSet[event] and listeners and #listeners > 0 then
            RegisterBlizzardEvent(self, event)
        end

    end

    if AC.Logger then
        AC.Logger:Debug("EventManager enabled.")
    end

end

function EventManager:Disable()

    if Frame then

        for event in pairs(self.BlizzardRegistered) do
            Frame:UnregisterEvent(event)
        end

    end

    self.BlizzardRegistered = {}
    self.Enabled = false

    if AC.Logger then
        AC.Logger:Debug("EventManager disabled.")
    end

end

function EventManager:Shutdown()

    if self.IsDispatching then
        return
    end

    self:Disable()

    for event, listeners in pairs(self.Listeners) do

        while #listeners > 0 do
            RemoveEntry(self, event, listeners[1])
        end

    end

    self.Listeners = {}
    self.ListenerIndex = {}

    if Frame then
        Frame:SetScript("OnEvent", nil)
        Frame:Hide()
        Frame = nil
        self.Frame = nil
    end

    self.Initialized = false

    if AC.Logger then
        AC.Logger:Debug("EventManager shut down.")
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("EventManager", EventManager)

return EventManager
