-------------------------------------------------------------------------------
-- Azeroth Companion
-- Inventory Shared Components
--
-- Focused presentation helpers extracted from InventoryManager pages to
-- reduce duplication. These are pure presentation utilities -- no business
-- logic, no storage access, no scan lifecycle.
--
-- Extracted patterns:
--   LayoutItemCards    -- pooled card list rendering (5 call sites)
--   HideCardSection    -- hide card pool + empty text + section header
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local InventoryComponents = {}
AC.InventoryComponents = InventoryComponents

local Layout = AC.DashboardLayout

-------------------------------------------------------------------------------
-- LayoutItemCards
--
-- Renders a list of items as DashboardCard widgets with automatic pooling.
-- Handles empty state display and hides unused cards from previous renders.
--
-- Parameters:
--   page        -- the page object (must have ScrollChild)
--   poolKey     -- string key for the card pool on page (e.g. "CategoryCards")
--   emptyKey    -- string key for empty state text on page (or nil)
--   yOffset     -- starting Y offset for layout
--   width       -- available width for cards
--   items       -- array of items to render
--   cardHeight  -- height for each card
--   cardBuilder -- function(card, item, index) that populates card fields
--   emptyTextKey-- localization key for empty state (required if emptyKey set)
--
-- Returns:
--   Updated yOffset after all cards
-------------------------------------------------------------------------------

function InventoryComponents:LayoutItemCards(page, poolKey, emptyKey, yOffset, width, items, cardHeight, cardBuilder, emptyTextKey)

    page[poolKey] = page[poolKey] or {}

    -- Handle empty state
    if #items == 0 then

        for _, card in ipairs(page[poolKey]) do
            card:Hide()
        end

        if emptyKey and emptyTextKey then
            return AC.Dashboard:ShowEmptyLine(page, page.ScrollChild, emptyKey, yOffset, width, emptyTextKey)
        end

        return yOffset

    end

    -- Hide empty state text if showing cards
    if emptyKey and page[emptyKey] then
        page[emptyKey]:Hide()
    end

    local cardWidth = width - (Layout.ROW_INDENT * 2)

    for index, item in ipairs(items) do

        local card = page[poolKey][index]

        if not card then
            card = AC.DashboardCard:Create(page.ScrollChild, "", { width = cardWidth, height = cardHeight })
            page[poolKey][index] = card
        end

        card:SetWidth(cardWidth)

        -- Let the caller populate card-specific fields
        if cardBuilder then
            cardBuilder(card, item, index)
        end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", Layout.ROW_INDENT, yOffset)
        card:Show()

        yOffset = yOffset - card:GetHeight() - Layout.HOME_SECTION_GAP

    end

    -- Hide unused cards from previous renders
    for index = #items + 1, #page[poolKey] do
        page[poolKey][index]:Hide()
    end

    return yOffset

end

-------------------------------------------------------------------------------
-- HideCardSection
--
-- Hides all cards in a pool, the associated empty state text, and the
-- section header. Used when a section should not be visible (e.g. no data,
-- feature disabled, or conditional section not met).
--
-- Parameters:
--   page     -- the page object
--   poolKey  -- string key for the card pool on page
--   titleKey -- localization key for the section header (or nil)
--   emptyKey -- string key for empty state text on page (or nil)
-------------------------------------------------------------------------------

function InventoryComponents:HideCardSection(page, poolKey, titleKey, emptyKey)

    -- Hide all cards in pool
    for _, card in ipairs(page[poolKey] or {}) do
        card:Hide()
    end

    -- Hide empty state text
    if emptyKey and page[emptyKey] then
        page[emptyKey]:Hide()
    end

    -- Hide section header
    local headers = page.ScrollChild and page.ScrollChild.SectionHeaders

    if titleKey and headers and headers[titleKey] then
        headers[titleKey]:Hide()
    end

end

return InventoryComponents