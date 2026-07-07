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

    local frame = CreateFrame("Frame", name, UIParent)

    frame:SetSize(width or 500, height or 400)
    frame:SetPoint("CENTER")

    ---------------------------------------------------------------------------
    -- Background
    ---------------------------------------------------------------------------

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.10, 0.10, 0.10, 0.95)

    frame.Background = background

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

return BaseWindow