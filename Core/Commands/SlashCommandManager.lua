-------------------------------------------------------------------------------
-- Azeroth Companion
-- Slash Command Manager
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SlashCommandManager = {}
AC.SlashCommandManager = SlashCommandManager

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function SlashCommandManager:Enable()

    SLASH_AZEROTHCOMPANION1 = "/ac"
    SLASH_AZEROTHCOMPANION2 = "/azeroth"

    SlashCmdList["AZEROTHCOMPANION"] = function(message)

        message = string.lower(message or "")

        if message == "help" then

            AC.Logger:Info("Commands: /ac, /ac settings, /ac dashboard, /ac help")
            return

        end

        if message == "dashboard"
        or message == "" then

            if AC.Dashboard then
                AC.Dashboard:Toggle()
            else
                AC.Logger:Warn("Dashboard not available.")
            end

            return

        end

        if message == "config"
        or message == "settings" then

            local window = AC.Core:GetModule("SettingsWindow")

            if window then
                window:Toggle()
            end

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
