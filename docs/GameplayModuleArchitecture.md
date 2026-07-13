# Azeroth Companion — Gameplay Module Architecture

**Status:** Authoritative design document.
**Scope:** Describes every existing and planned gameplay module, ownership boundaries, and the rules future development must follow.
**Not covered here:** Core framework services (ServiceManager, EventManager, WidgetManager, WindowManager, SettingsManager, ConfigurationManager, LocalizationService), which are documented separately and are not gameplay modules.

This document exists so that when a new Blizzard API or gameplay system is discovered, a future developer can determine exactly which module owns it — or whether it doesn't belong anywhere yet — before writing any implementation code.

---

## 1. Existing Modules

These sections describe the current implementation as it exists today. They are the source of truth — if the code and this document ever disagree, the document should be corrected to match the code, not the other way around, unless the disagreement is itself a bug.

### 1.1 Character

#### Purpose
Owns everything that describes *who the current character is* and *how they are progressing* — identity, specialization, level progression, item level, guild, faction, location, and session-over-session change in those things.

#### Responsibilities
- Character identity: name, realm, GUID, race, class.
- Specialization: current spec ID/name/role.
- Level progression: current level, max level for the player's expansion, rested XP.
- Item level: average and equipped item level.
- Guild and faction membership.
- Gold (`GetMoney()`).
- Bind location.
- Current zone/subzone/map.
- Time played (total and current-level).
- Session tracking: login timestamp, level/item-level gained since login.
- Insight generation for character-progression events (rested XP available, max level reached, leveled up this session, item level improved this session).

#### Blizzard APIs owned
`UnitName`, `UnitFullName`, `UnitGUID`, `UnitRace`, `UnitClass`, `UnitLevel`, `UnitFactionGroup`, `GetRealmName`, `C_SpecializationInfo.GetSpecialization`/`GetSpecializationInfo`, `GetMaxLevelForPlayerExpansion`, `GetXPExhaustion`, `GetAverageItemLevel`, `GetGuildInfo`, `GetMoney`, `GetBindLocation`, `GetZoneText`/`GetSubZoneText`/`C_Map.GetBestMapForUnit`, `RequestTimePlayed`.

