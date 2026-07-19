-------------------------------------------------------------------------------
-- Azeroth Companion
-- Slash Command Manager
--
-- Parses chat input only. User-facing action orchestration belongs to
-- UserActionService so slash commands and UI controls cannot drift.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SlashCommandManager = {}
AC.SlashCommandManager = SlashCommandManager

function SlashCommandManager:HandleDebug(argument)

    if argument == "on" then
        AC.UserActionService:SetDebugLoggingEnabled(true)
    elseif argument == "off" then
        AC.UserActionService:SetDebugLoggingEnabled(false)
    else
        AC.Logger:Warn("Usage: /ac debug on|off")
    end

end


function SlashCommandManager:HandleTrace(argument)

    local category = AC.UserActionService:ResolveTraceCategory(argument)

    if argument == "off" then
        AC.UserActionService:DisableAllTracing()
    elseif argument == "all" then
        AC.UserActionService:EnableAllTracing()
    elseif category then
        AC.UserActionService:EnableTraceCategory(category, true)
    else
        AC.Logger:Warn("Usage: /ac trace mythic|all|off")
    end

end


function SlashCommandManager:HandleDev(argument)

    if argument == "on" then

        if AC.UserActionService:SetDeveloperModeEnabled(true) and AC.DeveloperPanel then
            AC.DeveloperPanel:Show()
        end

    elseif argument == "off" then
        AC.UserActionService:SetDeveloperModeEnabled(false)
    elseif argument == "" then

        if AC.UserActionService:IsDeveloperModeEnabled() and AC.DeveloperPanel then
            AC.DeveloperPanel:Toggle()
        else
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
        end

    elseif argument == "testerror" then

        if not AC.UserActionService:IsDeveloperModeEnabled() then
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
            return
        end

        AC.UserActionService:GenerateTestError()

    elseif argument == "clearerrors" then

        if not AC.UserActionService:IsDeveloperModeEnabled() then
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
            return
        end

        AC.UserActionService:ClearCapturedErrors()

    else
        AC.Logger:Warn("Usage: /ac dev on|off|testerror|clearerrors")
    end

end

function SlashCommandManager:HandleCombatSession(argument)
    local service = AC.CombatSessionService

    if not service then
        AC.Logger:Warn("CombatSessionService is unavailable.")
        return
    end

    if argument ~= "" and argument ~= "detail" then
        AC.Logger:Warn("Usage: /ac combatsession [detail]")
        return
    end

    service:Refresh("slash-command")

    local diagnostics = service:GetDiagnostics()
    local latest = service:GetLatestSession()
    local lastRefresh = diagnostics.lastRefreshTime and string.format("%.1f", diagnostics.lastRefreshTime) or "none"

    AC.Logger:Info("CombatSessionService")
    AC.Logger:Info(("Lifecycle: initialized=%s enabled=%s API available=%s"):format(
        tostring(diagnostics.initialized == true),
        tostring(diagnostics.enabled == true),
        tostring(diagnostics.available == true)
    ))
    AC.Logger:Info(("Updates: %d | resets: %d | refreshes: %d | last=%s (%s)"):format(
        diagnostics.updateCount or 0,
        diagnostics.resetCount or 0,
        diagnostics.refreshCount or 0,
        diagnostics.lastReason or "none",
        lastRefresh
    ))
    AC.Logger:Info(("Cache: %d/%d | available: %d | observed: %d | evicted: %d"):format(
        diagnostics.cachedSessionCount or 0,
        diagnostics.cacheLimit or 0,
        diagnostics.availableSessionCount or 0,
        diagnostics.totalSessionsObserved or 0,
        diagnostics.evictedSessionCount or 0
    ))
    AC.Logger:Info(("Errors: session queries=%d | recaps=%d | last=%s"):format(
        diagnostics.queryErrors or 0,
        diagnostics.recapErrors or 0,
        diagnostics.lastError or "none"
    ))

    if not latest then
        AC.Logger:Info("Latest session: none")
        return
    end

    AC.Logger:Info(("Latest session: %s | %s | duration=%s | participants=%d | deaths=%d | available=%s"):format(
        tostring(latest.sessionID),
        latest.name or "unnamed",
        latest.durationSeconds and string.format("%.1fs", latest.durationSeconds) or "unavailable",
        latest.participantCount or 0,
        latest.deathCount or 0,
        tostring(latest.isAvailable == true)
    ))

    if argument ~= "detail" then
        return
    end

    AC.Logger:Info("Participants")

    for index, participant in ipairs(latest.participants or {}) do
        AC.Logger:Info(("  %d. %s | GUID=%s | class=%s | local=%s | displayType=%s"):format(
            index,
            participant.name or "unnamed",
            participant.sourceGUID or "unavailable",
            participant.classFilename or "unavailable",
            tostring(participant.isLocalPlayer == true),
            tostring(participant.sourceDisplayType or "unavailable")
        ))
    end

    AC.Logger:Info("Deaths")

    for index, death in ipairs(latest.deaths or {}) do
        AC.Logger:Info(("  %d. %s | GUID=%s | time=%s | recapID=%s | recap=%s | events=%s"):format(
            index,
            death.name or "unnamed",
            death.sourceGUID or "unavailable",
            death.deathTimeSeconds and string.format("%.1fs", death.deathTimeSeconds) or "unavailable",
            tostring(death.deathRecapID or "unavailable"),
            death.recap and tostring(death.recap.available == true) or "unavailable",
            death.recap and tostring(death.recap.eventCount or "unavailable") or "unavailable"
        ))
    end

end


function SlashCommandManager:Enable()

    SLASH_AZEROTHCOMPANION1 = "/ac"
    SLASH_AZEROTHCOMPANION2 = "/azeroth"

    SlashCmdList["AZEROTHCOMPANION"] = function(message)

        message = string.lower(message or "")

        if message == "" or message == "dashboard" then

            if not AC.UserActionService:ToggleDashboard() then
                AC.Logger:Warn("Dashboard not available.")
            end

            return

        end

        local command, argument = message:match("^(%S+)%s*(.-)$")
        command = command or ""
        argument = argument or ""

        if command == "help" then
            AC.Logger:Info("Commands: /ac, /ac dashboard, /ac settings, /ac debug on|off, /ac log, /ac clearlog, /ac trace mythic|all|off, /ac dev on|off, /ac combatsession [detail], /ac help")
        elseif command == "config" or command == "settings" then

            if not AC.UserActionService:OpenSettings() then
                AC.Logger:Warn("Settings window not available.")
            end

        elseif command == "debug" then
            SlashCommandManager:HandleDebug(argument)
        elseif command == "log" then

            if not AC.UserActionService:OpenLog() then
                AC.Logger:Warn("Diagnostics window not available.")
            end

        elseif command == "clearlog" then
            AC.UserActionService:ClearLog()
        elseif command == "dev" then
            SlashCommandManager:HandleDev(argument)
        elseif command == "trace" then
            SlashCommandManager:HandleTrace(argument)
        elseif command == "combatsession" then
            SlashCommandManager:HandleCombatSession(argument)

        else
            AC.Logger:Warn("Unknown command. Type /ac help for commands.")
        end

    end

end


AC.ServiceManager:Register("SlashCommandManager", SlashCommandManager)

return SlashCommandManager
