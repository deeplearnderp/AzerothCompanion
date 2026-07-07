-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Module
--
-- Framework validation module for player zone and coordinate tracking.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local PlayerModule =
{
    Name = "Player",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
    showCoordinates = true,
    showZoneName = true,
    updateInterval = 1.0,
    coordinatePrecision = 2,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function PlayerModule:ResetState()

    self.State =
    {
        Zone = "",
        SubZone = "",
        Coordinates =
        {
            x = 0,
            y = 0,
            mapID = 0,
        },
        IsMoving = false,
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function PlayerModule:Initialize()

    self:ResetState()

    AC.ConfigurationManager:Register("Player", Defaults)

    AC.Settings:RegisterPage("Player",
    {
        title = "Player",
        module = "Player",
        order = 20,
    })

    AC.Settings:RegisterSection("Player", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Player", "General",
    {
        key = "enabled",
        text = "Enable Player Module",
        default = true,
        tooltip = "Enable player zone and coordinate tracking.",
    })

    AC.Settings:AddCheckbox("Player", "General",
    {
        key = "showCoordinates",
        text = "Show Coordinates",
        default = true,
        tooltip = "Reserved for a future on-screen coordinate display.",
    })

    AC.Settings:AddCheckbox("Player", "General",
    {
        key = "showZoneName",
        text = "Show Zone Name",
        default = true,
        tooltip = "Reserved for a future on-screen zone display.",
    })

    AC.Settings:AddSlider("Player", "General",
    {
        key = "updateInterval",
        text = "Update Interval",
        minimum = 0.1,
        maximum = 5.0,
        step = 0.1,
        default = 1.0,
        tooltip = "How often player coordinates are refreshed in seconds.",
    })

    AC.Settings:AddDropdown("Player", "General",
    {
        key = "coordinatePrecision",
        default = 2,
        list =
        {
            { text = "0", value = 0 },
            { text = "1", value = 1 },
            { text = "2", value = 2 },
            { text = "3", value = 3 },
        },
        tooltip = "Decimal precision used for stored coordinates.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function PlayerModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("ZONE_CHANGED", self)
    AC.Events:Register("ZONE_CHANGED_NEW_AREA", self)
    AC.Events:Register("PLAYER_STARTED_MOVING", self)
    AC.Events:Register("PLAYER_STOPPED_MOVING", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then
        self:RefreshZone()
        self:RefreshCoordinates()
        self:StartTicker()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function PlayerModule:Disable()

    self:StopTicker()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function PlayerModule:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function PlayerModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Player", "enabled") ~= false

end

function PlayerModule:GetUpdateInterval()

    local interval = AC.ConfigurationManager:GetValue("Player", "updateInterval")

    if type(interval) ~= "number" then
        return Defaults.updateInterval
    end

    if interval < 0.1 then
        return 0.1
    elseif interval > 5.0 then
        return 5.0
    end

    return interval

end

function PlayerModule:GetCoordinatePrecision()

    local precision = AC.ConfigurationManager:GetValue("Player", "coordinatePrecision")

    if type(precision) ~= "number" then
        return Defaults.coordinatePrecision
    end

    if precision < 0 then
        return 0
    elseif precision > 3 then
        return 3
    end

    return math.floor(precision)

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function PlayerModule:OnPlayerEnteringWorld()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshZone()
    self:RefreshCoordinates()

end

function PlayerModule:OnZoneChanged()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshZone()

end

function PlayerModule:OnZoneChangedNewArea()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshZone()
    self:RefreshCoordinates()

end

function PlayerModule:OnPlayerStartedMoving()

    if not self:IsModuleEnabled() then
        return
    end

    self.State.IsMoving = true

end

function PlayerModule:OnPlayerStoppedMoving()

    if not self:IsModuleEnabled() then
        return
    end

    self.State.IsMoving = false
    self:RefreshCoordinates()

end

function PlayerModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Player" then
        return
    end

    if key == "enabled" then

        if value then
            self:RefreshZone()
            self:RefreshCoordinates()
            self:StartTicker()
        else
            self:StopTicker()
        end

        return

    end

    if key == "updateInterval" and self:IsModuleEnabled() then
        self:RestartTicker()
    end

end

-------------------------------------------------------------------------------
-- State Updates
-------------------------------------------------------------------------------

function PlayerModule:RefreshZone()

    self.State.Zone = GetZoneText() or ""
    self.State.SubZone = GetSubZoneText() or ""

end

function PlayerModule:RefreshCoordinates()

    local mapID = C_Map.GetBestMapForUnit("player")

    if not mapID then
        return
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")

    if not position then
        return
    end

    local x, y = position:GetXY()
    local precision = self:GetCoordinatePrecision()
    local multiplier = 10 ^ precision

    self.State.Coordinates.mapID = mapID
    self.State.Coordinates.x = math.floor(x * multiplier + 0.5) / multiplier
    self.State.Coordinates.y = math.floor(y * multiplier + 0.5) / multiplier

end

-------------------------------------------------------------------------------
-- Ticker
-------------------------------------------------------------------------------

function PlayerModule:StartTicker()

    self:StopTicker()

    if not self:IsModuleEnabled() then
        return
    end

    local interval = self:GetUpdateInterval()

    self.Ticker = C_Timer.NewTicker(interval, function()
        self:OnTick()
    end)

end

function PlayerModule:StopTicker()

    if self.Ticker then
        self.Ticker:Cancel()
        self.Ticker = nil
    end

end

function PlayerModule:RestartTicker()

    self:StartTicker()

end

function PlayerModule:OnTick()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshCoordinates()

end

-------------------------------------------------------------------------------
-- Accessors
-------------------------------------------------------------------------------

function PlayerModule:GetState()

    return self.State

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Player", PlayerModule)

return PlayerModule
