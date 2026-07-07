-------------------------------------------------------------------------------
-- Azeroth Companion
-- Settings Manager
--
-- Dynamic settings registration and window orchestration.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local tinsert = table.insert
local tsort = table.sort

local SettingsManager = {}
AC.SettingsManager = SettingsManager
AC.Settings = SettingsManager

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

SettingsManager.Pages = {}
SettingsManager.PageOrder = {}
SettingsManager.Window = nil
SettingsManager.NavigationPanel = nil
SettingsManager.ContentPanel = nil
SettingsManager.ActivePageId = nil
SettingsManager.Initialized = false
SettingsManager.Enabled = false

-------------------------------------------------------------------------------
-- Register Page
-------------------------------------------------------------------------------

function SettingsManager:RegisterPage(pageId, options)

    assert(type(pageId) == "string" and pageId ~= "", "Settings page id must be a string.")

    if self.Pages[pageId] then
        error(("Settings page '%s' is already registered."):format(pageId))
    end

    local page = AC.SettingsPage:New(pageId, options)

    self.Pages[pageId] = page
    tinsert(self.PageOrder, page)

    tsort(self.PageOrder, function(left, right)

        if left.Order == right.Order then
            return left.Title < right.Title
        end

        return left.Order < right.Order

    end)

    if self.Enabled and self.NavigationPanel then
        self:RefreshNavigation()
    end

    return page

end

-------------------------------------------------------------------------------
-- Register Section
-------------------------------------------------------------------------------

function SettingsManager:RegisterSection(pageId, sectionId, options)

    local page = self:GetPage(pageId)

    return page:RegisterSection(sectionId, options)

end

-------------------------------------------------------------------------------
-- Add Controls
-------------------------------------------------------------------------------

function SettingsManager:AddCheckbox(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "Checkbox", options)

end

function SettingsManager:AddSlider(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "Slider", options)

end

function SettingsManager:AddDropdown(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "Dropdown", options)

end

function SettingsManager:AddButton(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "Button", options)

end

function SettingsManager:AddEditBox(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "EditBox", options)

end

function SettingsManager:AddColorPicker(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "ColorPicker", options)

end

function SettingsManager:AddLabel(pageId, sectionId, options)

    return self:AddControl(pageId, sectionId, "Label", options)

end

function SettingsManager:AddControl(pageId, sectionId, controlType, options)

    assert(type(options) == "table", "Settings control options must be a table.")

    local page = self:GetPage(pageId)
    local controlDef = options
    controlDef.type = controlType

    if controlDef.module == nil and controlDef.moduleName == nil then
        controlDef.module = page.Module
    end

    if controlDef.key and controlDef.default ~= nil then
        self:EnsureDefault(controlDef.module or controlDef.moduleName or page.Module, controlDef.key, controlDef.default)
    end

    page:AddControl(sectionId, controlDef)

    if self.ActivePageId == pageId and self.ContentPanel then

        local cached = self.ContentPanel.PageFrames[pageId]

        if cached then
            self.ContentPanel:DestroyPage(pageId)
            self:SelectPage(pageId)
        end

    end

    return controlDef

end

-------------------------------------------------------------------------------
-- Page Access
-------------------------------------------------------------------------------

function SettingsManager:GetPage(pageId)

    local page = self.Pages[pageId]

    if not page then
        error(("Settings page '%s' is not registered."):format(tostring(pageId)))
    end

    return page

end

function SettingsManager:GetPages()

    return self.Pages

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function SettingsManager:EnsureDefault(moduleName, key, defaultValue)

    if moduleName == nil or key == nil or defaultValue == nil then
        return
    end

    local configuration = AC.ConfigurationManager
    local config = configuration:Get(moduleName)

    if config[key] == nil then
        config[key] = defaultValue
    end

end

function SettingsManager:NotifyChanged(moduleName, key, value)

    if AC.Events then
        AC.Events:Fire("SETTINGS_CHANGED", moduleName, key, value)
    end

end

-------------------------------------------------------------------------------
-- Window Wiring
-------------------------------------------------------------------------------

function SettingsManager:SetWindow(window)

    self.Window = window

end

function SettingsManager:SetPanels(navigationPanel, contentPanel)

    self.NavigationPanel = navigationPanel
    self.ContentPanel = contentPanel

    if contentPanel then
        contentPanel:SetSettingsManager(self)
    end

    if navigationPanel then
        navigationPanel:SetOnPageSelected(function(pageId)
            self:SelectPage(pageId)
        end)
    end

end

-------------------------------------------------------------------------------
-- Navigation
-------------------------------------------------------------------------------

function SettingsManager:RefreshNavigation()

    if not self.NavigationPanel then
        return
    end

    self.NavigationPanel:Rebuild(self.Pages)

    if not self.ActivePageId then

        local firstPage = self.PageOrder[1]

        if firstPage then
            self:SelectPage(firstPage.Id)
        elseif self.ContentPanel then
            self.ContentPanel:ShowEmpty()
        end

    else
        self.NavigationPanel:SetSelected(self.ActivePageId)
    end

end

function SettingsManager:SelectPage(pageId)

    local page = self.Pages[pageId]

    if not page then
        return false
    end

    self.ActivePageId = pageId

    if self.NavigationPanel then
        self.NavigationPanel:SetSelected(pageId)
    end

    if self.ContentPanel then
        self.ContentPanel:ShowPage(pageId, page)
    end

    return true

end

-------------------------------------------------------------------------------
-- Window Events
-------------------------------------------------------------------------------

function SettingsManager:OnWindowOpen()

    if self.ContentPanel then
        self.ContentPanel:RefreshActivePage()
    end

end

function SettingsManager:OnProfileChanged()

    if self.ContentPanel then
        self.ContentPanel:RefreshAllPages()
    end

end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function SettingsManager:Initialize()

    if self.Initialized then
        return
    end

    self.Initialized = true

    if AC.Logger then
        AC.Logger:Debug("SettingsManager initialized.")
    end

end

function SettingsManager:Enable()

    self.Enabled = true

    if self.NavigationPanel then
        self:RefreshNavigation()
    end

    if AC.Events then
        AC.Events:Register("PROFILE_CHANGED", self, "OnProfileChanged")
    end

    if AC.Logger then
        AC.Logger:Debug("SettingsManager enabled.")
    end

end

function SettingsManager:Disable()

    self.Enabled = false

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

    if AC.Logger then
        AC.Logger:Debug("SettingsManager disabled.")
    end

end

function SettingsManager:Shutdown()

    if self.ContentPanel then
        self.ContentPanel:Destroy()
    end

    self.Pages = {}
    self.PageOrder = {}
    self.ActivePageId = nil
    self.Window = nil
    self.NavigationPanel = nil
    self.ContentPanel = nil
    self.Initialized = false
    self.Enabled = false

    if AC.Logger then
        AC.Logger:Debug("SettingsManager shut down.")
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("SettingsManager", SettingsManager)

return SettingsManager
