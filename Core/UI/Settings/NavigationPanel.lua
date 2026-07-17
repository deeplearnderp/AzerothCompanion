-------------------------------------------------------------------------------
-- Azeroth Companion
-- Navigation Panel
--
-- Scrollable page navigation for the settings window.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local tinsert = table.insert
local tsort = table.sort

local NavigationPanel = {}
AC.NavigationPanel = NavigationPanel

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------

NavigationPanel.Layout =
{
    Margin = 8,
    ButtonHeight = 24,
    ButtonSpacing = 4,
    ButtonWidth = 184,
}

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function NavigationPanel:Create(parent)

    local panel =
    {
        Parent = parent,
        Buttons = {},
        SelectedPageId = nil,
        OnPageSelected = nil,
    }

    setmetatable(panel, { __index = self })

    local scrollFrame = CreateFrame("ScrollFrame", "AzerothCompanionSettingsNavigationScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 4)

    local scrollChild = CreateFrame("Frame", "AzerothCompanionSettingsNavigationChild", scrollFrame)
    scrollChild:SetWidth(NavigationPanel.Layout.ButtonWidth)
    scrollFrame:SetScrollChild(scrollChild)

    panel.Frame = scrollFrame
    panel.ScrollChild = scrollChild

    return panel

end

-------------------------------------------------------------------------------
-- Rebuild
-------------------------------------------------------------------------------

function NavigationPanel:Rebuild(pages)

    local scrollChild = self.ScrollChild

    for i = 1, #self.Buttons do
        self.Buttons[i]:Hide()
        self.Buttons[i]:SetParent(nil)
    end

    self.Buttons = {}

    local layout = self.Layout
    local yOffset = -layout.Margin
    local ordered = {}

    for pageId, page in pairs(pages) do
        tinsert(ordered, page)
    end

    tsort(ordered, function(left, right)
        if left.Order == right.Order then
            return left.Title < right.Title
        end

        return left.Order < right.Order
    end)

    for i = 1, #ordered do

        local page = ordered[i]
        local button = CreateFrame("Button", "AzerothCompanionSettingsNav" .. page.Id, scrollChild, "UIPanelButtonTemplate")

        button:SetSize(layout.ButtonWidth, layout.ButtonHeight)
        button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", layout.Margin, yOffset)
        button:SetText(page.Title)
        button.PageId = page.Id

        button:SetScript("OnClick", function(clicked)

            if self.OnPageSelected then
                self.OnPageSelected(clicked.PageId)
            end

        end)

        tinsert(self.Buttons, button)

        yOffset = yOffset - layout.ButtonHeight - layout.ButtonSpacing

    end

    scrollChild:SetHeight(math.abs(yOffset) + layout.Margin)

    if self.SelectedPageId then
        self:SetSelected(self.SelectedPageId)
    end

end

-------------------------------------------------------------------------------
-- Selection
-------------------------------------------------------------------------------

function NavigationPanel:SetSelected(pageId)

    self.SelectedPageId = pageId

    for i = 1, #self.Buttons do

        local button = self.Buttons[i]
        local selected = button.PageId == pageId

        if selected then
            button:LockHighlight()
            button:GetFontString():SetTextColor(unpack(AC.Presentation.HIGHLIGHT_COLOR))
        else
            button:UnlockHighlight()
            button:GetFontString():SetTextColor(1, 1, 1)
        end

    end

end

-------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------

function NavigationPanel:SetOnPageSelected(callback)

    self.OnPageSelected = callback

end

return NavigationPanel
