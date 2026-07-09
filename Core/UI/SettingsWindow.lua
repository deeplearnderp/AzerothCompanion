-------------------------------------------------------------------------------
-- Azeroth Companion
-- Settings Window
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow
local NavigationPanel = AC.NavigationPanel
local ContentPanel = AC.ContentPanel

local SettingsWindow = {}
AC.SettingsWindow = SettingsWindow

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function SettingsWindow:Initialize()

    self.Frame = BaseWindow:Create(
        "AzerothCompanionSettings",
        AC.L:Get("App.Title"),
        900,
        600
    )

    ---------------------------------------------------------------------------
    -- Close Button
    ---------------------------------------------------------------------------

    local close = CreateFrame(
        "Button",
        "AzerothCompanionSettingsClose",
        self.Frame,
        "UIPanelCloseButton"
    )

    close:SetPoint("TOPRIGHT", -4, -4)

    close:SetScript("OnClick", function()
        self:Hide()
    end)

    ---------------------------------------------------------------------------
    -- Version
    ---------------------------------------------------------------------------

    local version = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", self.Frame, "BOTTOMLEFT", 16, 12)
    version:SetText("v" .. tostring(AC.Version or "0.0.0"))

    self.VersionLabel = version

    ---------------------------------------------------------------------------
    -- Save / Cancel
    --
    -- Settings no longer write directly into ConfigurationManager (see
    -- ContentPanel). These buttons commit or discard whatever is pending.
    -- Both start disabled since nothing is dirty until a widget changes.
    ---------------------------------------------------------------------------

    local cancelButton = CreateFrame(
        "Button",
        "AzerothCompanionSettingsCancel",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    cancelButton:SetSize(90, 22)
    cancelButton:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -110, 8)
    cancelButton:SetText("Cancel")
    cancelButton:SetEnabled(false)

    cancelButton:SetScript("OnClick", function()

        if AC.Settings then
            AC.Settings:Cancel()
        end

    end)

    local saveButton = CreateFrame(
        "Button",
        "AzerothCompanionSettingsSave",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    saveButton:SetSize(90, 22)
    saveButton:SetPoint("LEFT", cancelButton, "RIGHT", 8, 0)
    saveButton:SetText("Save")
    saveButton:SetEnabled(false)

    saveButton:SetScript("OnClick", function()

        if AC.Settings then
            AC.Settings:Save()
        end

    end)

    self.CancelButton = cancelButton
    self.SaveButton = saveButton

    ---------------------------------------------------------------------------
    -- Navigation Host
    ---------------------------------------------------------------------------

    local navigationHost = CreateFrame(
        "Frame",
        "AzerothCompanionSettingsNavigation",
        self.Frame,
        "BackdropTemplate"
    )

    navigationHost:SetPoint("TOPLEFT", 10, -35)
    navigationHost:SetPoint("BOTTOMLEFT", 10, 36)
    navigationHost:SetWidth(200)

    navigationHost:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })

    navigationHost:SetBackdropColor(0.10, 0.10, 0.10, 0.90)

    ---------------------------------------------------------------------------
    -- Content Host
    ---------------------------------------------------------------------------

    local contentHost = CreateFrame(
        "Frame",
        "AzerothCompanionSettingsContent",
        self.Frame,
        "BackdropTemplate"
    )

    contentHost:SetPoint("TOPLEFT", navigationHost, "TOPRIGHT", 10, 0)
    contentHost:SetPoint("BOTTOMRIGHT", -10, 36)

    contentHost:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })

    contentHost:SetBackdropColor(0.15, 0.15, 0.15, 0.90)

    ---------------------------------------------------------------------------
    -- Panels
    ---------------------------------------------------------------------------

    self.NavigationPanel = NavigationPanel:Create(navigationHost)
    self.ContentPanel = ContentPanel:Create(contentHost)

    self.ContentPanel:SetOnDirtyChanged(function(dirty)

        self.SaveButton:SetEnabled(dirty)
        self.CancelButton:SetEnabled(dirty)

    end)

    ---------------------------------------------------------------------------
    -- Settings Manager
    ---------------------------------------------------------------------------

    if AC.Settings then
        AC.Settings:SetWindow(self)
        AC.Settings:SetPanels(self.NavigationPanel, self.ContentPanel)
    end

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function SettingsWindow:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function SettingsWindow:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function SettingsWindow:Shutdown()

    if AC.Settings then
        AC.Settings:SetWindow(nil)
        AC.Settings:SetPanels(nil, nil)
    end

    if self.ContentPanel then
        self.ContentPanel:Destroy()
    end

    self.NavigationPanel = nil
    self.ContentPanel = nil

end

-------------------------------------------------------------------------------
-- Show
-------------------------------------------------------------------------------

function SettingsWindow:Show()

    if AC.Settings then
        AC.Settings:OnWindowOpen()
    end

    self.Frame:Show()

end

-------------------------------------------------------------------------------
-- Hide
-------------------------------------------------------------------------------

function SettingsWindow:Hide()

    self.Frame:Hide()

end

-------------------------------------------------------------------------------
-- Toggle
-------------------------------------------------------------------------------

function SettingsWindow:Toggle()

    if self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register Module
-------------------------------------------------------------------------------

AC.Core:RegisterModule(
    "SettingsWindow",
    SettingsWindow
)

return SettingsWindow
