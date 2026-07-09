-------------------------------------------------------------------------------
-- Azeroth Companion
-- Inventory Module
--
-- Maintains internal inventory and equipment caches.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local format = string.format

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerItemLink = C_Container.GetContainerItemLink
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetAverageItemLevel = GetAverageItemLevel

local InventoryModule =
{
    Name = "Inventory",
}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local SLOT_KEY_FORMAT = "%d:%d"

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function InventoryModule:ResetCaches()

    self.ItemsBySlot = {}
    self.ItemCounts = {}
    self.Equipment = {}

    self.Session =
    {
        initialBagFullness = 0,
    }

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function InventoryModule:Initialize()

    self:ResetCaches()

    AC.ConfigurationManager:Register("Inventory", Defaults)

    AC.Settings:RegisterPage("Inventory",
    {
        title = "Inventory",
        module = "Inventory",
        order = 30,
    })

    AC.Settings:RegisterSection("Inventory", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Inventory", "General",
    {
        key = "enabled",
        text = "Enable Inventory Module",
        default = true,
        tooltip = "Track bag contents and equipped items in memory.",
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function InventoryModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("BAG_UPDATE", self)
    AC.Events:Register("PLAYER_EQUIPMENT_CHANGED", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then
        self:ScanInventory()
        self:ScanEquipment()
    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function InventoryModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function InventoryModule:Shutdown()

    self:Disable()
    self:ResetCaches()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function InventoryModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Inventory", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function InventoryModule:OnPlayerEnteringWorld()

    if not self:IsModuleEnabled() then
        return
    end

    self:ScanInventory()
    self:ScanEquipment()

    -- Capture initial bag fullness for session tracking
    local items = self:GetItems()
    local usedSlots = #items
    local totalSlots = 0

    if GetContainerNumSlots then
        for bagID = 0, NUM_BAG_SLOTS do
            totalSlots = totalSlots + (GetContainerNumSlots(bagID) or 0)
        end
    end

    self.Session.initialBagFullness = totalSlots > 0 and (usedSlots / totalSlots * 100) or 0
    self.Session.initialTotalItemCount = self:GetTotalItemCount()

end

function InventoryModule:OnBagUpdate(bagID)

    if not self:IsModuleEnabled() then
        return
    end

    if type(bagID) ~= "number" then
        self:ScanInventory()
        return
    end

    self:ScanBag(bagID)

end

function InventoryModule:OnPlayerEquipmentChanged(equipmentSlot)

    if not self:IsModuleEnabled() then
        return
    end

    if type(equipmentSlot) == "number" then
        self:ScanEquipmentSlot(equipmentSlot)
    else
        self:ScanEquipment()
    end

end

function InventoryModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Inventory" then
        return
    end

    if key ~= "enabled" then
        return
    end

    if value then
        self:ScanInventory()
        self:ScanEquipment()
    else
        self:ResetCaches()
    end

end

-------------------------------------------------------------------------------
-- Scanning
-------------------------------------------------------------------------------

function InventoryModule:IterateBagIDs(callback)

    local bagID = 0

    while bagID <= NUM_BAG_SLOTS do
        callback(bagID)
        bagID = bagID + 1
    end

    local reagentBag = Enum.BagIndex and Enum.BagIndex.ReagentBag

    if type(reagentBag) == "number" and reagentBag > NUM_BAG_SLOTS then
        callback(reagentBag)
    end

end

function InventoryModule:MakeSlotKey(bagID, slot)

    return format(SLOT_KEY_FORMAT, bagID, slot)

end

function InventoryModule:RemoveBagFromCache(bagID)

    for slotKey, item in pairs(self.ItemsBySlot) do

        if item.bagID == bagID then

            local itemID = item.itemID
            local count = item.count or 0

            if itemID and count > 0 then
                self.ItemCounts[itemID] = (self.ItemCounts[itemID] or 0) - count

                if self.ItemCounts[itemID] <= 0 then
                    self.ItemCounts[itemID] = nil
                end

            end

            self.ItemsBySlot[slotKey] = nil

        end

    end

end

function InventoryModule:ScanBag(bagID)

    if type(bagID) ~= "number" then
        return
    end

    self:RemoveBagFromCache(bagID)

    local numSlots = GetContainerNumSlots(bagID)

    if not numSlots or numSlots <= 0 then
        return
    end

    for slot = 1, numSlots do

        local info = GetContainerItemInfo(bagID, slot)

        if info and info.itemID then

            local itemID = info.itemID
            local count = info.stackCount or 1
            local slotKey = self:MakeSlotKey(bagID, slot)

            self.ItemsBySlot[slotKey] =
            {
                itemID = itemID,
                count = count,
                bagID = bagID,
                slot = slot,
                link = GetContainerItemLink(bagID, slot),
            }

            self.ItemCounts[itemID] = (self.ItemCounts[itemID] or 0) + count

        end

    end

end

function InventoryModule:ScanInventory()

    self.ItemsBySlot = {}
    self.ItemCounts = {}

    self:IterateBagIDs(function(bagID)
        self:ScanBag(bagID)
    end)

end

function InventoryModule:ScanEquipmentSlot(slotID)

    if type(slotID) ~= "number" then
        return
    end

    local itemID = GetInventoryItemID("player", slotID)

    if not itemID then
        self.Equipment[slotID] = nil
        return
    end

    self.Equipment[slotID] =
    {
        itemID = itemID,
        slotID = slotID,
        link = GetInventoryItemLink("player", slotID),
    }

end

function InventoryModule:ScanEquipment()

    self.Equipment = {}

    local slotID = INVSLOT_FIRST_EQUIPPED

    while slotID <= INVSLOT_LAST_EQUIPPED do
        self:ScanEquipmentSlot(slotID)
        slotID = slotID + 1
    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function InventoryModule:GetItems()

    local items = {}
    local index = 1

    for _, item in pairs(self.ItemsBySlot) do
        items[index] = item
        index = index + 1
    end

    return items

end

function InventoryModule:GetEquipment()

    return self.Equipment

end

function InventoryModule:GetItemCount(itemID)

    itemID = tonumber(itemID)

    if not itemID then
        return 0
    end

    return self.ItemCounts[itemID] or 0

end

function InventoryModule:HasItem(itemID)

    return self:GetItemCount(itemID) > 0

end

function InventoryModule:GetTotalItemCount()

    local total = 0

    for _, count in pairs(self.ItemCounts) do
        total = total + (count or 0)
    end

    return total

end

function InventoryModule:GetBagSummary()

    local items = self:GetItems()
    local usedSlots = #items
    local totalSlots = 0

    if GetContainerNumSlots then
        for bagID = 0, NUM_BAG_SLOTS do
            totalSlots = totalSlots + (GetContainerNumSlots(bagID) or 0)
        end
    end

    local freeSlots = totalSlots - usedSlots
    local percentage = totalSlots > 0 and (usedSlots / totalSlots * 100) or 0

    return
    {
        usedSlots = usedSlots,
        freeSlots = freeSlots,
        totalSlots = totalSlots,
        percentage = percentage,
    }

end

function InventoryModule:GetEquipmentSummary()

    local equippedSlots = 0

    for _, item in pairs(self.Equipment) do
        if item then
            equippedSlots = equippedSlots + 1
        end
    end

    local totalSlots = (INVSLOT_LAST_EQUIPPED - INVSLOT_FIRST_EQUIPPED) + 1
    local emptySlots = totalSlots - equippedSlots

    local averageItemLevel = 0

    if GetAverageItemLevel then
        averageItemLevel = GetAverageItemLevel() or 0
    end

    return
    {
        equippedSlots = equippedSlots,
        emptySlots = emptySlots,
        totalSlots = totalSlots,
        averageItemLevel = averageItemLevel,
    }

end

function InventoryModule:GetImportantItemsSummary()

    local hasHearthstone = self:HasItem(6948)

    local needsRepair = nil

    if MerchantFrame and MerchantFrame:IsShown() and CanMerchantRepair and CanMerchantRepair() then

        local repairCost = GetRepairAllCost and GetRepairAllCost()

        needsRepair = (repairCost and repairCost > 0) or false

    end

    return
    {
        hasHearthstone = hasHearthstone,
        needsRepair = needsRepair,
    }

end

function InventoryModule:GetSessionSummary()

    local currentTotal = self:GetTotalItemCount()
    local initialTotal = self.Session.initialTotalItemCount or currentTotal

    local delta = currentTotal - initialTotal

    local itemsAdded = delta > 0 and delta or 0
    local itemsRemoved = delta < 0 and -delta or 0

    local bagSummary = self:GetBagSummary()
    local currentFullness = bagSummary.percentage or 0
    local bagUsageChange = currentFullness - (self.Session.initialBagFullness or currentFullness)

    return
    {
        itemsAdded = itemsAdded,
        itemsRemoved = itemsRemoved,
        bagUsageChange = bagUsageChange,
    }

end

-------------------------------------------------------------------------------
-- Insights
-------------------------------------------------------------------------------

function InventoryModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    local bagSummary = self:GetBagSummary()
    local usedSlots = bagSummary.usedSlots
    local totalSlots = bagSummary.totalSlots
    local percentage = bagSummary.percentage

    -- Bags over 90% full
    if percentage >= 90 then
        table.insert(insights,
        {
            title = "Bags Almost Full",
            description = string.format("Your bags are %.0f%% full (%d / %d slots used).", percentage, usedSlots, totalSlots),
            priority = 70,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Bags over 75% full
    if percentage >= 75 and percentage < 90 then
        table.insert(insights,
        {
            title = "Bags Filling Up",
            description = string.format("Your bags are %.0f%% full (%d / %d slots used).", percentage, usedSlots, totalSlots),
            priority = 40,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Hearthstone missing (check for hearthstone item ID 6948 or 6948)
    if not self:HasItem(6948) then
        table.insert(insights,
        {
            title = "Hearthstone Missing",
            description = "You do not have a Hearthstone in your bags.",
            priority = 50,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Equipment needs repair (only detectable while at a merchant, since
    -- CanMerchantRepair() requires the merchant frame to be open --
    -- reuses the same computation GetImportantItemsSummary already does)
    local importantItems = self:GetImportantItemsSummary()

    if importantItems.needsRepair then
        table.insert(insights,
        {
            title = "Repairs Needed",
            description = "Your equipment needs repair.",
            priority = 60,
            category = "Inventory",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Inventory", InventoryModule)

return InventoryModule
