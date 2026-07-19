-------------------------------------------------------------------------------
-- Azeroth Companion
-- Minimap Icon
--
-- Standard LibDataBroker-1.1 / LibDBIcon-1.0 minimap launcher.
-- Left Click:  Toggle Dashboard
-- Right Click: Open Settings
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local MinimapIcon = {}
AC.MinimapIcon = MinimapIcon

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function MinimapIcon:Initialize()

    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    if not LDB then

        if AC.Logger then
            AC.Logger:Warn("LibDataBroker-1.1 not found. Minimap icon disabled.")
        end

        return

    end

    if not LDBIcon then

        if AC.Logger then
            AC.Logger:Warn("LibDBIcon-1.0 not found. Minimap icon disabled.")
        end

        return

    end

    -----------------------------------------------------------------------
    -- Data Object
    -----------------------------------------------------------------------

    self.DataObject = LDB:NewDataObject("AzerothCompanion",
    {
        type = "launcher",
        text = "Azeroth Companion",
        icon = "Interface\\Icons\\INV_Misc_Book_09",

        OnClick = function(_, button)

            if button == "LeftButton" then
                AC.UserActionService:ToggleDashboard()

            elseif button == "RightButton" then
                AC.UserActionService:OpenSettings()

            end

        end,

        OnTooltipShow = function(tooltip)

            if not tooltip or not tooltip.AddLine then
                return
            end

            tooltip:AddLine("Azeroth Companion")
            tooltip:AddLine(" ")
            tooltip:AddLine("Left Click: Open Dashboard")
            tooltip:AddLine("Right Click: Open Settings")

        end,
    })

    -----------------------------------------------------------------------
    -- Icon Registration (position persisted via DatabaseService)
    -----------------------------------------------------------------------

    local global = AC.DatabaseService and AC.DatabaseService:GetGlobal()

    if not global then

        if AC.Logger then
            AC.Logger:Warn("DatabaseService not available. Minimap icon position will not persist.")
        end

        global = {}

    end

    if type(global.Minimap) ~= "table" then
        global.Minimap = { hide = false }
    end

    self.Db = global.Minimap

    LDBIcon:Register("AzerothCompanion", self.DataObject, self.Db)

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("MinimapIcon", MinimapIcon)

return MinimapIcon
