-------------------------------------------------------------------------------
-- Azeroth Companion
-- Base Window
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local BaseWindow = {}

AC.BaseWindow = BaseWindow

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function BaseWindow:Create(name, title, width, height)

    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")

    frame:SetSize(width or 500, height or 400)
    frame:SetPoint("CENTER")

    ---------------------------------------------------------------------------
    -- Background
    --
    -- A real bordered backdrop (v1.0 Polish Sprint audit) -- every window
    -- in the addon previously rendered as a flat, edgeless color rectangle
    -- (a plain CreateTexture with no border at all), which is the single
    -- biggest reason the whole addon read as an unfinished placeholder
    -- rather than a real UI. `UI-Tooltip-Border` is a thin, understated
    -- Blizzard edge texture that keeps this addon's flat, modern look
    -- rather than pulling in an ornate parchment-style frame that would
    -- clash with everything else here.
    --
    -- Presentation System v2 -- these exact values are now also the named
    -- AC.Presentation.WINDOW_BACKDROP preset (Core/Presentation/Presentation.lua),
    -- so every window sharing this top-level treatment can reference the same
    -- values by name instead of retyping them. Inner surfaces use the shared
    -- CARD_BACKDROP instead.
    ---------------------------------------------------------------------------

    local backdrop = AC.Presentation.WINDOW_BACKDROP

    AC.Presentation.ApplyBackdrop(frame, backdrop)

    ---------------------------------------------------------------------------
    -- Title
    ---------------------------------------------------------------------------

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -12)
    titleText:SetText(title or "")

    frame.Title = titleText

    ---------------------------------------------------------------------------
    -- Movement
    ---------------------------------------------------------------------------

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    frame:Hide()

    if AC.WindowManager then
        AC.WindowManager:Register(name, frame)
    end

    return frame

end

-------------------------------------------------------------------------------
-- Add Close Button
--
-- The standard top-right close button every standalone window
-- (DiagnosticsWindow, SettingsWindow, PlayerJournalWindow,
-- DeveloperPanel, InventoryManager, ObservationDialog) wired up
-- identically -- extracted here once a fourth window repeated the exact
-- same five lines. `owner` is whichever object the window's own Show/Hide
-- lifecycle lives on (almost always the same table that called
-- BaseWindow:Create).
--
-- Navigation System -- clicking Close is a dismissal exactly like ESC or
-- a Back button, not a special third behavior: if this window is what
-- AC.NavigationService currently has on top of its stack, Close routes
-- through the same GoBack() ESC/Back already call, so the stack and what's
-- actually on screen never disagree (a plain owner:Hide() would leave the
-- stack still thinking this window is current, breaking the next ESC
-- press). Falls back to the original owner:Hide() when this window isn't
-- the tracked top, so lifecycle cleanup and other raw visibility callers
-- remain safe without corrupting navigation history.
-------------------------------------------------------------------------------

function BaseWindow:AddCloseButton(frame, owner)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    close:SetScript("OnClick", function()

        if not (AC.NavigationService and AC.NavigationService:GoBackIfCurrent(owner)) then
            owner:Hide()
        end

    end)

    frame.CloseButton = close

    return close

end

-------------------------------------------------------------------------------
-- Add Back Button
--
-- The standard top-left Back button for any standalone window that
-- participates in AC.NavigationService -- calls the exact same GoBack()
-- ESC and Close already call (there is never a second "go back"
-- implementation). Visibility is tied to the frame's own OnShow rather
-- than updated by hand at every navigation call site: every
-- RestoreNavigation already calls frame:Show() as part of restoring a
-- screen, so this is correct automatically, for any window, with zero
-- per-window bookkeeping.
-------------------------------------------------------------------------------

function BaseWindow:AddBackButton(frame, owner)

    local back = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    back:SetSize(70, 20)
    back:SetPoint("TOPLEFT", 4, -4)
    back:SetText(AC.L:Get("App.Back"))

    back:SetScript("OnClick", function()
        AC.NavigationService:GoBack()
    end)

    -- Reserve the control's header space permanently. Showing or hiding
    -- Back must never cause a window title to move between navigation
    -- states; window-specific identity headers may still choose their own
    -- fixed inset after calling this helper.
    if frame.Title then
        frame.Title:SetWidth(math.max((frame:GetWidth() or 0) - 180, 1))
    end

    frame:HookScript("OnShow", function()
        back:SetShown(AC.NavigationService:CanGoBack())
    end)

    frame.BackButton = back

    return back

end

return BaseWindow
