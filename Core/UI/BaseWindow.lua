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
    -- so every other window sharing this same "top-level window" treatment
    -- (as opposed to an inner panel -- see PANEL_BACKDROP, SettingsWindow.lua)
    -- can reference the same values by name instead of retyping them.
    ---------------------------------------------------------------------------

    local backdrop = AC.Presentation.WINDOW_BACKDROP

    frame:SetBackdrop(
    {
        bgFile = backdrop.bgFile,
        edgeFile = backdrop.edgeFile,
        edgeSize = backdrop.edgeSize,
        insets = backdrop.insets,
    })

    frame:SetBackdropColor(unpack(backdrop.bgColor))
    frame:SetBackdropBorderColor(unpack(backdrop.borderColor))

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
-- (DiagnosticsWindow, SettingsWindow, RecommendationInspector,
-- DeveloperPanel) wired up identically -- extracted here once a fourth
-- window repeated the exact same five lines. `owner` is whichever object
-- the window's own Show/Hide lifecycle lives on (almost always the same
-- table that called BaseWindow:Create) -- clicking Close calls
-- `owner:Hide()`, never assumes it's `frame` itself.
-------------------------------------------------------------------------------

function BaseWindow:AddCloseButton(frame, owner)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    close:SetScript("OnClick", function()
        owner:Hide()
    end)

    frame.CloseButton = close

    return close

end

return BaseWindow