-------------------------------------------------------------------------------
-- Azeroth Companion
-- Settings Section
--
-- Data model for a grouped set of settings controls.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local tinsert = table.insert

local SettingsSection = {}
AC.SettingsSection = SettingsSection

-------------------------------------------------------------------------------
-- New
-------------------------------------------------------------------------------

function SettingsSection:New(id, options)

    options = options or {}

    local instance =
    {
        Id = id,
        Title = options.title or id,
        Controls = {},
    }

    setmetatable(instance, { __index = SettingsSection })

    return instance

end

-------------------------------------------------------------------------------
-- Add Control
-------------------------------------------------------------------------------

function SettingsSection:AddControl(controlDef)

    tinsert(self.Controls, controlDef)

end

return SettingsSection
