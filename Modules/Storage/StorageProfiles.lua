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
-- (Enum.ItemClass/Enum.ItemConsumableSubclass), resolved through the shared
-- AC.ItemClassification (Core/Utility/ItemClassification.lua) -- the same
-- self-maintaining classifier MythicPlusModule's consumable tracking also
-- reads, so a brand-new seasonal potion is matched correctly the day it
-- ships, no addon update required.
--
-- Recommendation Mode (Storage Supply Manager Sprint) -- not a field on
-- the rule table itself (that stays shared, built-in data, not per-
-- player). Per-character mode ("CompanionRecommended" | "Preferred" |
-- "Any") and any preferred itemID override live in
-- ConfigurationManager, keyed by profile id + rule label (see
-- StorageModule:GetRecommendationMode/SetRecommendationMode). Every
-- rule reads as "Any" -- today's existing behavior, unchanged -- until a
-- player explicitly picks something else. "CompanionRecommended" has no
-- effect yet: the shared ItemRecommendationService this mode is designed
-- to call is a reserved future service, not built this pass -- see
-- docs/GameplayModuleArchitecture.md's Storage section for the full
-- architecture writeup. This is intentionally NOT a field on this table:
-- these presets are shared, built-in data every character reads
-- identically; a player's chosen mode/override is their own state.
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
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Flasksphials" }, amount = 8, label = "Storage.Rule.Flasks" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Fooddrink" }, amount = 40, label = "Storage.Rule.Food" },
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
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Flasksphials" }, amount = 8, label = "Storage.Rule.Flasks" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Fooddrink" }, amount = 40, label = "Storage.Rule.Food" },
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

    -- Storage Supply Manager Sprint -- Delves/PvP were requested profiles
    -- with no prior preset to draw from. Amounts below are a starting
    -- default, not a researched balance number -- deliberately mirroring
    -- Raid/MythicPlus's own shape (same rule types, same NeverMove
    -- guards) rather than inventing new consumable categories, since
    -- fabricating a PvP-specific item ID would be exactly the kind of
    -- guess this addon avoids elsewhere. Meant to be tuned, not treated
    -- as final -- see this file's own header on why that's a data-only
    -- edit, not an engine change.
    {
        id = "Delves",
        label = "Storage.Profile.Delves",
        builtin = true,
        rules =
        {
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Potion" }, amount = 10, label = "Storage.Rule.Potions" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Flasksphials" }, amount = 4, label = "Storage.Rule.Flasks" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Fooddrink" }, amount = 20, label = "Storage.Rule.Food" },
            { action = "NeverMove", targetType = "Category", targetValue = { classKey = "Questitem" }, label = "Storage.Rule.QuestItems" },
            { action = "NeverMove", targetType = "Equipped", targetValue = nil, label = "Storage.Rule.CurrentEquipment" },
        },
    },
    {
        id = "PvP",
        label = "Storage.Profile.PvP",
        builtin = true,
        rules =
        {
            -- No Flask rule -- unlike Raid/Mythic+/Delves, PvP consumable
            -- conventions lean far more on player preference than a
            -- default this addon should assert. Left out rather than
            -- guessed at.
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Potion" }, amount = 10, label = "Storage.Rule.Potions" },
            { action = "Maintain", targetType = "Category", targetValue = { subclass = "Fooddrink" }, amount = 20, label = "Storage.Rule.Food" },
            { action = "NeverMove", targetType = "Category", targetValue = { classKey = "Questitem" }, label = "Storage.Rule.QuestItems" },
            { action = "NeverMove", targetType = "Equipped", targetValue = nil, label = "Storage.Rule.CurrentEquipment" },
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
