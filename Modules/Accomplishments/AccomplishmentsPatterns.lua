-------------------------------------------------------------------------------
-- Azeroth Companion
-- Accomplishments Signature Pattern Data
--
-- Supporting data for AccomplishmentsModule's classification -- kept in its
-- own file so a future content update to this list is a clean, isolated
-- diff instead of touching the module's logic, the same reasoning
-- MythicPlusSpellData.lua's own header already gives for its own table.
--
-- IMPORTANT -- read before trusting this data:
--
-- Blizzard exposes no "this is a signature/meta achievement" flag anywhere
-- in the achievement API -- confirmed this pass: GetAchievementInfo's own
-- `flags` bitfield is documented (Warcraft Wiki) as exactly three bits
-- (Statistic/Hidden/ProgressBar), nothing for "meta." The only way to
-- recognize Loremaster/Pathfinder/Ahead of the Curve/Cutting Edge/Keystone
-- Master/Keystone Hero/Glory of the X/Heritage of the X achievements is by
-- matching Blizzard's own long-standing NAMING CONVENTION for them -- a
-- real pattern, not a guaranteed API contract. Treat this whole table as a
-- LIVING DOCUMENT requiring periodic spot-check each expansion (see
-- Core/Services/VerificationService.lua's `acc.signaturePatterns` entry),
-- qualitatively different from a one-time API-shape confirmation -- Blizzard
-- could rename a convention with no addon-facing signal that it happened.
--
-- Per-entry verification status (checked this pass vs. not) is noted
-- inline. `matchType`: "prefix" (name starts with pattern), "suffix" (name
-- ends with pattern), "contains" (pattern anywhere in name). `category`
-- matches AccomplishmentsModule's own category values. First match in
-- table order wins -- ordering matters for the "Glory of the X <suffix>"
-- entries below, which must be checked before any catch-all.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

AC.AccomplishmentsPatterns = {}

AC.AccomplishmentsPatterns.SIGNATURE_PATTERNS =
{
    -- Spot-checked this pass (real, current examples confirmed via
    -- Warcraft Wiki/Wowhead cross-reference: "Heritage of the Vulpera",
    -- "Heritage of the Kul Tirans", "Heritage of the Lightforged").
    { pattern = "Heritage of the ", matchType = "prefix", category = "CharacterMilestones", isSignature = true },

    -- NOT independently re-spot-checked this pass -- long-standing,
    -- well-known conventions from general addon-development knowledge,
    -- flagged for live verification rather than asserted as confirmed.
    { pattern = "Ahead of the Curve: ", matchType = "prefix", category = "Raiding", isSignature = true },
    { pattern = "Cutting Edge: ", matchType = "prefix", category = "Raiding", isSignature = true },
    { pattern = "Keystone Master:", matchType = "prefix", category = "MythicPlus", isSignature = true },
    { pattern = "Keystone Hero:", matchType = "prefix", category = "MythicPlus", isSignature = true },
    { pattern = "Loremaster of ", matchType = "prefix", category = "ExpansionProgress", isSignature = true },

    -- The real form is "<Expansion> Pathfinder, Part One/Two" -- not a
    -- clean prefix, so this matches anywhere in the name instead.
    { pattern = "Pathfinder", matchType = "contains", category = "ExpansionProgress", isSignature = true },

    -- "Glory of the X Raider" (raid) vs. "Glory of the X Hero"/"...
    -- Dungeoneer" (dungeon-season) share the same prefix but end
    -- differently -- suffix-matched so the two don't collapse into one
    -- bucket. Least-confident entries in this table: not spot-checked
    -- this pass, and the exact suffix convention may not hold for every
    -- past expansion's Glory achievements.
    { pattern = "Raider", matchType = "suffix", category = "Raiding", requiresPrefix = "Glory of the " },
    { pattern = "Hero", matchType = "suffix", category = "MythicPlus", requiresPrefix = "Glory of the " },
    { pattern = "Dungeoneer", matchType = "suffix", category = "MythicPlus", requiresPrefix = "Glory of the " },
}

return AC.AccomplishmentsPatterns
