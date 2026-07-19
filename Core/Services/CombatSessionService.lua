-------------------------------------------------------------------------------
-- Azeroth Companion
-- Combat Session Service
--
-- Shared, context-free owner of Blizzard's supported Retail combat-session
-- data. This service normalizes transient C_DamageMeter/C_DeathRecap results
-- in memory and exposes copies to consumers. It does not infer gameplay
-- context, write SavedVariables, or retain Blizzard-owned result objects.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local CombatSessionService = {}
AC.CombatSessionService = CombatSessionService

local MAX_CACHED_SESSIONS = 20
local DAMAGE_DONE = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
local DEATHS = Enum and Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ReadValue(value)
    if value == nil or IsSecret(value) then
        return nil
    end

    return value
end

local function Call(api, ...)
    if type(api) ~= "function" then
        return nil, "API unavailable"
    end

    local ok, result = pcall(api, ...)

    if not ok then
        return nil, tostring(result)
    end

    if IsSecret(result) then
        return nil, "secret result"
    end

    return result
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, child in pairs(value) do
        result[key] = Copy(child)
    end

    return result
end

local function GetMeterSession(sessionID, meterType)
    if not C_DamageMeter then
        return nil, "C_DamageMeter unavailable"
    end

    return Call(C_DamageMeter.GetCombatSessionFromID, sessionID, meterType)
end

local function ReadRecap(recapID, diagnostics)
    local recap =
    {
        available = false,
    }

    if not C_DeathRecap then
        diagnostics.recapErrors = diagnostics.recapErrors + 1
        return recap
    end

    local hasEvents, hasEventsError = Call(C_DeathRecap.HasRecapEvents, recapID)

    if hasEventsError then
        diagnostics.recapErrors = diagnostics.recapErrors + 1
        return recap
    end

    recap.available = hasEvents == true

    if recap.available then
        local events, eventsError = Call(C_DeathRecap.GetRecapEvents, recapID)

        if type(events) == "table" and not IsSecret(events) then
            recap.eventCount = #events
        elseif eventsError then
            diagnostics.recapErrors = diagnostics.recapErrors + 1
        end
    end

    return recap
end

local function GetParticipantKey(source, index)
    return ReadValue(source.sourceGUID)
        or ReadValue(source.name)
        or ("source:" .. index)
end

local function AddParticipant(participantsByKey, source, index)
    local key = GetParticipantKey(source, index)
    local participant = participantsByKey[key]

    if not participant then
        participant =
        {
            sourceGUID = ReadValue(source.sourceGUID),
            name = ReadValue(source.name),
            classFilename = ReadValue(source.classFilename),
            isLocalPlayer = ReadValue(source.isLocalPlayer),
            sourceDisplayType = ReadValue(source.sourceDisplayType),
        }
        participantsByKey[key] = participant
    end

    return participant
end

local function AddParticipants(participantsByKey, meterSession)
    local sources = meterSession and ReadValue(meterSession.combatSources)

    if type(sources) ~= "table" then
        return
    end

    for index = 1, #sources do
        local source = ReadValue(sources[index])

        if type(source) == "table" then
            AddParticipant(participantsByKey, source, index)
        end
    end
end

