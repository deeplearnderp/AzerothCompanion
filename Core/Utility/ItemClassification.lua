-------------------------------------------------------------------------------
-- Azeroth Companion
-- Item Classification
--
-- The single, shared classID/subClassID resolver and consumable classifier --
-- consolidated out of two independent implementations that used to compute
-- the same fact separately (StorageModule:GetItemClassInfo and
-- MythicPlusModule:ClassifyConsumableItem). Not a Service (no ServiceManager
-- registration, no lifecycle) and not a gameplay module -- a plain, stateless
-- utility shared by both, matching the "living data/utility file" pattern
-- already used by MythicPlusSpellData.lua/StorageProfiles.lua rather than
-- introducing new infrastructure. Depends only on Blizzard's own Enum/C_Item
-- globals, so it loads early, before either consumer module.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant

local ItemClassification = {}
AC.ItemClassification = ItemClassification

-------------------------------------------------------------------------------
-- classID/subClassID resolution
--
-- Memoized -- classID/subClassID are static per item, so this only ever
-- calls GetItemInfoInstant once per distinct itemID seen by the whole addon,
-- not once per caller. Generic: used for consumable subclass matching below
-- and, by StorageModule's own rule engine, for unrelated classKey matching
-- (Quest Items, Trade Goods) -- this function itself knows nothing about
-- consumables specifically.
-------------------------------------------------------------------------------

ItemClassification.ItemClassCache = {}

function ItemClassification:GetItemClassInfo(itemID)

    local cached = self.ItemClassCache[itemID]

    if cached then
        return cached
    end

    if not GetItemInfoInstant then
        return nil
    end

    local ok, _, _, _, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemID)

    if not ok or not classID then
        return nil
    end

    local info = { classID = classID, subClassID = subClassID }
    self.ItemClassCache[itemID] = info

    return info

end

-------------------------------------------------------------------------------
-- Consumable Classification
--
-- Deliberately NOT a hardcoded item-ID list -- potions/flasks/food are
-- reseasoned by Blizzard constantly, and a per-item list would go stale
-- every season. Instead this reads the item's own classID/subClassID (via
-- GetItemClassInfo above) against Blizzard's own stable taxonomy
-- (Enum.ItemClass.Consumable + Enum.ItemConsumableSubclass) -- a brand new
-- seasonal potion is correctly classified "potion" the day it ships, no
-- addon update needed. The one exception is Healthstone (itemID 5512), a
-- single, extremely long-standing item ID rather than a distinct subclass.
--
-- Trade-off: Blizzard's own classification does not distinguish healing vs.
-- mana vs. combat potions -- they are all just subclass "Potion". Reporting
-- that distinction would require a maintained per-potion-name list,
-- reintroducing exactly the seasonal staleness this design avoids, so this
-- reports an aggregate "potion" count rather than guessing at a finer split
-- Blizzard doesn't structurally expose.
-------------------------------------------------------------------------------

function ItemClassification:ClassifyConsumable(itemID)

    if itemID == 5512 then
        return "healthstone"
    end

    local classInfo = self:GetItemClassInfo(itemID)

    if not classInfo then
        return nil
    end

    local consumableClassID = (Enum.ItemClass and Enum.ItemClass.Consumable) or 0

    if classInfo.classID ~= consumableClassID then
        return nil
    end

    local subclassEnum = Enum.ItemConsumableSubclass

    if not subclassEnum then
        return nil
    end

    if classInfo.subClassID == subclassEnum.Potion then
        return "potion"
    elseif classInfo.subClassID == subclassEnum.Flasksphials then
        return "flask"
    elseif classInfo.subClassID == subclassEnum.Fooddrink then
        return "food"
    elseif classInfo.subClassID == subclassEnum.Itemenhancement then
        return "itemEnhancement"
    end

    return nil

end

return ItemClassification
