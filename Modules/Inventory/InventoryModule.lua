-------------------------------------------------------------------------------
-- Azeroth Companion
-- Inventory Module
--
-- Maintains internal inventory and equipment caches.
--
-- VERIFICATION STATUS (Live Verification & Framework Hardening sprint):
-- C_Container.GetContainerNumSlots/GetContainerItemInfo/GetContainerItemLink
-- confirmed via Warcraft Wiki (same ContainerItemInfo struct already
-- documented for Storage's bank scanning). Enum.BagIndex.ReagentBag
-- (value 5) confirmed real via Warcraft Wiki's full Enum.BagIndex table --
-- used correctly here (guarded, only iterated if it resolves to a number
-- greater than the standard bag count). GetRepairAllCost confirmed via
-- Warcraft Wiki, including its documented "requires a merchant window
-- open" constraint -- already correctly gated behind
-- `MerchantFrame:IsShown()`/`CanMerchantRepair()` at the one call site
-- (`GetEquipmentHealthSummary`), not a bug. GetAverageItemLevel confirmed
-- via Warcraft Wiki (3 return values: avgItemLevel, avgItemLevelEquipped,
-- avgItemLevelPvp; added 4.0.1). GetInventoryItemID/GetInventoryItemLink,
-- BAG_UPDATE/PLAYER_EQUIPMENT_CHANGED/PLAYER_ENTERING_WORLD/
-- SETTINGS_CHANGED are long-standing stable globals/events, materially
-- higher confidence than any of the above and not independently
-- re-researched this pass.
--
-- Equipment Health feature -- GetInventoryItemDurability(invSlotId) ->
-- current, max confirmed via Warcraft Wiki (single InventorySlotId
-- parameter, two return values). UPDATE_INVENTORY_DURABILITY confirmed
-- via Warcraft Wiki (fires whenever an equipped item's durability
-- changes, no payload args -- a full ScanEquipment() re-scan on this
-- event is correct, not a workaround, since there's no slot argument to
-- scan selectively). One thing NOT Wiki-confirmed this pass: which
-- specific slots return nil (no durability) versus 0/0. Jewelry/cosmetic
-- slots (Neck, both Rings, both Trinkets, Shirt, Tabard) are commonly
-- understood to have no durability and return nil, but that's general
-- game knowledge, not a documented API guarantee -- GetEquipmentHealthSummary
-- below is written to treat "no max durability returned" as "not tracked"
-- regardless of whether that shows up as nil or 0, so this is safe either
-- way, but worth a live spot-check.
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
local GetInventoryItemDurability = GetInventoryItemDurability
local GetAverageItemLevel = GetAverageItemLevel

local InventoryModule =
{
    Name = "Inventory",
}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local SLOT_KEY_FORMAT = "%d:%d"

-- Exposed on AC (not just a local here) since StorageProfiles.lua's own
-- built-in "Keep 1 Hearthstone" rule needs the same item ID -- previously
-- hardcoded independently in both files (v1.0 Polish Sprint audit); this
-- is now the one place it's defined. InventoryModule still owns
-- hearthstone *possession* detection (HasItem, GetImportantItemsSummary,
-- "Hearthstone Missing" Insight below) -- this is just the shared
-- identifier, not a second owner.
AC.HEARTHSTONE_ITEM_ID = 6948

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
    self.InventorySnapshotSequence = self.InventorySnapshotSequence or 0
    self.InventorySnapshotTimestamp = nil

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

    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if character and character.Inventory then
        self:LoadSnapshot(character.Inventory)
    end

    AC.DataManagementRegistry:RegisterCleanup(
    {
        id = "inventory-cache",
        order = 40,
        displayNameKey = "DataManagement.Inventory.Name",
        descriptionKey = "DataManagement.Inventory.Description",
        actionLabelKey = "DataManagement.Inventory.Action",
        confirmationTitleKey = "DataManagement.Inventory.ConfirmTitle",
        confirmationDescriptionKey = "DataManagement.Inventory.ConfirmDescription",
        getStatus = function()

            local snapshot = self:GetInventorySnapshot()

            if snapshot.timestamp then
                return AC.L:Format("DataManagement.StatusLastScan", AC.Presentation.FormatDate(snapshot.timestamp, "shortTime"))
            end

            return AC.L:Get("DataManagement.StatusNoCache")

        end,
        isAvailable = function()
            local currentCharacter = AC.DatabaseService and AC.DatabaseService:GetCharacter()
            return self.InventorySnapshotTimestamp ~= nil or (currentCharacter and currentCharacter.Inventory ~= nil) or false
        end,
        clear = function()
            self:ClearInventoryCache()
        end,
    })

end

function InventoryModule:ClearInventoryCache()

    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if character then
        character.Inventory = nil
    end

    self:ResetCaches()
    AC.Events:Fire("INVENTORY_SNAPSHOT_UPDATED")

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function InventoryModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("BAG_UPDATE", self)
    AC.Events:Register("PLAYER_EQUIPMENT_CHANGED", self)
    AC.Events:Register("UPDATE_INVENTORY_DURABILITY", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    --[[if self:IsModuleEnabled() then
        self:ScanInventory()
        self:ScanEquipment()
    end]]

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

function InventoryModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    self:ScanInventory()
    self:ScanEquipment()

    if isInitialLogin then
        local bagSummary = self:GetBagSummary()

        self.Session.initialBagFullness = bagSummary.percentage
        self.Session.initialTotalItemCount = self:GetTotalItemCount()
    end

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
    self:SaveSnapshot()
    self:MarkInventorySnapshotUpdated()

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

-- Equipment Health -- no slot argument is passed with this event (Wiki-
-- confirmed, see this file's own header), so a full re-scan is the only
-- option, not a shortcut taken for convenience. Cheap regardless -- 19
-- equipment slots, no bag scanning.
function InventoryModule:OnUpdateInventoryDurability()

    if not self:IsModuleEnabled() then
        return
    end

    self:ScanEquipment()

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
        AC.Events:Fire("INVENTORY_SNAPSHOT_UPDATED")
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

                -- Additive field for StorageModule's Quality-type rule
                -- matching (see docs/GameplayModuleArchitecture.md,
                -- "Storage") -- already returned by GetContainerItemInfo,
                -- just not previously stored. Does not change any
                -- existing reader of this record.
                quality = info.quality,
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
    
    self:MarkInventorySnapshotUpdated()

end

function InventoryModule:MarkInventorySnapshotUpdated()

    self.InventorySnapshotSequence = (self.InventorySnapshotSequence or 0) + 1
    self.InventorySnapshotTimestamp = time()

    AC.Events:Fire("INVENTORY_SNAPSHOT_UPDATED")

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

    -- durabilityCurrent/Max come back nil for slots that don't track
    -- durability (jewelry/cosmetic -- see this file's own header comment).
    -- Stored as-is, nil and all -- GetEquipmentHealthSummary is what
    -- decides "not tracked" vs "tracked", not this scan.
    local durabilityCurrent, durabilityMax = GetInventoryItemDurability(slotID)

    self.Equipment[slotID] =
    {
        itemID = itemID,
        slotID = slotID,
        link = GetInventoryItemLink("player", slotID),
        durabilityCurrent = durabilityCurrent,
        durabilityMax = durabilityMax,
    }

    self:SaveSnapshot()

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
-- Snapshot Persistence
-------------------------------------------------------------------------------

function InventoryModule:BuildSnapshot()

    local snapshot =
    {
        timestamp = time(),
        bags = {},
        equipment = {},
    }

    for key, item in pairs(self.ItemsBySlot) do
        snapshot.bags[key] =
        {
            itemID = item.itemID,
            count = item.count,
            bagID = item.bagID,
            slot = item.slot,
            link = item.link,
            quality = item.quality,
        }
    end

    for slotID, item in pairs(self.Equipment) do
        snapshot.equipment[slotID] = item
    end

    return snapshot

end

function InventoryModule:SaveSnapshot()

    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if not character then
        return
    end

    character.Inventory = self:BuildSnapshot()

end

function InventoryModule:LoadSnapshot(snapshot)

    if type(snapshot) ~= "table" then
        return
    end

    self.ItemsBySlot = {}
    self.ItemCounts = {}
    self.Equipment = {}

    for key, item in pairs(snapshot.bags or {}) do
        self.ItemsBySlot[key] = item
        if item.itemID then
            self.ItemCounts[item.itemID] =
            (self.ItemCounts[item.itemID] or 0) + (item.count or 1)
        end
    end

    for slotID, item in pairs(snapshot.equipment or {}) do
        self.Equipment[slotID] = item
    end

    self.InventorySnapshotTimestamp = snapshot.timestamp
    self.InventorySnapshotSequence = (self.InventorySnapshotSequence or 0) + 1

    AC.Events:Fire("INVENTORY_SNAPSHOT_UPDATED")
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

-- Authoritative, read-only bag snapshot for aggregate consumers such as
-- StorageModule. Bag scanning remains entirely owned by InventoryModule.
function InventoryModule:GetInventorySnapshot()

    local items = {}
    local hasSnapshot = self.InventorySnapshotTimestamp ~= nil
    local empty

    for _, item in pairs(self.ItemsBySlot) do

        table.insert(items,
                {
                    itemID = item.itemID,
                    count = item.count,
                    bagID = item.bagID,
                    slot = item.slot,
                    link = item.link,
                    quality = item.quality,
                })

    end

    table.sort(items, function(left, right)

        if left.bagID == right.bagID then
            return left.slot < right.slot
        end

        return left.bagID < right.bagID

    end)

    if hasSnapshot then
        empty = #items == 0
    end

    return
    {
        id = hasSnapshot and self.InventorySnapshotSequence or nil,
        timestamp = self.InventorySnapshotTimestamp,
        available = self:IsModuleEnabled() and hasSnapshot,
        freshness = hasSnapshot and "current" or "unknown",
        empty = empty,
        items = items,
        summary = hasSnapshot and self:GetBagSummary() or nil,
    }

end

function InventoryModule:GetEquipment()

    return self.Equipment

end

-------------------------------------------------------------------------------
-- Free Bag Slot
--
-- Reads this module's own already-maintained ItemsBySlot cache to find
-- one empty bag slot -- not a new scan, just a query over data Inventory
-- already owns. Exists so StorageModule can ask "where would a withdrawn
-- item go?" through Inventory's public API (Architectural Rule 7)
-- instead of scanning bags itself. Returns nil, nil if bags are full.
-------------------------------------------------------------------------------

function InventoryModule:GetFreeBagSlot()

    local freeBagID, freeSlot

    self:IterateBagIDs(function(bagID)

        if freeBagID then
            return
        end

        local numSlots = GetContainerNumSlots(bagID)

        if not numSlots or numSlots <= 0 then
            return
        end

        for slot = 1, numSlots do

            local slotKey = self:MakeSlotKey(bagID, slot)

            if not self.ItemsBySlot[slotKey] then
                freeBagID, freeSlot = bagID, slot
                break
            end

        end

    end)

    return freeBagID, freeSlot

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
        self:IterateBagIDs(function(bagID)
            totalSlots = totalSlots + (GetContainerNumSlots(bagID) or 0)
        end)
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

    local hasHearthstone = self:HasItem(AC.HEARTHSTONE_ITEM_ID)

    return
    {
        hasHearthstone = hasHearthstone,
    }

end

-------------------------------------------------------------------------------
-- Equipment Health
--
-- The one place equipped-gear durability is computed -- Dashboard and
-- RecommendationEngine both read this directly; neither recalculates it
-- (One Fact, One Home). Skips any slot where durabilityMax is nil/0 --
-- that's "not tracked" (jewelry/cosmetic), not "broken".
--
-- overallDurability is durability-WEIGHTED (sum of current / sum of max
-- across tracked pieces), not a simple average of per-item percentages --
-- this reflects the total remaining durability pool rather than letting a
-- low-max-durability piece count the same as a high-max one.
--
-- worstDurability (the single lowest percentage among tracked pieces) is
-- tracked separately and deliberately: a single broken weapon or armor
-- piece has real gameplay consequences (a broken weapon deals no damage)
-- regardless of what the average looks like. Dashboard and
-- RecommendationEngine key severity off worstDurability/brokenItems, not
-- overallDurability, for exactly this reason.
--
-- repairCost is nil unless standing at a repair-capable merchant --
-- GetRepairAllCost's own documented constraint (Warcraft Wiki-confirmed,
-- see this file's header), same gate this codebase already used before
-- this feature existed.
-------------------------------------------------------------------------------

function InventoryModule:GetEquipmentHealthSummary()

    local totalCurrent, totalMax = 0, 0
    local worstDurability = nil
    local brokenItems, damagedItems = 0, 0

    for _, item in pairs(self.Equipment) do

        if item and item.durabilityMax and item.durabilityMax > 0 then

            totalCurrent = totalCurrent + (item.durabilityCurrent or 0)
            totalMax = totalMax + item.durabilityMax

            local percentage = (item.durabilityCurrent or 0) / item.durabilityMax * 100

            if not worstDurability or percentage < worstDurability then
                worstDurability = percentage
            end

            if (item.durabilityCurrent or 0) <= 0 then
                brokenItems = brokenItems + 1
            elseif item.durabilityCurrent < item.durabilityMax then
                damagedItems = damagedItems + 1
            end

        end

    end

    local overallDurability = totalMax > 0 and (totalCurrent / totalMax * 100) or nil
    local repairCost = nil

    if MerchantFrame and MerchantFrame:IsShown() and CanMerchantRepair and CanMerchantRepair() then
        repairCost = GetRepairAllCost and GetRepairAllCost()
    end

    return
    {
        overallDurability = overallDurability,
        worstDurability = worstDurability,
        brokenItems = brokenItems,
        damagedItems = damagedItems,
        repairCost = repairCost,
        needsRepair = (brokenItems + damagedItems) > 0,
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

    -- Hearthstone missing
    if not self:HasItem(AC.HEARTHSTONE_ITEM_ID) then
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

    -- Equipment needs repair -- now detectable anywhere (Equipment Health
    -- feature), not just at a merchant; GetEquipmentHealthSummary is the
    -- one place this is computed, read directly rather than through
    -- GetImportantItemsSummary's now-hearthstone-only shape. Priority
    -- escalates when something is fully broken (a broken weapon deals no
    -- damage -- a materially worse state than merely damaged gear, not an
    -- arbitrary bump). data carries the real numbers through to
    -- RecommendationEngine so it can vary its own wording without
    -- recalculating anything itself (No Duplicated Calculations).
    local equipmentHealth = self:GetEquipmentHealthSummary()

    if equipmentHealth.needsRepair then
        table.insert(insights,
                {
                    title = "Repairs Needed",
                    description = "Your equipment needs repair.",
                    priority = equipmentHealth.brokenItems > 0 and 80 or 60,
                    category = "Inventory",
                    timestamp = time(),
                    expiresAt = 0,
                    dismissible = false,
                    data =
                    {
                        brokenItems = equipmentHealth.brokenItems,
                        damagedItems = equipmentHealth.damagedItems,
                        worstDurability = equipmentHealth.worstDurability,
                        repairCost = equipmentHealth.repairCost,
                    },
                })
    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Inventory", InventoryModule)

return InventoryModule