**VERIFICATION STATUS (Live Verification & Framework Hardening sprint):** all APIs above confirmed real via Warcraft Wiki (see `Core/Services/VerificationService.lua`'s registry for the full per-API citation list — `char.*` entries). Two real findings this pass:
- **Migrated:** the global `GetSpecialization()`/`GetSpecializationInfo()` are confirmed deprecated since Patch 11.2.0; this module now calls `C_SpecializationInfo.GetSpecialization()`/`GetSpecializationInfo()` instead, confirmed to return the same values in the same order.
- **Removed:** `C_Hearthstone.GetHearthstone` and `C_PlayerInfo.GetAccountGUID` are both confirmed to not exist (absent from Blizzard's own generated API documentation and from Warcraft Wiki's full API index) — both were already-dead fields (`hearthstoneItemID`, `warband.accountGUID`, confirmed never read anywhere) built on nonexistent calls, predating this session's research tooling. Removed rather than patched; this module no longer tracks "which hearthstone is set" or a Warband account identifier at all.

#### Dashboard responsibilities
Home page Profile card (name, level/spec/class, equipped item level). Profile page (Character, Equipment, Location, Character/Economy, Session sections).

#### Insight responsibilities
"Rested XP Available", "Max Level Reached", "Level Up This Session", "Item Level Improved".

#### Recommendation responsibilities
"Use Rested XP", "Explore Endgame Content", "Continue Leveling", "Try Harder Content".

#### Explicitly NOT responsible for
- Bag or equipment item data (Inventory).
- Achievement data (Achievements).
- Reputation/renown standing, even though it reads faction-adjacent identity (faction group only — Reputation module, planned).
- Currency other than gold (Currency module, planned).
- Warband Bank contents (Warband module, planned).
- Any Blizzard API namespace outside the list above.

---

### 1.2 Inventory

#### Purpose
Owns everything physically carried or equipped by the current character — bags, equipped items, and the state derived from them (fullness, repair status, important-item presence).

#### Responsibilities
- Bag contents and slot accounting (used/free/total slots, percentage full).
- Equipped item slots (equipped/empty count, average equipped item level).
- Important-item presence checks (hearthstone item possession — distinct from Character's "which hearthstone is set" fact). The item ID itself (`AC.HEARTHSTONE_ITEM_ID = 6948`, defined once in `InventoryModule.lua`) is the one shared identifier `StorageProfiles.lua`'s built-in "Keep 1 Hearthstone" preset rules also reference, rather than each file hardcoding the literal independently (v1.0 Polish Sprint — previously duplicated in 4 places across both files).
- Repair status (only when a merchant is open — this is a genuine Blizzard-imposed constraint, not a design choice).
- Session tracking: net items added/removed, bag-usage percentage change since login.
- Insight generation for inventory-state events (bags almost full, bags filling up, hearthstone missing, repairs needed).

#### Blizzard APIs owned
`C_Container.GetContainerNumSlots`/`GetContainerItemInfo`/`GetContainerItemLink`, `Enum.BagIndex.ReagentBag`, `GetInventoryItemID`/`GetInventoryItemLink`, `GetAverageItemLevel` (equipment-slot-scoped usage), `CanMerchantRepair`/`GetRepairAllCost`.

**VERIFICATION STATUS (Live Verification & Framework Hardening sprint):** all confirmed via Warcraft Wiki (`inv.*` entries in `Core/Services/VerificationService.lua`'s registry). `GetRepairAllCost`'s documented "requires a merchant window open" constraint is already correctly enforced at the one call site (`MerchantFrame:IsShown()`/`CanMerchantRepair()` guard) — confirmed correct, not a bug.

#### Dashboard responsibilities
Home page Inventory card (slots used, percent full, progress bar, status). Inventory page (Bag Summary, Equipment, Important Items, Session sections, Future Features note).

#### Insight responsibilities
"Bags Almost Full", "Bags Filling Up", "Hearthstone Missing", "Repairs Needed".

#### Recommendation responsibilities
"Visit a Vendor", "Consider Vendor Soon", "Acquire Hearthstone", "Repair Your Gear".

#### Explicitly NOT responsible for
- Character identity, progression, or gold (Character).
- Bank, Reagent Bank, or Warband Bank contents (Storage, implemented — see 1.7) — bags and banks are distinct Blizzard systems and distinct API families, and Storage owns all bank-side content now, not a planned module.
- Equipment durability (not currently collected by any module — a real gap, not yet owned by anyone; would extend Inventory when implemented, since it's equipment-state data).
- Currency (Currency module, planned). Reagent bank *contents* are Storage's concern (1.7), not Currency's — this corrects an earlier version of this document, which grouped reagent bank in with currency without justification.

---

### 1.3 Accomplishments (formerly Achievements)

**Redesigned this pass** from a flat, undifferentiated cache of every completed achievement into a curated "what defines this character's story" view. Blizzard's own Achievement UI already represents every achievement exhaustively; this module now deliberately caches only a small, classified subset — Expansion Progress, Raiding, Mythic+ (completion facts only), Feats of Strength, Character Milestones — and leaves everything else (exploration/fishing/cooking/holiday/misc achievements) untouched. See `Modules/Accomplishments/AccomplishmentsModule.lua`'s own header for the full reasoning; this section summarizes it.

#### Purpose
Owns a curated set of signature achievement completions, plus (as a deliberate, separately-scoped addition — see below) campaign completion and Renown progress, which answer the same "how far into this expansion am I" player question even though neither is achievement data.

#### Rename note
This module was `AchievementsModule`/`"Achievements"` before this pass. Renamed everywhere **except** two literal strings kept for save-data compatibility so existing players' history isn't orphaned: `ActivityHistoryService`'s stored `Module` field on every recorded accomplishment (still `"Achievements"`), and `DeveloperPanel.lua`'s `HISTORY_MODULES` History Inspector filter list (still includes `"Achievements"`). Every other reference — module registration name, file path, Settings namespace, Dashboard page, `RecommendationEngine`'s `category` field, `RecommendationInspector`'s module-display map — is `"Accomplishments"`.

#### Classification — how "curated" is decided
Blizzard exposes no "this is a signature/meta achievement" flag (`GetAchievementInfo`'s `flags` bitfield is documented as exactly Statistic/Hidden/ProgressBar — confirmed via Warcraft Wiki, nothing for "meta"). Two real mechanisms instead, no fabrication:
1. **Category tree, fully data-driven.** `GetCategoryInfo(categoryID)` returns `title, parentCategoryID, flags` (`parentCategoryID == -1` for top-level — confirmed via Warcraft Wiki). `BuildCategoryClassificationMap` walks `GetCategoryList()` + `GetCategoryInfo()` at runtime, no hardcoded category IDs anywhere, and identifies the top-level "Feats of Strength" category by its own Blizzard-provided title. Every achievement under it classifies `FeatsOfStrength` unconditionally. Known gap: the title match is an English literal, correct on an English client, unverified on other locales (Blizzard returns the title already localized with no other signal to identify that category by).
2. **Signature name-pattern table** (`Modules/Accomplishments/AccomplishmentsPatterns.lua`) — for everything else, matched against curated, documented Blizzard naming conventions (Loremaster of/Pathfinder/Ahead of the Curve/Cutting Edge/Keystone Master/Keystone Hero/Glory of the X/Heritage of the X). A real but not Blizzard-guaranteed pattern — treated as an ongoing content-drift risk requiring periodic per-expansion spot-check (`VerificationService`'s `acc.signaturePatterns` entry), qualitatively different from every other one-time API-shape confirmation in that registry.
3. **Expansion name inference** (Accordion Redesign, `Modules/Accomplishments/AccomplishmentsExpansionNames.lua`) — each cached accomplishment also carries an `expansion` field (e.g. `"Midnight"`), surfaced in the Dashboard's expanded accordion view. Blizzard exposes no expansion field anywhere in the achievement API; inferred the same "trust Blizzard's own category title" way as mechanism 1 above, since the category tree nests one top-level category per expansion. `BuildCategoryClassificationMap` resolves+caches `self.CategoryExpansionName[categoryID]` alongside its existing Feats-of-Strength walk. A category whose title matches nothing in the table resolves `expansion` to `nil` — an honest gap the Dashboard simply omits, never a guessed "Unknown." Same living-document framing as mechanism 2 (`VerificationService`'s `acc.expansionNames` entry) — a new expansion needs a one-line table addition, not a rewrite.

Only an achievement resolving via mechanism 1 or 2 is ever cached. **"Legacy Accomplishments" ships with an honest empty state this pass** — no Blizzard signal exists to auto-populate "historically interesting," and fabricating a curated list wasn't in scope; a real future follow-up, not silently dropped.

#### Campaign / Renown — deliberately separate concern, same module
Campaign completion (`C_CampaignInfo`) and Renown (`C_MajorFactions`) are **not achievement data** — a user-approved, deliberate scope decision to include them anyway (they answer the same "expansion progress" question the player cares about), kept structurally separate from `self.Accomplishments` (`self.CampaignProgress`/`self.RenownProgress`, own refresh functions/getters) so a future extraction is a clean cut, not a tangle. Renown specifically is owned **here, for now** — `docs/GameplayModuleArchitecture.md` §2.1 already lists a planned (not yet built) Reputation module as Renown's natural long-term owner; this addon has accepted that Renown ownership may need to move the day that module gets built, the same "owned here for now" temporary-ownership framing `StorageModule.lua` already established for Warband Bank item contents.

#### Blizzard APIs owned
`GetAchievementInfo` (both call forms), `GetCategoryList`, `GetCategoryNumAchievements`, `GetCategoryInfo` (new this pass). `C_CampaignInfo.GetAvailableCampaigns/GetState/GetChapterIDs/GetCurrentChapterID` (new this pass — a wholly separate system from achievements). `C_MajorFactions.GetMajorFactionIDs/GetMajorFactionData/GetCurrentRenownLevel/HasMaximumRenown/IsWeeklyRenownCapped` (new this pass — this addon's first call into this namespace, reusing the already-confirmed function set from the Reputation module's own planning audit in §2.1 below, deliberately not the also-real-but-unconfirmed `GetRenownLevels`).

**VERIFICATION STATUS:** See `VerificationService.lua`'s `ach.*`/`acc.*` registry rows for full citations. Real bug fixed in a prior pass (kept for history): `RefreshCompletedAchievements` previously looped a hardcoded `for achievementID = 1, 20000`, confirmed stale; fixed to the category-then-index traversal pattern still used today. **Still Needs Live Verification this pass:** `GetCategoryNumAchievements`'s `includeAll` semantics (carried over, unchanged); `C_CampaignInfo.GetCampaignInfo`'s exact return shape (read defensively, pcall + nil-guarded); the `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` event name (registered defensively, pcall); the entire signature-pattern table (ongoing, not one-time); the new `AccomplishmentsExpansionNames.lua` category-title match (`acc.expansionNames`, ongoing, not one-time).

#### Dashboard responsibilities — Accordion Redesign
Home page Accomplishments card (total points, most recent). The Accomplishments page evolved from a flat static list into the first step toward a "Character Journey" experience (now built — see section 9): the collapsed list answers "what defines this character," an expandable per-accomplishment detail view answers "tell me the story behind this one." Page shape — fully dynamic, no static schema: Hero (count + points + next milestone) → Expansion Progress (Campaign + Renown as plain lines, since neither is achievement data, plus real `ExpansionProgress`-category accomplishments as accordion rows) → Raiding → Mythic+ (completion facts only) → Feats of Strength (given prominence, a primary section) → Character Milestones → Legacy Accomplishments (empty state) → Recent History (deliberately still plain lines this pass) → Recommendations/Insights.

Collapsed accomplishment rows show **only the name** (no more baked-in earned date) at a higher visual weight (`GameFontNormal` + gold highlight) than the metadata around it. Clicking a row expands it in place — accordion behavior via a new `Dashboard:LayoutAccordionRows` engine (`Core/UI/Dashboard/Rows.lua`), showing Earned date / Category / Expansion (omitted, never fabricated, when unresolved) / Blizzard's own achievement Description (unlabeled wrapped body text). Only one accomplishment is expanded **page-wide** at a time (a single `page.ExpandedAccomplishmentID`, shared identically across all five accomplishment sections) — expanding a new one anywhere on the page collapses whatever was previously expanded; this falls out naturally with no cross-section coordination code since achievement IDs are globally unique. `LayoutAccordionRows` generalizes the accordion mechanic (pooling, single-expanded-item toggle, dynamic row height, detail show/hide) that previously existed only as `Dashboard:LayoutHistoryRows`, hardcoded to MythicPlus's Recent Runs table; `LayoutHistoryRows` is now a thin, output-identical wrapper over the same engine, so MythicPlus needed zero code changes. Recent History and the promoted future direction (Timeline integration, Player Journal references, related-accomplishment links inside the expanded view) are explicitly **not** built this pass — the architecture accommodates them, it doesn't implement them yet.

`AccomplishmentsModule:GetAccomplishments()` is also now the primary read source for the Character Journey page (section 9) — Journey applies no additional filtering on top of what this module already classifies, reusing this page's own `Accomplishments.FieldEarned`/`FieldCategory`/`FieldExpansion` loc keys and `Dashboard:SetAccordionDetailField`/`HideAccordionDetailField` (promoted out of this page into `Rows.lua` the moment Journey needed the identical mechanic).

#### Accordion Polish Pass

After using the accordion pages in-game, a real bug and three UX gaps were found and fixed at the shared engine level (`Core/UI/Dashboard/Sections.lua`/`Rows.lua`) — every fix here automatically benefits Accomplishments, Journey, MythicPlus's Recent Runs table, and any future accordion page.

**Root cause of section headers occasionally clipping the following section:** `Dashboard:BeginSection`/`Dashboard:AddDivider` (`Sections.lua`) created a brand-new FontString/Texture on *every* call, with none of the pooling every sibling widget-creating function in the same file already had. Every dynamic page's `Layout_` closure calls `BeginSection` once per section and re-runs on every refresh — on accordion pages specifically, *every row click* re-runs it (`ToggleAccomplishment`/`ToggleJourneyEntry` → `MeasureAndApplyScrolling` → `Layout_`, up to twice per call for the width remeasure). Each call left the *previous* header/divider on screen, un-hidden, at whatever Y offset was current for that render — a Y offset that shifts every time an earlier row expands or collapses. Old ghost headers froze at stale positions and could visually intrude into a section that had since become shorter. Fixed by pooling both directly on `scrollChild` (`scrollChild.SectionHeaders[titleKey]` / `scrollChild.Dividers[cacheKey]`), the exact same "cache on the object that owns it" idiom `ShowEmptyLine`'s `container[cacheKey]` already used — no call-site changes needed anywhere for `BeginSection` (titleKey was already a stable, page-unique key), one optional trailing parameter added to `AddDivider` for its one pooled caller (Journey's year separators). `RecommendationInspector.lua` turned out to be a third real victim (`Rebuild()` on every `Show()` against a persistent `ScrollChild`) — fixed for free by the same change, except its one *conditional* `BeginSection` call (`Inspector.ScoreHistory`, the only conditional one in the codebase) needed one explicit header-hide in its `else` branch, since a recommendation with no score history must also hide a header a *prior* recommendation's `Rebuild()` may have already cached.

**Secondary fix, same area:** `ShowEmptyLine` and all three `layoutCollapsed` implementations (`LayoutHistoryRows`'s inline builder, `LayoutAccomplishmentCollapsed`, `LayoutJourneyCollapsed`) returned a hardcoded height constant regardless of the real rendered (possibly word-wrapped) text height — a long accomplishment/achievement name wrapping to 2 lines silently under-reported its height, corrupting every offset after it. All four now measure the real `GetStringHeight()` with the original constant kept as a safe fallback (`math.max`'d against it for the two-line-capable `layoutCollapsed` cases, so the common short-text case keeps its exact prior compact height).

**Disclosure indicator, owned by the shared engine.** `Dashboard:LayoutAccordionRows` itself (not any `opts.buildRow`/`layoutCollapsed` callback) now creates/updates a pooled `row.DisclosureIcon` FontString every row — a Blizzard-style ▶ (collapsed) / ▼ (expanded) glyph (new `DashboardFormat.DISCLOSURE_COLLAPSED`/`DISCLOSURE_EXPANDED`, `Format.lua`, same raw-UTF-8-glyph-constant convention as `STAR_FILLED`/`CHECK_SUCCESS`), reusing the exact same `page[opts.expandedField] == recordID` boolean the engine already computes for its own toggle logic. Because it's engine-owned, MythicPlus's Recent Runs table gets it automatically with zero MythicPlus-authored code. New `Layout.ACCORDION_DISCLOSURE_WIDTH` (14px) reserves the left column; every `layoutCollapsed` implementation's own content shifts right by that amount — **a real, intentional, visible change to MythicPlus's Recent Runs columns** (Status/Date/Level/Name all shift right 14px; Time is anchored `TOPRIGHT` and unaffected), explicitly requested and approved as the one shared-improvement exception to "MythicPlus stays pixel-identical."

**Deeper expanded-detail hierarchy.** New `Layout.ACCORDION_DETAIL_INDENT` (= `ACCORDION_DISCLOSURE_WIDTH + ROW_INDENT + 8` = 30px) — `Dashboard:SetAccordionDetailField` now indents to this constant instead of `Layout.ROW_INDENT`, so expanded fields visibly nest under the row's own (now-shifted) title rather than lining up flush with it. The byte-identical `row.DescriptionText` block that had been independently duplicated in both `Pages/Accomplishments.lua` and `Pages/Journey.lua` is promoted into new `Dashboard:SetAccordionDetailDescription(row, text, yOffset, width)`/`HideAccordionDetailDescription(row)` (`Rows.lua`), using the same deeper indent — the same promotion discipline `SetAccordionDetailField` itself went through the pass before this one.

**Hover feedback: audited, already adequate.** `BuildHistoryRow` and `BuildAccomplishmentRow` already tinted the full row background on hover (`(1,1,1,0.06)`, matching `BuildRecommendationRow`'s identical established value) — real, shipping, covers the whole row including the new disclosure icon. No new mechanism was needed or added.

#### Insight responsibilities
"Achievement Earned", "Achievement Milestone" (title strings kept unchanged — purely internal matching keys against `RecommendationEngine`/`NotificationService`, never shown to the player, still accurate; only fires for a classified accomplishment now, unlike the old module which fired for anything).

#### Recommendation responsibilities
"Continue Your Pursuit" (`id = ContinueAchievementHunting`), "Reach Next Milestone" (`id = ReachNextMilestone`) — `category` field renamed to `"Accomplishments"`, ids kept unchanged for consistency with the rest of this addon's stable-id convention.

#### Explicitly NOT responsible for
- Any non-achievement Blizzard system beyond the deliberate Campaign/Renown exception above, even when an achievement rewards it (e.g., a Warband Bank tab unlocked by an achievement is Warband's data — the achievement completion itself is still Accomplishments' data).
- Detailed Mythic+ data (run history, rating, key levels) — `MythicPlusModule` remains the sole owner; this module only reflects the completion FACT of Keystone Master/Hero-type achievements.
- Per-criterion progress on incomplete achievements (`GetAchievementNumCriteria`/`GetAchievementCriteriaInfo`) — unaudited, a real future follow-up, not built this pass.
- Auto-populating "Legacy Accomplishments" — no Blizzard signal exists; would need a maintained curated ID list, a real future follow-up.

---

### 1.4 MythicPlus

#### Purpose
Owns Mythic+ keystone state, dungeon score, best runs, active-run state, weekly affixes, current season, and a long-term personal performance history (recorded runs, season statistics, and trend-based Insights derived from them). This is explicitly a personal companion, not a combat log analytics tool — see "Long-Term Performance Tracking" below for the line this module draws around that.

#### Responsibilities
- Owned keystone: whether the player has one, its dungeon map ID, its resolved dungeon name, and its level.
- Current season, read directly from Blizzard rather than hardcoded.
- Overall Mythic+ rating (dungeon score) and per-dungeon best runs.
- Active-run state while a Mythic+ run is in progress (keystone level, affixes, charged state, death count/time lost).
- The most recently completed run's outcome (level, on-time, score delta, personal-best flag, death count, active affixes, spec, item level, interrupt count, defensive-cooldown usage, boss/trash death split with location, consumable usage, net item-count delta).
- Weekly affixes, and the narrower Font-of-Power-receptacle-scoped slotted-keystone affixes.
- Session tracking: rating change since login, runs completed this session.
- Recording each completed run to ActivityHistoryService (Module = "MythicPlus") as it happens — the only write path into that history; ActivityHistoryService still owns storage/persistence/pruning, this module owns what a "completed run" record means. There is no historical backfill: history only ever reflects runs completed after this recording began, since Blizzard exposes no run log to backfill from.
- Deriving Recent Runs (`GetRecentRuns`, newest-first, reads back through `ActivityHistoryService:GetByModule`) and Season Statistics (`GetSeasonStatistics`, aggregated from recorded runs whose `Data.season` matches the current season) from that recorded history.
- Insight generation for Mythic+ events, including several derived from recorded history rather than live state alone (see Insight responsibilities below).

#### Blizzard APIs owned
`C_ChallengeMode`: `GetActiveKeystoneInfo`, `GetSlottedKeystoneInfo`, `HasSlottedKeystone`, `GetOverallDungeonScore`, `GetMapUIInfo`, `GetDeathCount`, `GetMapScoreInfo`, `GetCompletionInfo`, `IsChallengeModeActive`, `GetAffixInfo` (affix display resolution). `C_MythicPlus`: `GetOwnedKeystoneChallengeMapID`, `GetOwnedKeystoneLevel`, `GetCurrentAffixes`, `GetCurrentSeason`, `RequestMapInfo`. `GetExpansionLevel` (envelope metadata only). `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_DEAD`, `ENCOUNTER_START`/`ENCOUNTER_END`, and a narrowly-filtered `COMBAT_LOG_EVENT_UNFILTERED` — all registered only between `CHALLENGE_MODE_START` and the run ending (see "Long-Term Performance Tracking"). `C_Item.GetItemInfoInstant`, `C_Map.GetBestMapForUnit`/`GetPlayerMapPosition` (player's own position on their own death only).

#### Dashboard responsibilities
Home page Mythic+ card ("Current Keystone" in the daily-briefing layout — current season, active run or owned keystone/dungeon name/level, rating, best level) plus the Home page's "Recent Activity" card (most recent completed run, read via `GetRecentRuns(1)`). Mythic+ page — the flagship page: Hero section, Key Statistics grid, Recent Runs history table (expandable rows), Season Statistics grid, Personal Bests grid, Performance Trends grid, Consumables grid, Recommendations, Insights. Recent Runs' expandable rows are `Dashboard:LayoutHistoryRows` (`Rows.lua`), a thin wrapper over the same `LayoutAccordionRows` engine Accomplishments/Journey use (section 1.3's "Accordion Polish Pass") — its columns gained a shared disclosure icon and shifted right 14px to make room, an intentional shared-improvement exception to this page otherwise staying pixel-identical.

#### Insight responsibilities
Live-state insights: "No Keystone", "Keystone Ready" (an owned keystone with no run currently active — the trigger for RecommendationEngine's cross-module "Complete Your Keystone", see 1.6), "Personal Best", "Rating Increased", "Current Run Active". History-backed insights (each gated on enough recorded samples to be meaningful, not fired from one or two runs): "Recent Timed Rate", "Season Success Rate", "Weakest Dungeon" (lowest timed rate among dungeons run at least twice this season), "Dungeon Average Deaths" (for the currently-owned dungeon), "Deaths Today", "Success Rate Improving" (earlier vs. later half of the season's recorded runs), "Consumables Reminder" (low flask/food usage rate among *tracked* runs only — untracked older runs are excluded rather than assumed to mean "none used").

#### Recommendation responsibilities
Feeds RecommendationEngine via Insight → Recommendation mappings, now considering historical performance alongside live state: "No Keystone" → Retrieve Your Keystone, "Keystone Ready" → Complete Your Keystone (RecommendationEngine V2's flagship cross-module example — see 1.6), "Personal Best" → Push Further (with a real `reason` from the insight's level/dungeon data), "Rating Increased" → Keep Climbing, "Recent Timed Rate" → Consider a Lower Key Level (timed rate below 50%), "Weakest Dungeon" → Practice Your Weakest Dungeon, "Consumables Reminder" → Bring a Flask and Food. `GetSeasonStatistics()`'s per-dungeon `dungeonBreakdown` and the `GetDungeonStatistics(dungeonID)` getter built on top of it exist specifically so RecommendationEngine can read one dungeon's own historical success rate/completion time as supporting evidence without duplicating this module's aggregation.

#### Explicitly NOT responsible for
- Great Vault eligibility derived from M+ activity (Weekly module reads its own aggregate, doesn't ask MythicPlus to compute this).
- Raid or PvP content.
- Recreating a combat log analytics system — see "Long-Term Performance Tracking" for exactly where the line is drawn (one filtered sub-event, not a general parser).
- Party roster and named party member specs — deferred pending an explicit decision (see Future Extension Points); nothing about other players is currently recorded.
- Loot item identity, Valorstones, and Crests — see Future Extension Points; currency tracking belongs to the planned Currency module (Section 2.2), not MythicPlus.
- A hardcoded "recommended item level" table — Blizzard exposes no such API; see "Item Level Guidance" below for the self-referential alternative actually implemented.

#### Long-Term Performance Tracking

**Data flow:** `CHALLENGE_MODE_START` → `MythicPlusModule` resets per-run scratch state (`self.RunTracking`) and registers a small set of run-scoped listeners → those listeners accumulate interrupts/defensive-cooldown-uses/deaths(+location, boss-vs-trash)/consumable-item snapshots while the run is in progress → `CHALLENGE_MODE_COMPLETED_REWARDS` builds the completed-run record and calls `RecordCompletedRun()`, which appends one record to `ActivityHistoryService` (Module = `"MythicPlus"`) and unregisters the run-scoped listeners → `GetRecentRuns()`/`GetSeasonStatistics()` read that history back → `GetInsights()` derives history-backed Insights from it → `RecommendationEngine`'s existing generic Insight → Recommendation mappings turn some of those into Recommendations, unchanged in structure from before this feature → the Dashboard reads all of the above through public APIs only.

**History ownership:** MythicPlusModule is the only writer to its own `Module = "MythicPlus"` records. `ActivityHistoryService` owns storage, indexing, retrieval, and pruning; it never inspects or generates statistics from the `Data` payload — that stays MythicPlusModule's exclusive concern, keeping `RecommendationEngine`/`InsightEngine` fully generic (see below).

**Persistence:** `DatabaseService:GetCharacter().ActivityHistory`, unchanged from the prior phase — no new SavedVariables table. Bounded, not unlimited: `ActivityHistoryService` trims the oldest records once a module exceeds `MAX_RECORDS_PER_MODULE` (500), enforced on every `Append()`. For MythicPlus this is roughly a year or more of retention for an active pusher, a real enforced bound rather than "grows forever."

**Run record versioning:** Additive, not restructured. Every field from the previous schema (`dungeonID`, `level`, `time`, `onTime`, `scoreChange`, `isMapRecord`, `season`, `deathCount`, `affixIDs`) is unchanged, so a reader written against the old schema keeps working against both old and new records without modification. New fields (`recordVersion = 2`, `spec`, `itemLevel`, `timeRemaining`, `interruptCount`, `defensives`, `bossDeaths`/`trashDeaths`/`deathLocations`, `consumables`, `itemCountDelta`) are simply absent (nil) on records written before this phase; every reader nil-guards rather than assuming presence. This was a deliberate deviation from a fully nested `Metadata`/`Timing`/`Party`/etc. structure some might expect — nesting-then-migrating old records would have meant either breaking old reads or writing a migration step; flat-and-additive needed neither.

**Recommendation/Insight sources:** Unchanged architecturally from before this phase — `InsightEngine`/`RecommendationEngine` still iterate any registered module's `GetInsights()`/match on insight titles generically, with zero MythicPlus-specific code added to either engine. All of the new intelligence lives in `MythicPlusModule:GetInsights()` and a few new title-matched branches in `RecommendationEngine:EvaluateInsight()`, exactly like every existing mapping.

**Consumable classification, deliberately not a hardcoded item list:** Potions/flasks/food are reseasoned by Blizzard every patch, so a maintained item-ID list would go stale immediately. Instead `MythicPlusModule:ClassifyConsumableItem()` reads the item's own `classID`/`subClassID` (`C_Item.GetItemInfoInstant`, against `Enum.ItemClass.Consumable`/`Enum.ItemConsumableSubclass`) — Blizzard's own stable taxonomy, so a brand-new seasonal potion is correctly classified the day it ships. The one exception is Healthstone (itemID 5512, an exceptionally long-stable ID). Trade-off accepted: this cannot distinguish healing/mana/combat potions from each other (all just subclass "Potion") without reintroducing the same staleness problem, so only an aggregate "potion" count is reported.

**Interrupts, the one combat-log event:** Successful-interrupt detection genuinely requires `COMBAT_LOG_EVENT_UNFILTERED`'s `SPELL_INTERRUPT` sub-event — there is no lighter-weight way to know an interrupt *landed* rather than was merely cast. This is registered only between `CHALLENGE_MODE_START` and run end, and `OnCombatLogEventUnfiltered()` looks at exactly one sub-event filtered to `sourceGUID == UnitGUID("player")` — not a general combat log parser, and not used for anything else.

**Defensive cooldowns, a living list:** `Modules/MythicPlus/MythicPlusSpellData.lua` holds one well-known instant-cast "oh crap" cooldown per class, compiled from general knowledge and **not verified against a live client from this development environment**. Treat every spell ID there as needing an in-game spot check before being trusted, and expect it to need updates as Blizzard reworks/renames class defensives across expansions — it is explicitly a living document, not a finished one.

**Item Level Guidance:** Blizzard exposes no "recommended item level for Mythic+ key level N" API of any kind — confirmed, not assumed. The only non-fabricated alternative implemented is self-referential: `GetSeasonStatistics().averageItemLevelByKeyLevel` reports the player's own historical average equipped item level at each key level they have actually *succeeded* at this season, sourced entirely from `data.itemLevel` captured at each run's completion. This is a real personal data point, not an external "recommended" table.

**Future Extension Points:**
- **Party composition** — the deliberate decision this note asked for has now been made (Player Journal & Community Notes System — see Section 1.11). MythicPlusModule itself remains unmodified and self-only, exactly as designed here: the new party-member-facts ownership lives entirely in a new module, PlayerJournalModule, which reads basic roster identity (`UnitFullName`/`UnitGUID`/`UnitClass`/`UnitGroupRolesAssigned`) — not the heavier `NotifyInspect`/`INSPECT_READY` path this note originally flagged as the expensive alternative. This entry is kept, unedited above, as the historical record of the decision point; see 1.11 for what was actually built.
- **Missed interrupt opportunities** — assessed as impractical without tracking every enemy cast start/end and correlating against all interrupts across the group, which is meaningfully heavier than "keep statistics lightweight" allows. Not implemented.
- **Valorstones/Crests** — these are currencies, owned by the planned Currency module (Section 2.2), not MythicPlus. Reading `C_CurrencyInfo` here would duplicate a not-yet-built module's future ownership. Loot item *identity* (which specific items dropped) is similarly deferred — only a net item-count delta (via Inventory's existing `GetTotalItemCount()`) is currently captured, as a rough "did loot happen" signal, not itemized loot.
- ~~**Affix name/icon resolution**~~ — **Implemented** (Technical Debt & Completion sprint): `MythicPlusModule:GetAffixDisplayInfo(affixID)`, memoized, wraps the confirmed `C_ChallengeMode.GetAffixInfo`. The Dashboard's Recent Runs detail view now shows resolved affix names, falling back to the raw ID only if Blizzard's own call fails to resolve it.

#### Phase 2 API Audit — Resolution

The original audit (below, kept for its reasoning) evaluated Run History, Seasonal Statistics, Rating History, Best Runs, Affixes, and Great Vault against what Blizzard's API exposes. Run History, Seasonal Statistics, and Rating History are now implemented exactly as that audit recommended: not as a new Blizzard API call (none exists), but as MythicPlusModule recording its own observations via ActivityHistoryService as they happen, then deriving history/statistics from what's been recorded (`GetRecentRuns`/`GetSeasonStatistics`). There is no backfill — this data starts empty and accumulates only from the moment it shipped. Best Runs and Great Vault's conclusions are unchanged. Affixes gained one piece of real data (the affix IDs active during a completed run are now captured into that run's history record) but the name/icon resolution wrapper described below is still not built — the Dashboard's Recent Runs detail view currently renders recorded affix IDs as raw numbers for exactly that reason.

This audit covers the fields named in the Phase 2 task: Run History, Seasonal Statistics, Dungeon Statistics, Best Runs, Rating History, Affixes, and Great Vault progress. Each is evaluated against what Blizzard's API actually exposes today, per this document's "follow the data, do not speculate" rule.

| Topic | Available via Blizzard API | Not available from Blizzard | Recommended architecture addition |
|---|---|---|---|
| Best Runs | `C_ChallengeMode.GetMapScoreInfo()` — per-dungeon `mapChallengeModeID`, `level`, `dungeonScore` (already collected). | Per-run metadata beyond the current best (duration, affixes used, date) — Blizzard's own return is a single "best" snapshot per dungeon, not a run log. | None needed for current scope; if per-run metadata is ever exposed by a future API, extend `RefreshBestRuns()` in place — same module, same function. |
| Affixes — **Implemented** | `C_ChallengeMode.GetAffixInfo(affixID)` *(confirmed namespace, resolves an affix ID already collected in `weeklyAffixIDs`/`currentAffixIDs` into name/description/icon)*. Affix IDs active during a completed run are now captured into that run's recorded `Data.affixIDs`. | A "why was this affix chosen" or historical affix-rotation API. | Done: `MythicPlusModule:GetAffixDisplayInfo(affixID)`, memoized, wraps `GetAffixInfo` so the Dashboard shows affix names/icons without calling `C_ChallengeMode` directly (Rule 2). |
| Run History — **Implemented** | `C_ChallengeMode.GetCompletionInfo()` (already collected as `lastCompletedRun`) — only the single most recent completion; Blizzard keeps no client-queryable log of past runs. | A Blizzard-provided multi-run history API (still doesn't exist). | Done: `MythicPlusModule:RecordCompletedRun()` publishes each completed run to `ActivityHistoryService` (the previously-scaffolded integration point) as it happens; `GetRecentRuns()` reads it back newest-first. No new Blizzard API was needed, as predicted. |
| Rating History — **Implemented** | `GetOverallDungeonScore()` (current snapshot only) plus `oldOverallDungeonScore`/`newOverallDungeonScore` from `GetCompletionInfo()` on each completion (already collected as `oldScore`/`newScore`). | A Blizzard-provided historical rating-over-time API (still doesn't exist). | Done: the rating delta per completed run (`Data.scoreChange`) is captured in the same ActivityHistoryService record as the run itself, and `GetSeasonStatistics()` sums it into `ratingGained`. |
| Seasonal / Dungeon Statistics — **Implemented** | `GetMapScoreInfo()` per-dungeon score/level (already collected, used for Best Runs). Season-scoped aggregates (runs completed, timed/failed, success rate, average key level, highest timed/completed, rating gained) are now derived from recorded ActivityHistoryService runs, not from an undocumented Blizzard aggregate. | A Blizzard-provided "season statistics" API distinct from the per-dungeon best-run table (still doesn't exist — this was correctly not assumed). | Done: `MythicPlusModule:GetSeasonStatistics()` aggregates recorded runs whose `Data.season` matches the current season. Confirms the original recommendation — this was a presentation/aggregation exercise over already-collectible data (once recording existed), not a new Blizzard API. |
| Great Vault Progress — **Implemented (Weekly module, Section 1.5)** | `C_WeeklyRewards` *(see Section 1.5 — field shapes now confirmed against Blizzard's own FrameXML source; only the whole-dungeons-per-slot progress-counting assumption still needs a live client)*. | N/A — this is a resolved ownership question, not a data gap. | Not added to MythicPlus. Per Rule 1 and Rule 14, Great Vault reads Blizzard's own pre-aggregated `C_WeeklyRewards` data directly through the now-implemented Weekly module (Section 1.5) and is never re-derived from MythicPlus run data; MythicPlus did not gain vault-tracking logic as a side effect of this feature. |

The remaining rows (Best Runs, Affixes) are not authorized for implementation by this audit alone — each still requires the same before-code discipline (confirm exact function signatures/return shapes against the live client, update this document, only then write code) as every other module in this file.

---

### 1.5 Weekly

#### Purpose
Reports Great Vault reward-slot progress. Deliberately narrow — "Weekly" as a blanket concept (all weekly-reset content) is not a single Blizzard system and would not have one natural owner; this module exists specifically for the one clean, aggregate API Blizzard already provides, and currently only for the Mythic+ activity category (see "Out of Scope" below).

#### Responsibilities
- Great Vault reward-slot progress for the Mythic+ activity category: how many of the (up to three) slots are unlocked, each slot's own threshold/progress/level, and whether an unclaimed reward is waiting.
- Session-relative "a slot was newly unlocked this session" tracking, the same pattern MythicPlusModule already uses for "Rating Increased."

#### Blizzard APIs owned
`C_WeeklyRewards`: `GetActivities` (scoped to `Enum.WeeklyRewardChestThresholdType.Activities`), `HasAvailableRewards`, `GetItemHyperlink`. `C_Item`: `GetItemInfo`, `GetDetailedItemLevelInfo`. `WEEKLY_REWARDS_UPDATE`.

**VERIFICATION STATUS (Blizzard API Verification Workflow pass):** `WeeklyRewardActivityInfo`'s field shape (`type`, `index`, `threshold`, `progress`, `id`, `activityTierID`, `level`, `claimID`, `raidString`, `rewards`) and the `WEEKLY_REWARDS_UPDATE` event name are both confirmed directly against Blizzard's own FrameXML source (`Blizzard_WeeklyRewards/Blizzard_WeeklyRewards.lua`, mirrored at `Gethe/wow-ui-source`). This pass also found and fixed a real bug: `activity.level` is the Mythic+ KEY level (e.g. "15"), not an item level — the module previously exposed this to Home's "Highest Reward" card mislabeled. The real reward item level now comes from `GetActivityRewardItemLevel()`, which reproduces Blizzard's own `WeeklyRewardActivityItemMixin:SetDisplayedItem()` resolution chain (`activity.rewards` → `C_Item.GetItemInfo` → `C_WeeklyRewards.GetItemHyperlink` → `C_Item.GetDetailedItemLevelInfo`) field-for-field, and returns `nil` (never a guessed number) if any step fails or the item cache hasn't populated yet — note Blizzard's own UI has a `GET_ITEM_INFO_RECEIVED` retry for that cache-miss case that this module does not replicate (a documented possible follow-up, not implemented). **Still Needs Live Verification:** whether `threshold`/`progress` are counted in whole dungeons completed on the current build — conceptually confirmed via documentation and a cross-referenced community addon (`Broker_GreatVault`), but not literally observed against a live client's numbers. See `docs/DEVELOPMENT_BACKLOG.md`'s Critical section for the full citation list and the Live Verification Checklist.

#### Dashboard responsibilities
Home page "Vault Progress" card (`X / Y Slots`, plus a note when a reward is unclaimed) — clickable as of the Technical Debt & Completion sprint, navigating to a dedicated Weekly page (vault slot breakdown per index/threshold/progress, Recommendations, Insights) built with the same reusable StatisticsGrid/AppendDynamicSection helpers every other page uses.

#### Insight responsibilities
"Vault Slot Unlocked" (session-relative, objective), "Vault Reward Available" (objective, `HasAvailableRewards()`).

#### Recommendation responsibilities
"Vault Reward Available" → Claim Your Great Vault Reward. Also read (never as a trigger, only as supporting evidence) by RecommendationEngine's "Complete Your Keystone" recommendation — see "Companion Intelligence (RecommendationEngine V2)" below.

#### Out of Scope
Raid and PvP vault activity categories — `C_WeeklyRewards` covers them too, but no Raids/PvP module exists yet to consume that data, and guessing at their presentation would mean this module quietly doing another module's future job. Per-activity progress *toward* a vault slot (MythicPlus already owns and records that as `Data.level`/`Data.scoreChange` on its own completed-run history) — Weekly only reports the vault's own slot/threshold view of it.

---

### 1.6 Companion Intelligence (RecommendationEngine V2)

Not a gameplay module — `RecommendationEngine`/`InsightEngine` are Core services with no Blizzard API of their own — but documented here because this feature changed how they work together and, per Rule 6, deliberately amended one of this document's own architectural rules. See `Core/Intelligence/RecommendationEngine.lua`'s own header comment for the same rationale in code.

#### What changed
Previously a recommendation was a 1:1 reshaping of one Insight: title/description/priority/category, occasionally a `reason`/`expectedBenefit`/`estimatedTime`. It is now a genuinely explainable, cross-module, deterministically-scored record:

- **`sourceModules`** — which module(s) contributed real data to this recommendation. Defaults to the triggering Insight's own category (so every existing 1:1 mapping gets a correct, non-empty value for free); a cross-module recommendation lists every module it actually read from.
- **`supportingEvidence`** — an ordered list of `{ label, value }` facts the recommendation was actually built from (e.g. Current Rating, Historical Success Rate, Current Item Level, Vault Progress). Rendered today as bullet lines under a recommendation's reason/benefit/time (Recommendations page and the Home page's "Highest Priority" card); a dedicated "Why?" popup remains a future extension (see below) rather than something built this pass.
- **`score`** — see "Scoring" below. Replaces raw Insight `priority` as what `SortRecommendations()` actually sorts by.

#### Cross-module evidence gathering (the Rule 6 amendment)
A recommendation's *trigger* — whether it exists at all, and its base priority — still comes exclusively from one Insight, unchanged. What's new: once triggered, `RecommendationEngine:EvaluateInsight()` may call *other* modules' already-public fact getters (`CharacterModule:GetProfile()`, `MythicPlusModule:GetSeasonStatistics()`/`GetDungeonStatistics()`, `WeeklyModule:GetVaultProgress()`) to attach supporting evidence and scoring factors. This is the same category of action Dashboard already performs on every page — reading a module's public getter directly — just performed by RecommendationEngine instead. It is not a new gameplay judgment: every fact read this way is a pre-existing public getter, and RecommendationEngine never computes a new aggregate over raw module state itself (that would still violate ownership — MythicPlusModule computes `GetDungeonStatistics()`, RecommendationEngine only reads the result). Any fact that isn't available (no Weekly data this session, fewer than two historical runs of a dungeon) is simply omitted from that recommendation — never guessed at.

The flagship example is `RecommendationEngine.lua`'s `"Keystone Ready"` branch → **Complete Your Keystone**: MythicPlusModule's `"Keystone Ready"` Insight (an owned keystone, no run active — an objective fact, unchanged Insight-layer discipline) triggers it; RecommendationEngine then attaches current rating and this specific dungeon's own historical success rate/completion time (MythicPlus), the player's own equipped item level (Character), and Great Vault slot progress (Weekly) as supporting evidence — all real, all optional, none fabricated.

#### Scoring (Part 4)
Deterministic and documented in `RecommendationEngine:ComputeScore()`'s own comment block:

```
score = priority                                   (the triggering Insight's own urgency, unchanged)
      + 15  if historicalSuccessRate >= 70           (genuinely achievable, worth surfacing first)
      - 15  if historicalSuccessRate <  40           (recommending it anyway sets the player up to fail)
      + min(vaultSlotsRemaining * 5, 15)             (real, remaining Great Vault upgrade potential this week)
      + 5   if belowPersonalGearAverage              (player's own gear is below their own historical average at this key level)
```

Every term is optional and additive; a branch that supplies no `scoreFactors` gets `score == priority`, identical to V1 behavior. This keeps scoring generic enough for a future module (Delves, Raids, Professions, ...) that won't have vault/gear data at all — it contributes 0 to every term it doesn't supply, never a guessed value (Part 7).

#### Home page (Part 5/8)
The Home page is now ordered as a daily briefing rather than a flat card stack: a real-time-of-day greeting, the single highest-scored recommendation (with stars/reason/benefit/time, the same fields the Recommendations page shows), Current Character, Current Keystone, Vault Progress, then Recent Activity (the single most recent completed Mythic+ run) as a trailing history fact. Inventory, Achievements, and Storage (added in 1.7) remain on Home, moved to the bottom rather than removed — this window has no separate sidebar navigation (see Dashboard.lua's own file header), so their cards are still each page's only entry point.

#### Future Extension Points
- **A dedicated "Why?" view** — `supportingEvidence` already carries everything such a view would need; today it renders inline as bullet lines under a recommendation instead of behind a separate expandable/modal view. Building that view is additive (a new UI reading an already-existing field), not a data-model change.
- **Party composition, missed interrupts, Valorstones/Crests, loot identity, affix display** — unchanged from Section 1.4's own Future Extension Points; RecommendationEngine V2 did not revisit any of them.

#### RecommendationEngine V3 (Companion Intelligence)
Reasons across the player's whole account instead of one Insight at a time, without changing any of V2's ownership rules — the trigger for every recommendation is still exclusively an Insight (Rule 6, unchanged); V3 only changes what happens between "an Insight fired" and "a recommendation is stored."

**Pipeline.** `RecommendationEngine:Refresh()` is now six explicit phases: Collect (`AC.InsightEngine:GetInsights()`, unchanged — this engine never gathers gameplay data itself), Group (`GroupInsights()` — partitions the real Insight list into a "Preparation" group and everything else), Merge (`MergePreparationGroup()` — collapses 2+ Preparation insights into one recommendation instead of several scattered ones; a lone one is left exactly as before), Score (`ComputeScore()` + `ComputeConfidence()`, both applied in `AddRecommendation()`), Prioritize (`SortRecommendations()`, unchanged), Present (Dashboard's job, unchanged).

**Smart merging.** "Preparation" groups Inventory's Bags Almost Full/Filling Up/Hearthstone Missing/Repairs Needed with Storage's Missing/Excess Items — the same underlying "am I ready to go" concern regardless of which module noticed it. Two or more real insights from that group merge into one "Restock & Prepare" recommendation whose `supportingEvidence` is built entirely from what each merged insight's own `EvaluateInsight` branch already produced — never a re-derived judgment, only a consolidated presentation of real, already-decided facts.

**Duplicate reduction.** When "Keystone Ready" is active the same refresh, `GroupInsights()` omits "Storage Missing Items"/"Storage Excess Items"/"Repairs Needed" from grouping entirely — not silently dropped, genuinely subsumed, since "Complete Your Keystone"'s own evidence-gathering (below) already surfaces the same two facts (Storage's Mythic+-preset restock items, and now a real repair check read from Inventory) as real evidence on the richer recommendation. Showing a second card repeating them would be the same information twice.

**Confidence.** A new field, separate from score/priority — those measure urgency, confidence measures how *substantiated* a recommendation is. Deterministic: one point each for 2+ contributing modules, 2+ supporting evidence facts, and a real historical-success-rate factor being present; 2+ points is High, 1 (or any real evidence at all) is Medium, otherwise Low. Never a new gameplay judgment — every input is a field the recommendation already carries.

**Opportunity Score.** `ComputeScore()` gained three real terms beyond V2's four: a Vault slot exactly one run from unlocking (`vaultSlotOneRunAway`, from Weekly's own per-slot threshold/progress — the same general-knowledge/unverified caveat already on that whole field, not a new assumption), Storage's own `readinessPercent` for the Mythic+ preset (`preparationReady`/`preparationLacking` — previously informational only, "there's no documented, non-arbitrary weight for 'unprepared'"; `readinessPercent` is StorageModule's own computed number, so treating a high/low reading as a real signal is no longer a guess), and the real historical average-rating-gain-per-run magnitude (`averageRatingGain`, already computed for `expectedBenefit`'s wording, now also a scoring input). Still fully deterministic, still documented inline in `ComputeScore`'s own comment block, still zero for any factor a branch doesn't supply.

**Dashboard consumption.** `Dashboard:GetCategorizedRecommendationsAndInsights(category)` (`Core/UI/Dashboard/Sections.lua`) now matches a recommendation by `sourceModules` containment as well as `category` — for every non-merged recommendation `sourceModules` already equals `{category}` (V2's own default), so this changes nothing for them; it only means a merged "Restock & Prepare" (`category = "Preparation"`, `sourceModules = {"Inventory","Storage"}`) correctly surfaces on both the Inventory and Storage pages' own Recommendations sections, since it genuinely is about both. Confidence display lives once, in the shared `Rows.lua:LayoutItemRows` (every page's Recommendations list, including the standalone Recommendations page) and in Home's hand-built Highest Priority card — both purely read the `confidence` field RecommendationEngine already computed; neither computes anything.

**Future Extension Points** — Reward Value/Time Required/Urgency (beyond the Vault-slot term above) were named as *possible* factors in V2; still no real, non-fabricated data source for the rest as of V3. The "Mythic+ + Achievements → complete your personal best dungeon achievement" merge described in the V3 feature brief was evaluated and **not implemented** — Achievements only exposes achievement id/name/points, with no structured mapping from an achievement to the dungeon/criteria it's about, so building this would mean guessing at a correlation rather than reading a real one (the same discipline this document applies everywhere else).

#### Companion Intelligence V4 — Player Briefing & Notifications
Four new Core services, each owning exactly one responsibility and none of them computing a new gameplay fact — every one of them reads an already-real value from a gameplay module's public getter (mostly MythicPlusModule's, extended this same pass) or from InsightEngine/RecommendationEngine's already-current output, the same "services reason over real facts, modules own the facts" split V2/V3 already established.

- **`BriefingService`** ("Today's Briefing" on Home) — pure curation. Selects the highest-priority Recommendation plus up to four Insights (one per distinct category, so one chatty module can't crowd out the rest), using each one's own already-real `reason`/`description` text verbatim. Never rephrases, never invents a line.
- **`NotificationService`** (toast queue) — owns queueing, one-at-a-time display, auto-dismiss timing (a 1-second `C_Timer.NewTicker`, independent of whether the Dashboard window is open), and a bounded history (`MAX_HISTORY = 20`, same "cap it, don't grow forever" discipline as `ActivityHistoryService`). Two real trigger paths: (1) diffing `InsightEngine`'s title list refresh-to-refresh and notifying for a fixed, documented set of titles (`NOTIFICATION_TYPE_BY_INSIGHT_TITLE`) newly present this cycle — never the first refresh after login, so nothing already-true at load spams the player; (2) direct `Notify()` calls from other services (`MilestoneService`, on a new unlock) — a normal cross-service call, not a new exception. Presentation lives in `Core/UI/Dashboard/Notifications.lua`, a standalone always-present widget (the same "exists independent of the Dashboard window" reasoning `MinimapIcon.lua` already established), event-driven via a new framework event (`EventManager.FrameworkEvents` gained `"NOTIFICATION_CHANGED"`, fired by `NotificationService:PromoteNext()`) rather than polling.
- **`MilestoneService`** (Recent Milestones on Home) — personal, account-history milestones independent of Blizzard's achievement system. Owns only the generic threshold-definition list, persisted "already achieved" state (`DatabaseService:GetCharacter().Milestones`, the same lazily-created-per-character pattern `ActivityHistoryService` already uses for `.ActivityHistory` — no new SavedVariables table), and the unlock notification. Every `check(stats)` function compares a real field from `MythicPlusModule:GetMilestoneStats()` (new) against a fixed threshold — it never derives "longest win streak" or "highest key level" itself. Extensible: a future module adds its own definitions naming its own stats getter; this service's own logic doesn't change. **Character Journey pass:** added `GetAllAchieved()` (every achieved milestone, newest-first, untrimmed — `GetRecent(count)` now just adds the trim on top, zero behavior change for its existing callers) as the read source Character Journey (section 9) needs.
- **`ProgressSummaryService`** (surfaced as the standalone Progress page — see "Progress Dashboard" below) — four time windows (Last 7 Days, Last 30 Days, Season, Lifetime) and simple trend directions between adjacent windows, entirely by calling `MythicPlusModule:GetStatisticsForRange(startTime, endTime)` (new) with different boundaries and comparing two already-computed numbers against a fixed 10% threshold. Computes no aggregation of its own.

**MythicPlusModule extensions supporting the above:** `GetSeasonStatistics()`'s entire aggregation loop was extracted into a shared private `BuildStatisticsFromRecords(records)`, called by `GetSeasonStatistics()` (season-filtered, unchanged behavior) and the new `GetStatisticsForRange(startTime, endTime)` (date-range-filtered, via `ActivityHistoryService:GetByDateRange()` — previously-scaffolded infrastructure whose own comment already named "a future StatisticsService" as the intended consumer). The same single pass now also tracks `longestWinStreak`, `largestRatingGain`, `hasNoDeathRun`, `totalInterrupts`, and a `strongestDungeon`/`strongestDungeonRate` pair (the mirror of the existing `weakestDungeon`, computed in the same loop, not a second one) — no new scan added for any of it. `GetMilestoneStats()` packages the lifetime-scoped subset of these for `MilestoneService`. A new "Strongest Dungeon" Insight mirrors "Weakest Dungeon" exactly (same `WEAKEST_DUNGEON_MIN_SAMPLES` gate), lower priority (20 vs. 30) since "you're doing well at X" is worth knowing but less actionable than "you're weak at Y".

**WeeklyModule extension:** `GetNextLockedSlot()` — the next locked Vault slot and how much more progress it needs, shared by a new standing "Vault Slot Progress" Insight (not session-relative like "Vault Slot Unlocked" — it keeps reporting for as long as a slot stays locked) and by `RecommendationEngine`'s "Complete Your Keystone" evidence-gathering, which previously re-scanned `vaultProgress.slots` inline (V3) and now calls this one shared getter instead — the "which slot is next, how much more" logic exists in exactly one place.

**Explicitly evaluated and not implemented, each for a real reason, not an oversight:**
- **"Vaults Completed" / "Preparation improving" trends** (`ProgressSummaryService`) — no historical record exists to build either from. `WeeklyModule` reports only the current week's live vault snapshot and never writes to `ActivityHistoryService`; `StorageModule`'s readiness is likewise a live snapshot with no historical record. Building either honestly means adding real historical recording to those modules first, not fabricating a number here.
- **"Fastest Dungeon" milestone** — evaluated and declined: a single fastest-time-across-all-dungeons figure isn't a meaningful comparison (a +20 always takes longer than a +2 regardless of skill), and a real per-dungeon-per-level fastest-time system is a materially larger surface than this pass scoped for.
- **"Preparation Complete"/"Storage Ready"/"Bank Ready" notifications** — named as *possible* examples in the V4 brief; none are real, observable state transitions today. `StorageModule` has no session-relative "just became ready" tracking the way MythicPlus/Weekly already do for their own session-relative Insights (Rating Increased, Vault Slot Unlocked) — real module work, not something `NotificationService` can fabricate by watching for a title that doesn't exist.
- **"Mythic+ + Achievements" merge** — unchanged from V3's own conclusion above; still no structured achievement-to-dungeon mapping to build it from.

#### Progress Dashboard (Flagship Analytics)
Gives `ProgressSummaryService` and `MilestoneService` a real Dashboard home, answering "How am I improving?" — the exact follow-up the V4 pass above logged. Entirely a presentation layer: `Core/UI/Dashboard/Pages/Progress.lua` computes nothing itself, it only formats and lays out numbers `ProgressSummaryService:GetSummary()`/`GetTrends()`, `MilestoneService:GetRecent()`, and two already-existing public getters (`MythicPlusModule:GetProfile()` for current season/rating, `StorageModule:GetPreparationStatus("MythicPlus")` for live readiness) already produced. Same fully-dynamic, measure-at-full-width-then-narrow-if-needed shape as `Pages/MythicPlus.lua`.

**Sections:** Hero (current rating, with the Last-7-Days Timed % trend as a single headline indicator), Overview (season, highest key, timed %, runs completed, plus a live Preparation readiness line), Last 7 Days / Last 30 Days (seven stats each, a trend arrow appended to every value with a real — not "Unknown" — direction), Lifetime (nine totals/records), Personal Records (seven records), Recent Milestones (`MilestoneService:GetRecent(5)`), Current Trends (one line per metric with a real trend direction this cycle — a metric whose direction is "Unknown" simply isn't in the list, never shown blank or guessed).

**Reused rather than duplicated:** `Dashboard:LayoutTextLines` (`Rows.lua`) — a new generic pooled-list-of-lines-with-empty-state component, extracted from what used to be `Pages/Achievements.lua`'s own page-local `LayoutRecentAchievements` the moment Recent Milestones needed the identical shape; the Achievements page's call site now uses the shared version, and the old duplicate function is gone. `DashboardFormat.GetTrendArrow(direction)` (`Format.lua`) — one fixed, colored glyph per trend direction (▲/▼/—), shared by every grid cell and the Current Trends list.

**Preparation, deliberately shown once.** The literal page-layout brief listed "Preparation" under both the Last 7 Days and Last 30 Days blocks with a trend arrow. `StorageModule`'s readiness is a live snapshot with no historical record (the same gap `ProgressSummaryService`'s own header comment already documents for the "Preparation improving" trend it declined) — so it renders once, near Overview, as a current fact with no trend, rather than duplicated per window with a fabricated arrow.

**Home page.** One compact `Dashboard.Progress` card, placed next to the Mythic+/Vault/Recent Activity cluster — current rating plus the same Last-7-Days Timed % trend indicator the page's own Hero uses, plus a one-line season summary (highest key, timed %) when the season has recorded runs. Deliberately non-redundant with the Mythic+ Card (live keystone/vault state) and Recent Activity Card (chronological run feed) already on Home.

#### Recommendation Inspector ("Why?")
Makes every field RecommendationEngine V2/V3 already computes (`reason`, `expectedBenefit`, `supportingEvidence`, `confidence`, `sourceModules`, `estimatedTime`, `score`) actually inspectable, not just rendered as a few inline bullet lines — the "dedicated 'Why?' view" `supportingEvidence` was explicitly built for back in section 1.6's own "Future Extension Points," finally built. `Core/UI/RecommendationInspector.lua` is a **standalone window** (`AC.BaseWindow`, registered via `AC.Core:RegisterModule`, the same tier as `DiagnosticsWindow`/`SettingsWindow`), not a Dashboard page — it overlays on top of whatever the player was already looking at rather than replacing it. It computes nothing: `Show(recommendation)` takes the actual Recommendation table already in memory (captured by whichever row/card the player clicked) and only formats/lays out fields that already exist on it. Recommendations have no persisted identity across `RecommendationEngine:Refresh()` cycles, so there is nothing to look up by id — the Inspector only ever displays a snapshot of what was real and current at click time, the same relationship every pooled Dashboard row already has with its own data.

**Data-model addition, additive only:** every `supportingEvidence` entry is now `{ label, value, module }` — `module` is the real module name already known at the exact call site that builds that fact (the variable name of the module being read, or a merged "Restock & Prepare" candidate's own already-real `category`), never inferred or guessed after the fact. Existing readers that only destructure `label`/`value` are unaffected. This is what lets the Inspector group Supporting Evidence by contributing module (Storage / Mythic+ / Weekly / Character / Inventory, in first-appearance order) without duplicating RecommendationEngine's own "which module did this come from" knowledge.

**Module links.** Contributing Modules renders each of `sourceModules` as a real clickable link, routed through a small presentation-only `MODULE_TO_PAGE`/`MODULE_DISPLAY_KEY` map local to the Inspector (reusing the existing `Dashboard.MythicPlus`/`Dashboard.Inventory`/etc. localization keys rather than duplicating them) — clicking one hides the Inspector and calls `AC.Dashboard:Navigate(page)`. "Character" is the one module name that doesn't equal its own page name (Character's data displays on the Profile page), the same mapping Home's own cards already assume implicitly.

**Entry points.** Home's Highest Priority card gained a "Why?" button (reads `recommendationCard.CurrentRecommendation`, set fresh every `UpdateContent`, not captured at button-creation time — the button is built once, the recommendation it points at changes every refresh). Every recommendation row addon-wide — the standalone Recommendations page and every page's own dynamic Recommendations mini-section (Inventory, Achievements, MythicPlus, Storage, Weekly) — became clickable through one shared change to `Rows.lua:LayoutItemRows` (gated on `showStars = true`, so Insight rows, which have nothing to inspect, stay inert), with a hover highlight and a "Click for Why?" hint appended to the existing meta line.

**Reused rather than duplicated, and one real duplication found and fixed along the way:** the Inspector reuses `Dashboard:BeginSection`/`EndSection` (section headers) and `Dashboard:LayoutTextLines` (evidence line pooling) directly — both already generic enough (scrollChild/yOffset/contentWidth in, nothing Dashboard-page-specific) to work from a standalone window just as well as from a page. While wiring up Priority's star rating, `DashboardCard:SetStarRating` turned out to already have its own copy of the priority-to-stars formula (identical math to `DashboardFormat.PriorityToStars`, just never routed through it) and `Rows.lua:LayoutItemRows` built the same finished star string inline a second time — both now call a new `DashboardFormat.RenderStars(priority)`, and `DashboardCard.lua`'s own now-dead local `STAR_FILLED`/`STAR_EMPTY` constants were removed.

---

### 1.7 Storage

#### Purpose
An intelligent preparation system, not a bag/bank addon: owns bank, reagent bank, and (where Blizzard allows) Warband Bank *contents*, and compares them plus the player's bags (read through InventoryModule's public API, never rescanned) against a selected "storage profile" of rules to answer "am I prepared, and what's missing?"

#### Ownership resolution (Warband Bank)
Section 2.3 ("Warband", planned) originally reserved "the Warband Bank... its gold balance, tabs, and (when accessible) contents" for a dedicated future module. That reservation is now narrowed: Storage owns Warband Bank **item contents** (read for restock/preparation purposes, exactly like the character bank and reagent bank), decided explicitly before implementation because no Warband module exists yet to conflict with. If a Warband module is ever built, its scope is the bank's own gold balance and tab-purchase administration only — not item contents, which stay Storage's concern. This also corrects Section 1.2 (Inventory)'s previous, unjustified assignment of "reagent bank" to the planned Currency module.

#### Responsibilities
- Bank, reagent bank, and (where accessible) Warband Bank item contents — an in-memory cache scoped to bank-side locations only, scanned while the bank is open, never persisted (the same "cache, don't persist" treatment InventoryModule already gives bags).
- Storage profiles: a small set of built-in presets (Mythic+, Raid, Questing, Custom) — see "Built-in presets, not a rule editor" below.
- Rule-based matching against Item/Category/Quality/Expansion/User-Group targets (Blizzard's own classID/subClassID taxonomy for Category, the same self-maintaining approach MythicPlusModule:ClassifyConsumableItem already established). Profession-based targeting is explicitly NOT implemented — see "Explicitly NOT responsible for" below.
- Restock analysis: missing items, excess items, recommended withdrawals, recommended deposits, and a deterministic readiness percentage (`readinessPercent` — average, across Maintain/Keep rules, of how close bags alone are to each rule's target, capped per-rule at 100%) — computed live from InventoryModule + this module's own bank cache, never cached/stale.
- A live-computed shopping list (the "missing" side of restock analysis).
- Activity preparation status (`GetPreparationStatus`) — a real ready/not-ready signal plus the readiness percentage above, consumed by RecommendationEngine as supporting evidence (see 1.6) and by the Dashboard (Home cards, Storage page) directly, never computed by either of them.
- **Execute — real item movement, implemented with explicit guardrails** (Technical Debt & Completion sprint; see "Execute" below for the full detail).
- Insight generation for restock gaps only ("Storage Missing Items", "Storage Excess Items") — bag-fullness insights ("Bags Almost Full"/"Bags Filling Up") remain exclusively InventoryModule's, per Rule 1; Storage does not duplicate them even though Part 5's own brief named "inventory 94% full" as an example.

#### Execute
Implemented in the Technical Debt & Completion sprint, reversing the original "Analyze + Preview only" decision after explicit re-confirmation that the safety trade-off was understood and accepted. Guardrails, all enforced in `StorageModule`, not delegated to the Dashboard:
- **Refuses outright** in combat (`InCombatLockdown()`) or when the bank isn't open.
- **Never invents its own idea of what to move** — `ExecutePreparation()` only moves items that the same `AnalyzeProfile()` call already flagged as a withdrawal or deposit; NeverMove-excluded items are already filtered out upstream.
- **Whole-stack moves only.** No partial-stack splitting (`C_Container.SplitContainerItem` would be a second, separate unverified API this deliberately avoids introducing) — the amount actually moved is reported and may exceed the amount requested for that reason. Documented, not silent.
- **Every move is pcall-wrapped**; the cursor is explicitly cleared on any failure so a botched pickup never leaves an item stuck on the player's cursor.
- **The player must explicitly confirm every execution** via a Blizzard `StaticPopupDialogs` confirmation showing the exact counts about to move — nothing here ever runs automatically or silently.

#### Blizzard APIs owned
`C_Bank.FetchPurchasedBankTabIDs`/`CanUseBank` (bank tab enumeration, character and account/Warband), `C_Container.GetContainerNumSlots`/`GetContainerItemInfo`/`PickupContainerItem` (bank-side and, for Execute, bag-side moves — bag *scanning* itself remains Inventory's), `C_Item.GetItemInfoInstant`/`GetItemInfo` (classID/subClassID/expacID, for Category/Expansion rule matching), `BANKFRAME_OPENED`/`CLOSED` and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` (bank-open detection), `InCombatLockdown`/`CursorHasItem`/`ClearCursor` (Execute safety), `StaticPopupDialogs`/`StaticPopup_Show` (Execute confirmation, owned by Dashboard.lua's presentation layer, not this module).

**VERIFICATION STATUS (Blizzard API Verification Workflow pass):** Bank tab enumeration (`C_Bank.FetchPurchasedBankTabIDs`/`CanUseBank`, `Enum.BankType` = `{Character=0, Guild=1, Account=2}`) and `C_Container.PickupContainerItem` are both confirmed real via Warcraft Wiki (Bank APIs added 11.0.0; `PickupContainerItem` available through "Midnight" 12.1.0, `AllowedWhenUntainted`) — existing code already matches, no changes needed. The legacy reagent-bank container ID path (`Enum.BagIndex.Reagentbank`/`Bank`) is confirmed harmless-but-vestigial: reagent bank was removed as a separate system in Patch 11.2.0, folded into the same unified bank-tab system the primary `FetchPurchasedBankTabIDs` path already covers. The bag-item "favorite" field is confirmed **broken**, not merely unverified: `info.isFavorite` is read from `C_Container.GetContainerItemInfo`'s return, but Warcraft Wiki's documented `ContainerItemInfo` structure has no such field — it is always `false`/`nil` in practice, and (separately confirmed) nothing in this codebase consumes it even when populated. This is deliberately left as an honest, documented gap rather than a fabricated fix — see the inline comment at the `isFavorite` read site in `ScanBank()` — and is now real follow-up work (find the correct API and wire up a real rule, or remove the dead field), not an open verification question. **Still Needs Live Verification:** the Banker interaction-type check (`Enum.PlayerInteractionType.Banker`) and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`'s exact payload shape (not researched this pass), and the actual pickup-then-place Execute round-trip against a real bank/bag. `InCombatLockdown`/`CursorHasItem`/`ClearCursor`/`StaticPopupDialogs` remain long-standing, stable APIs with materially higher confidence than the rest of this list. `GetItemInfoInstant`'s classID/subClassID return-position offset is still copied from `MythicPlusModule:ClassifyConsumableItem`'s existing convention for consistency between the two files; not independently re-verified this pass. See `docs/DEVELOPMENT_BACKLOG.md`'s Critical section for the full citation list and the Live Verification Checklist.

#### Dashboard responsibilities
Home page Storage card (active profile name, ready/not-ready status, readiness-percentage bar) and Mythic+ card (readiness-percentage bar sourced from Storage's "MythicPlus" preset — a cross-module read, see 1.6/Rule 6). Storage page: Inventory Summary, Storage Health, Current Profile (display only — switching profiles is a Settings > Storage dropdown, not a page control, per "do not overload the page"), Restock Status (now with an Execute button, confirmation-gated), Shopping List, Recommendations, Insights.

#### Insight responsibilities
"Storage Missing Items", "Storage Excess Items" — both gated on an active profile existing and its analysis actually finding a gap.

#### Recommendation responsibilities
"Storage Missing Items" → Restock Your Bags, "Storage Excess Items" → Deposit Crafting Materials. Also enriches MythicPlus's "Complete Your Keystone" recommendation with preparation evidence (missing/withdrawal items for the Mythic+ preset) via RecommendationEngine's documented cross-module evidence-gathering exception (1.6, Rule 6) — Storage does not push this itself, RecommendationEngine reads `GetPreparationStatus("MythicPlus")` as a read-only fact lookup.

#### Explicitly NOT responsible for
- **A full rule-builder UI** — add/edit/delete arbitrary rules against items/categories/quality/expansion/groups remains deferred (this was re-confirmed, not revisited, in the Technical Debt & Completion sprint). StorageModule ships with built-in presets only (`StorageProfiles.lua`); `MatchesRule`/`AnalyzeProfile` are already generic enough that a future editor is additive UI work, not an engine change.
- **Partial-stack splitting during Execute** — see "Execute" above; whole-stack moves only.
- **Profession-based rule targeting** — Blizzard exposes no direct itemID → profession mapping without full TradeSkill recipe/reagent data, which belongs to the planned Professions module (2.4), not Storage. Implementing a guessed mapping here would be exactly the kind of fabricated data this addon avoids elsewhere.
- **User-defined group *authoring*** — the `Group` rule-target type and its underlying `self.Groups` data structure are fully functional (persisted via ConfigurationManager), but there is no UI yet to create a group; this ships empty by default.
- **"Estimated Preparation Time"** — Blizzard exposes no way to measure or predict how long moving items takes. Rather than inventing a number that looks precise but isn't, `GetPreparationStatus`/`AnalyzeProfile` report a real, computed `actionsNeeded` count (how many distinct withdraw/deposit lines exist) instead of a time unit. This is a deliberate deviation from the literal "30 seconds" example in this feature's brief.
- **Great Vault** (Weekly, 1.5), **currencies** (Currency, planned), **raid/PvP-specific loot** (out of scope entirely).

---

### 1.8 Developer Mode & Live Verification Suite

Not a gameplay module — like Companion Intelligence (1.6) and the Recommendation Inspector, this is framework/diagnostic tooling, documented here because it now touches every module's own architecture (instrumentation, live API probes) and because its own isolation guarantee is itself an architectural rule worth stating precisely.

#### Purpose
Makes verification fast without turning "add logging" into the answer to everything. A permanent, always-available developer surface — six tabs in one standalone window (`Core/UI/DeveloperPanel.lua`) plus the backing `Core/Services/DeveloperModeService.lua` and `Core/Services/VerificationService.lua` — rather than one-off debug prints scattered through gameplay modules.

#### The isolation guarantee
"Production behavior must remain unchanged when Developer Mode is disabled" is enforced structurally, not by convention:
- The Developer Mode flag is a single persisted boolean (`profile.DeveloperMode`, the same `DatabaseService`-backed pattern `Logger`'s own `Debug` flag already uses).
- The Event Monitor's Blizzard event registrations and the Refresh() timing/error instrumentation on every Service/Module are only ever **installed** inside `DeveloperModeService:SetEnabled(true)` and fully **removed** (unregistered / original functions restored) inside `SetEnabled(false)` — there is no always-on hook, not even a disabled-but-present one. Toggling off leaves zero trace: every wrapped `Refresh()` is restored to the exact original function reference.
- `DeveloperPanel:Show()` refuses to do anything at all unless `DeveloperModeService:IsEnabled()` is true — even a stale keybind or leftover call is a no-op.
- The one deliberate, disclosed exception: `RecommendationEngine:ComputeScore()` now always computes and stores a `scoreBreakdown` on every recommendation, regardless of Developer Mode. This mirrors how `score`/`confidence` themselves are already always computed — the same branches that produce `score` already ran, so recording which ones fired costs nothing extra and changes no recommendation's content or ranking. Only the Recommendation Inspector's rendering of it is gated on Developer Mode.

#### DeveloperModeService (`Core/Services/DeveloperModeService.lua`)
Owns exactly three things, plus two generic serializers every Developer Panel tab's Copy buttons share instead of each writing its own:
- **The flag itself** (`IsEnabled`/`SetEnabled`), persisted and restored on login, fires a new framework event (`DEVELOPER_MODE_CHANGED`) on toggle.
- **Event Monitor** — a bounded ring buffer (200 entries) fed by a fixed, documented list of Blizzard events (`MONITORED_EVENTS`) covering framework lifecycle and the systems this addon's own "Needs Live Verification" backlog items name. A separate list and a separate gate from `DiagnosticsService`'s own narrower Mythic+-investigation event list — same category of tool, different owner and different trigger, not merged (see that file's own header for why one exists at all).
- **Refresh() instrumentation** — wraps (only while enabled) the `Refresh()` method of every registered Service/Module that has one, timing each call via `debugprofilestop()` and recording success/duration/last error. Still calls the real function (via `pcall`, so an error is observed and logged, not silently swallowed) — nothing about *when* or *why* something refreshes changes, this only observes it.
- **`ToJSON`/`ToIndentedText`** — generic, data-shape-agnostic recursive serializers. Every Developer Panel tab hands its own already-gathered data table to these for Copy JSON/Copy Text; "Copy Summary" reuses whatever lines are already rendered on screen, so no third serializer was needed.

#### VerificationService (`Core/Services/VerificationService.lua`)
Added in the Live Verification & Framework Hardening sprint. Single source of truth for "what do we know about each Blizzard API this addon depends on, and how do we know it" — the Live API tab and Checklist tab below are both rendered views over this service's data, not independently maintained copies. Owns two independent things:
- **Registry** (`REGISTRY`, static, in-code) — 37 entries across all 11 modules, each classified against the trust hierarchy (Blizzard Source / Warcraft Wiki / Live Client / Needs Live / Incorrect) with a real citation, expected behavior, and a confidence rating. This is documentation as data — `docs/DEVELOPMENT_BACKLOG.md`'s verification section deliberately stopped duplicating this list in prose to avoid drift.
- **Log** (`DatabaseService:GetGlobal().VerificationLog`/`.ChecklistLog`, persisted, account-wide) — one record per registry id or checklist scenario, written only by an explicit human action (the Live API tab's Mark Verified/Failed buttons, or ticking a Checklist scenario) — never automatically. An addon cannot verify its own correctness against the live game; only a human watching the real result can. Account-wide rather than character-scoped, since Blizzard API behavior is a fact about the client/account, not about any one character.
- **`GetChecklist()`** — 26 guided in-game scenarios (Login, Reload UI, Character Select, Spec Swap, Hearthstone, Zone Change, Flight Path, Death, Resurrection, Dungeon Enter/Leave, Keystone Insert/Complete/Fail, Great Vault, Bank, Reagent Bank, Warband Bank, Mailbox, Vendor, Auction House, Achievement Earned, Inventory Full, Equipment Change, Currency Gain, Weekly Reset), each naming exactly which registry ids it exercises — several deliberately name none (Character Select, Hearthstone, Resurrection, Mailbox, Auction House, Currency Gain), with an honest "nothing to check" render rather than padding every scenario with a fabricated API dependency.

#### DeveloperPanel (`Core/UI/DeveloperPanel.lua`)
A standalone `BaseWindow` (same tier as `DiagnosticsWindow`/`SettingsWindow`), six tabs, presentation-only throughout — every value traces to an existing public getter, `DeveloperModeService`'s own observation state, or `VerificationService`'s registry/log:
- **Overview** — the flat status board (character/zone/spec/item level, current key/rating, vault state, storage readiness, recommendation/notification counts, the current top recommendation's score/confidence, loaded module counts, last refresh, last event, frame rate).
- **Modules** — one row per registered Service/Module: Initialized (true for anything appearing in these registries at all — `ModuleManager`/`ServiceManager` only ever list what completed `Initialize()`), Enabled (a module's own `IsModuleEnabled()` — the real per-feature Settings toggle — where one exists, else "Yes" for framework services with no such concept), Last Refresh/Duration/Last Error (from `DeveloperModeService`'s instrumentation), Insight/Recommendation/History counts (via `InsightEngine:GetInsightsByCategory`, `Dashboard:GetCategorizedRecommendationsAndInsights`, `ActivityHistoryService:GetByModule` — never recomputed here), and a per-row Refresh button (`DeveloperModeService:RefreshOne`).
- **Events** — a live, timestamped, clearable feed of `DeveloperModeService`'s own event log.
- **Live API Inspector** — expanded in the Live Verification & Framework Hardening sprint into a real validation suite, not just a Raw/Final comparison. A Verification Summary line (counts by status, from `VerificationService:GetSummaryCounts()`) sits above four "Inspect Now" probes (Weekly/Great Vault, Storage/Bank including Warband via the real `Enum.BankType` split `StorageModule` itself already uses, Mythic+, Affixes). Each probe still calls the real Blizzard API directly for "Raw" (the one place outside `DiagnosticsService` this addon calls a Blizzard API straight from a diagnostic tool, on-demand only, never polled) against the owning module's own already-existing public getter for "Final" — a row highlights when they genuinely disagree — but now also shows that probe's Expected interpretation, Confidence, Source citation, and Last-Verified timestamp (from `VerificationService`), plus new Mark Verified/Mark Failed buttons that write a human-confirmed result to the persisted log. Below the four probes, a read-only **Full Verification Registry** section lists all 37 registry entries (not just the 4 with a live-comparable probe) with their status glyph, citation, and last-verified timestamp — the tab's own answer to "for every probe display Raw/Parsed/Expected/Pass-Fail/Confidence/Source/Timestamp," honestly scoped to what's actually comparable versus what's only a static classification.
- **Checklist** — new this sprint. One row per `VerificationService:GetChecklist()` scenario: its related APIs' current status glyphs, when it was last marked done (or "Not yet done"), and a Mark Done/Mark Not Done toggle. Marking a scenario done only records that a human performed it and when (`RecordChecklistScenario`) — it never changes any registry id's own verification status by itself; that stays the Live API tab's own Mark Verified/Failed buttons, kept as two deliberately separate actions ("I did the thing" vs. "I confirmed the result was correct" are not the same claim).
- **History Inspector** — real, already-stored `ActivityHistoryService` records, filterable by Module/Type (a fixed, documented list matching the only two real writers today, `MythicPlusModule`'s "Dungeon" records and `AchievementsModule`'s "Achievement" records) and a Date preset, plus Clear History (confirmation-gated, via a new `ActivityHistoryService:ClearAll()` — the one small, legitimate service extension this pass needed, so `DeveloperPanel` never reaches into that service's internal `Records` array directly).

Every tab supports Copy JSON / Copy Text / Copy Summary (`DeveloperModeService`'s generic serializers, DiagnosticsWindow's own established "focus + highlight an EditBox, player presses Ctrl+C" idiom — WoW has no clipboard-write API). Fixed a real pre-existing bug in the Live Verification & Framework Hardening sprint: Copy Summary's `table.concat` assumed every tab's summary lines were plain strings, but the Live API tab has always stored colored lines as `{text=...}` tables — clicking Copy Summary while on that tab would have thrown a Lua error. `CopyCurrentTab` now normalizes either shape before concatenating. A persistent action row (Clear Notifications, Force Refresh, Refresh Individual Module, Toggle Tracing) sits above the tabs regardless of which one is active.

#### Recommendation Inspector extension (Developer Mode section)
`RecommendationEngine:ComputeScore()` now also returns (and `AddRecommendation` stores) `scoreBreakdown` — the ordered list of named terms that actually applied to produce `score`, built alongside the existing scoring logic rather than as a second pass. The Recommendation Inspector renders this as a new "Score Breakdown" section, visible only while Developer Mode is on — the literal answer to "explain exactly why one recommendation beat another" the brief asked for, reading a field that already exists rather than re-deriving anything.

#### `/ac dev on|off`
Toggles Developer Mode; bare `/ac dev` toggles the panel itself if Developer Mode is already on, otherwise warns that it's off.

---

### 1.9 v1.0 Polish & Completion Sprint

Not a new system — a full-codebase audit (every Dashboard page, service, gameplay module, and reusable widget) followed by targeted consolidation and bug fixes, with no new gameplay logic anywhere. Four parallel research passes read the entire codebase and reported only verified, file:line-cited findings; everything below was independently re-verified before being acted on.

**Real bugs fixed:**
- MythicPlus page's Key Statistics grid had "Best Timed" permanently hardcoded to "Unknown" instead of reading `seasonStats.highestTimedLevel` — real data that was already correctly used two sections further down the same page.
- Home's Recent Activity Card always navigated to the MythicPlus page on click, even when its newest feed entry was an Achievement record (the feed already merges both). Now reads a `TargetPage` field set fresh every refresh, the same "field read at click-time" pattern the Recommendation Inspector's own "Why?" button already established.
- Three dead localization keys removed (`Dashboard.RatingChangeFormat`, `Dashboard.RecentActivityTimedFormat`, `Dashboard.RecentActivityFailedFormat`) — leftovers from before Home Dashboard Evolution superseded them with `Dashboard.FeedMythicPlusTimedFormat`/`FeedMythicPlusFailedFormat`, never removed at the time.

**Duplication consolidated (new shared helpers, no behavior change):**
- `Dashboard:ShowEmptyLine` (`Sections.lua`) — `Rows.lua`'s `LayoutItemRows` and `LayoutTextLines` each hand-rolled an identical cached empty-state FontString block instead of calling it; both now do. Its own parameter was renamed `page` → `container` to reflect that a pool table works identically to a page table for this purpose.
- `Logger:GetPreciseTimestamp()` — `Logger.lua`'s own internal clock-math function and `DeveloperModeService.lua`'s `BuildEventTimestamp` were line-for-line identical; the latter is gone, the former is now exposed publicly.
- `BaseWindow:AddCloseButton(frame, owner)` — the five-line close-button construction was copy-pasted identically across all four standalone windows (`DiagnosticsWindow`, `SettingsWindow`, `RecommendationInspector`, `DeveloperPanel`); extracted once a fourth copy confirmed the pattern.
- `DashboardFormat.HIGHLIGHT_COLOR` / `DashboardFormat.SetHighlightColor(fontString)` — the gold accent color `1, 0.82, 0` was hand-typed in 14 places across 7 files; consolidated to one definition (one documented exception: `Layout.lua`'s `HERO_VALUE_FONT` setup runs at file-load time, before `Format.lua` has loaded, so it keeps the literal). Also unified one stray status-green variant (`0.3, 0.7, 0.4` → the `0.3, 0.8, 0.4` every other card already used).
- `AC.HEARTHSTONE_ITEM_ID` (`InventoryModule.lua`) — item ID 6948 was hardcoded independently in four places (`InventoryModule.lua` ×2, `StorageProfiles.lua` ×2); now one shared constant, referenced by both.
- `ServiceManager:GetAll()` / `ModuleManager:GetAll()` — new public iterators (the same ordered list their own lifecycle sweeps already use internally) so `DeveloperModeService`'s Refresh() instrumentation and `DeveloperPanel`'s Modules tab no longer reach into `.Services`/`.Modules`/`.Order` directly.

**Dead code removed:**
- `Modules/Player/PlayerModule.lua` — a "framework validation module" (its own header's words) for zone/coordinate tracking with a live Settings page (checkboxes for "Show Coordinates"/"Show Zone Name" that did nothing observable) and a 1-second ticker, confirmed via repo-wide grep to have zero consumers anywhere. This was flagged in the backlog for several passes; now confirmed dead and removed, `.toc` entry included — exactly the kind of leftover-scaffolding-that-looks-broken-to-a-new-user this sprint exists to find.
- `WidgetManager.lua`'s unused `local tinsert = table.insert` alias (every insert in the file used `table.insert` directly).
- Several stray 0-byte `New Text Document.txt` files scattered across `Core/` subdirectories (untracked filesystem litter, not addon content).
- Hover feedback added where a sibling widget of the same kind already had it but this one didn't: `Rows.lua`'s `BuildHistoryRow` (MythicPlus Recent Runs' expandable rows) gained the same `Background` hover-highlight `BuildRecommendationRow` already had; `ColorPicker.lua`'s clickable swatch gained a highlight texture (Button's built-in `SetHighlightTexture`, which never conflicts with `SetTooltip`'s own `OnEnter`/`OnLeave`) — previously the one clickable swatch/card/link in the addon with no hover cue at all.

**Audited and deliberately left alone, each for a real reason:**
- A number of service methods came back "confirmed unused anywhere in the repo" (`MilestoneService:IsAchieved`/`GetAchievedAt`/`GetAllDefinitions`, `ActivityHistoryService:GetActivity`/`GetByType`/`Count`, `EventManager:HasSubscribers`, `Logger:SetBufferSize`). None were removed — each is a reasonable, intentional piece of a service's public API (the same category as `ActivityHistoryService:GetByDateRange`, which sat unused for an entire prior pass before `ProgressSummaryService` became its first real consumer). Deleting working, correct getters because nothing happens to call them yet is not the same discipline as removing `PlayerModule`, which had a live Settings UI actively misleading players about a feature that doesn't do anything.
- `NotificationService:GetHistory(count)` vs. `ActivityHistoryService`/`MilestoneService`'s `GetRecent(count)` for the same "most recent N" shape — a real, minor naming inconsistency, not renamed this pass since it would touch a live call site (`Home.lua`) for a purely cosmetic gain.
- `DashboardCard`'s still-missing `Enable`/`Disable`/`Destroy`/`SetEnabled` (a longstanding backlog item) and the `SetTooltip`/`SetEnabled` duplication across all 7 `BaseWidget`-derived widgets — both re-confirmed as real, both left as tracked backlog debt rather than risked this late in a polish-only pass; both are architecture changes, not polish.
- `CharacterModule`/`InventoryModule` each independently calling `GetAverageItemLevel()` for overlapping item-level data, and `MythicPlusModule:GetDashboardSummary()`/`RunTracking.itemLevelAtStart` (both confirmed unread) — real findings, left as backlog items rather than risking an ownership change to gameplay modules this late in a polish sprint whose own brief says "do not expand scope."

---

### 1.10 Live Verification & Framework Hardening Sprint

Not a new gameplay system — an extension of the Blizzard API Verification Workflow (which had covered Weekly/Storage/MythicPlus) to the remaining modules (Character, Inventory, Achievements, Progress, Recommendation Engine, Notification Service, Milestone Service, Developer Panel itself), plus permanent tooling (`VerificationService`, see 1.8 above) so this is no longer a one-off documentation exercise. Every API this addon calls is now classified, cited, and queryable in-game.

**Real bugs found and fixed:**
- `AchievementsModule:RefreshCompletedAchievements()`'s hardcoded `for achievementID = 1, 20000` loop was confirmed stale — real achievement IDs already exceed 20000 (Wowhead's own achievement page for ID 42045 is a real current-expansion achievement) — meaning the module silently never discovered any achievement above that ceiling, including the entire current expansion's. Fixed to match Blizzard's own Achievement UI enumeration pattern (`GetCategoryList` → `GetCategoryNumAchievements` → `GetAchievementInfo(categoryID, index)`) rather than a magic number. See 1.3.
- `CharacterModule.lua` called the global `GetSpecialization()`/`GetSpecializationInfo()`, both confirmed deprecated since Patch 11.2.0. Migrated to `C_SpecializationInfo.GetSpecialization()`/`GetSpecializationInfo()`, confirmed to return identical values in the same order. See 1.1.
- `DeveloperPanel:CopyCurrentTab`'s "Copy Summary" mode assumed every tab's summary lines were plain strings; the Live API tab has always stored colored lines as `{text=...}` tables, so clicking Copy Summary there would throw a Lua error. Fixed by normalizing either shape before `table.concat`. See 1.8.

**Confirmed-nonexistent APIs removed, not patched:** `C_Hearthstone.GetHearthstone` and `C_PlayerInfo.GetAccountGUID` are both absent from Blizzard's own generated API documentation and from Warcraft Wiki's full API index — fabricated (predating this session's research tooling) and already confirmed dead (their fields, `hearthstoneItemID`/`warband.accountGUID`, were never read anywhere). Removed entirely from `CharacterModule.lua`. See 1.1.

**Confirmed clean, no changes needed:** `InventoryModule.lua` (`C_Container.*`, `Enum.BagIndex.ReagentBag`, `GetRepairAllCost`'s merchant-window gating), `AchievementsModule.lua`'s `GetAchievementInfo` field order, and every framework service audited (`ProgressSummaryService`, `RecommendationEngine`, `MilestoneService`, `BriefingService` compute nothing from Blizzard APIs directly — confirmed via repo-wide grep — `NotificationService`'s only direct call, `C_Timer.NewTicker`, is foundational and stable).

**Still Needs Live Verification (all three now specific, reproducible, and tracked in `VerificationService`'s registry — see the Developer Panel's Checklist tab for the exact in-game scenario for each):**
- `ach.categoryEnumeration` — `GetCategoryNumAchievements`'s `includeAll` parameter semantics aren't documented on Warcraft Wiki; `true` is passed on a reasonable but unconfirmed assumption.
- `storage.bankerInteraction` — `Enum.PlayerInteractionType.Banker` and the `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` payload shape were not researched this pass; lowest-confidence entry in the registry.
- `mp.eventOrdering` — the relative firing order of the 7 registered Challenge-Mode/Mythic-Plus events during a real run remains unconfirmed; confirming an event exists is not the same as confirming when it fires.

---

### 1.11 Player Journal & Community Notes

The first flagship *new gameplay system* since v1.0 Polish began — a local database of players you've grouped with in Mythic+ (identity, objective stats, personal notes, personal tags, a bounded timeline), plus an optional, disabled-by-default Community Notes layer. Audited and designed (Plan Mode, with the user resolving two genuine open risks directly) before any code was written, per the feature's own brief.

#### The deliberate decision Section 1.4 deferred

Section 1.4's own Future Extension Points entry on "Party composition" explicitly deferred storing facts about other players, reasoning that full named specs would need the heavier `NotifyInspect`/`INSPECT_READY` path, and that "this needs a deliberate decision before any code is written here, not a default." That deferral was scoped to `MythicPlusModule` specifically — `RunTracking` there remains entirely self-only, unmodified by this feature. The deliberate decision is made here instead, in a **new** module: `PlayerJournalModule` becomes the one new owner of party-member facts (Architectural Rule 1 — one owner per fact), using only basic roster reads (`UnitFullName`/`UnitGUID`/`UnitClass`/`UnitGroupRolesAssigned`) and a narrowly-filtered `COMBAT_LOG_EVENT_UNFILTERED` (`UNIT_DIED`/`SPELL_INTERRUPT`, roster members only) — never the full-inspect path that was the actual thing being avoided.

#### PlayerJournalModule (`Modules/PlayerJournal/PlayerJournalModule.lua`)

**Storage scope:** `DatabaseService:GetGlobal().PlayerJournal` — account-wide, not per-character and not a `ConfigurationManager` profile. `ConfigurationManager` is profile-backed (shareable across characters via profile-switching, wrong for private data about other players); `ActivityHistoryService`'s own per-character storage exists because a *run* happened to a specific character, but recognizing a past companion is a fact about the account/person playing, not about which alt was logged in — the same reasoning this addon's own `VerificationService` already established for its account-wide `VerificationLog`/`ChecklistLog`.

**Player key:** `"Name-Realm"`, dash-separated — deliberately the opposite format from `DatabaseService:GetCharacterKey()`'s `"Realm.Name"`, so a companion's key can never be visually confused with one of your own character keys.

**Run-tracking event flow:** `CHALLENGE_MODE_START` snapshots the party roster (self excluded); `GROUP_ROSTER_UPDATE` runs a grace-period leave check (a roster member missing for 5 seconds, with the run still active, is marked left-early — an addon-side heuristic, not a documented Blizzard behavior, flagged `pj.rosterLeaveDetection`); a run-scoped, pcall-registered `COMBAT_LOG_EVENT_UNFILTERED` tallies `UNIT_DIED`/`SPELL_INTERRUPT` for roster GUIDs only (mirroring `MythicPlusModule`'s own defensive-registration and player-only-filtering precedent, just applied to roster members too); `CHALLENGE_MODE_COMPLETED_REWARDS` snapshots this module's own state, then defers the actual finalization one frame via `C_Timer.After(0, ...)`.

**Why the one-frame defer:** confirmed by reading `Core/Events/EventManager.lua`'s own `DispatchBlizzard` — listeners for the same event fire in registration order, itself a function of `.toc`/`ModuleManager.Order` load order. Relying on "`MythicPlusModule`'s handler happens to run first" would be exactly the kind of silent, breakable coupling this document already warns against elsewhere. A timer (even 0-delay) only ever fires on `OnUpdate`, strictly after the current frame's event-dispatch loop fully completes — so by the time `FinalizeCompletedRunForRoster` runs, `MythicPlusModule:RecordCompletedRun()` has already appended its `ActivityHistoryService` record regardless of registration order. Correct by inspection of this addon's own code; flagged `pj.eventOrderingDefer` since it hasn't been watched happen in a real client.

**Reuse, not duplication (Architectural Rule 7):** dungeon/level/timed/rating-change facts are read from `MythicPlusModule:GetRecentRuns(1)` — the same public getter the Dashboard already uses — never recomputed. "Average Rating Gain" per companion is therefore the run's overall score change applied identically to every roster member present, not a true per-player Blizzard stat (none exists); documented inline rather than presented as if it were player-specific.

**Pruning:** Favorites (`tags["FavoritePlayer"] == true`) are exempt from both the hard cap (`maximumStoredPlayers`) and inactivity auto-pruning — the one thing the feature's own brief explicitly calls out as protected.

#### CommunityModule (`Modules/Community/CommunityModule.lua`)

Fully independent of `PlayerJournalModule` — its own top-level storage key (`DatabaseService:GetGlobal().PlayerJournalCommunity`, never nested under `PlayerJournal`'s own table), its own `ConfigurationManager` namespace (`"Community"`), its own Settings page. This file never references `PlayerJournalModule` at all; notes are keyed by the same `"Name-Realm"` format as a shared convention, not a dependency. This independence is what makes "`PlayerJournalModule` works perfectly with `CommunityModule` disabled" a structural fact rather than a currently-true one that could silently regress.

Disabled by default. Fully local this version — no sync backend, no server, no addon-channel broadcast exists yet, so a Community Note is only ever visible to the account that wrote it regardless of its own `visibility` field (captured now for a future backend, zero rendering effect today — documented inline so it isn't mistaken for a bug). Helpful/Not Helpful/Report/Hide are real functions with real local counters, but the UI controls that call them are disabled with a "Coming soon" tooltip rather than clickable — a clickable vote/report button implying real crowd feedback exists would misrepresent a fully local stub.

#### PlayerJournalWindow (`Core/UI/PlayerJournal/`)

A spine (`PlayerJournalWindow.lua`) plus one file per tab under `Tabs/` — the same split `Dashboard.lua` uses for `Pages/*.lua`, not `DeveloperPanel.lua`'s single-file-many-methods shape, since Personal/Community Notes need real editable widgets (multi-line `EditBox` via `InputScrollFrameTemplate`, tag toggle grids, `StaticPopupDialogs` wiring) — Dashboard-page-scale complexity, not read-only-fact-dump scale. Seven tabs: Overview, History, Statistics, Personal Notes (also hosts the Personal Tags toggle grid — no dedicated Tags tab exists in the window's own 7-tab list, and tags are subjective/personal data like notes), Community Notes, Timeline, Search.

`Show(playerKey)` takes a stable id, not a live object — a deliberate divergence from `RecommendationInspector:Show(recommendation)`, which takes a live object specifically because Recommendations are rebuilt from scratch every refresh with no stable identity. Journal records have a real stable identity (`"Name-Realm"`), so re-reading by id on every tab switch/refresh is both correct and simpler.

**Statistics tab** uses a cool blue accent color, visually distinct from Personal Notes/Tags' own warm gold accent elsewhere in the window — per the feature's own requirement that objective statistics always read as visually separate from personal opinion.

**End-of-run prompt:** `PlayerJournalModule` fires a new framework event, `PLAYER_JOURNAL_RUN_RECORDED` (added to `EventManager.FrameworkEvents`), rather than calling `StaticPopup_Show` directly — the same "service/module fires, UI listens" split `NotificationService`'s own `NOTIFICATION_CHANGED` already established. `PlayerJournalWindow` is the intended listener, opening on the Search tab pre-filtered to that run's roster.

#### First Blizzard-UI hooks (`Core/UI/PlayerJournalContextMenu.lua`, `Core/UI/PlayerJournalTooltip.lua`)

This addon's first hooks into Blizzard-owned UI frames — confirmed via repo-wide grep before writing either file that zero existing precedent existed anywhere else in the codebase (every prior `GameTooltip` usage was this addon's own frames showing the standard tooltip widget, never modifying Blizzard's own tooltip-population pipeline or a unit context menu).

**Context menu:** `Menu.ModifyMenu(tag, callback)` — the current, post-Dragonflight menu API (confirmed via Warcraft Wiki's own Blizzard Menu implementation guide). Calling `:CreateButton()` again on the element `:CreateButton()` just returned promotes it to a submenu automatically — exactly one "Azeroth Companion" entry added to Blizzard's own menu, matching the feature's own "keep the Blizzard context menu clean" requirement. The exact `MENU_UNIT_*` tag name for "any party member regardless of slot" could not be pinned down without a live client (the wiki confirms the `MENU_UNIT_<UNIT_TYPE>` format with `PARTY1` as one example, not whether a slot-independent tag also exists) — registered defensively against every plausible tag, each in its own `pcall` so one bad tag name never breaks the others (a `Menu.ModifyMenu` registration for a tag that never fires is a harmless no-op, unlike `RegisterEvent` on a nonexistent event, which throws). Flagged `ctxmenu.unitMenuTags`. Nothing else in this feature depends on this hook succeeding — the window opens via the minimap icon, slash command, and Dashboard regardless.

**Tooltip:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, callback)` — the current, standard tooltip-extension technique (confirmed via real published addon source), superseding the legacy `OnTooltipSetUnit` script hook. Gated on one master "Show Journal Info in Tooltips" setting; adds only lines with real data (Runs Together, Last Seen, a note preview, a Favorite glyph, a Community Note count) and renders nothing at all for a player with no journal record.

#### Explicitly NOT built this version

- **Export/Import Personal Notes** — Settings buttons exist (visible, correctly labeled "Coming in a future update") but are inert; `SettingsManager`/`ContentPanel.lua` has no `enabled=false`-at-creation support for a settings-page button today, so these render clickable rather than grayed — a real, minor, documented framework gap, not extended for two stub buttons.
- **Community Notes sync/voting/reporting backend, Trusted Sources** — structural stubs only, per the feature's own brief ("no backend implementation required yet").
- **Rich text formatting** in Personal/Community Notes — this addon has no rich-text framework; notes are plain multi-line text (`EditBox:SetMultiLine(true)` via `InputScrollFrameTemplate`), not a fabricated formatting toolbar.

### 1.12 Companion Intelligence vNext

A cross-cutting personalization pass across `RecommendationEngine` and the Companion Intelligence V4 services, plus the first integration of `PlayerJournalModule` (Section 1.11) into the rest of the addon. Preceded by a full audit of 13 files; the audit's most important finding was architectural, not additive: `RecommendationEngine:Refresh()` rebuilds `self.Recommendations = {}` from scratch every call (by design, per its own header), so nothing about a recommendation could persist across refreshes. Three of this pass's goals (History, an extended Inspector, a new Statistics page) needed that fixed first.

**Skeptical pass on the brief's own examples:** several illustrative examples in the original request are not honestly buildable from data that exists anywhere in this addon — login-day patterns and vault-completion-day patterns (nothing records login events or historical per-week vault outcomes; `ProgressSummaryService`'s own header already declined the vault one for the same reason), "repairs before raid" (no raid concept exists in this addon at all), and "carries 40 potions" (only consumed-during-run is recorded, never carried-in). These were skipped rather than faked; "typically uses N potions per run" (real, via `averageConsumablesPerRun` below) is the honest substitute actually built.

#### Recommendation identity (`Core/Intelligence/RecommendationEngine.lua`)

Every `EvaluateInsight` branch and `MergePreparationGroup`'s merged candidate now carries a stable, English, code-level `id` (e.g. `"CompleteYourKeystone"`) alongside its existing `title` — deliberately not the `title` itself, since `title` is resolved through `AC.L:Get` and this addon supports runtime language switching (`LocalizationService`); keying persisted history by locale-dependent text would silently orphan it on a language change. `RecommendationEngine` itself gained no new statefulness — it stays exactly the rebuilt-every-refresh pipeline its own header already documents; `id` is just one more field on an already-ephemeral table.

#### RecommendationHistoryService (`Core/Services/RecommendationHistoryService.lua`)

The one new stateful sibling service (same shape as `MilestoneService`: own lifecycle, own lazily-created `DatabaseService:GetCharacter().RecommendationHistory` field, reads `RecommendationEngine`'s already-public `GetRecommendations()` only — Rule 6 pattern, never a new gameplay judgment). Tracks, per recommendation `id`: first/last shown, `timesShown` (distinct **cycles**, not raw refreshes — see below), `timesCompleted`/`timesNotAcknowledged` (both *inferred* from the recommendation disappearing between refreshes), `timesDismissed` (the one *certain* signal — an explicit player click), a capped `scoreHistory`.

**Cycle mechanics:** each `id` maps (via a small fixed `CYCLE_FINGERPRINT_FIELDS` table, same "documented keyed exception list" convention as `NOTIFICATION_TYPE_BY_INSIGHT_TITLE`) to the `recommendation.data` fields that make a *new* instance of it — e.g. `dungeonID`/`level` for `CompleteYourKeystone`. The same fingerprint reappearing across refreshes updates `lastShown` only; a changed fingerprint increments `timesShown`; an active cycle's `id` going absent resolves it (completed/not-acknowledged/already-dismissed). This is what lets a recommendation honestly disappear and reappear across weeks (a new keystone) without either permanently suppressing it or inflating counts every time the Dashboard window happens to redraw.

**Honesty requirement (binding on every UI surface that reads this service):** "Completed"/"Not Acknowledged" are inferred from disappearance, never proof the underlying gameplay action happened — every label built from them reads "Likely Completed"/"Not Acknowledged," never a bare "Completed" claim. `RecommendationInspector:Show()` calls `MarkAcknowledged(id)` (opening the Inspector is the one real, observable "the player looked at this" signal available); the new Dismiss buttons (Recommendations page rows, Home's Highest Priority card) call `DismissRecommendation(id)`.

**Dismiss is presentation-layer filtering, not a new engine concept:** `Sections.lua`'s new `Dashboard:FilterDismissedRecommendations()` reads each recommendation's history record and excludes any with `dismissedThisCycle == true` from whatever's about to render — `RecommendationEngine` itself never learns a recommendation was dismissed and keeps generating it every refresh (the underlying situation is still real and true); a dismissed recommendation reappears the moment its cycle genuinely changes, never permanently.

#### SessionNotesService (`Core/Services/SessionNotesService.lua`) — Home's "Today's Companion Notes"

Same shape as `BriefingService`: selects/orders already-real, session-relative facts, computes nothing itself. Sources: `AchievementsModule:GetSessionSummary()` (pre-existing), `MythicPlusModule:GetSessionSummary()` (new — added specifically so this service never reads `mythicPlusModule.Session` directly, an ownership violation caught in this pass's own self-review), `WeeklyModule:GetSlotsGainedThisSession()` (new, extracted from that module's own existing `Session.initialUnlockedSlots` comparison so the calculation exists in exactly one place). Says "This session," never "last session" — nothing in this addon persists a previous session's summary; claiming otherwise would misrepresent current-session data as being about a session that already ended (a true "last session" feature is logged in `docs/DEVELOPMENT_BACKLOG.md` as a future item requiring new persistence).

#### PlayerJournal → RecommendationEngine (Goal 6)

`PlayerJournalModule` gained `GetCurrentPartyJournalMatches()` — reuses its own existing `SnapshotRoster()` (already used for run tracking, no dependency on run-tracking state, safe to call anytime), returns journal data only for roster members who already have a record (never fabricated). `RecommendationEngine`'s `"Keystone Ready"` branch reads it (the same Rule 6 cross-module-evidence pattern already used there for Character/Weekly/Storage/Inventory) and attaches one display-only `supportingEvidence` entry per match — deliberately **not** added to `sourceModules` (that list drives `RecommendationInspector`'s clickable "Contributing Modules" buttons, each of which navigates to a Dashboard page; `PlayerJournal` has no Dashboard page, so it would be a dead click) and **no** `scoreFactor` is set from it, per the brief's "never auto-generate opinions" — display only.

#### Statistics page (`Core/UI/Dashboard/Pages/Statistics.lua`)

Follows `Pages/Progress.lua`'s exact template. Aggregates `RecommendationHistoryService:GetAllHistory()` in-page (presentation-layer summation over an already-real per-id list, the same category of thing `Progress.lua` already does for its own season/lifetime sums) into total generated/completed/dismissed/not-acknowledged, average time-to-resolve, and a per-category breakdown. Registered in `Layout.VALID_PAGES`, `Navigation.lua`'s dispatch chain, and a new Home entry card mirroring the existing Progress card.

#### Consolidation (Goal 9 polish)

`MythicPlusModule:BuildStatisticsFromRecords` now computes `averageConsumablesPerRun`/`averageInterruptsPerRun` directly (Rule 7 — one calculation, not the two `ProgressSummaryService` used to compute locally via now-deleted `ConsumablesPerRun`/`InterruptsPerRun` helpers); `RecommendationEngine.lua`'s locally-duplicated `FormatDuration` was removed in favor of `AC.DashboardFormat.FormatClock` once Statistics' own average-completion-time stat gave that formatting a third real call site, the threshold the file's own prior comment had named as the reason to eventually share it. A pre-existing, unrelated Settings-page `order = 60` collision between `PlayerJournalModule` and `StorageModule` (found while adding `NotificationService`'s own new page nearby) was fixed alongside this work.

---

## 2. Planned Modules

These are architectural placeholders. Nothing below authorizes writing code — each one requires its own dedicated Blizzard API audit (matching the rigor already applied to the modules above and to the Warband investigation) before implementation begins. Namespaces marked *(confirmed)* were verified against Blizzard's own documentation this design cycle; namespaces marked *(unverified)* are named from general knowledge only and must be independently confirmed before any module design work starts on them.

### 2.1 Reputation

#### Purpose
Owns all faction standing, including Renown, regardless of whether a given faction happens to be character-scoped or account-wide.

**Current state:** Renown (`C_MajorFactions`) is read by `AccomplishmentsModule` today, deliberately, as a temporary exception (see section 1.3) — the Accomplishments redesign needed "expansion progress" data and this Reputation module doesn't exist yet. If this module is ever built, Renown ownership should move here, and `AccomplishmentsModule`'s `RefreshRenownProgress`/`GetRenownProgress` should be deleted in favor of reading this module's own getter instead.

#### Intended ownership
A dedicated module — not Character, not Warband. Renown (`C_MajorFactions`) is a sibling system to standard faction reputation in Blizzard's own API structure, not a Warband-specific concept; the fact that some major factions are flagged account-wide is a property of that faction entry, not a reason to split ownership across two modules.

#### Candidate Blizzard API namespaces
`C_MajorFactions` *(confirmed)*: `GetMajorFactionIDs`, `GetMajorFactionData`, `GetCurrentRenownLevel`, `HasMaximumRenown`, `IsWeeklyRenownCapped`. Base reputation API (`C_Reputation`/`GetFactionInfo` family) *(unverified this cycle — confirm function names before implementation)*.

#### Example Dashboard information
Reputation page listing tracked factions with standing/renown level; Home card summarizing factions near a cap or reward.

#### Possible Insights
"Weekly Renown Capped", "Faction Paragon Ready."

#### Possible Recommendations
"You've capped this faction's weekly renown — turn in elsewhere."

#### Out of Scope
Faction group (Alliance/Horde) — that stays in Character, as basic identity, not progression.

---

### 2.2 Currency

#### Purpose
Owns all currencies except gold.

#### Intended ownership
A dedicated module. Gold remains in Character deliberately — not because gold is conceptually different from other currencies, but because Character already correctly owns it today, and moving it would be an unjustified change to a working module. Every other currency, character-scoped or account-wide, belongs here for the same reason Renown belongs to Reputation rather than Warband: the account-wide/character-scoped split is a property of the currency, not a reason to split the module.

#### Candidate Blizzard API namespaces
`C_CurrencyInfo` *(confirmed namespace exists; specific function list not exhaustively verified this cycle)*.

#### Example Dashboard information
Currency page or Home-card summary of currencies near their weekly cap.

#### Possible Insights
"Currency Near Weekly Cap."

#### Possible Recommendations
"Spend this currency before it caps."

#### Out of Scope
Gold (Character). Warband Bank's deposited gold specifically (Warband module — a bank balance, not a currency-tracking concept).

---

### 2.3 Warband

**Scope narrowed by Storage's implementation (Section 1.7):** Storage now owns Warband Bank *item contents* (read for restock/preparation purposes, decided explicitly before Storage was implemented, since no Warband module existed yet to conflict with). What remains here, if this module is ever built, is administrative: the bank's own gold balance and tab-purchase state — not item contents.

#### Purpose
Owns the Warband Bank's gold balance and tab-purchase administration. Not "anything account-wide," which would make this a dumping ground rather than a clean domain, and not item contents, which is Storage's concern (1.7).

#### Intended ownership
A dedicated module, scoped narrowly. Renown and non-gold currency, despite also being account-wide in some cases, belong to Reputation and Currency respectively (see above); Warband Bank item contents belong to Storage (1.7) — Warband, if built, would own only the bank's gold balance and how many tabs are purchased/available.

#### Candidate Blizzard API namespaces
`C_Bank` *(confirmed)* — `CanUseBank`, `FetchDepositedMoney`, `FetchNumPurchasedBankTabs`, `HasMaxBankTabs`, parameterized by `Enum.BankType.Account`. (`FetchPurchasedBankTabIDs`/`FetchPurchasedBankTabData` and item contents are Storage's, not this module's, per the scope narrowing above.)

#### Example Dashboard information
A small Home-adjacent fact ("Warband Bank: 12,450g", tab count) — likely folded into an existing page rather than warranting its own, given how little remains in scope.

#### Possible Insights
None considered reliable — the bank's availability is too situational (gated by physical proximity or a time-limited spell) for a trustworthy insight trigger, consistent with the dedicated Warband API audit's conclusion.

#### Possible Recommendations
None, for the same reason.

#### Out of Scope
Renown (Reputation). Non-gold currency balances in general (Currency) — only the bank's own deposited gold is Warband's concern. Warband Bank *item contents* (Storage, implemented — 1.7). Character Bank item contents (also Storage, 1.7, not Inventory — bags and banks are distinct Blizzard systems, per Inventory's own "Explicitly NOT responsible for").

---

### 2.4 Professions

#### Purpose
Owns known recipes, crafting cooldowns, and work orders.

#### Intended ownership
A dedicated module — professions are a large, self-contained Blizzard system with their own UI, not a natural extension of any existing module.

#### Candidate Blizzard API namespaces
`C_TradeSkillUI` *(confirmed namespace exists; full function list not exhaustively verified this cycle)*.

#### Example Dashboard information
Professions page: known professions, recipe cooldowns, pending work orders.

#### Possible Insights
"Profession Cooldown Ready."

#### Possible Recommendations
"Craft or queue an order before reset."

#### Out of Scope
Reagent *possession* (Inventory owns bag contents; Professions may read that data through Inventory's public API when checking craftability, but never re-scans bags itself — see Architectural Rules, "never duplicate logic").

---

### 2.5 Collections

#### Purpose
Owns transmog, mounts, pets, and toys.

#### Intended ownership
A dedicated module.

#### Candidate Blizzard API namespaces
`C_TransmogCollection`, `C_MountJournal`, `C_PetJournal`, `C_ToyBox` *(all unverified this cycle — general knowledge only, confirm before implementation)*.

#### Example Dashboard information
Collections page: completion counts per category.

#### Possible Insights
Low-frequency at best ("New Collectible Available").

#### Possible Recommendations
Weak fit — largely completionist browsing, not actionable content.

#### Out of Scope
Achievement tracking of collection milestones (Achievements owns achievement completion, even when the achievement is collection-themed).

---

### 2.6 Raids

#### Purpose
Owns raid lockout, saved-instance, and attendance state.

#### Intended ownership
A dedicated module — **pending its own API audit**. Not designed further here.

#### Candidate Blizzard API namespaces
`GetSavedInstanceInfo` and related lockout functions *(unverified this cycle)*.

#### Example Dashboard information
TBD — pending audit.

#### Possible Insights
TBD — pending audit.

#### Possible Recommendations
TBD — pending audit.

#### Out of Scope
Great Vault raid-activity thresholds (Weekly module reads Blizzard's own aggregate).

---

### 2.7 PvP

#### Purpose
Owns PvP rating, honor, and season progress.

#### Intended ownership
A dedicated module — **pending its own API audit**. Not designed further here.

#### Candidate Blizzard API namespaces
`C_PvP` *(unverified this cycle)*.

#### Example Dashboard information
TBD — pending audit.

#### Possible Insights
TBD — pending audit.

#### Possible Recommendations
TBD — pending audit.

#### Out of Scope
Great Vault PvP-activity thresholds (Weekly module reads Blizzard's own aggregate). Honor as a currency (Currency module, if Blizzard exposes it through `C_CurrencyInfo`; confirm during PvP's own audit rather than assuming).

---

### 2.8 Delves

#### Purpose
Owns Delve progress, companion state, and related weekly content.

#### Intended ownership
A dedicated module — **pending its own API audit**. This domain has the least verified grounding of any planned module; do not begin implementation without first completing a dedicated audit of the same rigor as the Warband investigation.

#### Candidate Blizzard API namespaces
Unconfirmed this cycle — likely spans quest-log APIs and a dedicated currency, neither confirmed.

#### Example Dashboard information
TBD — pending audit.

#### Possible Insights
TBD — pending audit.

#### Possible Recommendations
TBD — pending audit.

#### Out of Scope
Nothing can be scoped out yet without first scoping in what this module actually owns.

---

## 3. Architectural Rules

These rules govern every module, existing or planned. They are not suggestions — a change that violates one of these needs to revisit the architecture first, per the project's stated philosophy, not route around it.

1. **Gameplay data has exactly one owner.** If two modules could plausibly own the same fact, that is a signal to stop and resolve the ambiguity (see Section 5, Decision Tree) before writing code — not to pick one arbitrarily or split it across both.
2. **The Dashboard never gathers gameplay data directly.** It never calls a Blizzard API itself. Every value shown anywhere in the Dashboard traces back to a gameplay module's public API.
3. **Modules never read Dashboard state.** Data flows one direction: module → Dashboard. A module's behavior must never depend on whether the Dashboard is open, which page is active, or any other presentation-layer state.
4. **Modules expose public APIs; the Dashboard consumes them.** A module's internal tables (its `Profile`/`Session`/cache structures) are never read directly by the Dashboard or by any other module — only through explicit `Get*`/`Is*` accessor functions.
5. **Insights are generated by modules, not by the Dashboard or by each other.** Each module's `GetInsights()` is the only place that module's raw state becomes a player-facing "something noteworthy happened" signal.
6. **A recommendation's trigger and priority always come from an Insight, never from raw module state.** RecommendationEngine decides *whether* and *how urgently* to recommend something only by matching on what `GetInsights()` produced — it never invents a new trigger by polling a module directly. **Narrow, deliberate exception (RecommendationEngine V2 — see "Companion Intelligence" under 1.4):** once a recommendation's trigger is established from an Insight, RecommendationEngine may read *other* modules' already-public fact getters (`GetProfile()`, `GetSeasonStatistics()`, ...) — the same getters Dashboard already calls directly — purely to attach read-only supporting evidence and scoring factors to that recommendation. This is a fact lookup, never a new gameplay judgment, and every fact read this way is already a public getter used elsewhere. This exception does not extend to Insights: `InsightEngine`/each module's `GetInsights()` are unchanged by it.
7. **A module may read another module's public API, but never its internal state, and never to duplicate logic the owning module already provides** (e.g., Professions may ask Inventory "do I have this reagent?" through Inventory's public API; it never re-implements bag scanning itself).
8. **Configuration is never gameplay data.** Settings, toggles, and preferences live in `ConfigurationManager`; a module's `Profile`/session data never doubles as a place to store a user preference, and vice versa.
9. **ConfigurationManager is the single source of truth for all settings**, read and written only through its public API — never a raw SavedVariables table accessed directly by a module or by the Dashboard.
10. **Localization never changes gameplay logic.** `AC.L:Get()`/`AC.L:Format()` affect display text only; no module's behavior, thresholds, or data collection may vary by active locale.
11. **Services own cross-cutting functionality that no single gameplay module should own** (event dispatch, widget creation, window management, settings workflow, localization) — a capability needed by multiple modules belongs in a service, not copied into each module that needs it.
12. **A new Blizzard API namespace is evaluated against existing and planned module ownership before any code is written** (see Section 5). It is never implemented inside whichever module happens to be open in the editor at the time.
13. **Account-wide scope is a property of data, not a reason to create or choose a module.** (See the Renown and Currency ownership resolutions above — the existence of an account-wide variant of a system does not mean it belongs to Warband.)
14. **A module never depends on another *planned* module's data existing.** WeeklyProgress reads Blizzard's own aggregate rather than depending on MythicPlus (implemented) or the planned Raids/PvP modules; this pattern — prefer Blizzard's own aggregation over inventing cross-module dependencies — applies generally.
15. **When ownership is unclear, implementation stops.** The correct response to an ambiguous new API is to revisit this document, not to guess.

---

## 4. Data Ownership Matrix

| Gameplay Data | Owner Module | Dashboard Page | Insight Source | Recommendation Source |
|---|---|---|---|---|
| Character Identity (name, race, class, GUID) | Character | Profile | — | — |
| Specialization | Character | Profile | — | — |
| Level / Progression / Rested XP | Character | Profile, Home | Character | Character |
| Equipped / Average Item Level | Character | Profile, Home | Character | Character |
| Guild / Faction Group | Character | Profile | — | — |
| Gold | Character | Profile | — | — |
| Played Time / Session Stats | Character | Profile | Character | Character |
| Bind Location / Hearthstone Item Set | Character | Profile *(collected, not yet surfaced)* | — | — |
| Zone / Subzone / Travel | Character | Profile | — | — |
| Bag Space | Inventory | Inventory, Home | Inventory | Inventory |
| Equipment (equipped/empty slots) | Inventory | Inventory | — | — |
| Equipment Durability | *Unowned — real gap, would extend Inventory* | Inventory *(future)* | Inventory *(future)* | Inventory *(future)* |
| Hearthstone Possession | Inventory | Inventory | Inventory | Inventory |
| Repair Status | Inventory | Inventory | Inventory | Inventory |
| Signature Accomplishments (curated, points, completion, recent) | Accomplishments | Accomplishments, Home | Accomplishments | Accomplishments |
| Campaign Completion | Accomplishments *(deliberate exception -- not achievement data, see 1.3)* | Accomplishments | — | — |
| Renown | Accomplishments *(owned here temporarily -- see 1.3 and 2.1)* | Accomplishments | — | — |
| Per-Criterion Achievement Progress | *Unowned -- real gap, would extend Accomplishments (see 1.3)* | Accomplishments *(future)* | — | — |
| Legacy Accomplishments (curated historical list) | *Unowned -- no Blizzard signal, needs a maintained list (see 1.3)* | Accomplishments *(future)* | — | — |
| Great Vault | Weekly | Home | Weekly | Weekly *(+ read as cross-module evidence by RecommendationEngine's "Complete Your Keystone")* |
| Reputation (standard) | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* |
| Renown | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* |
| Currencies (non-gold) | Currency *(planned)* | Currency *(planned)* | Currency *(planned)* | Currency *(planned)* |
| Warband Bank (gold balance, tabs) | Warband *(planned, narrowed scope — see 2.3)* | *(planned)* | — *(unreliable trigger, see 2.3)* | — |
| Bank / Reagent Bank / Warband Bank (item contents) | Storage | Storage, Home | Storage | Storage *(+ read as cross-module evidence by RecommendationEngine's "Complete Your Keystone")* |
| Storage Profiles / Rules | Storage | Storage (Settings dropdown for selection) | — | — |
| Mythic+ Keystone / Rating / Best Runs / Season | MythicPlus | Mythic+, Home | MythicPlus | MythicPlus *(RecommendationEngine also reads Character/Weekly/Storage directly for cross-module supporting evidence — see Rule 6)* |
| Player Journal (companion identity/stats/notes/tags/timeline) | PlayerJournal | Player Journal Window *(standalone, not a Dashboard page)* | PlayerJournal | PlayerJournal *(+ read as display-only cross-module evidence by RecommendationEngine's "Complete Your Keystone" — see 1.12)* |
| Community Notes | Community | Player Journal Window (Community Notes tab) | — | — |
| Recommendation History (shown/completed/dismissed counts, score history) | RecommendationHistoryService | Statistics, Recommendation Inspector | — | — *(presentation-layer state about recommendations, not gameplay data itself — see 1.12)* |
| Session Notes (this-session runs/achievements/vault gains) | SessionNotesService | Home ("Today's Companion Notes") | — | — |
| Professions (recipes, cooldowns) | Professions *(planned)* | Professions *(planned)* | Professions *(planned)* | Professions *(planned)* |
| Collections (transmog/mounts/pets/toys) | Collections *(planned)* | Collections *(planned)* | Collections *(planned)* | — *(weak fit)* |
| Raids (lockouts, attendance) | Raids *(planned, pending audit)* | TBD | TBD | TBD |
| PvP (rating, honor, season) | PvP *(planned, pending audit)* | TBD | TBD | TBD |
| Delves | Delves *(planned, pending audit)* | TBD | TBD | TBD |

---

## 5. Decision Tree

Follow this exactly when a new Blizzard API or gameplay system is discovered. Do not skip a step, and do not write code before reaching a definitive answer.

```
I found a new Blizzard API / gameplay system.

    ↓

Does an existing module already own this gameplay domain?
(Check Section 1 and the Data Ownership Matrix.)

    ├── YES → Add it to that module's public API.
    │          Update this document's Data Ownership Matrix.
    │
    └── NO
         ↓
    Does it naturally belong to a planned module (Section 2)?

         ├── YES, and that module is already implemented
         │        → Add it to that module.
         │
         ├── YES, but that module does not exist yet
         │        → Do not implement it early inside another module.
         │          Wait until that module is built, or bring its
         │          implementation forward deliberately as a scoped
         │          decision — never as an incidental addition
         │          to an unrelated module.
         │
         └── NO — it fits no existing or planned module
                  ↓
             Stop. Do not write implementation code.
             Revisit this document:
               - Is this a genuinely new domain? Add a new
                 "Planned Module" section describing it, following
                 the same audit discipline as every module above
                 (confirm real Blizzard APIs, do not assume).
               - Is it actually a sub-concern of an existing domain
                 that was scoped too narrowly? Correct the module's
                 "Responsibilities" section rather than inventing
                 a new module for one field.
             Only after this document is updated does implementation
             begin.
```

---

## 6. Version Roadmap

### Version 1 (current)
- Existing modules: Character, Inventory, Achievements, MythicPlus, Weekly, Storage.
- Framework: Dashboard, Insight Engine, Recommendation Engine (V2 — see 1.6), Localization, Settings (Save/Cancel), ActivityHistoryService.
- Focus: polish and stabilization of what exists, not new gameplay domains.

### Version 2 — Suggested Implementation Order

| Order | Module | Justification |
|---|---|---|
| 1 | ~~Weekly~~ — **Done.** Implemented (see 1.5): Great Vault slot progress for the Mythic+ activity category. `C_WeeklyRewards`'s exact field shape is unverified against a live client — see 1.5's verification notice. |
| 2 | Reputation | Cheapest remaining module to build and resolves the Renown ownership question this entire architecture exercise was built around — implementing it early keeps that resolution from becoming theoretical. |
| 3 | ~~MythicPlus~~ — **Done.** Implemented (see 1.4): keystone, rating, best runs, active run, weekly affixes, dungeon name, current season, and long-term run history/statistics via `ActivityHistoryService`. |
| 4 | Currency | Cheap once Reputation has already established the "character-scoped + account-scoped side by side" pattern this module reuses; ranked after the higher-engagement modules since its value is more of a glance-at number than actionable weekly content. |
| 5 | ~~Warband~~ *(scope narrowed)* / ~~Storage~~ — **Storage done.** Implemented (see 1.7): bank, reagent bank, and Warband Bank *item contents*, restock analysis, shopping list, and activity-preparation evidence. This absorbed the item-contents portion originally planned for Warband; if Warband is still built later, its remaining scope (gold balance, tab administration only) is small enough that its own bank-gated-availability caveat still applies. |
| 6 | Professions | Real value, especially for crafters, but a substantially larger surface (multiple professions, recipes, reagents, work orders) than anything above — appropriately placed after the smaller, cheaper wins. |
| 7 | Collections | Real but lower-urgency value (completionist browsing, not actionable weekly content); moderate effort. |
| 8 | Raids | Requires its own dedicated API audit before design work can even begin — scheduled after the fully-scoped modules above are done. |
| 9 | PvP | Same audit prerequisite as Raids. |
| 10 | Delves | Least-verified domain in this document; requires the most upfront audit work of any planned module, so it's scheduled last. |

No module on this list is authorized for implementation until its own dedicated API audit (matching the Warband investigation's rigor) confirms the real function names, return shapes, event-vs-poll behavior, and any special UI-state requirements — this document describes *where things belong*, not a green light to build them.

---

## 7. Technical Debt & Completion Sprint

A dedicated audit-then-complete pass over previously-deferred functionality, temporary placeholders, and unused infrastructure, rather than new gameplay domains. Full audit categories (deferred features, placeholders, technical debt, unused infrastructure) were produced before any code changed, per this project's standing "audit first" discipline.

#### What this sprint completed
- **Storage Execute** — real item movement, previously deferred for safety reasons, now implemented with explicit guardrails after re-confirming the trade-off (see 1.7's "Execute" subsection).
- **Storage readiness percentage** — `GetPreparationStatus`/`AnalyzeProfile` gained a deterministic `readinessPercent`, surfaced as a progress bar on the Home page's Mythic+ and Storage cards (Preparation as a first-class Dashboard concept).
- **Weekly Dashboard page** — previously Home-card-only; the Vault Progress card is now clickable and opens a real page.
- **Mythic+ affix name/icon resolution** — `GetAffixDisplayInfo`, previously flagged as "not yet built" despite a confirmed Blizzard namespace, is now implemented.
- **Achievements: recent history + milestones** — `ActivityHistoryService` (generic, already proven by MythicPlus) is now used by Achievements too; two of its four "Future Features" placeholders became real Dashboard sections. The Achievements page also gained Recommendations/Insights sections it never had.
- **Bug fix**: `PROFILE_SECTIONS` had two sections both titled "Character" (a copy/paste error) — split into "Character" and "Guild & Currency".
- **Home page card polish**: Character card now surfaces guild and rested status; Inventory card now surfaces free-slot count and a Storage-status cross-reference (read directly, same pattern as every other cross-module Home card fact).
- **"Last updated" timestamps** — `RecommendationEngine`/`InsightEngine`'s `GetLastRefresh()`, built previously and never displayed, now appears on every dynamic data page via a new generic `Dashboard:UpdateLastUpdatedText(page)` helper (added to `CreateDataPage` itself, so every current and future data page gets it for free).

#### What was deliberately re-scoped, not silently skipped
Two explicit decisions were made before implementation (not assumed): Storage Execute was re-enabled despite its original safety deferral (heavy guardrails applied instead of leaving it deferred), and the remaining scope was prioritized toward high-value/low-risk completions rather than attempting every item the initial audit surfaced in one pass.

#### Prioritized follow-up list (audited, not implemented this pass)
In priority order, highest-value-for-effort first:

1. **Achievements category/expansion breakdown** — needs additional Blizzard category-API surface (`GetCategoryInfo`/`GetCategoryNumAchievements` and similar) not yet audited/verified against a live client. Moderate effort once that audit happens.
2. **A full Storage rule-builder UI** (add/edit/delete rules against items/categories/quality/expansion/groups) — the engine (`MatchesRule`/`AnalyzeProfile`) already supports it; this is pure UI work, but a large surface (item pickers, category/quality dropdowns, group management).
3. **Storage partial-stack splitting during Execute** (`C_Container.SplitContainerItem`) — would let Execute move exact amounts instead of whole stacks; deliberately not introduced this pass to avoid adding a second unverified item-movement API before the first one has been spot-checked in-game.
4. **Inventory: Recent Loot / Interesting Items / Vendor Suggestions** — still genuinely blocked, not a scoping choice: no itemized loot log, no "interesting item" classification heuristic, and no vendor-junk-value data exists anywhere in this addon yet. Would need new data collection, not just new UI.
5. **Profile: Warband Overview** — blocked on the (still narrowly-scoped, still unbuilt) Warband module; see 1.7's ownership resolution and 2.3.
6. **Reputation, Currency, Warband, Professions, Collections, Raids, PvP, Delves** — all still-planned modules per Section 2, unchanged by this sprint. Each needs its own dedicated Blizzard API audit before implementation begins, per Rule 15.

None of the above is blocked by indecision — each has a concrete, stated reason (needs an unaudited API, is pure-but-large UI work, needs new data collection, or is waiting on a sibling module) rather than "postponed because it was postponed."

---

## 8. Presentation Layer

Not a gameplay module — no Data Ownership Matrix entry, no lifecycle (`Initialize`/`Enable`/etc.). `AC.Presentation` (`Core/Presentation/Presentation.lua`) is a generic, addon-wide leaf module for formatting primitives: dates, relative time, numbers/percent/rating/item level, duration/money/clock, semantic colors. Usable by any module or service, not just Dashboard pages.

#### Why this exists
Testing surfaced a real bug: accomplishment/history/milestone dates rendered with no year (`06/23` instead of `Jun 23, 2026`) — a real problem for characters played 10-20 years, where the year is part of the character's story. Auditing the cause found `date("%b %d", ...)` duplicated at 10 separate call sites across the Dashboard, while 11 other sites already correctly included the year — the addon was already visually inconsistent with itself. The same audit found the identical "same concept, duplicated and drifted" pattern for numbers (raw `string.format` at 15+ sites) and semantic colors (success/warning/critical literals at 10+ sites, with confirmed drift — two different greens, two different reds, for the same meaning).

#### What it owns
- `FormatDate(timestamp, style)` — `"short"` (`"Jun 23, 2026"`) / `"shortTime"` (`"Jun 23, 2026  14:05"`, matching the double-space convention `RecommendationInspector.lua`'s own already-correct sites already used). Every style always includes a 4-digit year — this is the actual bug fix.
- `FormatRelativeTime(timestamp)` — a genuinely new capability, not a consolidation: no existing call site reused a shared "time since X" formatter before this. "Today"/"Yesterday"/"N days ago" for under 30 days, falls back to `FormatDate(timestamp, "short")` past that — never a fabricated "N months/years ago" bucket (months have inconsistent lengths; no honest way to round one).
- `FormatNumber`/`FormatPercent`/`FormatRating`/`FormatItemLevel` — one generic implementation (`FormatRating`/`FormatItemLevel` are semantically-named wrappers, since their logic was already identical at every real call site found).
- `FormatNumberWithCommas`/`FormatDuration`/`FormatMoney`/`FormatClock` — moved verbatim from `DashboardFormat`, since they're generic primitives, not Dashboard-specific.
- `GetSemanticColor(name)` (`"success"`/`"warning"`/`"critical"`/`"dim"`/`"highlight"`) — consolidates literals that had already drifted (e.g. two different greens meaning "success" on different pages) into one canonical value per meaning. `HIGHLIGHT_COLOR` is the v1.0 Polish Sprint gold-accent constant, promoted here from `Format.lua`.

#### `DashboardFormat` vs `Presentation` split
`Core/UI/Dashboard/Format.lua` keeps everything that is Dashboard/Recommendation-specific **composed** presentation — `RenderStars`/`PriorityToStars`, `CHECK_SUCCESS`/`CHECK_FAILURE`, `GetTrendArrow` — a real category boundary, not an arbitrary one. `FormatNumberWithCommas`/`FormatDuration`/`FormatMoney`/`FormatClock`/`HIGHLIGHT_COLOR` are now thin backward-compatible aliases pointing at `Presentation`'s versions, so the ~50 pre-existing `AC.DashboardFormat.X(...)` call sites across the codebase keep working completely unchanged — a non-breaking migration, not a rewrite.

#### Migration scope this pass
The 10 confirmed no-year date bugs were fixed (`Rows.lua` ×2, `Pages/Accomplishments.lua`, `Pages/Progress.lua`, `Pages/MythicPlus.lua` ×2, `RecommendationInspector.lua`, `PlayerJournal/Tabs/History.lua`, `DeveloperPanel.lua`, `Pages/Profile.lua`). The 11 already-correct `%Y`-including date sites were **not** touched — a deferred consistency migration, not silently expected to happen for free. 15+ number/percent sites and 10+ color sites were migrated; 3 signed `+/-` number sites (already logged under Technical Debt > Architecture, with a real open `>= 0` vs `> 0` boundary question needing in-game verification) were deliberately left alone rather than silently resolving that open question.

#### Explicitly deferred — zero duplication found, not built as speculative scaffolding
Typography, Icon Styling, Density, Themes, Accessibility, UI Profiles. The addon has exactly one visual treatment throughout, no theming or density mode exists, and nothing currently varies by accessibility need. Building empty namespaces for these now would be designing for a hypothetical future requirement this project's own engineering discipline explicitly avoids — revisit the day there's a real second theme, a real font-scaling requirement, or a real accessibility ask.

#### Presentation System v2 — Phase 1 (Token Consolidation)

A full UX/UI audit (every widget file, every Dashboard page, every satellite window) found real, demonstrated duplication beyond what the first pass above covered: the same semantic meaning (success/critical/dim/"link" accent/bordered-panel backdrop) hand-typed as different literal values across files, a card widget (`DashboardCard.lua`) with its own parallel constant block that never referenced the shared `Layout.lua` design tokens, three independent empty-state implementations, and the same width-remeasure boilerplate hand-copied across 7 page files. This is **Phase 1** of a 3-phase roadmap:

- **Phase 1 (this pass)** — consolidate the confirmed duplication into real tokens. Done.
- **Phase 2 (future, not built)** — promote Dashboard's own presentation primitives (`BeginSection`/`ShowEmptyLine`/`BuildHeroSection`/pooled-row layout, currently `Dashboard:`-namespaced in `Sections.lua`/`Rows.lua`) into a truly shared, addon-wide `PresentationWidgets.lua` that satellite windows (`DeveloperPanel`, `PlayerJournalWindow`) call instead of each hand-rolling their own near-duplicate `LayoutLines`-style helper. This is the real fix for why those windows still read as a slightly different visual dialect from the Dashboard.
- **Phase 3 (deferred, no demonstrated need)** — Themes/Density/Accessibility/UI Profiles/Animations. Same reasoning as the section above: one visual treatment exists, building empty namespaces for a hypothetical future would contradict this project's own "no speculative scaffolding" discipline.

**New tokens added to `Presentation.lua`:**
- `SEMANTIC_COLORS.accent = {0.55, 0.75, 1}` (cool blue) — canonicalizes `PlayerJournal/Tabs/Statistics.lua`'s own already-deliberate "objective statistics get a cool blue, distinct from the gold personal-notes accent" value (that file's own header comment justified it; kept as the source of truth). Two unrelated blues elsewhere migrated to it: `RecommendationInspector.lua`'s link-button blue and `PlayerJournal/Tabs/Overview.lua`'s Tags-section blue — both a real, visible color shift, unifying three unrelated "info/link" blues into one addon-wide meaning.
- `WINDOW_BACKDROP` / `PANEL_BACKDROP` — `WINDOW_BACKDROP` is `BaseWindow`'s prior values verbatim (no change). `PANEL_BACKDROP` is `SettingsWindow`'s `navigationHost` values verbatim; `SettingsWindow`'s `contentHost` panel, which previously disagreed with its own sibling panel (`0.15,0.15,0.15,0.90` vs. `0.10,0.10,0.10,0.90`), now migrates to `PANEL_BACKDROP` — a real, visible darkening that fixes two panels of the same window looking inconsistent with each other.

**`DashboardCard.lua` → `Layout.lua`:** its full padding/gap/icon constant block (`PADDING_*`, `INDICATOR_RESERVE`, `*_GAP` fields, `ICON_SIZE`, `ICON_TITLE_GAP`, `BAR_ANIMATION_DURATION`) moved into `Layout.lua` as `Layout.CARD_*` fields — identical values, pure relocation, zero visual change. This was the single largest "parallel design-token file" violation found: the addon's card widget never referenced its own design-token file at all. Load-order note: `.toc` loads `Widgets/DashboardCard.lua` before `Dashboard/Layout.lua`, so `DashboardCard.lua` reads `AC.DashboardLayout.CARD_X` inline at point-of-use inside `Create()` rather than caching a file-top-level `local Layout` upvalue (which would capture `nil` at load time) — the same load-order-safe pattern already used elsewhere in this codebase.

**Real color migrations to already-existing `success`/`critical`/`dim`/`warning` tokens** (each a visible change unless noted as a pure refactor): `Sections.lua` `ShowEmptyLine`, `DashboardCard.lua` (`SecondaryText`, `SetStatus("Normal"/"Important")`), `Rows.lua` `BuildRecommendationRow` description text, `RecommendationInspector.lua` (`HeaderDescription`, two link-button colors), `PlayerJournal/Tabs/Overview.lua` Tags section, `DeveloperPanel.lua` (Modules stats row, Checklist done label, LiveAPI mismatch row, Full-Registry status row). `PlayerJournal/Tabs/Statistics.lua`'s `StatColor` and `PlayerJournal/Tabs/History.lua`'s "left early" red were both already byte-identical to the canonical token — pure refactors reading from the shared source instead of a second independent literal, zero visual change.

**Left deliberately untouched** (judgment calls, not fixes for a confirmed problem): `DashboardCard.lua`'s Detail Section caption (a deliberately warm tone) and its `SetStatus` else-branch/hover-indicator grays; `DeveloperPanel.lua`'s `LayoutLines` default text color (primary dense-tool content, not a secondary/dim role) and one unaudited metadata-line gray. Logged as future follow-ups, not fixed here — forcing every gray in the addon to converge would have been an unrequested visual change, not a consolidation.

**Empty-state consolidation:** deleted a dead `section.emptyText` branch in `Sections.lua`'s `BuildFieldRows` (confirmed via grep that no schema ever sets it — `AppendFutureFeatures` is what schemas actually use). `Pages/Recommendations.lua`'s "Caught Up" empty state deliberately **keeps** its celebratory `GameFontHighlight`/centered treatment rather than being flattened to match every other page's plain dim empty-state line — being caught up is a genuinely positive, distinct moment. Its two real bugs were fixed instead: an untied gray color (now `GetSemanticColor("success")`) and hardcoded width/height that bypassed real measurement (now routed through real string-height measurement, same as every other dynamic page).

**Width-remeasure consolidation:** new `Dashboard:MeasureAndApplyScrolling(page, scrollChild, measureFn)` in `Sections.lua` replaces a byte-identical "measure at full width, remeasure narrower if it doesn't fit" block that had been hand-copied across all 7 dynamic pages (`Pages/Recommendations.lua`, `Storage.lua`, `Weekly.lua`, `MythicPlus.lua`, `Accomplishments.lua`, `Progress.lua`, `Statistics.lua`) — a behavior-preserving consolidation, not a rewrite.

**`PlayerJournalWindow.lua` title fix:** the window previously created its own separate `GameFontNormalLarge` identity FontString *in addition to* `BaseWindow`'s own default `frame.Title` — a real duplicate-title bug. Fixed by mirroring `Home.lua`'s own established precedent (its own comment: *"BaseWindow already creates frame.Title. Reposition it... rather than layering a second title on top of it"*): the separate FontString is gone, `frame.Title` is repositioned and reused as the identity header instead.

#### Canonical Absolute Date Format Sweep

`Presentation.FormatDate`'s `"short"` style (`"Jun 23, 2026"`) is the addon's one canonical absolute date format — no alternate styles exist, and none should be added (this pass deliberately did not introduce a second date-style constant; every call site either has a real timestamp to format or doesn't display a date at all). A full repo grep beyond the Presentation Layer pass's original 10-site fix found one more real month/day-only bug and 9 duplicate hand-rolled implementations of styles `Presentation.FormatDate` already provides:

- **Real bug fixed** — `Pages/Accomplishments.lua`'s `FormatEarnedDate` rendered accomplishments as `MM/DD` with no year at all (`string.format("%02d/%02d", accomplishment.month, accomplishment.day)`). This one was missed by the original 10-site sweep because it's a `string.format` call, not a `date(...)` call — the earlier grep only searched for the latter. Fixed by constructing a real Unix timestamp from Blizzard's own achievement date fields (`time({year = 2000 + accomplishment.year, month = accomplishment.month, day = accomplishment.day})` — the module's own file header already documents Blizzard's year field as a 2-digit offset, e.g. `24` for 2024) and formatting it through `Presentation.FormatDate(timestamp, "short")`, same as every other date in the addon.
- **9 duplicate implementations migrated, zero visual change** — `PlayerJournalTooltip.lua`, `DeveloperPanel.lua` (Player Journal oldest/newest entry, ×2), `RecommendationInspector.lua` (×2), `PlayerJournal/Tabs/Overview.lua`'s `FormatRelativeDate` helper (kept as a thin wrapper — its 2 call sites still need its "Unknown" fallback for a zero/missing timestamp, so it wasn't inlined away, just its body redirected), `PlayerJournal/Tabs/CommunityNotes.lua`, `PlayerJournal/Tabs/Search.lua`. Each already hand-rolled `date("%b %d, %Y", timestamp)` — byte-identical output to `Presentation.FormatDate(timestamp, "short")`, just a second (now ninth) independent copy of the same format string that could have silently drifted. Pure refactors.
- **2 files, 3 call sites — real, minor visual change** — `PlayerJournal/Tabs/Timeline.lua` and `PlayerJournal/Tabs/PersonalNotes.lua` (note timestamp + edited-timestamp suffix) used `"%b %d, %Y %H:%M"`, a single space before the time — a third, unintended date-with-time variant distinct from both `"short"` (no time) and the canonical `"shortTime"` (double space before the time, matching `RecommendationInspector.lua`'s original convention). Migrated to `Presentation.FormatDate(timestamp, "shortTime")` — the single space becomes the canonical double space, flagged explicitly rather than absorbed silently into "just a refactor."
- **Left deliberately untouched** — `MythicPlusModule.lua`/`ActivityHistoryService.lua`'s `date("%Y-%m-%d", ...)` internal day-bucketing keys (used only to group records by calendar day, never shown to the player as a date); `Logger.lua`/`DeveloperPanel.lua`'s `date("%H:%M:%S", ...)` clock-time formatting (a time, not a date — out of this sweep's scope); `DeveloperPanel.lua`'s History Inspector debug listing (`date("%Y-%m-%d %H:%M", ...)`), a dense single-line machine-readable log format for a dev-only tool, consistent with that panel's already-established "different visual dialect, not held to Dashboard-consistency" precedent from the Presentation System v2 pass above.

## 9. Character Journey

Not a gameplay module — no lifecycle (`Initialize`/`Enable`/etc.), no Data Ownership Matrix entry, no new SavedVariables. `Core/UI/Dashboard/Pages/Journey.lua` is a curated, chronological "museum" of a character's meaningful lifetime moments, answering "who has this character become," not "what happened yesterday" — explicitly not another activity log. Named and built as the direct continuation of the Accomplishments Accordion Redesign (section 1.3), whose own file header had already called itself "the first step toward a longer-term Character Journey direction."

#### Why this exists
The addon had spent several passes building the raw material for this feature without naming it: `AccomplishmentsModule` (a curated, dated record of signature achievements), `MilestoneService` (permanent, achieve-once personal milestones), the Presentation layer (canonical date/color tokens), and the accordion engine (section 1.3). A full audit of every history-shaped system in the addon (`ActivityHistoryService`, `AccomplishmentsModule`, `MythicPlusModule`, `WeeklyModule`, `ProgressSummaryService`, `RecommendationHistoryService`, `MilestoneService`, `SessionNotesService`, `PlayerJournalModule`, `CommunityModule`) found the real work was aggregation and presentation, not new tracking — but also found two systems that are **not** safe to build a permanent timeline on without further work, excluded honestly rather than worked around.

#### Zero new tracking — Phase 1 data model
Pure aggregation over two already-public, already-durable read APIs, normalized page-locally (not promoted to a shared module — matches how `Pages/Accomplishments.lua` keeps its own formatting helpers page-local until a second real caller needs the identical shape; none does yet):
- `AccomplishmentsModule:GetAccomplishments()` — Blizzard's own `month/day/year` earned date, re-derived live every refresh (not from a capped log), no pruning, no backfill gap. Applies **no additional filter** on top of what `AccomplishmentsModule` already classifies — Journey holding a stricter bar than its own sibling page would make the same fact "signature enough" on one page and not the other.
- `MilestoneService:GetAllAchieved()` (new getter, section 1.6) — 12 achieve-once personal milestones, permanent timestamp, never re-fires, never pruned.

**A honesty nuance carried into the UI:** `MilestoneService`'s achieved timestamp is when the addon *detected* the crossing, not necessarily when the player first crossed it (a fresh install on a veteran character backfill-stamps every already-true milestone at "now" on first `Refresh()`). Not new to Journey — Progress's "Recent Milestones" card already has this property, unflagged — but Journey makes the date prominent enough that its detail view labels it **"Recorded,"** not **"Earned,"** for milestone-sourced entries.

#### Explicitly excluded this pass — real fabrication risk, not oversights
- **Player Journal** ("first met a favorite player," "50 runs together") — `PlayerJournalModule`'s storage root is account-wide (`DatabaseService:GetGlobal().PlayerJournal`), and no field anywhere records which of the account's characters first met a companion or logged a given run. Attributing an account-wide `firstSeen`/`runsTogether` fact to "this character's journey" without that field would be a guess, not a recorded fact. Honest unblock for a future pass: a per-character attribution field written once alongside the existing `firstSeen = time()`, plus a per-character runs-together counter alongside the existing account-wide one — additive, nil-guarded, no migration step.
- **Recommendation History / Community Notes** — neither has any "notable moment" concept today, only routine engagement counters (`timesCompleted`, `GetTotalNoteCount()`). Buildable later from existing getters once a real threshold definition is designed.
- **"Highest Mythic+ ever, with a date"** — a genuinely different "record can be broken again" pattern, structurally incompatible with `MilestoneService`'s achieve-once model. Belongs to `MythicPlusModule` (Rule 1) in a future pass — a small new persisted map updated only when a new max is detected inside the existing run-recording path, deliberately separate from `MilestoneService`.

#### UI design
**Ordering — oldest-to-newest**, a deliberate, explicit departure from every other Dashboard list (all newest-first): this page tells a story arc, not "what's new." Direct existing precedent: `Rows.lua`'s `LayoutRunLevelChart` already ships this exact reasoning ("oldest run on the left, newest on the right — reader scans a timeline").

**Grouped by year only, not expansion** — year is the one axis every entry can honestly provide (`MilestoneService` entries have no expansion concept at all); expansion stays a per-entry field in the expanded detail, mirroring Accomplishments' own honest-omission pattern for it. A new `LayoutYearSeparator` (page-local, pooled by year label since the set of years is genuinely dynamic across a character's lifetime) uses a lighter treatment than a full `BeginSection`/`EndSection` — the wrong tool for a per-year runtime string. Undated entries (the rare `accomplishment.year == 0` case) sort first under one "Undated" bucket — never faked as a real date.

**Rows reuse the accordion engine, once per year-bucket** — `Dashboard:LayoutAccordionRows` called once per year (the same multi-call-per-page shape `Pages/Accomplishments.lua` uses across its five sections, no engine changes), `Dashboard:BuildAccomplishmentRow` reused unchanged for the collapsed row. One shared `page.ExpandedJourneyEntryID` across every year-bucket gives page-wide accordion behavior for free (record IDs — `"Accomplishment:"..id` / `"Milestone:"..id` — are globally unique). Collapsed row text is `"Mon DD, YYYY — Title"` (a deliberate departure from Accomplishments' name-only row — a date-forward feel fits a timeline). Detail view reuses `Dashboard:SetAccordionDetailField`/`HideAccordionDetailField` — promoted out of `Pages/Accomplishments.lua` into `Rows.lua` the moment this page needed the identical mechanic (byte-identical bodies, zero behavior change for Accomplishments).

**No Recommendations/Insights tail** — no "Journey" category exists anywhere in `RecommendationEngine`/`InsightEngine`; manufacturing one would mean fake matching or permanently-empty chrome. Direct precedent: `Pages/Progress.lua` already ships with zero `AppendDynamicSection` calls.

#### Dashboard responsibilities
Home page Journey card (entry count, most recent moment) between the Accomplishments and Storage cards. Journey page — Hero (total moment count, most recent as caption; empty state names what kinds of moments will eventually appear rather than a bare "no data" line) → year-grouped accordion sections.

#### Explicitly NOT responsible for
- Any new Blizzard API call, any new persisted state, any new service — Phase 1 is presentation and aggregation only.
- A second curation filter on top of `AccomplishmentsModule`'s own classification (see "Zero new tracking" above).
- Player Journal, Recommendation History, or Community Notes-sourced entries this pass (see "Explicitly excluded" above).

#### Phased roadmap
Phase 2 — `MilestoneService`'s `check(stats)` → `check()` generalization (only once actually needed) + new non-MythicPlus threshold definitions (50-runs-together *only if* the Player Journal attribution gap is solved first; Nth Community Note; Recommendations Completed). Phase 3 — the "record can be broken again" pattern for highest-Mythic+-ever. Phase 4+ (not designed) — expansion "chapter" summary cards (the year-grouped model re-slices by expansion later without a data-model change), exportable/shareable Journey, accomplishment icon rendering (already a separately logged backlog item).
