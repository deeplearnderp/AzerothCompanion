-------------------------------------------------------------------------------
-- Azeroth Companion
-- User Action Service
--
-- Shared orchestration for actions exposed by slash commands and developer UI.
-- Owning systems retain their state; this service only provides one entry point
-- for multi-step actions and navigation.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local UserActionService =
{
    Name = "UserActionService",

    -- Only categories with active Logger:Trace producers belong here.
    TraceCategories =
    {
        { command = "mythic", category = "Mythic+", labelKey = "Developer.ActionTraceMythicPlus" },
    },
}

AC.UserActionService = UserActionService

local function NotifyStateChanged()

    if AC.Events then
        AC.Events:Fire("USER_ACTION_STATE_CHANGED")
    end

end


function UserActionService:IsDeveloperModeEnabled()
    return AC.DeveloperModeService and AC.DeveloperModeService:IsEnabled() or false
end

function UserActionService:SetDeveloperModeEnabled(enabled)

    if not AC.DeveloperModeService then
        return false
    end

    AC.DeveloperModeService:SetEnabled(enabled)
    NotifyStateChanged()

    return true

end


function UserActionService:IsDebugLoggingEnabled()
    return AC.Logger and AC.Logger:IsDebugEnabled() or false
end

function UserActionService:SetDebugLoggingEnabled(enabled)

    if not AC.Logger then
        return false
    end

    AC.Logger:SetDebugEnabled(enabled)
    AC.Logger:Info("Debug mode " .. (enabled and "enabled." or "disabled."))
    NotifyStateChanged()

    return true

end


function UserActionService:GetTraceState()

    return
    {
        description = AC.Logger and AC.Logger:GetActiveTraceDescription() or "off",
        all = AC.Logger and AC.Logger.TraceAll == true or false,
        categories = AC.Logger and AC.Logger.TraceCategories or {},
    }

end

function UserActionService:GetAvailableTraceCategories()
    return self.TraceCategories
end

function UserActionService:ResolveTraceCategory(command)

    for _, descriptor in ipairs(self.TraceCategories) do

        if descriptor.command == command then
            return descriptor.category
        end

    end

    return nil

end

function UserActionService:IsTraceCategoryEnabled(category)
    return AC.Logger and AC.Logger:IsTraceCategoryEnabled(category) or false
end

function UserActionService:EnableAllTracing()

    if not AC.Logger then
        return false
    end

    AC.Logger:SetDebugEnabled(true)
    AC.Logger:EnableAllTrace()
    AC.Logger:Info("Tracing all categories.")
    NotifyStateChanged()

    return true

end

function UserActionService:DisableAllTracing()

    if not AC.Logger then
        return false
    end

    AC.Logger:DisableAllTrace()
    AC.Logger:Info("Tracing disabled.")
    NotifyStateChanged()

    return true

end


function UserActionService:EnableTraceCategory(category, exclusive)

    if not AC.Logger or type(category) ~= "string" or category == "" then
        return false
    end

    AC.Logger:SetDebugEnabled(true)

    if exclusive then
        AC.Logger:DisableAllTrace()
    end

    AC.Logger:SetTraceCategory(category, true)
    AC.Logger:Info("Tracing category: " .. category)
    NotifyStateChanged()

    return true

end

function UserActionService:DisableTraceCategory(category)

    if not AC.Logger or type(category) ~= "string" or category == "" then
        return false
    end

    AC.Logger:SetTraceCategory(category, false)
    NotifyStateChanged()

    return true

end


function UserActionService:OpenLog()

    if not AC.DiagnosticsWindow then
        return false
    end

    AC.DiagnosticsWindow:Show()
    return true

end

function UserActionService:CopyLog()

    if not AC.DiagnosticsWindow then
        return false
    end

    if not AC.DiagnosticsWindow.Frame:IsShown() or not AC.NavigationService:IsCurrent(AC.DiagnosticsWindow) then
        AC.DiagnosticsWindow:Show()
    end

    AC.DiagnosticsWindow:PrepareCopy()
    return true

end

function UserActionService:ClearCapturedErrors()

    local errorCapture = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("ErrorCapture")

    if not errorCapture then
        return false
    end

    errorCapture:ClearErrors()
    AC.Logger:Info("Developer Runtime: captured errors cleared.")

    return true

end

function UserActionService:GenerateTestError()
    error("Azeroth Companion Developer Runtime test error.")
end

function UserActionService:ClearLog()

    if not AC.Logger then
        return false
    end

    AC.Logger:ClearBuffer()

    if AC.DiagnosticsWindow and AC.DiagnosticsWindow.Refresh then
        AC.DiagnosticsWindow:Refresh(true)
    end

    AC.Logger:Info("Diagnostic log cleared.")
    return true

end


function UserActionService:OpenDashboard()

    if not AC.Dashboard or not AC.NavigationService then
        return false
    end

    AC.NavigationService:Push(AC.NavigationService.Windows.Dashboard, AC.Dashboard.CurrentPage or AC.NavigationService.Views.Dashboard.Home)
    return true

end

function UserActionService:ToggleDashboard()

    if not AC.Dashboard then
        return false
    end

    AC.Dashboard:Toggle()
    return true

end

function UserActionService:OpenSettings()

    local window = AC.Core and AC.Core:GetModule("SettingsWindow")

    if not window then
        return false
    end

    window:Show()
    return true

end


function UserActionService:RefreshAll()

    if not AC.Dashboard then
        return false
    end

    AC.Dashboard:RefreshEngines(nil)
    AC.Logger:Info("Developer Panel: forced a full refresh.")

    return true

end


AC.ServiceManager:Register("UserActionService", UserActionService)

return UserActionService
