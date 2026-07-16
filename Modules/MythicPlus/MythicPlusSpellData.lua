-------------------------------------------------------------------------------
-- Azeroth Companion
-- Mythic+ Spell Reference Data
--
-- Supporting data for MythicPlusModule's run tracking -- kept in its own
-- file so a future content update to this list is a clean, isolated
-- diff instead of touching the module's logic.
--
-- IMPORTANT -- read before trusting this data:
--
-- The Defensives table below is a best-effort list of well-known, long-
-- standing class "oh crap" cooldowns, compiled from general knowledge
-- and NOT verified against a live client from this environment (no WoW
-- client is reachable here). Treat every spell ID as needing a spot
-- check in-game (e.g. hover the ability and compare to /run
-- print(GetSpellInfo(<id>)), or use the Diagnostics trace framework)
-- before relying on it. This list is inherently a living document, not a
-- finished one -- Blizzard renames, reworks, and rebalances class
-- defensives most expansions, and this only covers one well-known
-- cooldown per class, not every situational defensive.
--
-- There is deliberately no equivalent table for consumables (potions,
-- flasks, food, weapon oils, augment runes). Those are bag items, not
-- spells, and Blizzard's own item classification (C_Item.GetItemInfoInstant's
-- classID/subClassID, via Enum.ItemClass.Consumable and
-- Enum.ItemConsumableSubclass) already tells us "this is a potion" /
-- "this is a flask" without needing to know which specific seasonal
-- item it is. That check lives in the shared AC.ItemClassification
-- (Core/Utility/ItemClassification.lua, called from MythicPlusModule:
-- ClassifyConsumableItem) because it needs no per-season maintenance --
-- a hardcoded item-ID list would go stale every season as Blizzard
-- rotates the current potion/flask, which is exactly the kind of
-- guaranteed-to-rot data this file's structure is meant to avoid.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

AC.MythicPlusSpellData = {}

-------------------------------------------------------------------------------
-- Defensives
--
-- Keyed by class file name (UnitClass's 3rd return value / already what
-- CharacterModule stores as profile.classFile) -- each entry is
-- { [spellID] = displayName }. Only the single most iconic, long-standing
-- defensive per class is listed; a class using an unlisted defensive
-- simply won't be counted, which is the correct, honest behavior for
-- data this module isn't confident about rather than guessing further.
-------------------------------------------------------------------------------

AC.MythicPlusSpellData.Defensives =
{
    WARRIOR = { [871] = "Shield Wall", [12975] = "Last Stand" },
    PALADIN = { [642] = "Divine Shield", [498] = "Divine Protection" },
    HUNTER = { [186265] = "Aspect of the Turtle" },
    ROGUE = { [31224] = "Cloak of Shadows" },
    PRIEST = { [47585] = "Dispersion", [47788] = "Guardian Spirit" },
    DEATHKNIGHT = { [48792] = "Icebound Fortitude", [48707] = "Anti-Magic Shell" },
    SHAMAN = { [108271] = "Astral Shift" },
    MAGE = { [45438] = "Ice Block" },
    WARLOCK = { [104773] = "Unending Resolve" },
    MONK = { [115203] = "Fortifying Brew", [122783] = "Diffuse Magic" },
    DRUID = { [61336] = "Survival Instincts", [22812] = "Barkskin" },
    DEMONHUNTER = { [198589] = "Blur", [196718] = "Darkness" },
    EVOKER = { [363916] = "Obsidian Scales", [374348] = "Renewing Blaze" },
}

return AC.MythicPlusSpellData
