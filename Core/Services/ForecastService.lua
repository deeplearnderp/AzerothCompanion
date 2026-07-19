-------------------------------------------------------------------------------
-- Azeroth Companion
-- Forecast Service
--
-- Owns forward-looking opportunity collection, normalization, priority, and
-- ordering. Gameplay owners may contribute candidates through providers;
-- consumers receive one stable ForecastItem shape and never perform planning
-- logic themselves.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ForecastService =
{
    Name = "ForecastService",
    Providers = {},
}

AC.ForecastService = ForecastService

local CATEGORY_PRIORITY =
{
    GreatVault = 90,
    WeeklyReset = 80,
    Delves = 70,
    MythicPlus = 65,
    Events = 60,
    WorldActivities = 50,
    Reputation = 40,
}

local PLACEHOLDERS =
{
    { id = "great-vault", category = "GreatVault", titleKey = "Forecast.GreatVault.Title", descriptionKey = "Forecast.GreatVault.Description", actionKey = "Forecast.GreatVault.Action", destination = "Home", icon = "Interface\\Icons\\INV_Misc_EngGizmos_03" },
    { id = "weekly-reset", category = "WeeklyReset", titleKey = "Forecast.WeeklyReset.Title", descriptionKey = "Forecast.WeeklyReset.Description", actionKey = "Forecast.WeeklyReset.Action", destination = "Home", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { id = "delves", category = "Delves", titleKey = "Forecast.Delves.Title", descriptionKey = "Forecast.Delves.Description", actionKey = "Forecast.Delves.Action", destination = "Dungeons", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { id = "mythic-plus", category = "MythicPlus", titleKey = "Forecast.MythicPlus.Title", descriptionKey = "Forecast.MythicPlus.Description", actionKey = "Forecast.MythicPlus.Action", destination = "MythicPlus", icon = "Interface\\Icons\\Achievement_ChallengeMode_Gold" },
    { id = "events", category = "Events", titleKey = "Forecast.Events.Title", descriptionKey = "Forecast.Events.Description", actionKey = "Forecast.Events.Action", destination = "Home", icon = "Interface\\Icons\\INV_Misc_Calendar_01" },
    { id = "world-activities", category = "WorldActivities", titleKey = "Forecast.WorldActivities.Title", descriptionKey = "Forecast.WorldActivities.Description", actionKey = "Forecast.WorldActivities.Action", destination = "Home", icon = "Interface\\Icons\\INV_Misc_Map02" },
    { id = "reputation", category = "Reputation", titleKey = "Forecast.Reputation.Title", descriptionKey = "Forecast.Reputation.Description", actionKey = "Forecast.Reputation.Action", destination = "Home", icon = "Interface\\Icons\\Achievement_Reputation_01" },
}

local function NormalizeItem(candidate, providerID)

    if type(candidate) ~= "table" or type(candidate.id) ~= "string" or candidate.id == "" then
        return nil
    end

    if type(candidate.category) ~= "string" or candidate.category == "" then
        return nil
    end

    if type(candidate.title) ~= "string" or candidate.title == "" then
        return nil
    end

    local priority = tonumber(candidate.priority) or CATEGORY_PRIORITY[candidate.category] or 0
    priority = math.max(0, math.min(100, priority))

    local metadata = {}
    local action

    if type(candidate.metadata) == "table" then
        for key, value in pairs(candidate.metadata) do
            metadata[key] = value
        end
    end

    metadata.provider = providerID

    if type(candidate.action) == "table" and type(candidate.action.type) == "string" and candidate.action.type ~= "" then

        action = {}

        for key, value in pairs(candidate.action) do
            action[key] = value
        end

    end

    return
    {
        id = candidate.id,
        category = candidate.category,
        title = candidate.title,
        description = type(candidate.description) == "string" and candidate.description or "",
        priority = priority,
        expiresAt = tonumber(candidate.expiresAt),
        icon = type(candidate.icon) == "string" and candidate.icon or nil,
        actionText = type(candidate.actionText) == "string" and candidate.actionText or "",
        action = action,
        metadata = metadata,
    }

end

local function SortItems(left, right)

    if left.priority ~= right.priority then
        return left.priority > right.priority
    end

    if left.expiresAt and right.expiresAt and left.expiresAt ~= right.expiresAt then
        return left.expiresAt < right.expiresAt
    end

    if left.expiresAt ~= right.expiresAt then
        return left.expiresAt ~= nil
    end

    return left.id < right.id

end


function ForecastService:Initialize()

    self.Items = {}
    self.LastRefresh = 0

end

function ForecastService:Shutdown()

    self.Items = {}
    self.LastRefresh = 0

end

function ForecastService:RegisterProvider(providerID, provider)

    assert(type(providerID) == "string" and providerID ~= "", "Forecast provider ID must be a non-empty string.")
    assert(type(provider) == "table" and type(provider.CollectForecasts) == "function", "Forecast provider must implement CollectForecasts().")

    if self.Providers[providerID] and self.Providers[providerID] ~= provider then
        error(string.format("Forecast provider '%s' is already registered.", providerID))
    end

    self.Providers[providerID] = provider

end


function ForecastService:Refresh()

    local items = {}
    local seenIDs = {}
    local providedCategories = {}

    local function AddCandidate(candidate, providerID)

        local item = NormalizeItem(candidate, providerID)

        if not item or seenIDs[item.id] then
            return
        end

        seenIDs[item.id] = true
        providedCategories[item.category] = providerID ~= "Phase1" or providedCategories[item.category]
        table.insert(items, item)

    end

    for providerID, provider in pairs(self.Providers) do

        local ok, provided = pcall(provider.CollectForecasts, provider)

        if ok and type(provided) == "table" then
            for _, candidate in ipairs(provided) do
                AddCandidate(candidate, providerID)
            end
        elseif not ok and AC.Logger then
            AC.Logger:Error(string.format("Forecast provider '%s' failed: %s", providerID, tostring(provided)), "Services")
        end

    end


    for _, placeholder in ipairs(PLACEHOLDERS) do

        if not providedCategories[placeholder.category] then
            AddCandidate(
            {
                id = "placeholder:" .. placeholder.id,
                category = placeholder.category,
                title = AC.L:Get(placeholder.titleKey),
                description = AC.L:Get(placeholder.descriptionKey),
                icon = placeholder.icon,
                actionText = AC.L:Get(placeholder.actionKey),
                action = { type = "navigate", destination = placeholder.destination },
                metadata = { placeholder = true },
            }, "Phase1")
        end

    end

    table.sort(items, SortItems)

    self.Items = items
    self.LastRefresh = time()

end

function ForecastService:GetForecasts()

    return self.Items or {}

end

function ForecastService:GetHighestPriorityForecast()

    return self.Items and self.Items[1] or nil

end

function ForecastService:GetLastRefresh()

    return self.LastRefresh or 0

end


AC.ServiceManager:Register("ForecastService", ForecastService)

return ForecastService
