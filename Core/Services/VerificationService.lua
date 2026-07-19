-------------------------------------------------------------------------------
-- Azeroth Companion
-- Verification Service
--
-- Live Verification & Framework Hardening sprint. Single source of truth
-- for "what do we actually know about each Blizzard API this addon
-- depends on, and how do we know it" -- the Developer Panel's Live API
-- tab, its Checklist tab, and DEVELOPMENT_BACKLOG.md's verification
-- section are all rendered/generated views over the same data here, not
-- independently maintained copies that can drift out of sync.
--
-- Two independent kinds of record:
--
--   Registry (below, REGISTRY) -- static, in-code, one entry per checkable
--   API/behavior, each already classified against the trust hierarchy
--   (Blizzard Source / Warcraft Wiki / Live Client / Needs Live /
--   Incorrect) with a real citation. This is documentation as data.
--
--   Log (persisted, DatabaseService:GetGlobal().VerificationLog /
--   .ChecklistLog) -- one record per registry id or checklist scenario,
--   written ONLY when a human confirms a real result (DeveloperPanel's
--   Mark Verified/Mark Failed buttons, or ticking off a guided-checklist
--   scenario). Never written automatically -- an addon cannot verify its
--   own correctness against the live game, only a human watching the
--   real result can. Account-wide (DatabaseService's Global table), not
--   character-scoped, since API behavior is a fact about the game
--   client/account, not about any one character.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local pairs = pairs
local ipairs = ipairs
local time = time

local VerificationService =
{
    Name = "VerificationService",
}

AC.VerificationService = VerificationService

-------------------------------------------------------------------------------
-- Status Enum
-------------------------------------------------------------------------------

VerificationService.Status =
{
    SOURCE = "source",       -- Verified by Blizzard Source (Interface FrameXML/generated API docs)
    WIKI = "wiki",           -- Verified by Warcraft Wiki
    LIVE = "live",           -- Verified in the live game (human-confirmed)
    NEEDS_LIVE = "needsLive",-- Cannot be settled by source/docs alone
    INCORRECT = "incorrect", -- Confirmed wrong/nonexistent
}

-- Presentation Asset Audit -- these previously carried an independent
-- copy of the same checkmark/cross bytes DashboardFormat.CHECK_SUCCESS/
-- CHECK_FAILURE already define (colored, for Dashboard rows). Both now
-- point at the one shared bare-glyph source (AC.Presentation), so a
-- future font-support fix only has one place to touch.
VerificationService.StatusGlyph =
{
    source = AC.Presentation.CHECK_GLYPH,
    wiki = AC.Presentation.CHECK_GLYPH,
    live = AC.Presentation.CHECK_GLYPH,
    needsLive = AC.Presentation.WARNING_GLYPH,
    incorrect = AC.Presentation.CROSS_GLYPH,
}

VerificationService.StatusLabelKey =
{
    source = "Developer.StatusSource",
    wiki = "Developer.StatusWiki",
    live = "Developer.StatusLive",
    needsLive = "Developer.StatusNeedsLive",
    incorrect = "Developer.StatusIncorrect",
}

-------------------------------------------------------------------------------
-- Registry
--
-- One row per checkable Blizzard API/behavior this addon actually calls.
-- `status` is the current best-known classification from source/docs
-- research; a human "Mark Verified"/"Mark Failed" action (RecordResult
-- below) can raise it to `live` or drop it to `incorrect` without editing
-- this table. `confidence` is a separate axis: even a wiki-confirmed
-- entry can be Medium if the wiki page itself under-documents a
-- parameter (see ach.categoryEnumeration).
-------------------------------------------------------------------------------

local S = VerificationService.Status

local REGISTRY =
{
    -- Character -----------------------------------------------------------
    { id = "char.unitAccessors", module = "Character", api = "UnitName/UnitFullName/UnitGUID/UnitRace/UnitClass/UnitLevel/UnitFactionGroup", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (foundational Unit* API family)", expected = "Real values for unit \"player\"; never nil for a logged-in character.",
      notes = "Not individually re-fetched this pass -- unchanged across the game's entire history, negligible risk." },
    { id = "char.realmZone", module = "Character", api = "GetRealmName/GetZoneText/GetSubZoneText", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", expected = "Current realm/zone/subzone strings; subZone may be empty string outside a named subzone.",
      notes = "Not individually re-fetched this pass -- long-standing stable globals." },
    { id = "char.money", module = "Character", api = "GetMoney", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki", expected = "Copper amount, number, never nil." },
    { id = "char.bindLocation", module = "Character", api = "GetBindLocation", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki", expected = "Hearthstone-bound subzone name string." },
    { id = "char.restedXP", module = "Character", api = "GetXPExhaustion", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki",
      expected = "Number (rested XP pool), or nil if the player is not rested -- module must nil-guard, does." },
    { id = "char.specialization", module = "Character", api = "C_SpecializationInfo.GetSpecialization / GetSpecializationInfo", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", expected = "specIndex number (or nil if unlearned); GetSpecializationInfo(specIndex) returns specId/name/description/icon/role/primaryStat as its first 6 values.",
      notes = "Migrated this pass off the global GetSpecialization()/GetSpecializationInfo(), both confirmed deprecated since patch 11.2.0. The new namespaced calls return the same first 6 values in the same order, confirmed via Warcraft Wiki -- a safe drop-in, not a guess." },
    { id = "char.itemLevel", module = "Character / Inventory", api = "GetAverageItemLevel", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki (added 4.0.1)",
      expected = "3 return values in order: avgItemLevel, avgItemLevelEquipped, avgItemLevelPvp." },
    { id = "char.guildInfo", module = "Character", api = "GetGuildInfo(\"player\")", status = S.WIKI, confidence = "Medium", citation = "Warcraft Wiki",
      expected = "guildName, guildRankName, guildRankIndex, realm (4 values); can return nil during initial login load.",
      notes = "Wiki recommends re-reading on GUILD_ROSTER_UPDATE/PLAYER_GUILD_UPDATE for reliability; this module already registers PLAYER_GUILD_UPDATE, not independently confirmed live that a single refresh on that event is always sufficient." },
    { id = "char.maxLevel", module = "Character", api = "GetMaxLevelForPlayerExpansion", status = S.WIKI, confidence = "Medium", citation = "Warcraft Wiki",
      expected = "Single deterministic level number for the current expansion.", notes = "Not individually re-fetched this pass." },
    { id = "char.bestMap", module = "Character / MythicPlus", api = "C_Map.GetBestMapForUnit", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki",
      expected = "UI map ID number for \"player\"/\"party1\" etc, or nil.", notes = "Confirmed across two separate passes (MythicPlus death-location capture, and this pass)." },
    { id = "char.removedApis", module = "Character", api = "C_Hearthstone.GetHearthstone / C_PlayerInfo.GetAccountGUID", status = S.INCORRECT, confidence = "High",
      citation = "Blizzard's own generated API documentation (Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua lists all 32 real C_PlayerInfo functions; GetAccountGUID is not among them) + Warcraft Wiki's full API index (no C_Hearthstone namespace listed anywhere)",
      expected = "N/A -- both APIs do not exist.", notes = "Removed this pass, not patched in place: both fields (hearthstoneItemID, warband.accountGUID) were confirmed dead (never read anywhere in the codebase) before removal." },

    -- Inventory -------------------------------------------------------------
    { id = "inv.container", module = "Inventory / Storage", api = "C_Container.GetContainerNumSlots / GetContainerItemInfo / GetContainerItemLink", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (ContainerItemInfo struct)", expected = "Standard post-10.0 container API; ContainerItemInfo has no isFavorite field (see storage.favoriteField)." },
    { id = "inv.equippedSlots", module = "Inventory", api = "GetInventoryItemID / GetInventoryItemLink", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki",
      notes = "Not individually re-fetched this pass -- foundational, unchanged." },
    { id = "inv.reagentBagEnum", module = "Inventory", api = "Enum.BagIndex.ReagentBag", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki (Enum.BagIndex full table, value 5)",
      expected = "A number greater than the standard 4 bag slots; used correctly (guarded, only iterated when it resolves to a number)." },
    { id = "inv.repairCost", module = "Inventory", api = "GetRepairAllCost / CanMerchantRepair", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki",
      expected = "repairAllCost (copper), canRepair; only meaningful while a repair-capable merchant window is open.",
      notes = "Already correctly gated behind MerchantFrame:IsShown()/CanMerchantRepair() at the one call site -- matches the documented constraint exactly, not a bug." },

    -- Accomplishments (formerly Achievements -- `ach.*` id prefixes kept
    -- unchanged for persisted VerificationLog compatibility, same
    -- reasoning ActivityHistoryService's own stored "Achievements" Module
    -- tag was kept -- see AccomplishmentsModule.lua's own header) --------
    { id = "ach.achievementInfo", module = "Accomplishments", api = "GetAchievementInfo(achievementID) / GetAchievementInfo(categoryID, index)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", expected = "15 values in order: id,name,points,completed,month,day,year,description,flags,icon,rewardText,isGuild,wasEarnedByMe,earnedBy,isStatistic; identical shape for both call forms." },
    { id = "ach.categoryEnumeration", module = "Accomplishments", api = "GetCategoryList / GetCategoryNumAchievements / GetAchievementInfo(categoryID, index)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Warcraft Wiki (documents the pattern; Blizzard's own achievement UI uses this exact category-then-index traversal)",
      expected = "Every completed, non-statistic achievement the player has earned is discovered exactly once across all categories.",
      notes = "Fixed a prior pass to replace a stale hardcoded `for achievementID = 1, 20000` loop (confirmed too low -- real achievement IDs already exceed 20000, e.g. Wowhead achievement 42045 is a real current-expansion achievement). GetCategoryNumAchievements's `includeAll` boolean parameter's exact semantics are not documented on Warcraft Wiki; this pass passes `true` on a reasonable but unconfirmed assumption it means \"count hidden/not-currently-visible achievements too\"." },
    { id = "ach.categoryInfo", module = "Accomplishments", api = "GetCategoryInfo(categoryID)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", expected = "3 values: title, parentCategoryID, flags; parentCategoryID == -1 for a top-level category (no parent).",
      notes = "New this pass -- Accomplishments redesign. Used to walk the full category tree at runtime (no hardcoded category IDs) and identify the top-level \"Feats of Strength\" category by its own Blizzard-provided title. KNOWN GAP: matching that title against the English literal \"Feats of Strength\" is correct on an English client only -- Blizzard returns the title already localized and this module has no other signal to identify that specific category by; not re-verified for non-English locales this pass." },
    { id = "acc.signaturePatterns", module = "Accomplishments", api = "Modules/Accomplishments/AccomplishmentsPatterns.lua (name-pattern classification)", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "General addon-development knowledge + one spot-check this pass (Heritage of the Vulpera/Kul Tirans/Lightforged, cross-referenced)",
      expected = "Achievement names beginning/ending with the documented patterns (Loremaster of/Pathfinder/Ahead of the Curve/Cutting Edge/Keystone Master/Keystone Hero/Glory of the X/Heritage of the X) reliably identify the intended signature-achievement category.",
      notes = "QUALITATIVELY DIFFERENT from every other row in this registry: this is not a one-time API-shape confirmation, it's an ONGOING content-drift risk -- Blizzard could rename a naming convention with zero addon-facing signal that it happened. Needs a periodic per-expansion spot-check, not a single close-out. Only the Heritage of the X entry was independently spot-checked this pass; the rest are carried from general knowledge and flagged accordingly." },
    { id = "acc.expansionNames", module = "Accomplishments", api = "Modules/Accomplishments/AccomplishmentsExpansionNames.lua (top-level category title -> expansion name match)", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "General addon-development knowledge -- Blizzard's achievement UI top-level categories are organized one-per-expansion; not independently spot-checked this pass",
      expected = "Every top-level achievement category's own Blizzard-provided title exactly matches one entry in AccomplishmentsExpansionNames.lua.",
      notes = "Same ongoing-content-drift category as acc.signaturePatterns (ships a new expansion, needs a one-line table addition) -- not a one-time API-shape confirmation. A category whose title matches nothing in the table resolves to expansion = nil on the accomplishment record, rendered by the Dashboard as an honest omission, never fabricated as \"Unknown\"." },

    -- Accomplishments -- Campaign / Renown (NOT achievement data, owned
    -- here temporarily -- see AccomplishmentsModule.lua's own header) ----
    { id = "acc.campaignInfo", module = "Accomplishments", api = "C_CampaignInfo.GetAvailableCampaigns / GetState / GetChapterIDs / GetCurrentChapterID", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", expected = "GetState returns Enum.CampaignState (0 Invalid, 1 Complete, 2 InProgress, 3 Stalled).",
      notes = "New this pass. C_CampaignInfo.GetCampaignInfo's exact return shape was NOT verified this pass -- read defensively (pcall + nil-guarded .name field access) in AccomplishmentsModule.lua rather than assumed." },
    { id = "acc.renownInfo", module = "Accomplishments", api = "C_MajorFactions.GetMajorFactionIDs / GetMajorFactionData / GetCurrentRenownLevel / HasMaximumRenown / IsWeeklyRenownCapped", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (reuses this addon's own already-confirmed function set from the Reputation module's planning audit, docs/GameplayModuleArchitecture.md section 2.1)",
      expected = "Real Major Faction IDs/renown levels for the current expansion's account-wide factions.",
      notes = "New this pass -- first time this addon has called C_MajorFactions. Deliberately does NOT use GetRenownLevels, which surfaced in a fresh search this pass but was never independently confirmed; the five-function set already verified for the planned Reputation module was reused instead." },
    { id = "acc.renownChangedEvent", module = "Accomplishments", api = "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "General addon-development knowledge, not independently confirmed this pass", expected = "Fires when a tracked Major Faction's Renown level changes.",
      notes = "Registered defensively (pcall) in AccomplishmentsModule.lua -- a wrong/renamed event name degrades to Renown only refreshing on the next PLAYER_ENTERING_WORLD, never a hard failure." },

    -- Weekly / Great Vault ----------------------------------------------------
    { id = "weekly.activities", module = "Weekly", api = "C_WeeklyRewards.GetActivities / HasAvailableRewards / GetItemHyperlink", status = S.SOURCE, confidence = "High",
      citation = "Blizzard Interface Source (Blizzard_WeeklyRewards/Blizzard_WeeklyRewards.lua)", expected = "Activities and World each resolve to three WeeklyRewardActivityInfo slots with type,index,threshold,progress,id,activityTierID,level,claimID,raidString,rewards." },
    { id = "weekly.itemLevelChain", module = "Weekly", api = "C_WeeklyRewards.GetExampleRewardItemHyperlinks / GetItemHyperlink; C_Item.GetItemInfo / GetDetailedItemLevelInfo", status = S.SOURCE, confidence = "High", citation = "Blizzard Interface Source (Blizzard_WeeklyRewards/Blizzard_WeeklyRewards.lua)",
      expected = "Real generated reward item level resolves through activity.rewards and GetItemHyperlink; unlocked preview item level can fall back to GetExampleRewardItemHyperlinks, matching Blizzard's own preview tooltip.",
      notes = "Both calls are documented MayReturnNothing (item-cache miss); this module degrades to no-reward-shown rather than guessing, but does not replicate Blizzard's own GET_ITEM_INFO_RECEIVED retry." },
    { id = "weekly.progressUnits", module = "Weekly", api = "activity.threshold / activity.progress unit meaning", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Community addon cross-reference only (mega-tin/Broker_GreatVault) -- not an official source",
      expected = "threshold/progress are counted in whole Mythic+ dungeons completed this week (e.g. 1/4, not some other unit)." },
    { id = "weekly.event", module = "Weekly", api = "WEEKLY_REWARDS_UPDATE", status = S.SOURCE, confidence = "High", citation = "Blizzard Interface Source" },

    -- Storage -----------------------------------------------------------------
    { id = "storage.bankTabs", module = "Storage", api = "C_Bank.FetchViewableBankTypes / FetchPurchasedBankTabIDs / Enum.BankType", status = S.WIKI, confidence = "High",
      citation = "Blizzard Bank API documentation", expected = "FetchViewableBankTypes identifies sources exposed by the active bank interaction; FetchPurchasedBankTabIDs returns each source's owned tab IDs." },
    { id = "storage.reagentBankLegacy", module = "Storage", api = "Enum.BagIndex.Reagentbank / Bank (legacy fallback path)", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki",
      expected = "Harmless-but-vestigial: reagent bank folded into the unified bank-tab system in Patch 11.2.0, already covered by storage.bankTabs." },
    { id = "storage.pickupItem", module = "Storage", api = "C_Container.PickupContainerItem", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki (AllowedWhenUntainted)",
      notes = "Real pickup-then-place round trip against a live bank/bag still needs a human watching it happen -- see checklist scenario Bank." },
    { id = "storage.favoriteField", module = "Storage", api = "ContainerItemInfo.isFavorite", status = S.INCORRECT, confidence = "High",
      citation = "Warcraft Wiki (full ContainerItemInfo field list has no isFavorite field)",
      expected = "N/A -- field does not exist; always false/nil in practice. Also confirmed unread anywhere else in the codebase.",
      notes = "Left as a documented, honest gap (inline comment at the read site) rather than a fabricated fix -- real follow-up: find the correct API or remove the dead field." },
    { id = "storage.bankerInteraction", module = "Storage", api = "Enum.PlayerInteractionType.Banker / AccountBanker / PLAYER_INTERACTION_MANAGER_FRAME_SHOW / HIDE payload", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "Blizzard enum documentation; payload still needs live verification", expected = "Regular and Warband banker interactions each activate Storage exactly once and expose their viewable bank types synchronously." },

    -- Mythic+ -------------------------------------------------------------------
    { id = "mp.challengeMode", module = "MythicPlus", api = "C_ChallengeMode.GetActiveKeystoneInfo / GetSlottedKeystoneInfo / HasSlottedKeystone / GetOverallDungeonScore / GetMapUIInfo / GetDeathCount / GetMapScoreInfo / GetChallengeCompletionInfo / IsChallengeModeActive / GetAffixInfo",
      status = S.WIKI, confidence = "Medium", citation = "Original Phase 2 API audit (namespace + shape confirmed, not independently re-fetched with fresh citations this pass)",
      expected = "See docs/GameplayModuleArchitecture.md section 1.4's Phase 2 API Audit table for the per-function detail already on record." },
    { id = "mp.mythicPlusNamespace", module = "MythicPlus", api = "C_MythicPlus.GetOwnedKeystoneChallengeMapID / GetOwnedKeystoneLevel / GetCurrentAffixes / GetCurrentSeason / RequestMapInfo",
      status = S.WIKI, confidence = "Medium", citation = "Original Phase 2 API audit", expected = "See docs/GameplayModuleArchitecture.md section 1.4." },
    { id = "mp.eventsSource", module = "MythicPlus", api = "CHALLENGE_MODE_START / RESET / KEYSTONE_SLOTTED / MAPS_UPDATE / MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", status = S.SOURCE, confidence = "High",
      citation = "Blizzard Interface Source (Blizzard_ChallengesUI)" },
    { id = "mp.eventsWiki", module = "MythicPlus", api = "CHALLENGE_MODE_COMPLETED / CHALLENGE_MODE_DEATH_COUNT_UPDATED", status = S.SOURCE, confidence = "High", citation = "Blizzard Interface Source (Blizzard_ChallengesUI) / Warcraft Wiki",
      notes = "CHALLENGE_MODE_COMPLETED is the authoritative Retail completion event; completion details are read synchronously through C_ChallengeMode.GetChallengeCompletionInfo()." },
    { id = "mp.eventOrdering", module = "MythicPlus", api = "Relative firing order of the events above during a real run", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "N/A -- confirming an event exists is not the same as confirming when it fires relative to the others.",
      expected = "No documented guarantee found; needs a human watching the Event Monitor tab during a real run." },
    { id = "mp.combatLog", module = "MythicPlus", api = "COMBAT_LOG_EVENT_UNFILTERED (SPELL_INTERRUPT sub-event only)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (long-standing stable event)", notes = "Filtered to exactly one sub-event, sourced from the player only -- not a general combat log parser." },
    { id = "mp.itemInfoInstant", module = "MythicPlus", api = "C_Item.GetItemInfoInstant (classID/subClassID return-position offset)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Now resolved in the shared AC.ItemClassification (Core/Utility/ItemClassification.lua) -- consolidated out of MythicPlusModule and StorageModule's previously-independent copies during the consumable classifier consolidation, so this single entry now covers both consumers, not just MythicPlus.", expected = "classID/subClassID at the positions AC.ItemClassification:GetItemClassInfo assumes." },
    { id = "mp.mapPosition", module = "MythicPlus", api = "C_Map.GetBestMapForUnit / GetPlayerMapPosition", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki" },
    { id = "mp.spellData", module = "MythicPlus", api = "MythicPlusSpellData.lua defensive cooldown spell IDs (one per class)", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "Compiled from general knowledge, explicitly documented as a living list", expected = "Each listed spell ID actually corresponds to that class's well-known defensive cooldown on the current client." },

    -- Delves --------------------------------------------------------------------
    { id = "delves.progression", module = "Delves", api = "C_DelvesUI.GetDelvesFactionForSeason / C_MajorFactions.GetMajorFactionRenownInfo", status = S.SOURCE, confidence = "High",
      citation = "Blizzard generated DelvesUI API documentation + Blizzard Major Factions UI usage", expected = "The current Delves Journey faction resolves to MajorFactionRenownInfo with renownLevel, renownReputationEarned, and renownLevelThreshold." },
    { id = "delves.companion", module = "Delves", api = "C_DelvesUI companion faction/display/trait/curio rarity/link accessors; C_GossipInfo; C_Reputation; C_Traits; C_Spell", status = S.SOURCE, confidence = "High",
      citation = "Blizzard_DelvesCompanionConfiguration.lua", expected = "Calling companion accessors with no companion ID uses the active mirrored companion; faction APIs supply name/level, active trait entries supply role and curio spell data, trait-condition account elements resolve curio rarity/rank, and GetCurioLink supplies the native tooltip hyperlink." },

    -- Framework services --------------------------------------------------------
    { id = "notif.ticker", module = "NotificationService", api = "C_Timer.NewTicker", status = S.WIKI, confidence = "High", citation = "Warcraft Wiki (foundational timer utility)",
      notes = "Only direct Blizzard API call across Progress/Recommendation/Notification/Milestone/Briefing services -- the rest are confirmed (repo-wide grep, this pass) to compute nothing from Blizzard APIs directly, only from other modules' already-verified public getters." },
    { id = "devpanel.events", module = "DeveloperPanel", api = "PLAYER_ALIVE / BAG_UPDATE_DELAYED / BANKFRAME_OPENED / BANKFRAME_CLOSED (Event Monitor's own monitored list)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki", notes = "Not individually re-fetched this pass -- long-standing stable events; every other event on the monitored list is already covered by its owning module's own registry row above." },

    -- Player Journal & Community Observations -------------------------------------------
    { id = "pj.rosterUnitAccessors", module = "PlayerJournal", api = "UnitFullName / UnitGUID / UnitClass / UnitGroupRolesAssigned (party1-4)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (same API family as char.unitAccessors, applied to party unit tokens instead of \"player\")",
      expected = "Real identity/role facts for present party members; UnitExists gates each slot first." },
    { id = "pj.unitDiedCombatLog", module = "PlayerJournal", api = "COMBAT_LOG_EVENT_UNFILTERED (UNIT_DIED / SPELL_INTERRUPT sub-events, party roster only)", status = S.WIKI, confidence = "High",
      citation = "Warcraft Wiki (same event family as mp.combatLog -- MythicPlusModule's own player-only SPELL_INTERRUPT filtering)",
      expected = "destGUID/sourceGUID match a tracked roster member's GUID for the relevant sub-event." },
    { id = "pj.rosterLeaveDetection", module = "PlayerJournal", api = "Grace-period roster-departure heuristic (GROUP_ROSTER_UPDATE diff + 5s recheck)", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "Not a documented Blizzard behavior -- an addon-side heuristic layered on top of confirmed roster-read APIs.",
      expected = "A party member missing from the roster for the full grace period, with the run still active, reliably indicates a real early departure rather than a brief reconnect/instance-transition hiccup." },
    { id = "pj.eventOrderingDefer", module = "PlayerJournal", api = "C_Timer.After(0, ...) deferred read of MythicPlusModule:GetRecentRuns(1)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Confirmed by reading Core/Events/EventManager.lua's own DispatchBlizzard (listeners fire in registration order; a timer only ever runs on OnUpdate, after the current frame's event-dispatch loop) -- correct by inspection of this addon's own code, not yet watched happen in a real client.",
      expected = "MythicPlusModule:RecordCompletedRun() has already appended its ActivityHistoryService record by the time PlayerJournalModule's deferred read runs." },
    { id = "ctxmenu.modifyMenu", module = "PlayerJournal", api = "Menu.ModifyMenu(tag, callback) + submenu auto-promotion (CreateButton then CreateButton again on the result)", status = S.WIKI, confidence = "Medium",
      citation = "Warcraft Wiki's own Blizzard Menu implementation guide", expected = "Exactly one \"Azeroth Companion\" submenu appended to the target menu, never replacing existing entries." },
    { id = "ctxmenu.nestedSubmenu", module = "PlayerJournal", api = "The same CreateButton-called-twice submenu-promotion mechanic as ctxmenu.modifyMenu, applied one level deeper (Community Observations submenu created from inside the already-promoted \"Azeroth Companion\" submenu, not from rootDescription directly)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Reasoned by extension of ctxmenu.modifyMenu's own confirmed mechanic -- the Wiki guide describes ElementDescription generically, with no stated restriction on nesting depth, but nesting one level deeper than the guide's own example has not been independently observed.",
      expected = "Right-clicking a party member shows \"Azeroth Companion\" -> \"Community Observations\" as a working nested submenu (View Observations / Add Observation / Hide Observations), not a broken or flattened menu entry." },
    { id = "ctxmenu.unitMenuTags", module = "PlayerJournal", api = "Exact MENU_UNIT_* tag name(s) for \"any party member\"", status = S.NEEDS_LIVE, confidence = "Low",
      citation = "Warcraft Wiki confirms the MENU_UNIT_<UNIT_TYPE> format with PARTY1 as one example, not whether a slot-independent tag also exists -- registered defensively against multiple plausible tags, each pcall-wrapped.",
      expected = "At least one of the registered tags fires when right-clicking a real party member in a live client." },
    { id = "ctxmenu.selfMenuTag", module = "PlayerJournal", api = "MENU_UNIT_SELF -- the tag for the player's own frame and the target frame while self-targeted", status = S.WIKI, confidence = "High",
      citation = "Confirmed against Blizzard's own current client source (12.0.7, build 68182), not the tag-name pattern: UnitPopupManager:OpenMenu() (Interface/AddOns/Blizzard_UnitPopupShared/UnitPopupShared.lua) builds the Menu.ModifyMenu tag as \"MENU_UNIT_\"..which; UnitPopupSharedMenus.lua registers UnitPopupManager:RegisterMenu(\"SELF\", UnitPopupMenuSelf) as a menu genuinely separate from RegisterMenu(\"PLAYER\", UnitPopupMenuPlayer); and TargetFrame's own dropdown init explicitly checks UnitIsUnit(\"target\", \"player\") and switches to \"SELF\" instead of \"TARGET\" when true. Root cause of a live-testing failure: MENU_UNIT_SELF was missing from TAGS_TO_HOOK entirely, so the submenu never appeared for either self-context case.",
      expected = "Right-clicking your own player frame, and right-clicking your target frame while self-targeted, both now show the Azeroth Companion submenu with the self-specific wording (View My Observations / Add Observation About Myself, no Hide entry)." },
    { id = "ctxmenu.createCheckbox", module = "PlayerJournal", api = "ElementDescription:CreateCheckbox(text, isSelectedFunc, setSelectedFunc)", status = S.WIKI, confidence = "Medium",
      citation = "Warcraft Wiki's own Blizzard Menu implementation guide (shown with an identical 3-argument example, a reputation-panel checkbox)", expected = "A checkbox menu entry reflecting IsFavorite's current value, toggling it on click." },
    { id = "ctxmenu.contextDataUnitSecretValue", module = "PlayerJournal", api = "ResolvePlayerKey's contextData.unit, passed to UnitExists()/UnitFullName() from inside a Menu.ModifyMenu callback (Core/UI/PlayerJournalContextMenu.lua)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Secret Value Audit -- structurally identical to tooltip.getUnitSecretValue and pj.tooltipDataGuid, both CONFIRMED broken by real in-game errors: a unit-identifying value obtained from inside a Blizzard secure UI callback (there, TooltipDataProcessor's postcall; here, Menu.ModifyMenu's own callback), passed straight to a normal Unit* API. Not yet independently confirmed for this specific callback -- flagged from the pattern, not asserted as proven -- but the same policy that broke both tooltip attempts plausibly applies here too. Read is now wrapped in AC.SecretValueGuard:TryRead (Core/Security/SecretValueGuard.lua), so this is no longer an open crash risk while awaiting live confirmation.",
      expected = "If this does throw the same \"Secret values are only allowed during untainted execution\" class of error on a real right-click, SecretValueGuard already contains it: the submenu simply doesn't add (no identity resolved), logged at Debug level, no visible Lua error. A human watching /ac dev -> Checklist (or Debug logging) can confirm whether that skip is actually happening on a real right-click, which settles this entry either way without needing another live crash first." },
    { id = "tooltip.postCall", module = "PlayerJournal", api = "TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, callback) -- the registration itself", status = S.WIKI, confidence = "High",
      citation = "Confirmed via real published addon source (the current, standard tooltip-extension technique, superseding the legacy OnTooltipSetUnit script hook)." },
    { id = "tooltip.getUnitSecretValue", module = "PlayerJournal", api = "tooltip:GetUnit()'s returned unit token, passed to UnitIsPlayer()/UnitFullName() from inside a postcall", status = S.INCORRECT, confidence = "High",
      citation = "Confirmed by a real, repeated in-game Lua error (Stabilization pass): \"bad argument #1 to UnitIsPlayer() ... Secret values are only allowed during untainted execution.\" The unit token GetUnit() returns from inside a TooltipDataProcessor postcall is a secret/opaque value in this WoW client, not a plain unit string -- passing it to any normal Unit* API throws.",
      expected = "N/A -- this pattern no longer works from a postcall hook. Removed from Core/UI/PlayerJournalTooltip.lua, replaced by the postcall's own `data.guid` field + GetPlayerInfoByGUID (see pj.tooltipDataGuid below)." },
    { id = "pj.tooltipDataGuid", module = "PlayerJournal", api = "TooltipDataProcessor.AddTooltipPostCall's second (data) argument's guid field, for Enum.TooltipDataType.Unit, indexed/used directly", status = S.INCORRECT, confidence = "High",
      citation = "Confirmed by a second real, repeated in-game Lua error (Stabilization pass, second round): \"attempt to index local 'guid' (a secret string value, while execution tainted by AzerothCompanion).\" data.guid IS present, but it is ALSO a secret/opaque value from inside a postcall -- the same blanket policy that broke tooltip:GetUnit(), not a narrower issue specific to that one field.",
      expected = "N/A -- no unit-identifying value reachable from inside a TooltipDataProcessor postcall (unit token or guid) is readable by addon code. Removed from Core/UI/PlayerJournalTooltip.lua entirely, replaced by an architecture that resolves identity outside the callback (see pj.knownUnitsCache below) and never reads guid/unit token again." },
    { id = "pj.knownUnitsCache", module = "PlayerJournal", api = "Identity resolved via GROUP_ROSTER_UPDATE/UPDATE_MOUSEOVER_UNIT/PLAYER_TARGET_CHANGED/PLAYER_FOCUS_CHANGED + UnitFullName/UnitGUID on player/party1-4/target/focus/mouseover, cached by display name", status = S.WIKI, confidence = "High",
      citation = "Same trusted UnitFullName/UnitGUID-on-a-plain-token pattern already verified by pj.rosterUnitAccessors, generalized to a few more always-legal global tokens -- these are ordinary events and ordinary unit tokens, never a value that originated from inside a secure UI callback, so nothing here is reachable by the secret-value restriction that broke the two entries above.",
      expected = "KnownUnits correctly maps a player's tooltip-displayed name (and name-realm form) to their playerKey whenever they are the player, a current party member, current target/focus, or the current mouseover unit." },
    { id = "pj.tooltipLineTextSafe", module = "PlayerJournal", api = "TooltipDataProcessor postcall data.lines[1].leftText (the tooltip's own rendered name line)", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "Reasoned, not yet independently confirmed: reading/modifying data.lines is TooltipDataProcessor's own stated, documented, addon-facing purpose (unlike the supplementary guid field that proved secret), and a Unit tooltip's first line has long been the plain unit name by convention. Given this addon has now been wrong twice reasoning about which tooltip-adjacent value is safe, this is deliberately flagged rather than asserted with the same confidence as pj.knownUnitsCache. Secret Value Audit -- elevated priority: this postcall fires for EVERY unit tooltip, including NPCs (Enum.TooltipDataType.Unit is not player-scoped), so it is exercised far more heavily in NPC-dense content like Mythic+ dungeons than in open-world play, and reports of live errors while hovering NPCs in a dungeon are consistent with this specific read failing for non-player tooltips even if it holds for player tooltips.",
      expected = "data.lines[1].leftText is a plain, non-secret string equal to the unit's displayed name (with class-color escape codes only, stripped by StripTooltipColorCodes), for players AND NPCs alike. The read is now wrapped in AC.SecretValueGuard:TryRead (Core/Security/SecretValueGuard.lua), so a wrong assumption here degrades to silently skipping that one tooltip's enhancement (Debug-logged) rather than a visible Lua error -- confirm via Debug logging or /ac dev -> Checklist whether skips are actually occurring, particularly while hovering NPCs. If this does prove unreliable, the documented escalation (see Core/UI/PlayerJournalTooltip.lua's own header) is to stop reading GameTooltip's content at all, not to parse it more cleverly." },
    { id = "presentation.unverifiedGlyphs", module = "Presentation", api = "Presentation.CHECK_GLYPH / CROSS_GLYPH / WARNING_GLYPH (\"✓\"/\"✗\"/\"⚠\") and DashboardFormat.BULLET (\"•\")", status = S.NEEDS_LIVE, confidence = "Medium",
      citation = "UI Polish Pass -- raised by precedent, not yet independently confirmed: DashboardFormat.STAR_FILLED/STAR_EMPTY (\"★\"/\"☆\", Miscellaneous Symbols block) were just confirmed live to render as missing-character boxes, the second Unicode block found broken after the Geometric Shapes disclosure/trend glyphs (▶/▼/▲) earlier. These four remaining glyphs are different Unicode blocks again (Dingbats for check/cross, Miscellaneous Symbols for warning, General Punctuation for the bullet) and were not reported broken by this pass's own visual audit, so left as-is rather than guess-changed -- but given this addon has now been wrong three separate times about which Unicode blocks Blizzard's client font (FRIZQT__.TTF) covers, asserting these four are safe without the same live confirmation would repeat the mistake.",
      expected = "Each glyph renders as its intended character, not a missing-character box, in a live client. If any prove broken, the priority-star precedent (retired entirely rather than patched a second time -- see Format.lua's own header) is the model to follow: prefer a readable label/color over a fourth guess at a luckier Unicode codepoint, not another glyph swap." },
}

-------------------------------------------------------------------------------
-- Guided Verification Checklist
--
-- 26 scripted scenarios, each naming exactly which registry rows it
-- actually exercises -- several deliberately list none, with an honest
-- note explaining why, rather than padding every scenario with an
-- API to "justify" its presence.
-------------------------------------------------------------------------------

local CHECKLIST =
{
    { id = "Login", labelKey = "Developer.ChecklistLogin", relatedIds = { "char.unitAccessors", "char.realmZone", "inv.container", "ach.achievementInfo", "ach.categoryEnumeration", "weekly.activities", "weekly.event", "mp.challengeMode", "mp.mythicPlusNamespace", "delves.progression", "delves.companion" } },
    { id = "ReloadUI", labelKey = "Developer.ChecklistReloadUI", relatedIds = { "weekly.progressUnits" } },
    { id = "CharacterSelect", labelKey = "Developer.ChecklistCharacterSelect", relatedIds = {} },
    { id = "SpecSwap", labelKey = "Developer.ChecklistSpecSwap", relatedIds = { "char.specialization" } },
    { id = "Hearthstone", labelKey = "Developer.ChecklistHearthstone", relatedIds = {} },
    { id = "ZoneChange", labelKey = "Developer.ChecklistZoneChange", relatedIds = { "char.realmZone", "char.bestMap" } },
    { id = "FlightPath", labelKey = "Developer.ChecklistFlightPath", relatedIds = { "char.bestMap" } },
    { id = "Death", labelKey = "Developer.ChecklistDeath", relatedIds = { "mp.combatLog", "char.bestMap" } },
    { id = "Resurrection", labelKey = "Developer.ChecklistResurrection", relatedIds = {} },
    { id = "DungeonEnter", labelKey = "Developer.ChecklistDungeonEnter", relatedIds = { "mp.mapPosition", "mp.challengeMode", "pj.rosterUnitAccessors" } },
    { id = "DungeonLeave", labelKey = "Developer.ChecklistDungeonLeave", relatedIds = { "mp.eventOrdering", "pj.rosterLeaveDetection" } },
    { id = "KeystoneInsert", labelKey = "Developer.ChecklistKeystoneInsert", relatedIds = { "mp.eventsSource", "mp.eventOrdering" } },
    { id = "KeystoneComplete", labelKey = "Developer.ChecklistKeystoneComplete", relatedIds = { "mp.eventsWiki", "mp.eventOrdering", "weekly.progressUnits", "pj.eventOrderingDefer", "pj.unitDiedCombatLog" } },
    { id = "KeystoneFail", labelKey = "Developer.ChecklistKeystoneFail", relatedIds = { "mp.eventsSource", "mp.eventOrdering" } },
    { id = "GreatVault", labelKey = "Developer.ChecklistGreatVault", relatedIds = { "weekly.activities", "weekly.itemLevelChain", "weekly.progressUnits", "weekly.event" } },
    { id = "Bank", labelKey = "Developer.ChecklistBank", relatedIds = { "storage.bankTabs", "storage.bankerInteraction", "storage.pickupItem", "storage.favoriteField" } },
    { id = "ReagentBank", labelKey = "Developer.ChecklistReagentBank", relatedIds = { "storage.reagentBankLegacy" } },
    { id = "WarbandBank", labelKey = "Developer.ChecklistWarbandBank", relatedIds = { "storage.bankTabs", "storage.bankerInteraction" } },
    { id = "Mailbox", labelKey = "Developer.ChecklistMailbox", relatedIds = {} },
    { id = "Vendor", labelKey = "Developer.ChecklistVendor", relatedIds = { "inv.repairCost" } },
    { id = "AuctionHouse", labelKey = "Developer.ChecklistAuctionHouse", relatedIds = {} },
    { id = "AchievementEarned", labelKey = "Developer.ChecklistAchievementEarned", relatedIds = { "ach.achievementInfo", "ach.categoryEnumeration" } },
    { id = "InventoryFull", labelKey = "Developer.ChecklistInventoryFull", relatedIds = { "inv.container" } },
    { id = "EquipmentChange", labelKey = "Developer.ChecklistEquipmentChange", relatedIds = { "char.itemLevel", "inv.equippedSlots" } },
    { id = "CurrencyGain", labelKey = "Developer.ChecklistCurrencyGain", relatedIds = {} },
    { id = "WeeklyReset", labelKey = "Developer.ChecklistWeeklyReset", relatedIds = { "weekly.progressUnits", "weekly.activities" } },

    -- Player Journal & Community Observations -------------------------------------------
    { id = "PlayerJournalRun", labelKey = "Developer.ChecklistPlayerJournalRun", relatedIds = { "pj.rosterUnitAccessors", "pj.eventOrderingDefer", "pj.unitDiedCombatLog" } },
    { id = "PlayerJournalLeave", labelKey = "Developer.ChecklistPlayerJournalLeave", relatedIds = { "pj.rosterLeaveDetection" } },
    { id = "PlayerJournalContextMenu", labelKey = "Developer.ChecklistPlayerJournalContextMenu", relatedIds = { "ctxmenu.modifyMenu", "ctxmenu.nestedSubmenu", "ctxmenu.unitMenuTags", "ctxmenu.selfMenuTag", "ctxmenu.createCheckbox", "ctxmenu.contextDataUnitSecretValue" } },
    { id = "PlayerJournalTooltip", labelKey = "Developer.ChecklistPlayerJournalTooltip", relatedIds = { "tooltip.postCall", "pj.knownUnitsCache", "pj.tooltipLineTextSafe" } },
}

-------------------------------------------------------------------------------
-- Registry Access
-------------------------------------------------------------------------------

function VerificationService:GetRegistry()

    return REGISTRY

end

function VerificationService:GetById(id)

    for _, entry in ipairs(REGISTRY) do

        if entry.id == id then
            return entry
        end

    end

    return nil

end

function VerificationService:GetByModule(moduleName)

    local results = {}

    for _, entry in ipairs(REGISTRY) do

        if entry.module == moduleName then
            table.insert(results, entry)
        end

    end

    return results

end

function VerificationService:GetChecklist()

    return CHECKLIST

end

-------------------------------------------------------------------------------
-- Persisted Log
--
-- Written only by an explicit human action (DeveloperPanel button /
-- checklist checkbox), never automatically.
-------------------------------------------------------------------------------

local function GetLog()

    return AC.DatabaseService:GetGlobal().VerificationLog

end

local function GetChecklistLog()

    return AC.DatabaseService:GetGlobal().ChecklistLog

end

function VerificationService:RecordResult(id, passed, notes)

    local log = GetLog()

    log[id] =
    {
        passed = passed and true or false,
        timestamp = time(),
        source = "Live Client",
        notes = notes or "",
    }

end

function VerificationService:GetRecord(id)

    return GetLog()[id]

end

function VerificationService:GetEffectiveStatus(id)

    local record = GetLog()[id]

    if record then
        return record.passed and S.LIVE or S.INCORRECT
    end

    local entry = self:GetById(id)

    return entry and entry.status or S.NEEDS_LIVE

end

function VerificationService:RecordChecklistScenario(scenarioId, completed)

    local log = GetChecklistLog()

    log[scenarioId] =
    {
        completed = completed and true or false,
        timestamp = time(),
    }

end

function VerificationService:GetChecklistRecord(scenarioId)

    return GetChecklistLog()[scenarioId]

end

-------------------------------------------------------------------------------
-- Clear Recorded Results
--
-- Developer Panel Maintenance owns the destructive UI and confirmation;
-- VerificationService remains the only writer for its two persisted logs.
-- Clear in place so any live reader retaining either table reference observes
-- the reset immediately.
-------------------------------------------------------------------------------

function VerificationService:ClearRecordedResults()

    local verificationLog = GetLog()
    local checklistLog = GetChecklistLog()

    for id in pairs(verificationLog) do
        verificationLog[id] = nil
    end

    for scenarioId in pairs(checklistLog) do
        checklistLog[scenarioId] = nil
    end

end

-------------------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------------------

function VerificationService:GetSummaryCounts()

    local counts = { source = 0, wiki = 0, live = 0, needsLive = 0, incorrect = 0 }

    for _, entry in ipairs(REGISTRY) do

        local status = self:GetEffectiveStatus(entry.id)
        counts[status] = (counts[status] or 0) + 1

    end

    return counts

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("VerificationService", VerificationService)

return VerificationService