local function AddDeaths(deaths, participantsByKey, meterSession, diagnostics)
    local sources = meterSession and ReadValue(meterSession.combatSources)

    if type(sources) ~= "table" then
        return
    end

    for index = 1, #sources do
        local source = ReadValue(sources[index])

        if type(source) == "table" then
            local participant = AddParticipant(participantsByKey, source, index)
            local recapID = ReadValue(source.deathRecapID)
            local death =
            {
                sourceGUID = participant.sourceGUID,
                name = participant.name,
                classFilename = participant.classFilename,
                isLocalPlayer = participant.isLocalPlayer,
                deathTimeSeconds = ReadValue(source.deathTimeSeconds),
                deathRecapID = recapID,
            }

            if type(recapID) == "number" and recapID >= 0 then
                death.recap = ReadRecap(recapID, diagnostics)
            end

            deaths[#deaths + 1] = death
        end
    end
end

local function SortParticipants(left, right)
    return (left.name or left.sourceGUID or "") < (right.name or right.sourceGUID or "")
end

local function SortDeaths(left, right)
    local leftTime = left.deathTimeSeconds
    local rightTime = right.deathTimeSeconds

    if type(leftTime) == "number" and type(rightTime) == "number" then
        return leftTime < rightTime
    end

    return type(leftTime) == "number"
end

function CombatSessionService:Initialize()
    self.Sessions = {}
    self.SessionOrder = {}
    self.LatestSessionID = nil
    self.Diagnostics =
    {
        initialized = true,
        enabled = false,
        refreshCount = 0,
        updateCount = 0,
        resetCount = 0,
        totalSessionsObserved = 0,
        evictedSessionCount = 0,
        queryErrors = 0,
        recapErrors = 0,
        lastReason = nil,
        lastRefreshTime = nil,
        lastError = nil,
    }
end

function CombatSessionService:Enable()
    AC.Events:Register("DAMAGE_METER_COMBAT_SESSION_UPDATED", self)
    AC.Events:Register("DAMAGE_METER_RESET", self)
    self.Diagnostics.enabled = true
    self:Refresh("enable")
end

function CombatSessionService:Disable()
    AC.Events:UnregisterAll(self)
    self.Diagnostics.enabled = false
end

function CombatSessionService:Shutdown()
    self:Disable()
    self:Initialize()
end

function CombatSessionService:IsAvailable()
    if not C_DamageMeter or not C_DamageMeter.IsDamageMeterAvailable then
        return false
    end

    local available = Call(C_DamageMeter.IsDamageMeterAvailable)
    return available == true
end

function CombatSessionService:NormalizeSession(availableSession)
    local sessionID = ReadValue(availableSession.sessionID)

    if type(sessionID) ~= "number" then
        return nil
    end

    local damageSession, damageError = GetMeterSession(sessionID, DAMAGE_DONE)
    local deathSession, deathError = GetMeterSession(sessionID, DEATHS)
    local participantsByKey = {}
    local deaths = {}

    if damageError then
        self.Diagnostics.queryErrors = self.Diagnostics.queryErrors + 1
    end

    if deathError then
        self.Diagnostics.queryErrors = self.Diagnostics.queryErrors + 1
    end

    AddParticipants(participantsByKey, damageSession)
    AddDeaths(deaths, participantsByKey, deathSession, self.Diagnostics)

    local participants = {}

    for _, participant in pairs(participantsByKey) do
        participants[#participants + 1] = participant
    end

    table.sort(participants, SortParticipants)
    table.sort(deaths, SortDeaths)

    return
    {
        sessionID = sessionID,
        name = ReadValue(availableSession.name),
        durationSeconds = damageSession and ReadValue(damageSession.durationSeconds) or nil,
        participants = participants,
        participantCount = #participants,
        deaths = deaths,
        deathCount = #deaths,
        isAvailable = true,
        updatedAt = GetTime(),
    }
end

function CombatSessionService:Refresh(reason, updatedSessionID)
    self.Diagnostics.refreshCount = self.Diagnostics.refreshCount + 1
    self.Diagnostics.lastReason = reason
    self.Diagnostics.lastRefreshTime = GetTime()
    self.Diagnostics.lastError = nil

    local available
    local queryError

    if C_DamageMeter then
        available, queryError = Call(C_DamageMeter.GetAvailableCombatSessions)
    else
        queryError = "C_DamageMeter unavailable"
    end

    if type(available) ~= "table" then
        self.Diagnostics.queryErrors = self.Diagnostics.queryErrors + 1
        self.Diagnostics.lastError = queryError or "Combat sessions unavailable"

        if AC.Logger then
            AC.Logger:Debug("CombatSessionService refresh unavailable: " .. self.Diagnostics.lastError, "CombatSession")
        end

        return false
    end

    for _, session in pairs(self.Sessions) do
        session.isAvailable = false
    end

    for index = 1, #available do
        local availableSession = ReadValue(available[index])
        local session = type(availableSession) == "table" and self:NormalizeSession(availableSession) or nil

        if session then
            local isNew = self.Sessions[session.sessionID] == nil
            self.Sessions[session.sessionID] = session

            if isNew then
                self.SessionOrder[#self.SessionOrder + 1] = session.sessionID
                self.Diagnostics.totalSessionsObserved = self.Diagnostics.totalSessionsObserved + 1
            end

            if session.sessionID == updatedSessionID or not self.LatestSessionID then
                self.LatestSessionID = session.sessionID
            end
        end
    end

    while #self.SessionOrder > MAX_CACHED_SESSIONS do
        local oldestSessionID = table.remove(self.SessionOrder, 1)
        self.Sessions[oldestSessionID] = nil
        self.Diagnostics.evictedSessionCount = self.Diagnostics.evictedSessionCount + 1
    end

    if self.LatestSessionID and not self.Sessions[self.LatestSessionID] then
        self.LatestSessionID = self.SessionOrder[#self.SessionOrder]
    end

    if not updatedSessionID and #available > 0 then
        local newest = ReadValue(available[#available])
        local newestSessionID = type(newest) == "table" and ReadValue(newest.sessionID) or nil

        if type(newestSessionID) == "number" then
            self.LatestSessionID = newestSessionID
        end
    end

    return true
end

function CombatSessionService:OnDamageMeterCombatSessionUpdated(_, sessionID)
    self.Diagnostics.updateCount = self.Diagnostics.updateCount + 1
    self.Diagnostics.lastUpdatedSessionID = ReadValue(sessionID)
    self:Refresh("session-updated", ReadValue(sessionID))
end

function CombatSessionService:OnDamageMeterReset()
    self.Diagnostics.resetCount = self.Diagnostics.resetCount + 1
    self:Refresh("damage-meter-reset")
end

function CombatSessionService:GetSession(sessionID)
    return Copy(self.Sessions[sessionID])
end

function CombatSessionService:GetSessions()
    local sessions = {}

    for index = 1, #self.SessionOrder do
        local session = self.Sessions[self.SessionOrder[index]]

        if session then
            sessions[#sessions + 1] = Copy(session)
        end
    end

    return sessions
end

function CombatSessionService:GetLatestSession()
    return self:GetSession(self.LatestSessionID)
end

function CombatSessionService:GetDiagnostics()
    local diagnostics = Copy(self.Diagnostics)
    local availableSessionCount = 0

    for _, session in pairs(self.Sessions) do
        if session.isAvailable then
            availableSessionCount = availableSessionCount + 1
        end
    end

    local latestSession = self.Sessions[self.LatestSessionID]

    diagnostics.cacheLimit = MAX_CACHED_SESSIONS
    diagnostics.cachedSessionCount = #self.SessionOrder
    diagnostics.availableSessionCount = availableSessionCount
    diagnostics.latestSessionID = self.LatestSessionID
    diagnostics.latestParticipantCount = latestSession and latestSession.participantCount or 0
    diagnostics.latestDeathCount = latestSession and latestSession.deathCount or 0
    diagnostics.available = self:IsAvailable()
    return diagnostics
end

AC.ServiceManager:Register("CombatSessionService", CombatSessionService)

return CombatSessionService
