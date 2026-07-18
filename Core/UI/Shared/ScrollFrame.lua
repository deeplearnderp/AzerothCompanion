-------------------------------------------------------------------------------
-- Azeroth Companion
-- Shared ScrollFrame
--
-- The single owner of "create a UIPanelScrollFrameTemplate scrollFrame plus
-- its scrollChild, positioned so the stock scrollbar has room to render
-- without escaping the window, with the parchment-skinned arrow buttons
-- hidden." Dashboard (Sections.lua/Home.lua), Player Journal, and Developer
-- Panel each used to hand-roll this independently -- Dashboard's own copy
-- was the only one that reserved room for the scrollbar correctly and hid
-- the arrows; Player Journal and Developer Panel each reserved room in
-- their own CONTENT_WIDTH formula but never applied it to the scrollFrame's
-- own anchor, leaving a dead gutter inside the window AND a scrollbar with
-- nowhere to render but past the window's true edge. Generic window
-- infrastructure like this belongs beside BaseWindow.lua, not inside the
-- Dashboard feature -- Dashboard is one of this file's consumers, not its
-- owner.
--
-- PADDING/SCROLLBAR_RESERVE are 16/24 here because every one of this file's
-- three original callers had already, independently, chosen those same two
-- numbers -- not a new design decision, just the first time that existing,
-- unspoken convention got a single name.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SharedScrollFrame = {}
AC.SharedScrollFrame = SharedScrollFrame

SharedScrollFrame.PADDING = 16
SharedScrollFrame.SCROLLBAR_RESERVE = 24

-------------------------------------------------------------------------------
-- Content Width
--
-- The one formula for "how wide can content be, given a left inset and the
-- scrollbar's reserved right margin." leftInset defaults to PADDING since
-- that is by far the common case (a page/window with its own left margin
-- matching its scrollFrame's left inset) -- callers with a genuinely
-- different left inset (Home.lua's leftInset 0) pass it explicitly.
-------------------------------------------------------------------------------

function SharedScrollFrame:ContentWidth(windowWidth, leftInset)

    return windowWidth - (leftInset or self.PADDING) - self.SCROLLBAR_RESERVE

end

-------------------------------------------------------------------------------
-- Create
--
-- topInset/leftInset/bottomInset are positive magnitudes (this negates
-- topInset itself for the TOPLEFT anchor) -- the right inset is never a
-- parameter, since SCROLLBAR_RESERVE unconditionally IS the right inset;
-- a caller that could pick a different right inset is exactly how this bug
-- happened in the first place. contentWidth is the caller's own
-- responsibility (via ContentWidth above) rather than assumed here, since
-- only the caller knows its own window width and left inset.
-------------------------------------------------------------------------------

function SharedScrollFrame:Create(parent, contentWidth, topInset, leftInset, bottomInset)

    topInset = topInset or self.PADDING
    leftInset = leftInset or self.PADDING
    bottomInset = bottomInset or self.PADDING

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

    scrollFrame:SetPoint("TOPLEFT", leftInset, -topInset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -self.SCROLLBAR_RESERVE, bottomInset)

    -- UIPanelScrollFrameTemplate's ScrollBar ships its own ScrollUpButton/
    -- ScrollDownButton -- stock Blizzard parchment-skinned arrows that
    -- clash with this addon's dark theme. Hidden once, here, for every
    -- window built through this function. Mouse-wheel and thumb-drag are
    -- untouched -- neither depends on these buttons. Guarded so a future
    -- template swap degrades to "buttons stay visible" rather than an error.
    local scrollBar = scrollFrame.ScrollBar

    if scrollBar then

        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
        end

        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
        end

    end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(contentWidth)
    scrollChild:SetHeight(1)

    scrollFrame:SetScrollChild(scrollChild)

    return scrollFrame, scrollChild

end

return SharedScrollFrame
