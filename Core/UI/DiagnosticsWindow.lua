-------------------------------------------------------------------------------
-- Azeroth Companion
-- Diagnostics Window
--
-- The copyable log window for Part 3 ("/ac log") and the live debug view
-- for Part 7, combined into one window rather than two overlapping UIs --
-- a single scrollable, always-a-real-EditBox log view that both lets you
-- Ctrl+A/Ctrl+C at any time and updates live while open.
--
-- Presentation only. All storage lives in Logger (Logger:GetBufferText()/
-- ClearBuffer()); this window never keeps its own copy of log history.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = AC.BaseWindow

local DiagnosticsWindow = {}
AC.DiagnosticsWindow = DiagnosticsWindow

-------------------------------------------------------------------------------
-- Layout Constants
-------------------------------------------------------------------------------

local WINDOW_WIDTH = 700
local WINDOW_HEIGHT = 500
local CONTENT_WIDTH = 640
local CONTENT_HEIGHT = 380
local REFRESH_INTERVAL = 0.5

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function DiagnosticsWindow:Initialize()

    self.Paused = false
    self.AutoScroll = true

    self.Frame = BaseWindow:Create(
        "AzerothCompanionDiagnostics",
        "Diagnostics",
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )

    AC.NavigationService:RegisterWindow(AC.NavigationService.Windows.Diagnostics, self)

    ---------------------------------------------------------------------------
    -- Close Button
    ---------------------------------------------------------------------------

    BaseWindow:AddCloseButton(self.Frame, self)
    BaseWindow:AddBackButton(self.Frame, self)

    ---------------------------------------------------------------------------
    -- Log View
    ---------------------------------------------------------------------------

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        "AzerothCompanionDiagnosticsScroll",
        self.Frame,
        "UIPanelScrollFrameTemplate"
    )

    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetSize(CONTENT_WIDTH, CONTENT_HEIGHT)

    local editBox = CreateFrame(
        "EditBox",
        "AzerothCompanionDiagnosticsEditBox",
        scrollFrame
    )

    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(CONTENT_WIDTH)
    editBox:SetJustifyH("LEFT")

    editBox:SetScript("OnEscapePressed", function(control)
        control:ClearFocus()
    end)

    scrollFrame:SetScrollChild(editBox)

    self.ScrollFrame = scrollFrame
    self.EditBox = editBox

    ---------------------------------------------------------------------------
    -- Controls
    ---------------------------------------------------------------------------

    local pauseButton = CreateFrame(
        "Button",
        "AzerothCompanionDiagnosticsPause",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    pauseButton:SetSize(90, 22)
    pauseButton:SetPoint("BOTTOMLEFT", self.Frame, "BOTTOMLEFT", 16, 12)
    pauseButton:SetText("Pause")

    pauseButton:SetScript("OnClick", function()
        self:TogglePause()
    end)

    self.PauseButton = pauseButton

    local clearButton = CreateFrame(
        "Button",
        "AzerothCompanionDiagnosticsClear",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    clearButton:SetSize(90, 22)
    clearButton:SetPoint("LEFT", pauseButton, "RIGHT", 8, 0)
    clearButton:SetText("Clear")

    clearButton:SetScript("OnClick", function()
        AC.UserActionService:ClearLog()
    end)

    local copyButton = CreateFrame(
        "Button",
        "AzerothCompanionDiagnosticsCopy",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    copyButton:SetSize(90, 22)
    copyButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
    copyButton:SetText("Copy")

    copyButton:SetScript("OnClick", function()
        AC.UserActionService:CopyLog()
    end)

    local autoScrollButton = CreateFrame(
        "Button",
        "AzerothCompanionDiagnosticsAutoScroll",
        self.Frame,
        "UIPanelButtonTemplate"
    )

    autoScrollButton:SetSize(120, 22)
    autoScrollButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0)

    autoScrollButton:SetScript("OnClick", function()
        self:ToggleAutoScroll()
    end)

    self.AutoScrollButton = autoScrollButton

    self:UpdateButtonLabels()

    ---------------------------------------------------------------------------
    -- Live Refresh
    --
    -- Throttled OnUpdate for the live-log view (Part 7). Hidden frames do
    -- not receive OnUpdate in WoW's frame system, so this naturally costs
    -- nothing while the window is closed -- no separate enable/disable
    -- bookkeeping required.
    ---------------------------------------------------------------------------

    local elapsedSinceRefresh = 0

    self.Frame:SetScript("OnUpdate", function(_, elapsed)

        elapsedSinceRefresh = elapsedSinceRefresh + elapsed

        if elapsedSinceRefresh < REFRESH_INTERVAL then
            return
        end

        elapsedSinceRefresh = 0

        self:Refresh()

    end)

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function DiagnosticsWindow:Refresh(force)

    if not self.EditBox then
        return
    end

    if self.Paused and not force then
        return
    end

    local text = AC.Logger:GetBufferText()

    self.EditBox:SetText(text)

    if self.AutoScroll then
        self.EditBox:SetCursorPosition(#text)
    end

end

-- WoW exposes native EditBox clipboard shortcuts rather than an addon
-- clipboard API. Freeze the exact Logger snapshot rendered into the EditBox
-- before selecting it so the live refresh cannot invalidate the selection
-- while the user presses Ctrl+C.
function DiagnosticsWindow:PrepareCopy()

    self.Paused = true
    self:UpdateButtonLabels()
    self:Refresh(true)
    self.EditBox:SetFocus()
    self.EditBox:HighlightText()

end

-------------------------------------------------------------------------------
-- Controls
-------------------------------------------------------------------------------

function DiagnosticsWindow:TogglePause()

    self.Paused = not self.Paused
    self:UpdateButtonLabels()

    if not self.Paused then
        self:Refresh()
    end

end

function DiagnosticsWindow:ToggleAutoScroll()

    self.AutoScroll = not self.AutoScroll
    self:UpdateButtonLabels()

end

function DiagnosticsWindow:UpdateButtonLabels()

    if self.PauseButton then
        self.PauseButton:SetText(self.Paused and "Resume" or "Pause")
    end

    if self.AutoScrollButton then
        self.AutoScrollButton:SetText(self.AutoScroll and "Auto-scroll: On" or "Auto-scroll: Off")
    end

end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------

function DiagnosticsWindow:Show()

    AC.NavigationService:Push(AC.NavigationService.Windows.Diagnostics, AC.NavigationService.Views.Diagnostics.Log)

end

function DiagnosticsWindow:RestoreNavigation(entry)

    self:Refresh()
    self.Frame:Show()

    if entry.Context and entry.Context.scrollPosition and not self.AutoScroll then
        self.ScrollFrame:SetVerticalScroll(entry.Context.scrollPosition)
    end

end

function DiagnosticsWindow:CaptureNavigation(entry)

    entry.Context = entry.Context or {}
    entry.Context.scrollPosition = self.ScrollFrame and self.ScrollFrame:GetVerticalScroll() or 0

end

function DiagnosticsWindow:Hide()

    if not AC.NavigationService:GoBackIfCurrent(self) then
        self.Frame:Hide()
    end

end

function DiagnosticsWindow:Toggle()

    if self.Frame:IsShown() and AC.NavigationService:IsCurrent(self) then
        AC.NavigationService:GoBack()
    else
        self:Show()
    end

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("DiagnosticsWindow", DiagnosticsWindow)

return DiagnosticsWindow
