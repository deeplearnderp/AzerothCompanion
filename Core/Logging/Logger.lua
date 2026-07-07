-------------------------------------------------------------------------------
-- Azeroth Companion
-- Logger
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Logger = {}
AC.Logger = Logger

Logger.PREFIX = "|cff33ff99[Azeroth Companion]|r"

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

function Logger:IsDebugEnabled()

    if AC.Debug then
        return true
    end

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile and profile.Debug then
            return true
        end

    end

    return false

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Logger:Initialize()

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile then
            AC.Debug = profile.Debug == true
        end

    end

end

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------

function Logger:Info(message)
    print(self.PREFIX .. " " .. tostring(message))
end

function Logger:Warn(message)
    print("|cffffff00[Azeroth Companion]|r " .. tostring(message))
end

function Logger:Error(message)
    print("|cffff3333[Azeroth Companion]|r " .. tostring(message))
end

function Logger:Debug(message)

    if not self:IsDebugEnabled() then
        return
    end

    print("|cff66ccff[Azeroth Companion][Debug]|r " .. tostring(message))

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("Logger", Logger)

return Logger
