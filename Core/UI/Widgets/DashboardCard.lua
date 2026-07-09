-------------------------------------------------------------------------------
-- Azeroth Companion
-- Dashboard Card Widget
--
-- Reusable presentation card for Dashboard display. Optionally clickable,
-- in which case it hover-highlights and shows a small navigation
-- indicator on the right edge.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DashboardCard = {}

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------

function DashboardCard:Create(parent, title, options)

    options = options or {}

    local width = options.width or 360
    local height = options.height or 100

    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    card:SetHeight(height)

    -----------------------------------------------------------------------
    -- Background
    -----------------------------------------------------------------------

    local baseR, baseG, baseB, baseA

    if options.emphasized then
        baseR, baseG, baseB, baseA = 0.17, 0.15, 0.09, 0.92
    else
        baseR, baseG, baseB, baseA = 0.15, 0.15, 0.15, 0.85
    end

    local background = card:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(baseR, baseG, baseB, baseA)

    card.Background = background

    -----------------------------------------------------------------------
    -- Title
    -----------------------------------------------------------------------

    local titleFont = options.titleFont or "GameFontNormal"

    local titleText = card:CreateFontString(nil, "OVERLAY", titleFont)
    titleText:SetPoint("TOPLEFT", 14, -12)
    titleText:SetText(title or "")
    titleText:SetTextColor(1, 0.82, 0)

    card.Title = titleText

    -----------------------------------------------------------------------
    -- Primary Value
    -----------------------------------------------------------------------

    local primaryFont = options.primaryFont or "GameFontHighlight"
    local textWidth = width - 28 - (options.onClick and 20 or 0)

    local primaryValue = card:CreateFontString(nil, "OVERLAY", primaryFont)
    primaryValue:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -10)
    primaryValue:SetWidth(textWidth)
    primaryValue:SetJustifyH("LEFT")
    primaryValue:SetWordWrap(true)
    primaryValue:SetText(options.primaryValue or "")

    card.PrimaryValue = primaryValue

    -----------------------------------------------------------------------
    -- Secondary Text
    -----------------------------------------------------------------------

    local secondaryText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secondaryText:SetPoint("TOPLEFT", primaryValue, "BOTTOMLEFT", 0, -8)
    secondaryText:SetWidth(textWidth)
    secondaryText:SetJustifyH("LEFT")
    secondaryText:SetWordWrap(true)
    secondaryText:SetText(options.secondaryText or "")
    secondaryText:SetTextColor(0.8, 0.8, 0.8)

    card.SecondaryText = secondaryText

    -----------------------------------------------------------------------
    -- Status Indicator
    -----------------------------------------------------------------------

    local statusText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMRIGHT", -14, 12)
    statusText:SetText(options.statusText or "")
    statusText:SetJustifyH("RIGHT")

    card.StatusText = statusText

    -----------------------------------------------------------------------
    -- Progress Bar (optional, standard Blizzard status bar texture)
    -----------------------------------------------------------------------

    if options.showBar then

        local barHolder = CreateFrame("Frame", nil, card)
        barHolder:SetSize(width - 28, 12)
        barHolder:SetPoint("TOPLEFT", secondaryText, "BOTTOMLEFT", 0, -10)

        local barBackground = barHolder:CreateTexture(nil, "BACKGROUND")
        barBackground:SetAllPoints()
        barBackground:SetColorTexture(0, 0, 0, 0.5)

        local bar = CreateFrame("StatusBar", nil, barHolder)
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        bar:SetStatusBarColor(0.3, 0.6, 0.9)

        card.Bar = bar
        card.BarHolder = barHolder

    end

    -----------------------------------------------------------------------
    -- Click Navigation (optional)
    --
    -- WoW does not expose a generic "pointer" cursor API for plain
    -- frames the way a browser does, so clickability is communicated
    -- through a hover highlight plus a right-side indicator instead.
    -----------------------------------------------------------------------

    if options.onClick then

        local indicator = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        indicator:SetPoint("RIGHT", -14, 0)
        indicator:SetText("\226\150\182") -- "▶"
        indicator:SetTextColor(0.6, 0.6, 0.6)

        card.Indicator = indicator

        card:EnableMouse(true)

        card:SetScript("OnEnter", function(self)
            self.Background:SetColorTexture(baseR + 0.05, baseG + 0.05, baseB + 0.05, baseA)
            if self.Indicator then
                self.Indicator:SetTextColor(1, 0.82, 0)
            end
            if options.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(options.tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)

        card:SetScript("OnLeave", function(self)
            self.Background:SetColorTexture(baseR, baseG, baseB, baseA)
            if self.Indicator then
                self.Indicator:SetTextColor(0.6, 0.6, 0.6)
            end
            if options.tooltip then
                GameTooltip:Hide()
            end
        end)

        card:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                options.onClick(self)
            end
        end)

    end

    -----------------------------------------------------------------------
    -- Update Methods
    -----------------------------------------------------------------------

    function card:SetTitle(text)
        self.Title:SetText(text or "")
    end

    function card:SetPrimaryValue(text)
        self.PrimaryValue:SetText(text or "")
    end

    function card:SetSecondaryText(text)
        self.SecondaryText:SetText(text or "")
    end

    function card:SetStatus(status, text)
        text = text or ""

        self.StatusText:SetText(text)

        if status == "Normal" then
            self.StatusText:SetTextColor(0.5, 0.8, 0.5)
        elseif status == "Warning" then
            self.StatusText:SetTextColor(1, 0.82, 0)
        elseif status == "Important" then
            self.StatusText:SetTextColor(1, 0.3, 0.3)
        else
            self.StatusText:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    function card:SetBarValue(percentage, r, g, b)

        if not self.Bar then
            return
        end

        percentage = tonumber(percentage) or 0

        if percentage < 0 then
            percentage = 0
        elseif percentage > 100 then
            percentage = 100
        end

        self.Bar:SetValue(percentage)

        if r and g and b then
            self.Bar:SetStatusBarColor(r, g, b)
        end

    end

    return card

end

AC.DashboardCard = DashboardCard

return DashboardCard
