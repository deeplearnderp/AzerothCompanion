-------------------------------------------------------------------------------
-- Azeroth Companion
-- Data Management Settings Page
--
-- Presentation only. Provider identity, status, availability, and cleanup
-- behavior are supplied by DataManagementRegistry descriptors.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DataManagementPage =
{
    Name = "DataManagementPage",
    PageID = "DataManagement",
}

local CONFIRMATION_DIALOG = "AZEROTHCOMPANION_DATA_MANAGEMENT_CONFIRM"


local function Resolve(descriptor, field, fallbackKey)

    local key = descriptor[field]

    if key then
        return AC.L:Get(key)
    end

    local directField = field:gsub("Key$", "")
    local directValue = descriptor[directField]

    if directValue then
        return directValue
    end

    return fallbackKey and AC.L:Get(fallbackKey) or ""

end


function DataManagementPage:Initialize()

    AC.Settings:RegisterPage(self.PageID,
    {
        title = AC.L:Get("DataManagement.Title"),
        module = self.PageID,
        order = 90,
    })

    self:RegisterConfirmationDialog()

end


function DataManagementPage:Enable()

    AC.Events:Register("DATA_MANAGEMENT_PROVIDERS_CHANGED", self, "Rebuild")
    AC.Events:Register("DATA_MANAGEMENT_UPDATED", self, "Refresh")
    self:Rebuild()

end


function DataManagementPage:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end


function DataManagementPage:RegisterConfirmationDialog()

    StaticPopupDialogs[CONFIRMATION_DIALOG] =
    {
        text = "%s\n\n%s",
        button1 = AC.L:Get("DataManagement.Clear"),
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
        OnShow = function(dialog, data)
            dialog.button1:SetText(data and data.acceptText or AC.L:Get("DataManagement.Clear"))
        end,
        OnAccept = function(_, data)

            if not data then
                return
            end

            if data.clearAll then
                AC.DataManagementRegistry:ClearAll()
            else
                AC.DataManagementRegistry:Clear(data.providerID)
            end

        end,
    }

end


function DataManagementPage:ShowProviderConfirmation(descriptor)

    StaticPopup_Show(
        CONFIRMATION_DIALOG,
        Resolve(descriptor, "confirmationTitleKey", "DataManagement.ConfirmProviderTitle"),
        Resolve(descriptor, "confirmationDescriptionKey", "DataManagement.ConfirmProviderDescription"),
        {
            providerID = descriptor.id,
            acceptText = Resolve(descriptor, "actionLabelKey", "DataManagement.Clear"),
        })

end


function DataManagementPage:ShowClearAllConfirmation()

    StaticPopup_Show(
        CONFIRMATION_DIALOG,
        AC.L:Get("DataManagement.ConfirmAllTitle"),
        AC.L:Get("DataManagement.ConfirmAllDescription"),
        {
            clearAll = true,
            acceptText = AC.L:Get("DataManagement.ClearAll"),
        })

end


function DataManagementPage:Rebuild()

    local page = AC.Settings:GetPage(self.PageID)

    page.Sections = {}
    page.SectionOrder = {}

    for _, descriptor in ipairs(AC.DataManagementRegistry:GetProviders()) do

        local provider = descriptor
        local sectionID = "Provider_" .. provider.id

        AC.Settings:RegisterSection(self.PageID, sectionID,
        {
            title = Resolve(provider, "displayNameKey"),
        })

        if provider.descriptionKey or provider.description then
            AC.Settings:AddLabel(self.PageID, sectionID,
            {
                text = Resolve(provider, "descriptionKey"),
                color = AC.BaseWidget.Style.ColorDisabled,
            })
        end

        if provider.getStatus then
            AC.Settings:AddLabel(self.PageID, sectionID,
            {
                getText = function()
                    return AC.DataManagementRegistry:GetStatus(provider.id)
                end,
            })
        end

        AC.Settings:AddButton(self.PageID, sectionID,
        {
            text = Resolve(provider, "actionLabelKey", "DataManagement.Clear"),
            tooltip = Resolve(provider, "descriptionKey"),
            isEnabled = function()
                return AC.DataManagementRegistry:IsAvailable(provider.id)
            end,
            onClick = function()
                self:ShowProviderConfirmation(provider)
            end,
        })

    end

    AC.Settings:RegisterSection(self.PageID, "ClearAll",
    {
        title = AC.L:Get("DataManagement.ClearAllTitle"),
    })

    AC.Settings:AddLabel(self.PageID, "ClearAll",
    {
        text = AC.L:Get("DataManagement.ClearAllDescription"),
        color = AC.BaseWidget.Style.ColorDisabled,
    })

    AC.Settings:AddButton(self.PageID, "ClearAll",
    {
        text = AC.L:Get("DataManagement.ClearAll"),
        tooltip = AC.L:Get("DataManagement.ClearAllDescription"),
        isEnabled = function()
            return AC.DataManagementRegistry:HasAvailableProviders()
        end,
        onClick = function()
            self:ShowClearAllConfirmation()
        end,
    })

    local contentPanel = AC.Settings.ContentPanel

    if contentPanel then

        contentPanel:DestroyPage(self.PageID)

        if AC.Settings.ActivePageId == self.PageID then
            AC.Settings:SelectPage(self.PageID)
        end

    end

end


function DataManagementPage:Refresh()

    local contentPanel = AC.Settings.ContentPanel

    if contentPanel then
        contentPanel:RefreshAllPages()
    end

end


AC.ServiceManager:Register("DataManagementPage", DataManagementPage)

return DataManagementPage
