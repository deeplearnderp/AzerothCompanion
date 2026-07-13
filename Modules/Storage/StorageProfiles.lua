-------------------------------------------------------------------------------
-- Azeroth Companion
-- Storage Profiles (Built-In Presets)
--
-- Data only -- no logic -- following the same "living data table" pattern
-- as Modules/MythicPlus/MythicPlusSpellData.lua. A full user-facing rule
-- builder (add/edit/delete arbitrary rules) was explicitly deferred this
-- pass (see docs/GameplayModuleArchitecture.md, Storage section); these
-- built-in presets are what StorageModule ships with today. Adding a
-- rule editor later means writing UI that edits this same rule shape --
-- no engine change required (StorageModule:MatchesRule/AnalyzeProfile
-- already work generically against any table of this shape).
--
-- Rule shape:
--   {
--     action = "Maintain" | "Keep" | "Deposit" | "NeverMove",
--     targetType = "Item" | "Category" | "Quality" | "Expansion" | "Group",
--     targetValue = <itemID | {classID=, subClassID=} | Enum.ItemQuality value | expacID | group name>,
--     amount = <number, only meaningful for Maintain/Keep/Deposit>,
--     label = "<display text -- a Localization key, resolved by the caller>",
--   }
--
-- "Maintain" = keep at least `amount` of this in bags (restock target).
-- "Keep"     = same as Maintain but phrased for a single always-carry
--              item (Hearthstone, a toy) rather than a stacked consumable.
-- "Deposit"  = anything in bags beyond `amount` (0 for "Deposit All") is
--              flagged for deposit to the bank.
-- "NeverMove" = an exclusion -- checked before any Maintain/Keep/Deposit
--              rule, so a favorited/equipped/quest item is never flagged
--              for deposit even if it also matches a broader category rule.
--
-- Category targets use Blizzard's own classID/subClassID taxonomy
-- (Enum.ItemClass/Enum.ItemConsumableSubclass) -- the same self-maintaining
-- approach MythicPlusModule:ClassifyConsumableItem already uses, so a
-- brand-new seasonal potion is matched correctly the day it ships, no
-- addon update required.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

AC.StorageProfiles = AC.StorageProfiles or {}

AC.StorageProfiles.BuiltIn =
{
    {
        id = "MythicPlus",
        label = "Storage.Profile.MythicPlus",
        builtin = true,
        rules =
        {
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Potion" }, amount = 20, label = "Storage.Rule.Potions" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Flask" }, amount = 8, label = "Storage.Rule.Flasks" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Food" }, amount = 40, label = "Storage.Rule.Food" },
            { action = "Keep", targetType = "Item", targetValue = AC.HEARTHSTONE_ITEM_ID, amount = 1, label = "Storage.Rule.Hearthstone" },
            { action = "NeverMove", targetType = "Category", targetValue = { classKey = "Questitem" }, label = "Storage.Rule.QuestItems" },
            { action = "NeverMove", targetType = "Equipped", targetValue = nil, label = "Storage.Rule.CurrentEquipment" },
        },
    },
    {
        id = "Raid",
        label = "Storage.Profile.Raid",
        builtin = true,
        rules =
        {
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Potion" }, amount = 40, label = "Storage.Rule.Potions" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Flask" }, amount = 8, label = "Storage.Rule.Flasks" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Food" }, amount = 40, label = "Storage.Rule.Food" },
            { action = "NeverMove", targetType = "Category", targetValue = { classKey = "Questitem" }, label = "Storage.Rule.QuestItems" },
            { action = "NeverMove", targetType = "Equipped", targetValue = nil, label = "Storage.Rule.CurrentEquipment" },
        },
    },
    {
        id = "Questing",
        label = "Storage.Profile.Questing",
        builtin = true,
        rules =
        {
            { action = "Keep", targetType = "Item", targetValue = AC.HEARTHSTONE_ITEM_ID, amount = 1, label = "Storage.Rule.Hearthstone" },
            { action = "NeverMove", targetType = "Category", targetValue = { classKey = "Questitem" }, label = "Storage.Rule.QuestItems" },
            { action = "Deposit", targetType = "Category", targetValue = { classKey = "Tradegoods" }, amount = 0, label = "Storage.Rule.CraftingMaterials" },
        },
    },
    {
        id = "Custom",
        label = "Storage.Profile.Custom",
        builtin = true,
        rules = {},
    },
}

return AC.StorageProfiles
