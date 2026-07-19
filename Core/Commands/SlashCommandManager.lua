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
            AC.Logger:Info("Commands: /ac, /ac dashboard, /ac settings, /ac debug on|off, /ac log, /ac clearlog, /ac trace mythic|all|off, /ac dev on|off, /ac help")
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
        else
            AC.Logger:Warn("Unknown command. Type /ac help for commands.")
        end

    end

end


AC.ServiceManager:Register("SlashCommandManager", SlashCommandManager)

return SlashCommandManager
