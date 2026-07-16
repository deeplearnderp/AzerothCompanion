-------------------------------------------------------------------------------
-- Azeroth Companion
-- Slash Command Manager
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SlashCommandManager = {}
AC.SlashCommandManager = SlashCommandManager

-------------------------------------------------------------------------------
-- Trace Category Aliases
--
-- Short slash-command words map to Logger's canonical category names.
-------------------------------------------------------------------------------

local TRACE_CATEGORY_ALIASES =
{
    mythic = "Mythic+",
    inventory = "Inventory",
    events = "Events",
}

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

function SlashCommandManager:HandleDebug(argument)

    if argument == "on" then

        AC.Logger:SetDebugEnabled(true)
        AC.Logger:Info("Debug mode enabled.")

    elseif argument == "off" then

        AC.Logger:SetDebugEnabled(false)
        AC.Logger:Info("Debug mode disabled.")

    else

        AC.Logger:Warn("Usage: /ac debug on|off")

    end

end

-------------------------------------------------------------------------------
-- Log Window
-------------------------------------------------------------------------------

function SlashCommandManager:HandleLog()

    if AC.DiagnosticsWindow then
        AC.DiagnosticsWindow:Toggle()
    else
        AC.Logger:Warn("Diagnostics window not available.")
    end

end

function SlashCommandManager:HandleClearLog()

    AC.Logger:ClearBuffer()
    AC.Logger:Info("Diagnostic log cleared.")

    if AC.DiagnosticsWindow and AC.DiagnosticsWindow.Refresh then
        AC.DiagnosticsWindow:Refresh()
    end

end

-------------------------------------------------------------------------------
-- Trace
--
-- Selecting a category is exclusive ("Only Mythic+", "Only Inventory", ...)
-- -- it replaces whatever was previously traced rather than adding to it.
-- Selecting any category (or "all") also turns on the debug master switch,
-- since a trace selection with debug still off would silently produce
-- nothing.
-------------------------------------------------------------------------------

function SlashCommandManager:HandleTrace(argument)

    if argument == "off" then

        AC.Logger:DisableAllTrace()
        AC.Logger:Info("Tracing disabled.")

        return

    end

    if argument == "all" then

        AC.Logger:SetDebugEnabled(true)
        AC.Logger:EnableAllTrace()
        AC.Logger:Info("Tracing all categories.")

        return

    end

    local category = TRACE_CATEGORY_ALIASES[argument]

    if not category then

        AC.Logger:Warn("Usage: /ac trace mythic|inventory|events|all|off")

        return

    end

    AC.Logger:SetDebugEnabled(true)
    AC.Logger:DisableAllTrace()
    AC.Logger:SetTraceCategory(category, true)
    AC.Logger:Info("Tracing category: " .. category)

end

-------------------------------------------------------------------------------
-- Developer Mode
-------------------------------------------------------------------------------

function SlashCommandManager:HandleDev(argument)

    if not AC.DeveloperModeService then

        AC.Logger:Warn("Developer Mode is not available.")
        return

    end

    if argument == "on" then

        AC.DeveloperModeService:SetEnabled(true)

        if AC.DeveloperPanel then
            AC.DeveloperPanel:Show()
        end

    elseif argument == "off" then

        AC.DeveloperModeService:SetEnabled(false)

        if AC.DeveloperPanel then
            AC.DeveloperPanel:Hide()
        end

    elseif argument == "" then

        if AC.DeveloperModeService:IsEnabled() then

            if AC.DeveloperPanel then
                AC.DeveloperPanel:Toggle()
            end

        else
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
        end

    elseif argument == "testerror" then

        -- Developer Test Harness -- deliberately a real, uncaught error()
        -- call (not routed through any pcall of our own), so it reaches
        -- the global error handler exactly the way a genuine bug would,
        -- validating the real capture/aggregation/chaining pipeline
        -- end-to-end rather than a simulation of it. Same source line
        -- every time, so repeated invocations exercise occurrence-count
        -- aggregation; any other real error encountered separately
        -- exercises the "different error creates a new entry" path.
        if not AC.DeveloperModeService:IsEnabled() then
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
            return
        end

        error("Azeroth Companion Developer Runtime test error (/ac dev testerror).")

    elseif argument == "clearerrors" then

        if not AC.DeveloperModeService:IsEnabled() then
            AC.Logger:Warn("Developer Mode is off. Usage: /ac dev on|off")
            return
        end

        local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")

        if errorCapture then
            errorCapture:ClearErrors()
            AC.Logger:Info("Developer Runtime: captured errors cleared.")
        end

    else
        AC.Logger:Warn("Usage: /ac dev on|off|testerror|clearerrors")
    end

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function SlashCommandManager:Enable()

    SLASH_AZEROTHCOMPANION1 = "/ac"
    SLASH_AZEROTHCOMPANION2 = "/azeroth"

    SlashCmdList["AZEROTHCOMPANION"] = function(message)

        message = string.lower(message or "")

        if message == ""
        or message == "dashboard" then

            if AC.Dashboard then
                AC.Dashboard:Toggle()
            else
                AC.Logger:Warn("Dashboard not available.")
            end

            return

        end

        local command, argument = message:match("^(%S+)%s*(.-)$")
        command = command or ""
        argument = argument or ""

        if command == "help" then

            AC.Logger:Info("Commands: /ac, /ac dashboard, /ac settings, /ac debug on|off, /ac log, /ac clearlog, /ac trace mythic|inventory|events|all|off, /ac dev on|off, /ac help")
            return

        end

        if command == "config"
        or command == "settings" then

            local window = AC.Core:GetModule("SettingsWindow")

            if window then
                window:Toggle()
            end

            return
        end

        if command == "debug" then
            SlashCommandManager:HandleDebug(argument)
            return
        end

        if command == "log" then
            SlashCommandManager:HandleLog()
            return
        end

        if command == "clearlog" then
            SlashCommandManager:HandleClearLog()
            return
        end

        if command == "dev" then
            SlashCommandManager:HandleDev(argument)
            return
        end

        if command == "trace" then
            SlashCommandManager:HandleTrace(argument)
            return
        end

        AC.Logger:Warn("Unknown command. Type /ac help for commands.")

    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("SlashCommandManager", SlashCommandManager)

return SlashCommandManager
