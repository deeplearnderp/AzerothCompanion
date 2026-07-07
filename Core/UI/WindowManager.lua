-------------------------------------------------------------------------------
-- Azeroth Companion
-- Window Manager
--
-- Responsible for creating and managing framework windows.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local WindowManager = {}
AC.WindowManager = WindowManager

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

WindowManager.Windows = {}

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

function WindowManager:Register(name, frame)

    assert(type(name) == "string", "Window name must be a string.")
    assert(type(frame) == "table", "Frame must be valid.")

    self.Windows[name] = frame

end

-------------------------------------------------------------------------------
-- Get
-------------------------------------------------------------------------------

function WindowManager:Get(name)

    return self.Windows[name]

end

-------------------------------------------------------------------------------
-- Show
-------------------------------------------------------------------------------

function WindowManager:Show(name)

    local frame = self.Windows[name]

    if frame then
        frame:Show()
    end

end

-------------------------------------------------------------------------------
-- Hide
-------------------------------------------------------------------------------

function WindowManager:Hide(name)

    local frame = self.Windows[name]

    if frame then
        frame:Hide()
    end

end

-------------------------------------------------------------------------------
-- Toggle
-------------------------------------------------------------------------------

function WindowManager:Toggle(name)

    local frame = self.Windows[name]

    if not frame then
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end

end

-------------------------------------------------------------------------------
-- Hide All
-------------------------------------------------------------------------------

function WindowManager:HideAll()

    for _, frame in pairs(self.Windows) do
        frame:Hide()
    end

end

-------------------------------------------------------------------------------
-- Iterator
-------------------------------------------------------------------------------

function WindowManager:Iterate()

    return pairs(self.Windows)

end

return WindowManager