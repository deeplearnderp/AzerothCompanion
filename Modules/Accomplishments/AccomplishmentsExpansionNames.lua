-------------------------------------------------------------------------------
-- Azeroth Companion
-- Accomplishments Expansion Name Data
--
-- Supporting data for AccomplishmentsModule's classification -- kept in its
-- own file for the same reason AccomplishmentsPatterns.lua is: a future
-- content update (a new expansion ships) is a clean, isolated diff instead
-- of touching the module's logic.
--
-- IMPORTANT -- read before trusting this data:
--
-- Blizzard exposes no "expansion" field anywhere in the achievement API --
-- confirmed this pass: neither GetAchievementInfo's 15-value return nor
-- GetCategoryInfo's title/parentCategoryID/flags return carries any
-- expansion concept. The only signal is that Blizzard's own achievement
-- category tree nests one top-level category PER EXPANSION, and that
-- category's title IS the expansion's real name -- the same "trust
-- Blizzard's own category title" precedent AccomplishmentsModule.lua
-- already uses to identify "Feats of Strength" (see that module's own
-- header). This table is that expansion name list, oldest first, ending
-- at whatever this addon currently calls its "current" expansion
-- (matches this addon's own existing "Midnight" 12.1.0 API-availability
-- citations already in StorageModule.lua / docs/DEVELOPMENT_BACKLOG.md).
--
-- Treat this as a LIVING DOCUMENT requiring a one-line addition every time
-- a new expansion ships -- qualitatively cheaper to maintain than the
-- signature-pattern table (a new entry, never a changed one), but real
-- upkeep, not a one-time confirmation. The exact literal category titles
-- Blizzard uses should be spot-checked in-game before shipping (same
-- discipline as AccomplishmentsPatterns.lua's own per-entry verification
-- notes -- see VerificationService.lua's `acc.expansionNames` entry). An
-- achievement whose top-level category title matches nothing here gets
-- expansion = nil -- an honest gap, never a guess.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

AC.AccomplishmentsExpansionNames =
{
    "Classic",
    "The Burning Crusade",
    "Wrath of the Lich King",
    "Cataclysm",
    "Mists of Pandaria",
    "Warlords of Draenor",
    "Legion",
    "Battle for Azeroth",
    "Shadowlands",
    "Dragonflight",
    "The War Within",
    "Midnight",
}

return AC.AccomplishmentsExpansionNames
