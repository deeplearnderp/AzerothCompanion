-------------------------------------------------------------------------------
-- Azeroth Companion
-- Settings Page
--
-- Data model for a settings page and its sections.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SettingsPage = {}
AC.SettingsPage = SettingsPage

-------------------------------------------------------------------------------
-- New
-------------------------------------------------------------------------------

function SettingsPage:New(id, options)

    options = options or {}

    local instance =
    {
        Id = id,
        Title = options.title or id,
        Module = options.module or options.moduleName or id,
        Order = options.order or 0,
        Sections = {},
        SectionOrder = {},
    }

    setmetatable(instance, { __index = SettingsPage })

    return instance

end

-------------------------------------------------------------------------------
-- Register Section
-------------------------------------------------------------------------------

function SettingsPage:RegisterSection(sectionId, options)

    if self.Sections[sectionId] then
        error(("Settings section '%s' already exists on page '%s'."):format(sectionId, self.Id))
    end

    local section = AC.SettingsSection:New(sectionId, options)

    self.Sections[sectionId] = section
    table.insert(self.SectionOrder, section)

    return section

end

-------------------------------------------------------------------------------
-- Get Section
-------------------------------------------------------------------------------

function SettingsPage:GetSection(sectionId)

    return self.Sections[sectionId]

end

-------------------------------------------------------------------------------
-- Add Control
-------------------------------------------------------------------------------

function SettingsPage:AddControl(sectionId, controlDef)

    local section = self.Sections[sectionId]

    if not section then
        error(("Settings section '%s' does not exist on page '%s'."):format(sectionId, self.Id))
    end

    section:AddControl(controlDef)

end

return SettingsPage
