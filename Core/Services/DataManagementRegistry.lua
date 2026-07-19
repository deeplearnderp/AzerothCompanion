-------------------------------------------------------------------------------
-- Azeroth Companion
-- Data Management Registry
--
-- Module-owned cleanup capabilities register here. The registry validates,
-- orders, queries, and dispatches them; it never owns the underlying data.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DataManagementRegistry =
{
    Name = "DataManagementRegistry",
    Providers = {},
    OrderedProviders = {},
}

AC.DataManagementRegistry = DataManagementRegistry


function DataManagementRegistry:Initialize()

    self.Providers = {}
    self.OrderedProviders = {}

end


function DataManagementRegistry:RegisterCleanup(descriptor)

    assert(type(descriptor) == "table", "Cleanup descriptor must be a table.")
    assert(type(descriptor.id) == "string" and descriptor.id ~= "", "Cleanup descriptor id must be a string.")
    assert(
        (type(descriptor.displayNameKey) == "string" and descriptor.displayNameKey ~= "")
            or (type(descriptor.displayName) == "string" and descriptor.displayName ~= ""),
        "Cleanup descriptor requires displayNameKey or displayName."
    )
    assert(type(descriptor.clear) == "function", "Cleanup descriptor clear must be a function.")

    if self.Providers[descriptor.id] then
        error(("Cleanup provider '%s' is already registered."):format(descriptor.id))
    end

    descriptor.order = tonumber(descriptor.order) or 100
    self.Providers[descriptor.id] = descriptor
    table.insert(self.OrderedProviders, descriptor)

    table.sort(self.OrderedProviders, function(left, right)

        if left.order == right.order then
            return left.id < right.id
        end

        return left.order < right.order

    end)

    if AC.Events then
        AC.Events:Fire("DATA_MANAGEMENT_PROVIDERS_CHANGED")
    end

    return descriptor

end


function DataManagementRegistry:GetProviders()
    return self.OrderedProviders
end

function DataManagementRegistry:GetProvider(id)
    return self.Providers[id]
end


function DataManagementRegistry:IsAvailable(id)

    local descriptor = self.Providers[id]

    if not descriptor then
        return false
    end

    if not descriptor.isAvailable then
        return true
    end

    local ok, available = pcall(descriptor.isAvailable)

    if not ok then

        if AC.Logger then
            AC.Logger:Error(("Cleanup provider '%s' availability failed: %s"):format(id, tostring(available)))
        end

        return false
    end

    return available == true

end


function DataManagementRegistry:GetStatus(id)

    local descriptor = self.Providers[id]

    if not descriptor or not descriptor.getStatus then
        return ""
    end

    local ok, status = pcall(descriptor.getStatus)

    if not ok then

        if AC.Logger then
            AC.Logger:Error(("Cleanup provider '%s' status failed: %s"):format(id, tostring(status)))
        end

        return ""
    end

    return status or ""

end


function DataManagementRegistry:Clear(id, suppressNotification, ignoreAvailability)

    local descriptor = self.Providers[id]

    if not descriptor or (not ignoreAvailability and not self:IsAvailable(id)) then
        return false
    end

    local ok, result = pcall(descriptor.clear)

    if not ok then

        if AC.Logger then
            AC.Logger:Error(("Cleanup provider '%s' failed: %s"):format(id, tostring(result)))
        end

        return false
    end

    if not suppressNotification and AC.Events then
        AC.Events:Fire("DATA_MANAGEMENT_UPDATED", id)
    end

    return result ~= false

end


function DataManagementRegistry:ClearAll()

    local cleared = 0

    for _, descriptor in ipairs(self.OrderedProviders) do

        if self:Clear(descriptor.id, true, true) then
            cleared = cleared + 1
        end

    end

    if AC.Events then
        AC.Events:Fire("DATA_MANAGEMENT_UPDATED", nil)
    end

    return cleared

end


function DataManagementRegistry:HasAvailableProviders()

    for _, descriptor in ipairs(self.OrderedProviders) do

        if self:IsAvailable(descriptor.id) then
            return true
        end

    end

    return false

end


AC.ServiceManager:Register("DataManagementRegistry", DataManagementRegistry)

return DataManagementRegistry
