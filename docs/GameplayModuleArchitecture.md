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
- Authoritative, read-only bag snapshots (`GetInventorySnapshot`) with an in-session snapshot identity and timestamp. Aggregate consumers read this API; they never rescan bag containers.
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

**Disclosure indicator, owned by the shared engine.** `Dashboard:LayoutAccordionRows` itself (not any `opts.buildRow`/`layoutCollapsed` callback) now creates/updates a pooled `row.DisclosureIcon` FontString every row — a `">"` (collapsed) / `"v"` (expanded) glyph (`DashboardFormat.DISCLOSURE_COLLAPSED`/`DISCLOSURE_EXPANDED`, `Format.lua`), reusing the exact same `page[opts.expandedField] == recordID` boolean the engine already computes for its own toggle logic. Because it's engine-owned, MythicPlus's Recent Runs table gets it automatically with zero MythicPlus-authored code. New `Layout.ACCORDION_DISCLOSURE_WIDTH` (14px) reserves the left column; every `layoutCollapsed` implementation's own content shifts right by that amount — **a real, intentional, visible change to MythicPlus's Recent Runs columns** (Status/Date/Level/Name all shift right 14px; Time is anchored `TOPRIGHT` and unaffected), explicitly requested and approved as the one shared-improvement exception to "MythicPlus stays pixel-identical."

**Glyph fix (live in-game testing).** The original ▶/▼ (U+25B6/U+25BC, Geometric Shapes block) rendered as missing-character boxes in-game — Blizzard's client font (FRIZQT__.TTF) doesn't cover that Unicode block. No verified Blizzard native disclosure texture/atlas was available to substitute (avoided guessing an exact path, since a wrong one fails the same way — silently blank). Replaced with the plain ASCII `">"`/`"v"` fallback instead; same single engine-owned call site, so the fix required no page-level changes.

**Deeper expanded-detail hierarchy.** New `Layout.ACCORDION_DETAIL_INDENT` (= `ACCORDION_DISCLOSURE_WIDTH + ROW_INDENT + 8` = 30px) — `Dashboard:SetAccordionDetailField` now indents to this constant instead of `Layout.ROW_INDENT`, so expanded fields visibly nest under the row's own (now-shifted) title rather than lining up flush with it. The byte-identical `row.DescriptionText` block that had been independently duplicated in both `Pages/Accomplishments.lua` and `Pages/Journey.lua` is promoted into new `Dashboard:SetAccordionDetailDescription(row, text, yOffset, width)`/`HideAccordionDetailDescription(row)` (`Rows.lua`), using the same deeper indent — the same promotion discipline `SetAccordionDetailField` itself went through the pass before this one.

**Hover feedback: audited, already adequate.** `BuildHistoryRow` and `BuildAccomplishmentRow` already tinted the full row background on hover (`(1,1,1,0.06)`, matching `BuildRecommendationRow`'s identical established value) — real, shipping, covers the whole row including the new disclosure icon. No new mechanism was needed or added.

**Presentation Asset Audit (follow-on pass).** The accordion glyph fix above prompted a full sweep of every UI file for Unicode glyphs, hardcoded textures/atlases, and duplicate presentation constants. Two more spots turned out to share the *exact* confirmed-broken codepoints: the static `"▶"` (U+25B6) navigation chevrons in `DashboardCard.lua`/`RecommendationInspector.lua`, and `TREND_ARROWS.Declining`'s `"▼"` (U+25BC) in `Format.lua` — all now plain ASCII (`">"`, `"^"/"v"/"-"` for the full trend-arrow set, converted together for one internally-consistent indicator rather than shipping two of three as still-unverified Unicode). Separately, the audit found real duplicate-glyph-definition debt: the checkmark/cross glyph was defined independently in both `Format.CHECK_SUCCESS/FAILURE` and `VerificationService.StatusGlyph`; the bullet `"•"` was an inline literal at 5 call sites with no shared constant; and the star `"★"` was hardcoded 3× in `enUS.lua` independently of `Format.STAR_FILLED`. Fixed by promoting the bare checkmark/cross/warning glyphs to `Presentation.CHECK_GLYPH`/`CROSS_GLYPH`/`WARNING_GLYPH` (addon-wide primitives, since `VerificationService` isn't Dashboard code — same reasoning `HIGHLIGHT_COLOR` was promoted under), with `Format.lua`'s colored versions now thin compositions over them; adding `Format.BULLET`; and refactoring the 3 star-bearing localization strings to take the glyph as a `%s` argument sourced from `Format.STAR_FILLED` instead of embedding their own copy (one redundant pure-glyph key, `Evidence.PlayerJournalFavoriteGlyph`, removed entirely). Remaining Unicode (★/☆, ✓/✗/⚠, •) is unconfirmed against the live client but not proven broken — left as-is rather than pre-emptively rewritten, flagged for live verification.

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
`C_ChallengeMode`: `GetActiveKeystoneInfo`, `GetSlottedKeystoneInfo`, `HasSlottedKeystone`, `GetOverallDungeonScore`, `GetMapUIInfo`, `GetDeathCount`, `GetMapScoreInfo`, `GetChallengeCompletionInfo`, `IsChallengeModeActive`, `GetAffixInfo` (affix display resolution). `C_MythicPlus`: `GetOwnedKeystoneChallengeMapID`, `GetOwnedKeystoneLevel`, `GetCurrentAffixes`, `GetCurrentSeason`, `RequestMapInfo`. `GetExpansionLevel` (envelope metadata only). `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_DEAD`, `ENCOUNTER_START`/`ENCOUNTER_END`, and a narrowly-filtered `COMBAT_LOG_EVENT_UNFILTERED` — all registered only between `CHALLENGE_MODE_START` and the run ending (see "Long-Term Performance Tracking"). `C_Item.GetItemInfoInstant`, `C_Map.GetBestMapForUnit`/`GetPlayerMapPosition` (player's own position on their own death only).

#### Dashboard responsibilities
Home page Mythic+ card ("Current Keystone" in the daily-briefing layout — current season, active run or owned keystone/dungeon name/level, rating, best level) routes to the dedicated competitive-analysis Mythic+ page: Hero, Key Statistics, Recent Runs history, Season Statistics, Performance Trends, Consumables, Recommendations, and Insights. The separate Dungeons page may reference an active Mythic+ run only as authoritative "current dungeon" context; it does not display Mythic+ completion history or competitive analysis. Recent Runs' expandable rows remain `Dashboard:LayoutHistoryRows` (`Rows.lua`), a thin wrapper over the same `LayoutAccordionRows` engine Accomplishments/Journey use (section 1.3's "Accordion Polish Pass").

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

**Data flow:** `CHALLENGE_MODE_START` → `MythicPlusModule` resets per-run scratch state (`self.RunTracking`) and registers a small set of run-scoped listeners → those listeners accumulate interrupts/defensive-cooldown-uses/deaths(+location, boss-vs-trash)/consumable-item snapshots while the run is in progress → `CHALLENGE_MODE_COMPLETED` reads `C_ChallengeMode.GetChallengeCompletionInfo()`, builds the completed-run record, and calls `RecordCompletedRun()`, which appends one record to `ActivityHistoryService` (Module = `"MythicPlus"`) and unregisters the run-scoped listeners → `GetRecentRuns()`/`GetSeasonStatistics()` read that history back → `GetInsights()` derives history-backed Insights from it → `RecommendationEngine`'s existing generic Insight → Recommendation mappings turn some of those into Recommendations, unchanged in structure from before this feature → the Dashboard reads all of the above through public APIs only.

**History ownership:** MythicPlusModule is the only writer to its own `Module = "MythicPlus"` records. `ActivityHistoryService` owns storage, indexing, retrieval, and pruning; it never inspects or generates statistics from the `Data` payload — that stays MythicPlusModule's exclusive concern, keeping `RecommendationEngine`/`InsightEngine` fully generic (see below).

**Persistence:** `DatabaseService:GetCharacter().ActivityHistory`, unchanged from the prior phase — no new SavedVariables table. Bounded, not unlimited: `ActivityHistoryService` trims the oldest records once a module exceeds `MAX_RECORDS_PER_MODULE` (500), enforced on every `Append()`. For MythicPlus this is roughly a year or more of retention for an active pusher, a real enforced bound rather than "grows forever."

**Run record versioning:** Additive, not restructured. Every field from the previous schema (`dungeonID`, `level`, `time`, `onTime`, `scoreChange`, `isMapRecord`, `season`, `deathCount`, `affixIDs`) is unchanged, so a reader written against the old schema keeps working against both old and new records without modification. New fields (`recordVersion = 2`, `spec`, `itemLevel`, `timeRemaining`, `interruptCount`, `defensives`, `bossDeaths`/`trashDeaths`/`deathLocations`, `consumables`, `itemCountDelta`) are simply absent (nil) on records written before this phase; every reader nil-guards rather than assuming presence. This was a deliberate deviation from a fully nested `Metadata`/`Timing`/`Party`/etc. structure some might expect — nesting-then-migrating old records would have meant either breaking old reads or writing a migration step; flat-and-additive needed neither.

**Recommendation/Insight sources:** Unchanged architecturally from before this phase — `InsightEngine`/`RecommendationEngine` still iterate any registered module's `GetInsights()`/match on insight titles generically, with zero MythicPlus-specific code added to either engine. All of the new intelligence lives in `MythicPlusModule:GetInsights()` and a few new title-matched branches in `RecommendationEngine:EvaluateInsight()`, exactly like every existing mapping.

**Consumable classification, deliberately not a hardcoded item list:** Potions/flasks/food are reseasoned by Blizzard every patch, so a maintained item-ID list would go stale immediately. Instead `MythicPlusModule:ClassifyConsumableItem()` delegates to the shared `AC.ItemClassification:ClassifyConsumable()` (`Core/Utility/ItemClassification.lua` — consolidated here during the Product Polish consumable classifier consolidation so this and StorageModule's rule matching read from one implementation, not two independently-drifting copies), which reads the item's own `classID`/`subClassID` (`C_Item.GetItemInfoInstant`, against `Enum.ItemClass.Consumable`/`Enum.ItemConsumableSubclass`) — Blizzard's own stable taxonomy, so a brand-new seasonal potion is correctly classified the day it ships. The one exception is Healthstone (itemID 5512, an exceptionally long-stable ID). Trade-off accepted: this cannot distinguish healing/mana/combat potions from each other (all just subclass "Potion") without reintroducing the same staleness problem, so only an aggregate "potion" count is reported.

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
| Run History — **Implemented** | `C_ChallengeMode.GetChallengeCompletionInfo()` (collected as `lastCompletedRun`) — only the single most recent completion; Blizzard keeps no client-queryable log of past runs. | A Blizzard-provided multi-run history API (still doesn't exist). | Done: `MythicPlusModule:RecordCompletedRun()` publishes each completed run to `ActivityHistoryService` (the previously-scaffolded integration point) as it happens; `GetRecentRuns()` reads it back newest-first. No new Blizzard API was needed, as predicted. |
| Rating History — **Implemented** | `GetOverallDungeonScore()` (current snapshot only) plus `oldOverallDungeonScore`/`newOverallDungeonScore` from `GetChallengeCompletionInfo()` on each completion (collected as `oldScore`/`newScore`). | A Blizzard-provided historical rating-over-time API (still doesn't exist). | Done: the rating delta per completed run (`Data.scoreChange`) is captured in the same ActivityHistoryService record as the run itself, and `GetSeasonStatistics()` sums it into `ratingGained`. |
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
The Home page is ordered as a daily briefing rather than a flat card stack: a real-time-of-day greeting, the single highest-scored recommendation, Character, Mythic+, Vault Progress, then Dungeons as a compact chronological summary of recorded general-dungeon and Delve activity. The Mythic+ card opens the dedicated `MythicPlus` page; the Dungeons card opens `Dungeons`. Inventory, Accomplishments, and existing auxiliary destinations remain available because this window has no separate sidebar navigation (see `Core/UI/Dashboard/Dashboard.lua`).

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
- Bank, reagent bank, and (where accessible) Warband Bank item contents — transactional, in-memory per-source snapshots scanned only while that source is viewable, never persisted. Character and Warband snapshots retain independent identity/timestamps/freshness so scanning one cannot erase the other; the movement cache remains scoped to containers readable by the current interaction.
- Scan-state public API (`GetScanStatus`, `GetLastScan`, `GetStorageSources`, `GetSnapshot`, `IsStorageAvailable`, `GetRefreshReason`) — keeps unavailable, never scanned, stale, failed, and successfully empty storage distinct for presentation callers.
- Aggregate-storage public API (`GetAggregateStorage`, `GetItemsByCategory`, `GetCategorySummary`) — composes InventoryModule's authoritative bag snapshot with StorageModule's character/Warband bank snapshots into one presentation-neutral item model. Source ownership, availability, freshness, and per-source snapshot identity remain attached to every normalized record; missing Blizzard item metadata remains unknown rather than inferred.
- Aggregate-search public API (`GetSearchFilters`, `SearchItems`) — performs case-insensitive partial-name matching, category/source/owner/quality filtering, result grouping, and deterministic ordering over `GetAggregateStorage`. Search never scans containers, persists queries, or asks presentation callers to understand source-specific records.
- Storage profiles: a small set of built-in presets (Mythic+, Raid, Questing, Custom) — see "Built-in presets, not a rule editor" below.
- Rule-based matching against Item/Category/Quality/Expansion/User-Group targets (Blizzard's own classID/subClassID taxonomy for Category, resolved through the shared `AC.ItemClassification` — see "Consumable classification" above). Profession-based targeting is explicitly NOT implemented — see "Explicitly NOT responsible for" below.
- Restock analysis: missing items, excess items, recommended withdrawals, recommended deposits, and a deterministic readiness percentage (`readinessPercent` — average, across Maintain/Keep rules, of how close bags alone are to each rule's target, capped per-rule at 100%) — computed live from InventoryModule + this module's own bank cache, never cached/stale.
- A live-computed shopping list (the "missing" side of restock analysis).
- Activity preparation status (`GetPreparationStatus`) — a real ready/not-ready signal plus the readiness percentage above, consumed by existing RecommendationEngine/Dashboard callers. Snapshot-aware presentation uses `GetStorageReadiness`, which refuses to label stale or unavailable storage as ready.
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
`C_Bank.FetchViewableBankTypes`/`FetchPurchasedBankTabIDs` (authoritative source and tab enumeration for character and account/Warband banks), `C_Container.GetContainerNumSlots`/`GetContainerItemInfo`/`PickupContainerItem` (bank-side and, for Execute, bag-side moves — bag *scanning* itself remains Inventory's), `C_Item.GetItemInfoInstant`/`GetItemInfo` (classID/subClassID/expacID, for Category/Expansion rule matching), `BANKFRAME_OPENED`/`CLOSED` and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` with `Banker`/`AccountBanker` interaction types (bank-open detection), `InCombatLockdown`/`CursorHasItem`/`ClearCursor` (Execute safety), `StaticPopupDialogs`/`StaticPopup_Show` (Execute confirmation, owned by `Core/UI/Dashboard/Pages/Storage.lua`, not this module).

**VERIFICATION STATUS (Blizzard API Verification Workflow pass):** Current Blizzard-generated Bank API documentation confirms `C_Bank.FetchViewableBankTypes` and `FetchPurchasedBankTabIDs`; the former identifies the sources exposed by the active interaction and the latter returns their owned tab IDs. `C_Container.PickupContainerItem` is confirmed real via Warcraft Wiki (available through "Midnight" 12.1.0, `AllowedWhenUntainted`). The legacy reagent-bank container ID path (`Enum.BagIndex.Reagentbank`/`Bank`) remains harmless-but-vestigial. The bag-item "favorite" field is confirmed **broken**, not merely unverified: `ContainerItemInfo` has no documented `isFavorite` field, and nothing in this codebase consumes it. **Still Needs Live Verification:** regular Character Bank and summoned Warband Bank interaction timing (`Banker`/`AccountBanker` with `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`), the per-source snapshot/freshness transitions, and the actual pickup-then-place Execute round-trip. See `docs/DEVELOPMENT_BACKLOG.md` and the Developer Checklist for the live scenarios.

#### Dashboard responsibilities
Home page Storage card (active profile name, ready/not-ready status, readiness-percentage bar) and Mythic+ card (readiness-percentage bar sourced from Storage's "MythicPlus" preset — a cross-module read, see 1.6/Rule 6). The Dashboard Storage page remains a summary and launcher. The dedicated Inventory Manager is presentation-only: its Overview consumes the scan/readiness APIs above, Categories consumes `GetCategorySummary`, and Search consumes `GetSearchFilters`/`SearchItems`; neither window scans containers, classifies items, or implements storage queries.

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
A standalone `BaseWindow` (same tier as `DiagnosticsWindow`/`SettingsWindow`), seven tabs, presentation-only throughout — every value traces to an existing public getter, `DeveloperModeService`'s own observation state, `AC.DeveloperRuntime`'s capabilities, or `VerificationService`'s registry/log:
- **Overview** — the flat status board (character/zone/spec/item level, current key/rating, vault state, storage readiness, recommendation/notification counts, the current top recommendation's score/confidence, loaded module counts, last refresh, last event, frame rate).
- **Modules** — one row per registered Service/Module: Initialized (true for anything appearing in these registries at all — `ModuleManager`/`ServiceManager` only ever list what completed `Initialize()`), Enabled (a module's own `IsModuleEnabled()` — the real per-feature Settings toggle — where one exists, else "Yes" for framework services with no such concept), Last Refresh/Duration/Last Error (from `DeveloperModeService`'s instrumentation), Insight/Recommendation/History counts (via `InsightEngine:GetInsightsByCategory`, `Dashboard:GetCategorizedRecommendationsAndInsights`, `ActivityHistoryService:GetByModule` — never recomputed here), and a per-row Refresh button (`DeveloperModeService:RefreshOne`).
- **Events** — a live, timestamped, clearable feed of `DeveloperModeService`'s own event log.
- **Errors** — presents `AC.DeveloperRuntime`'s `ErrorCapture` capability; see its own subsection below.
- **Live API Inspector** — expanded in the Live Verification & Framework Hardening sprint into a real validation suite, not just a Raw/Final comparison. A Verification Summary line (counts by status, from `VerificationService:GetSummaryCounts()`) sits above four "Inspect Now" probes (Weekly/Great Vault, Storage/Bank including Warband via the real `Enum.BankType` split `StorageModule` itself already uses, Mythic+, Affixes). Each probe still calls the real Blizzard API directly for "Raw" (the one place outside `DiagnosticsService` this addon calls a Blizzard API straight from a diagnostic tool, on-demand only, never polled) against the owning module's own already-existing public getter for "Final" — a row highlights when they genuinely disagree — but now also shows that probe's Expected interpretation, Confidence, Source citation, and Last-Verified timestamp (from `VerificationService`), plus new Mark Verified/Mark Failed buttons that write a human-confirmed result to the persisted log. Below the four probes, a read-only **Full Verification Registry** section lists all 37 registry entries (not just the 4 with a live-comparable probe) with their status glyph, citation, and last-verified timestamp — the tab's own answer to "for every probe display Raw/Parsed/Expected/Pass-Fail/Confidence/Source/Timestamp," honestly scoped to what's actually comparable versus what's only a static classification.
- **Checklist** — new this sprint. One row per `VerificationService:GetChecklist()` scenario: its related APIs' current status glyphs, when it was last marked done (or "Not yet done"), and a Mark Done/Mark Not Done toggle. Marking a scenario done only records that a human performed it and when (`RecordChecklistScenario`) — it never changes any registry id's own verification status by itself; that stays the Live API tab's own Mark Verified/Failed buttons, kept as two deliberately separate actions ("I did the thing" vs. "I confirmed the result was correct" are not the same claim).
- **History Inspector** — real, already-stored `ActivityHistoryService` records, filterable by Module/Type (a fixed, documented list matching the only two real writers today, `MythicPlusModule`'s "Dungeon" records and `AchievementsModule`'s "Achievement" records) and a Date preset, plus Clear History (confirmation-gated, via a new `ActivityHistoryService:ClearAll()` — the one small, legitimate service extension this pass needed, so `DeveloperPanel` never reaches into that service's internal `Records` array directly).

#### Errors tab — Developer Panel over Developer Runtime
Presentation over `AC.DeveloperRuntime`'s `ErrorCapture` capability, built independently of it (a dedicated "get the runtime right first" pass preceded this) — `ErrorCapture` remains the single source of truth: no caching, no polling, no second copy of its data, read entirely through its own public `GetErrors()`/`ClearErrors()`/`GetSettings()`/`IsInstalled()`.

- **Toolbar** — "Capture: ON/OFF" (from the new `ErrorCapture:IsInstalled()` — ground truth that the handler is actually installed, distinct from `GetSettings().CaptureLuaErrors`'s persisted intent) and "Errors: N" combined on one status line, plus a Clear Errors button (no confirmation dialog, per explicit instruction — calls `ErrorCapture:ClearErrors()` directly) — same lazy-build-once idiom `EventsClearButton` already uses.
- **List** — every unique captured error, newest-first (a locally-reversed copy; `ErrorCapture`'s own array, ordered by first-seen, is never mutated). Collapsed row: a fixed-length truncated message preview, source location, and occurrence count + last seen on one line — a predictable row height for a scannable log-style list, rather than word-wrapping the full message inline.
- **Expand/collapse** — reuses `AC.Dashboard:LayoutAccordionRows` directly, the same shared engine `Accomplishments`/`Journey`/`MythicPlus` already call directly (not through a page-specific wrapper) — not a second accordion implementation. `DeveloperPanel.lua`'s own header previously argued against reusing Dashboard's `Rows.lua` primitives at all ("fighting player-facing spacing/typography for a developer tool that wants density"); that reasoning was about simple text lines and predates any expand/collapse need, so the Errors tab is now the one documented exception, using the engine's pooling/toggle/disclosure-icon mechanics while keeping its own dense, DeveloperPanel-appropriate fonts for row content. Because `LayoutAccordionRows` writes into `page.Pools[poolKey]` and `page` here is `DeveloperPanel` itself, the rows land in the exact same `self.Pools` table `HideOtherTabs`'s existing generic hide loop already covers — no special-casing needed for the rows (only the toolbar, which lives outside `self.Pools`, needed one, same as `EventsClearButton`).
- **A real bug caught during integration, not a hypothetical:** `LayoutAccordionRows`' empty-state line caches itself on `pool.EmptyText` — a string key `ipairs()` never reaches, so `HideOtherTabs`' generic hide loop was silently skipping it. No existing DeveloperPanel tab had exercised that caching convention before Errors, so the gap was real but previously unreachable; `HideOtherTabs` now explicitly hides `pool.EmptyText` too, benefiting any future pool that uses the same convention, not just this one.
- **A small, backward-compatible extension to the shared engine:** `Dashboard:SetAccordionDetailDescription`/`HideAccordionDetailDescription` (`Rows.lua`) previously cached to a single hardcoded `row.DescriptionText` field, fine for `Accomplishments`/`Journey`'s one description block per row. Errors needs two (Full Message, Stack Trace) — both now take an optional `cacheKey` parameter (defaulting to `"Description"`, reconstructing the exact prior field name), so the two existing callers are unaffected while Errors can use two independent fields on the same row.
- **Expanded detail** — Full Message (`SetAccordionDetailDescription`), Signature/First Seen/Last Seen/Occurrence Count (`SetAccordionDetailField`, the same label/value primitive `Accomplishments`/`Journey` already use), and Stack Trace (`SetAccordionDetailDescription` again, under its own cache key — an honest "(not captured...)" string when unavailable rather than a blank). **Not built:** a "Locals" section — `ErrorCapture` doesn't capture local variables at the crash site, so none is rendered; a comment marks where one would go if that field is ever added to the capture pipeline, rather than inventing placeholder data now.
- **Two small, additive `ErrorCapture` API completions**, found missing during the audit rather than assumed: `IsInstalled()` (ground-truth install state, so the Panel doesn't reach into `OriginalHandler` directly) and a third `ComputeSignature`/`BuildEntry` return value, `entry.location` — the crash site's own bare `file:line`, already computed internally as the signature's first frame but not previously surfaced as its own field. Neither changes signature/aggregation logic, install/remove, or suppression behavior.
- **Timestamps shown as-is** — `firstSeen`/`lastSeen` are `ErrorCapture`'s existing session-relative `HH:MM:SS.mmm` clock strings (`Logger`'s own convention), not reformatted into a calendar date the data doesn't actually contain.

**Post-implementation bug fix — capture was silently failing.** Live testing found `/ac dev testerror` correctly triggering Blizzard's own error popup while the Errors tab stayed at 0 — proof the chain-through to the original handler worked, but something inside `ErrorCapture:OnError` was throwing and being fully discarded by `HandleGlobalError`'s `pcall`, which had zero logging on capture failure. Root cause traced to the debugstack/signature-computation step (the one area already flagged `NEEDS_LIVE` in the original design) with no visibility into what was actually failing. Fixed by: isolating stack-trace capture and signature computation in their own protected boundary inside `OnError`, logging the real error on failure and degrading to a message-only signature rather than losing the entry entirely; adding the same logging to `HandleGlobalError`'s outer capture `pcall` (previously fully silent on failure); and simplifying `debugstack()` to a bare call with no level argument, since `GetOwnFrames`' own `AC.Name`/`SELF_FILE` filtering was already designed to find the right frames regardless of how many irrelevant ones lead the raw trace — the skip-count guess was never actually load-bearing. No change to aggregation logic, signature *algorithm*, install/remove, or suppression behavior. Also added: a **Generate Test Error** button in the Errors tab toolbar calling `AC.SlashCommandManager:HandleDev("testerror")` directly — the identical entry point `/ac dev testerror` uses, not a second copy of the test logic — and the status line now shows Capture (the persisted setting) and Installed (`IsInstalled()`'s ground truth) as two separate values rather than one conflated boolean, so a future mismatch between "should be on" and "actually is on" is immediately visible instead of hidden. Separately, fixed the Developer Panel's title being visually overlapped by its QoL toolbar row — `Initialize()` now measures the title's own real rendered height (`self.Frame.Title:GetStringHeight()`) rather than assuming a fixed offset, and derives the QoL row's and tab bar's Y positions from that measurement plus one named gap constant, so the layout self-corrects if the title text or font ever changes rather than relying on a hardcoded number that happened to work.

**Stabilization pass — a second, real gap found and closed, plus full pipeline instrumentation.** Auditing the complete path (`SlashCommandManager → ErrorCapture → DeveloperRuntime → DeveloperPanel`) after the fix above found `DEVELOPER_RUNTIME_UPDATED` was being correctly fired by `ErrorCapture`/`DeveloperRuntime` the whole time — but `DeveloperPanel` never actually registered a listener for it, despite the event's own doc comment already saying "the Developer Panel is the intended listener." A captured error while the Errors tab was already open had no path to trigger a redraw; only navigating away and back forced a fresh read. Fixed with `DeveloperPanel:OnDeveloperRuntimeUpdated`, registered unconditionally in `Initialize()` (a framework event, zero real-Blizzard-registration cost either way), refreshing the Errors tab live whenever it's the active tab and the window is shown. Comprehensive logging (all `Debug`-level, opt-in, matching `Logger`'s existing gating) now covers every stage requirement #5 named: handler installation/removal (`Install`/`Remove`, including the previously-silent skip conditions), handler invocation (top of `HandleGlobalError`), signature generation + aggregation + storage (one consolidated line in `OnError` naming module/key/occurrence count/total unique entries), runtime notification (`NotifyUpdate`, both the immediate and combat-deferred paths, plus the regen-flush), and UI refresh (`OnDeveloperRuntimeUpdated`). No remaining branch in this pipeline fails without at least a `Debug`-level trace of what happened.

**Stabilization pass — signature/location/origin extraction redesigned, root cause of a third real bug.** Live testing (this addon now stable enough to catch real accuracy bugs, not just capture-or-not bugs) found a `/ac dev testerror` thrown from `SlashCommandManager.lua:177` (inside `HandleDev`) reported as `module = DeveloperPanel.lua`, `location = DeveloperPanel.lua:1226`, `signature = DeveloperPanel.lua:1226` — the Generate Test Error button's own `OnClick` handler, which only *called* `HandleDev`, not the actual crash site. Root cause: the previous design picked signature/location/module from the first addon-owned, non-self frame it found in `debugstack()`'s own output — and `debugstack()`'s exact frame-preservation behavior when read from inside an installed `seterrorhandler` callback is not something this addon can verify without a live client (already flagged `NEEDS_LIVE`). This live result proves that assumption unreliable as a *primary* source of truth, not just theoretically uncertain.

Redesigned around a fact that doesn't depend on `debugstack()` at all: Lua's `error()` (default level — the level both this addon's own `error()` calls and every native runtime fault use) unconditionally prepends `"chunkname:line: "` to the message before any error handler ever sees it. This is universal, guaranteed Lua behavior, not specific to this addon's test-error command, and requires no stack-depth assumption or line-skip guess — `ExtractMessageLocation` parses this prefix directly off the message string. The raw stack trace is now only a *secondary* source, cross-referenced solely to recover the containing function's name for the signature's readability (`FindFunctionName`) — never depended on for location/module/origin correctness.

New `ClassifyOrigin` buckets every captured error's source path into `"Azeroth Companion"` / `"Blizzard"` / `"Third Party"` (with the addon's own folder name extracted for the third-party case) — `AC.Name` for this addon's own code, `Blizzard_*` sub-addon folders or `FrameXML` (both long-standing, stable Blizzard path conventions, not guessed) for Blizzard's own UI, and the addon folder name straight from the path otherwise. Signature format changed from the old two-frame join (`"File.lua:NNN <- File.lua:NNN"`) to `"File.lua:NNN -- FuncName()"` (function name omitted if the stack cross-reference doesn't find one) — stable against Blizzard rewording error text (it was never message-text-dependent even before), now also correct rather than frame-order-dependent. Kept single-line deliberately (not the two-line form a chat-style example might suggest) so Developer Panel's `SetAccordionDetailField` — a shared, fixed-single-line-height Dashboard primitive also used by `Accomplishments`/`Journey` — didn't need its own layout contract touched for one field.

New `CleanStackTrace` strips this addon's own `ErrorCapture.lua`/`DeveloperRuntime.lua` frames from `entry.stackTrace` (the field Developer Panel actually displays) by default — Developer Runtime's own machinery was never the bug, only what caught it, and was never meant to be part of what a developer reads while diagnosing a captured error. The true, unfiltered trace is preserved separately in a new `entry.rawStackTrace` field regardless of any setting, and a new `ShowRawStackTraces` setting (default off, same lightweight profile-table convention as the other five `ErrorCapture` settings) makes `entry.stackTrace` show the raw trace verbatim instead, without needing to re-capture anything.

`SIGNATURE_FRAME_COUNT`/`GetOwnFrames`/`ExtractFileLine`/`SELF_FILE` (the old stack-frame-first-match implementation) removed entirely rather than left dead alongside the new code. Preserved unchanged throughout: the aggregation *mechanism* (still exact-string dedup on whatever the signature computes to), occurrence counting, timestamps, `ToJSON`/`ToIndentedText`'s generic serialization (now including the two new fields, `origin`/`thirdPartyAddon`, additively), and the Generate Test Error button/Copy actions. Verified (not assumed) that Copy JSON/Copy Text/Copy Summary each produce their intended output for the Errors tab specifically — no bug found in any of the three, but **Copy Text**'s name is genuinely ambiguous next to **Copy Summary** (both sound like "the readable one"); Copy Text is actually `ToIndentedText` — the *same full structured record data* as Copy JSON, just indented plain text instead of JSON syntax — while Copy Summary is the short one-line-per-record display text. Recommended, not implemented (renaming touches shared Developer Panel infrastructure used by all seven tabs, out of scope for an Error-Capture-only pass): rename to **"Copy Full Text"** or **"Copy Detailed Text"** to read as JSON's plain-text twin rather than a synonym for Summary.

**Verification pass — three correctness fixes and two metadata additions found by deliberately auditing the redesign above for edge cases, not by further live testing.** Treated everything already live-verified (install, capture, aggregation, occurrence counts, Panel display, Copy JSON) as proven per this pass's own instruction, and audited only what hadn't been stress-tested against edge cases yet:

- **`ExtractMessageLocation` false-positive risk, closed.** A bare `"^(.-):(%d+):"` pattern would also match a message that merely *contains* an early "word:digits:" substring with no real chunkname behind it (e.g. a hypothetical message mentioning a step count like "12:34"), mistaking it for a genuine location prefix. Every real WoW chunkname is path-shaped; requiring a path separator (`/` or `\`) in the captured segment closes this without any risk of missing a genuine prefix.
- **`ClassifyOrigin` ambiguity, closed.** The previous `path:find(AC.Name)` was a substring search over the whole path — a hypothetical third-party addon whose own folder name merely *contains* "AzerothCompanion" (e.g. "AzerothCompanionPlus") would have been misclassified as this addon's own code. Fixed by extracting the addon folder name first and comparing it *exactly*. (A third party addon literally using Blizzard's reserved `Blizzard_` folder prefix would still be misclassified as `"Blizzard"` — accepted as a negligible-probability edge case WoW's own naming conventions already discourage, not further hardened.)
- **`FindFunctionName` anonymous-function display, corrected.** `debugstack()` renders an anonymous function as `"in function <chunkname:linedefined>"` rather than a quoted name — the previous pattern matched this bracketed form too, surfacing the raw location text as a fake "function name" (a signature ending in something like `"...lua:45()"`). Now only the quoted-name form matches; anonymous functions and `"in main chunk"` both correctly fall through to no function-name suffix, which is more honest than a technically-non-nil but meaningless value.
- **Two metadata fields added**, eliminating future re-parsing: `entry.functionName` and `entry.lineNumber` were already being computed as part of building the signature/location strings, just never surfaced as their own fields — anything wanting to sort/filter/group by line number or function name would have had to re-parse `location`/`key` for data this file already had in hand. Threaded through `ComputeSignature` → `OnError` → `BuildEntry`, additive only.
- **Stack cleanup re-verified, no bug found**: `CleanStackTrace` preserves frame order (filters, never reorders), and the `ShowRawStackTraces` path assigns the exact unmodified `stackTrace` string to `entry.stackTrace` with no transformation at all.
- **A real, evidence-based risk found in a sibling feature, deliberately not fixed this pass**: `Core/UI/PlayerJournalContextMenu.lua`'s `ResolvePlayerKey` calls `UnitExists(contextData.unit)`/`UnitFullName(contextData.unit)` on a value handed to it from inside a `Menu.ModifyMenu` callback — structurally identical to the exact pattern that broke *twice*, confirmed by real in-game errors, for the sibling tooltip feature (a unit-identifying value read from inside a Blizzard secure UI callback, passed to a normal `Unit*` API). Not yet independently confirmed live for this specific callback, but the pattern match is strong enough to flag rather than ignore — recorded as `ctxmenu.contextDataUnitSecretValue` (`NEEDS_LIVE`) in `VerificationService`. Deliberately **not** redesigned preemptively: doing so without live confirmation would be exactly the speculative redesign this stabilization effort exists to avoid. If it does throw the same way on a real right-click, the fix is already validated (the tooltip architecture: resolve identity via ordinary game events outside the callback, never a `Unit*` call on a value the callback's own context data supplies).

Every tab supports Copy JSON / Copy Text / Copy Summary (`DeveloperModeService`'s generic serializers, DiagnosticsWindow's own established "focus + highlight an EditBox, player presses Ctrl+C" idiom — WoW has no clipboard-write API). Fixed a real pre-existing bug in the Live Verification & Framework Hardening sprint: Copy Summary's `table.concat` assumed every tab's summary lines were plain strings, but the Live API tab has always stored colored lines as `{text=...}` tables — clicking Copy Summary while on that tab would have thrown a Lua error. `CopyCurrentTab` now normalizes either shape before concatenating. A persistent action row (Clear Notifications, Force Refresh, Refresh Individual Module, Toggle Tracing) sits above the tabs regardless of which one is active.

#### Recommendation Inspector extension (Developer Mode section)
`RecommendationEngine:ComputeScore()` now also returns (and `AddRecommendation` stores) `scoreBreakdown` — the ordered list of named terms that actually applied to produce `score`, built alongside the existing scoring logic rather than as a second pass. The Recommendation Inspector renders this as a new "Score Breakdown" section, visible only while Developer Mode is on — the literal answer to "explain exactly why one recommendation beat another" the brief asked for, reading a field that already exists rather than re-deriving anything.

#### `/ac dev on|off`
`/ac dev on` enables Developer Mode and immediately calls `AC.DeveloperPanel:Show()` (single-command activation, added after an audit found the prior two-step `/ac dev on` then `/ac dev` flow was a UX gap, not a registration bug). `/ac dev off` disables it and hides the panel. Bare `/ac dev` still toggles the panel if Developer Mode is already on, otherwise warns that it's off.

---

### 1.8a Developer Runtime — Error Capture (Phase 1)

New long-lived subsystem, `Core/Runtime/`, distinct from `DeveloperModeService`/`DeveloperPanel` above. Error Capture is its first capability; Warning Capture, Runtime Diagnostics, Performance Metrics, Verification Results, Event Statistics, and Export Tools are the named future capabilities this architecture was built to accommodate without redesign. **No Developer Panel UI yet** — this phase is the runtime only, verified independently before presentation is added.

#### DeveloperRuntime (`Core/Runtime/DeveloperRuntime.lua`) — the capability host
Owns none of any capability's data — only shared plumbing every capability would otherwise reimplement:
- **Capability registry** — the same "ordered array + name-keyed lookup" idiom `ServiceManager`/`ModuleManager` already use. Capabilities self-register at their own file's bottom (`AC.DeveloperRuntime:RegisterCapability(name, capability)`), the identical pattern every Service/Module already follows — adding a future capability means a new file, zero changes here.
- **Developer Mode integration** — reacts to `DeveloperModeService`'s existing `DEVELOPER_MODE_CHANGED` event (registered in `Initialize()`, not `Enable()`, so the listener is guaranteed active before `DeveloperModeService:Enable()` restores a persisted flag and fires it, regardless of `.toc` order between the two files) and calls `Install()`/`Remove()` on every registered capability. `DeveloperModeService` never needs to know this file exists — identical to how it already doesn't know `DeveloperPanel` exists. Each capability's own `Install()` decides for itself whether its own sub-settings allow installing; the host never knows what any capability's settings mean. Every capability call is `pcall`-isolated (`SafeCall`) — one capability's bug can never block another's install/remove.
- **Combat-aware update notification** — `NotifyUpdate(capabilityName)` fires a new framework event, `DEVELOPER_RUNTIME_UPDATED` (payload: capability name), immediately if `InCombatLockdown()` is false, or queues it if true, flushed on `PLAYER_REGEN_ENABLED` (registered/unregistered symmetrically with Developer Mode, never running while it's off). Generic across every current and future capability — the Developer Panel (once built) refreshes only the tab matching the payload.

#### ErrorCapture (`Core/Runtime/ErrorCapture.lua`) — the first capability
Hooks the global Lua error handler while Developer Mode is on and `CaptureLuaErrors` is enabled:
- **Interception**: `geterrorhandler()`/`seterrorhandler()`, the same technique `!BugGrabber` uses. The previous handler (Blizzard's default, or another error-capture addon's if present) is captured once at install and **always** called afterward — success or failure of this file's own capture logic. `SuppressBlizzardPopups` (opt-in, default off) is the one exception, and only applies on this file's own successful capture path — if its own logic throws, Blizzard's real handler always still runs. A bug here can never cause an error to go completely unseen.
- **Signature (aggregation key)** — deliberately not the raw message text (two unrelated bugs can share an identical generic Lua error message), and no longer stack-frame matching either (corrected here — this passage previously described an earlier "first two `AC.Name`-matched stack frames" design that a later Stabilization Pass replaced; this doc had gone stale relative to the code). The **primary** source of truth is `ExtractMessageLocation`: Lua's `error()` unconditionally prepends `"chunkname:line: "` to the message before any handler sees it — a fixed, guaranteed format requiring no stack-depth guess at all. The raw stack trace (via `debugstack()`) is only a **secondary** source, cross-referenced solely to recover a function name for readability; location/module/origin never depend on it. Falls back to the raw message text if no parseable prefix exists (rare — e.g. `error()` called with an explicit level of 0).
- **Captured fields** — timestamp (see Persistence below), message, stack trace (if `CaptureStackTraces` on), best-effort module/location/origin (parsed from the message's own prefix, never fabricated if undeterminable), map ID, instance name/difficulty (only if `IsInInstance()`), player name, realm, addon version, WoW build, combat state, occurrence count, first/last seen. Every field is a direct Blizzard getter result or omitted. `playerName`/`realm`/`addonVersion`/`wowBuild`/`inCombat`/`mapID`/`instanceName` are captured once, at first occurrence, and never updated on later aggregation — a deliberate "first-seen snapshot" convention that stays meaningful once history persists across sessions (e.g. `addonVersion` answering "which version did this bug first appear in," not "which version is currently running").
- **Bounded storage** — 200 unique entries (`MAX_UNIQUE_ERRORS`), oldest-first-seen evicted, regardless of whether `AggregateDuplicates` is on (off still bounds total entries, just doesn't merge them). Eviction (`table.remove(self.Errors, 1)`) mutates the persisted array in place — see Persistence below.
- **Settings** — `profile.DeveloperRuntime.ErrorCapture` (`CaptureLuaErrors`, `SuppressBlizzardPopups`, `AggregateDuplicates`, `DelayNotificationsUntilOutOfCombat`, `CaptureStackTraces`), same lightweight profile-table convention `DeveloperModeService`'s own flag and `Logger`'s own `Debug` flag already use. **Per-profile, distinct from the error history itself** (see below), which is account-wide.

#### Error History Persistence

Error History is a **permanent diagnostics record**, not a temporary runtime log — the addon's Developer Panel is intended to durably answer "what has actually gone wrong in this addon, on this account, since I last cleared it," across `/reload`, relog, and full game restart alike. This was a deliberate architecture change, not the original design: prior to this pass, `self.Errors` was a plain in-memory Lua table, reset to empty by every `Initialize()`, with no persisted storage at all — an undocumented gap, not a considered decision (nothing in this doc, prior to this pass, ever stated an intent either way).

- **Storage scope: `Global`, not `Profile` or `Character`.** `AC.DatabaseService:GetGlobal().DeveloperRuntime.ErrorCapture.Errors` (`DatabaseService.lua`'s `Defaults.Global.DeveloperRuntime.ErrorCapture`, `{ SchemaVersion = 1, Errors = {} }`) — the same account-wide tier already established for `VerificationLog`/`ChecklistLog` and `PlayerJournal`, for the identical reason: whether this addon's own code throws is a fact about the account running it, not about which character is logged in. Character-scoping would split one bug into N disconnected histories with no compelling reason to. Nested under a shared `DeveloperRuntime` key (not a flat top-level `Global` entry) so future capabilities named earlier in this section (Warning Capture, Performance Metrics, ...) have a consistent home alongside it.
- **Mechanism — no explicit "save" step.** `ErrorCapture:Initialize()` points `self.Errors` directly at `Global.DeveloperRuntime.ErrorCapture.Errors` — the same table object, not a copy — so every existing `table.insert`/`table.remove` in `OnError`'s aggregation and eviction logic already mutates the persisted SavedVariables table. WoW serializes it to disk automatically at logout/reload, exactly like `PlayerJournalModule`'s/`VerificationService`'s own account-wide data, neither of which has a `Save()` method either. `self.ErrorsByKey` is rebuilt from `self.Errors` on every `Initialize()` — a purely derived lookup index, never itself persisted.
- **Lifecycle boundary: `Clear Errors`, not a setting.** There is no "persist error history" toggle — persistence is the unconditional default, and the existing Clear Errors button is the only way an error is ever removed. `ErrorCapture:ClearErrors()` empties `self.Errors` **in place** (`table.remove` from the end, not `self.Errors = {}`) specifically because reassigning the reference would silently detach it from the persisted table, leaving the "cleared" entries to reappear on the next reload.
- **Timestamp model — absolute, not session-relative.** `firstSeen`/`lastSeen` are now `time()` (Lua epoch seconds), generated in exactly one place (`OnError`'s own `timestamp` local). The previous `AC.Logger:GetPreciseTimestamp()` (`HH:MM:SS.mmm`, relative to the current session's clock) would have become actively misleading once persisted — indistinguishable across different days. Formatted only at display/export time, via Developer Panel's `FormatErrorTimestamp` helper (`AC.Presentation.FormatDate(timestamp, "shortTime")`) — never stored pre-formatted. `occurrenceCount`'s field shape is unchanged; its meaning is now a true cumulative count from first capture until the next Clear, rather than silently resetting every session.
- **Retention** — unchanged 200-entry bound (`MAX_UNIQUE_ERRORS`), now durable rather than session-scoped. No time-based expiry — an error is retained until either evicted by the 200-entry cap or removed by Clear Errors, whichever comes first.
- **Migration** — none required. No prior SavedVariables shape ever stored error history (confirmed by reading `DatabaseService.Defaults` in full before this change), so this is a purely additive default with nothing to reconcile.

#### Reliability Hardening Pass

A dedicated audit pass (before any UI was built, on purpose — "the runtime must be trustworthy before it becomes visible") went through every path where recursion, re-entrancy, or a stuck state could occur.

**Re-entrancy protection.** The function actually registered via `seterrorhandler` is now `ErrorCapture:HandleGlobalError`, guarded by an `IsHandlingError` flag that covers the *entire* operation — both the capture attempt and the chained call to whatever handler was previously installed, not just the capture half. If this function is invoked again while that flag is already true (a genuinely uncertain case — whether calling through to the original handler could itself throw and cause the engine to re-enter our handler is not something static analysis can confirm, flagged `NEEDS_LIVE` below), the re-entrant call skips `OnError` entirely and goes straight to the original handler, itself `pcall`-wrapped. Every branch returns normally — this function is designed so it can never itself throw, under any internal failure, which is what makes "immediately fall back to Blizzard's default error handling, do not recurse" an actual guarantee rather than a best-effort.

**A real correctness bug caught during this pass, not just a defensive addition:** `debugstack()` is called from inside `OnError`, which runs from inside `HandleGlobalError`'s own `pcall` — both `ErrorCapture.lua`'s own frames. Relying on a fixed numeric skip count to land past them would have been guessing at an unconfirmed stack depth; worse, if that guess were even slightly wrong, every captured error's signature would have collapsed to `ErrorCapture.lua`'s own line number instead of the real crash site — silently defeating aggregation entirely (every distinct bug merging into one, the opposite of what the aggregation redesign exists for). Fixed by explicitly excluding any stack line whose file is literally `ErrorCapture.lua` from signature computation, regardless of how many such lines appear or where — correctness no longer depends on knowing the exact call depth.

**Duplicate installation** — already guarded (`if self.OriginalHandler then return end`), re-confirmed sufficient.

**Failed/unsafe removal** — `Remove()` now checks whether `geterrorhandler()` still returns exactly the function object this file itself installed (`InstalledHandler`) before restoring `OriginalHandler`. If some other addon (e.g. `BugGrabber`) installed its own handler on top of ours after our own install, blindly restoring our stored original would silently clobber that other addon's hook — instead, this file forgets its own state and leaves the current handler alone. If the restore call itself fails (`pcall`-wrapped), `OriginalHandler` is deliberately left set rather than cleared, so a later `Remove()` retries instead of silently believing cleanup already succeeded.

**Invalid state transitions** — `Initialize()` now explicitly resets every field (`OriginalHandler`, `InstalledHandler`, `IsHandlingError`), not just the error store, so state is never implicitly relying on Lua's default-nil behavior. `DEVELOPER_MODE_CHANGED(true)` firing twice without an intervening `false` is already structurally prevented upstream by `DeveloperModeService:SetEnabled`'s own no-op guard — no redundant guard added here, since one would just duplicate logic that already can't be reached.

**Capability registration/shutdown errors** — already `pcall`-isolated per-capability via `DeveloperRuntime`'s `SafeCall` (built in the previous pass); re-confirmed this covers `Initialize`/`Install`/`Remove` for every capability, present and future. `RegisterCapability`'s hard error on duplicate registration is deliberately unchanged — it fires only at file-load time on a programming error, the same precedent `ServiceManager:Register`/`ModuleManager:Register` already established.

#### Developer Test Harness (`/ac dev testerror`, `/ac dev clearerrors`)
Exist only while Developer Mode is on (each checks `IsEnabled()` and warns otherwise, same as bare `/ac dev`). `testerror` calls a real, unwrapped `error()` — not a simulation — so it exercises the actual global-handler pipeline end-to-end: capture, signature computation, stack trace, chaining to Blizzard's real handler (still shown, since `SuppressBlizzardPopups` defaults off), and runtime survival. The same source line every time means repeated invocations validate occurrence-count aggregation; any other real error encountered separately validates that a genuinely different bug creates a new entry. `clearerrors` wires the slash command layer to the already-existing `ErrorCapture:ClearErrors()`, useful for resetting between test runs. `/ac dev testwarning` was considered and **deliberately not implemented** — no Warning Capture capability exists yet to validate, so the command would have nothing real to test.

**Deferred, not forgotten**: `VerificationService` registry entries for the two genuinely uncertain Blizzard behaviors found during the original audit (exact argument shape `seterrorhandler`'s function receives; whether errors from protected/secure code paths route through it identically, now sharpened by this pass to specifically include "whether the engine re-enters a handler that itself throws while chaining to a previous handler") — not yet added as real registry rows. Developer Panel "Errors" tab — next phase, now on a runtime that's been deliberately tested rather than only reasoned about.

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
- `storage.bankerInteraction` — `Enum.PlayerInteractionType.Banker` / `AccountBanker` are documented, while the exact `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` payload timing still requires a live Character Bank and Warband Bank check.
- `mp.eventOrdering` — the relative firing order of the 7 registered Challenge-Mode/Mythic-Plus events during a real run remains unconfirmed; confirming an event exists is not the same as confirming when it fires.

---

### 1.11 Player Journal & Community Notes

The first flagship *new gameplay system* since v1.0 Polish began — a local database of players you've grouped with in Mythic+ (identity, objective stats, personal notes, personal tags, a bounded timeline), plus an optional, disabled-by-default Community Notes layer. Audited and designed (Plan Mode, with the user resolving two genuine open risks directly) before any code was written, per the feature's own brief.

#### The deliberate decision Section 1.4 deferred

Section 1.4's own Future Extension Points entry on "Party composition" explicitly deferred storing facts about other players, reasoning that full named specs would need the heavier `NotifyInspect`/`INSPECT_READY` path, and that "this needs a deliberate decision before any code is written here, not a default." That deferral was scoped to `MythicPlusModule` specifically — `RunTracking` there remains entirely self-only, unmodified by this feature. The deliberate decision is made here instead, in a **new** module: `PlayerJournalModule` becomes the one new owner of party-member facts (Architectural Rule 1 — one owner per fact), using only basic roster reads (`UnitFullName`/`UnitGUID`/`UnitClass`/`UnitGroupRolesAssigned`) and a narrowly-filtered `COMBAT_LOG_EVENT_UNFILTERED` (`UNIT_DIED`/`SPELL_INTERRUPT`, roster members only) — never the full-inspect path that was the actual thing being avoided.

#### PlayerJournalModule (`Modules/PlayerJournal/PlayerJournalModule.lua`)

**Storage scope:** `DatabaseService:GetGlobal().PlayerJournal` — account-wide, not per-character and not a `ConfigurationManager` profile. `ConfigurationManager` is profile-backed (shareable across characters via profile-switching, wrong for private data about other players); `ActivityHistoryService`'s own per-character storage exists because a *run* happened to a specific character, but recognizing a past companion is a fact about the account/person playing, not about which alt was logged in — the same reasoning this addon's own `VerificationService` already established for its account-wide `VerificationLog`/`ChecklistLog`.

**Player key:** `"Name-Realm"`, dash-separated — deliberately the opposite format from `DatabaseService:GetCharacterKey()`'s `"Realm.Name"`, so a companion's key can never be visually confused with one of your own character keys.

**Run-tracking event flow:** `CHALLENGE_MODE_START` snapshots the party roster (self excluded); `GROUP_ROSTER_UPDATE` runs a grace-period leave check (a roster member missing for 5 seconds, with the run still active, is marked left-early — an addon-side heuristic, not a documented Blizzard behavior, flagged `pj.rosterLeaveDetection`); a run-scoped, pcall-registered `COMBAT_LOG_EVENT_UNFILTERED` tallies `UNIT_DIED`/`SPELL_INTERRUPT` for roster GUIDs only (mirroring `MythicPlusModule`'s own defensive-registration and player-only-filtering precedent, just applied to roster members too); `CHALLENGE_MODE_COMPLETED` snapshots this module's own state, then defers the actual finalization one frame via `C_Timer.After(0, ...)`.

**Why the one-frame defer:** confirmed by reading `Core/Events/EventManager.lua`'s own `DispatchBlizzard` — listeners for the same event fire in registration order, itself a function of `.toc`/`ModuleManager.Order` load order. Relying on "`MythicPlusModule`'s handler happens to run first" would be exactly the kind of silent, breakable coupling this document already warns against elsewhere. A timer (even 0-delay) only ever fires on `OnUpdate`, strictly after the current frame's event-dispatch loop fully completes — so by the time `FinalizeCompletedRunForRoster` runs, `MythicPlusModule:RecordCompletedRun()` has already appended its `ActivityHistoryService` record regardless of registration order. Correct by inspection of this addon's own code; flagged `pj.eventOrderingDefer` since it hasn't been watched happen in a real client.

**Reuse, not duplication (Architectural Rule 7):** dungeon/level/timed/rating-change facts are read from `MythicPlusModule:GetRecentRuns(1)` — the same public getter the Dashboard already uses — never recomputed. "Average Rating Gain" per companion is therefore the run's overall score change applied identically to every roster member present, not a true per-player Blizzard stat (none exists); documented inline rather than presented as if it were player-specific.

**Pruning:** Favorites (`tags["FavoritePlayer"] == true`) are exempt from both the hard cap (`maximumStoredPlayers`) and inactivity auto-pruning — the one thing the feature's own brief explicitly calls out as protected.

#### CommunityModule (`Modules/Community/CommunityModule.lua`)

Fully independent of `PlayerJournalModule` — its own top-level storage key (`DatabaseService:GetGlobal().PlayerJournalCommunity`, never nested under `PlayerJournal`'s own table), its own `ConfigurationManager` namespace (`"Community"`), its own Settings page. This file never references `PlayerJournalModule` at all; notes are keyed by the same `"Name-Realm"` format as a shared convention, not a dependency. This independence is what makes "`PlayerJournalModule` works perfectly with `CommunityModule` disabled" a structural fact rather than a currently-true one that could silently regress.

Disabled by default. Fully local this version — no sync backend, no server, no addon-channel broadcast exists yet, so a Community Note is only ever visible to the account that wrote it regardless of its own `visibility` field (captured now for a future backend, zero rendering effect today — documented inline so it isn't mistaken for a bug). Helpful/Not Helpful/Report/Hide are real functions with real local counters, but the UI controls that call them are disabled with a "Coming soon" tooltip rather than clickable — a clickable vote/report button implying real crowd feedback exists would misrepresent a fully local stub.

#### PlayerJournalWindow (`Core/UI/PlayerJournal/`)

A spine (`PlayerJournalWindow.lua`) plus one file per tab under `Tabs/` — the same spine-and-pages split used under `Core/UI/Dashboard/`, not `DeveloperPanel.lua`'s single-file-many-methods shape, since Personal/Community Notes need real editable widgets (multi-line `EditBox` via `InputScrollFrameTemplate`, tag toggle grids, `StaticPopupDialogs` wiring) — Dashboard-page-scale complexity, not read-only-fact-dump scale. Seven tabs: Overview, History, Statistics, Personal Notes (also hosts the Personal Tags toggle grid — no dedicated Tags tab exists in the window's own 7-tab list, and tags are subjective/personal data like notes), Community Notes, Timeline, Search.

`Show(playerKey)` takes a stable id, not a live object — a deliberate divergence from `RecommendationInspector:Show(recommendation)`, which takes a live object specifically because Recommendations are rebuilt from scratch every refresh with no stable identity. Journal records have a real stable identity (`"Name-Realm"`), so re-reading by id on every tab switch/refresh is both correct and simpler.

**Statistics tab** uses a cool blue accent color, visually distinct from Personal Notes/Tags' own warm gold accent elsewhere in the window — per the feature's own requirement that objective statistics always read as visually separate from personal opinion.

**End-of-run prompt:** `PlayerJournalModule` fires a new framework event, `PLAYER_JOURNAL_RUN_RECORDED` (added to `EventManager.FrameworkEvents`), rather than calling `StaticPopup_Show` directly — the same "service/module fires, UI listens" split `NotificationService`'s own `NOTIFICATION_CHANGED` already established. `PlayerJournalWindow` is the intended listener, opening on the Search tab pre-filtered to that run's roster.

#### First Blizzard-UI hooks (`Core/UI/PlayerJournalContextMenu.lua`, `Core/UI/PlayerJournalTooltip.lua`)

This addon's first hooks into Blizzard-owned UI frames — confirmed via repo-wide grep before writing either file that zero existing precedent existed anywhere else in the codebase (every prior `GameTooltip` usage was this addon's own frames showing the standard tooltip widget, never modifying Blizzard's own tooltip-population pipeline or a unit context menu).

**Context menu:** `Menu.ModifyMenu(tag, callback)` — the current, post-Dragonflight menu API (confirmed via Warcraft Wiki's own Blizzard Menu implementation guide). Calling `:CreateButton()` again on the element `:CreateButton()` just returned promotes it to a submenu automatically — exactly one "Azeroth Companion" entry added to Blizzard's own menu, matching the feature's own "keep the Blizzard context menu clean" requirement. The exact `MENU_UNIT_*` tag name for "any party member regardless of slot" could not be pinned down without a live client (the wiki confirms the `MENU_UNIT_<UNIT_TYPE>` format with `PARTY1` as one example, not whether a slot-independent tag also exists) — registered defensively against every plausible tag, each in its own `pcall` so one bad tag name never breaks the others (a `Menu.ModifyMenu` registration for a tag that never fires is a harmless no-op, unlike `RegisterEvent` on a nonexistent event, which throws). Flagged `ctxmenu.unitMenuTags`. Nothing else in this feature depends on this hook succeeding — the window opens via the minimap icon, slash command, and Dashboard regardless.

**Tooltip:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, callback)` — the current, standard tooltip-extension technique (confirmed via real published addon source), superseding the legacy `OnTooltipSetUnit` script hook. Gated on one master "Show Journal Info in Tooltips" setting; adds only lines with real data (Runs Together, Last Seen, a note preview, a Favorite glyph, a Community Note count) and renders nothing at all for a player with no journal record.

**Stabilization pass — two confirmed live errors, one architectural root cause.** Live testing hit `bad argument #1 to UnitIsPlayer() ... Secret values are only allowed during untainted execution` (calling `UnitIsPlayer` on `tooltip:GetUnit()`'s returned unit token). The first fix replaced the unit token with the postcall's own `data.guid` field — which then hit a second, equally real error: `attempt to index local 'guid' (a secret string value, while execution tainted by AzerothCompanion)`. Both failures are the same policy, not two separate bugs: Blizzard now treats **every** unit-identifying value reachable from inside a `TooltipDataProcessor` postcall as secret — opaque to addon code — regardless of which specific field or API is used to reach it. There is no "safe" identity field hiding in this callback to find; the correct fix is to stop resolving identity from inside it at all (`pcall` was explicitly not an option either time — the dependency itself was wrong, not merely fallible).

**Redesigned architecture:** identity is now resolved entirely *outside* the tooltip callback, in ordinary Blizzard event handlers (`GROUP_ROSTER_UPDATE`, `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`) — the same trusted `UnitFullName`/`UnitGUID`-on-a-plain-global-token pattern this addon's own roster capture already uses and has verified (`pj.rosterUnitAccessors`), generalized from `party1`-`4` to a few more always-legal tokens (`player`/`target`/`focus`/`mouseover`). These are ordinary events reacting to ordinary unit tokens — nothing here ever touches a value that originated from inside a secure UI callback, so nothing here can be "secret." Results cache into `KnownUnits` (display name, and name-realm form, → `playerKey`; a same-text collision between two different real players marks that key ambiguous rather than guessing). The `TooltipDataProcessor` postcall itself now does only what that API is actually documented and intended for: reads the tooltip's own **rendered name line** (`data.lines[1].leftText`, stripped of class-color escape codes) and looks it up in `KnownUnits` — never `tooltip:GetUnit()`, never `data.guid`, never any unit token, anywhere in the callback.

This design rests on two things not yet independently confirmed against a live client, flagged in `VerificationService` rather than asserted with the same confidence as everything above: `pj.knownUnitsCache` (`WIKI`, High — the identity-resolution side, trusted by extension of the already-verified pattern) and `pj.tooltipLineTextSafe` (`NEEDS_LIVE`, Medium — whether `data.lines` line text itself is truly safe, and whether a Unit tooltip's first line is reliably the plain name). Given this addon has now been wrong twice reasoning about which tooltip-adjacent value is safe, that second flag is deliberate honesty, not boilerplate — if it too proves wrong, the documented escalation (in the file's own header) is to stop reading `GameTooltip`'s content at all and decorate via a fully separate, addon-owned frame, not another attempt to parse tooltip internals more cleverly. `VerificationService`'s registry reflects the full history: `tooltip.postCall` (registration mechanism, still `WIKI`/confirmed) → `tooltip.getUnitSecretValue` (`INCORRECT`, first error) → `pj.tooltipDataGuid` (`INCORRECT`, second error, promoted from an earlier `NEEDS_LIVE` guess once actually confirmed) → `pj.knownUnitsCache` + `pj.tooltipLineTextSafe` (the current design).

**Startup-order bug, confirmed via a real `/reload` Lua error, root cause not in the Runtime.** `RefreshKnownUnits()`'s initial cache-seed call executed unconditionally at file-load time — but its body calls `AC.ConfigurationManager:GetValue(...)`, which unconditionally calls `AC.DatabaseService:GetProfile()`, and `DatabaseService.DB` is only set inside `DatabaseService:Initialize()`. This file is a bare UI hook, not a registered Service/Module, so it has no `Initialize()`/`Enable()` the framework calls at the right time — its own top-level code runs the instant WoW loads the file, a phase distinct from and earlier than framework bootstrap (`Core:Initialize()`, triggered by `ADDON_LOADED`, which only fires after every `.toc` file has finished loading). The bug was conflating "my file finished loading" with "the framework is ready." Fixed by deferring the initial call to the already-existing `FRAMEWORK_INITIALIZED` framework event (fired once, as the last step of `Core:Initialize()`, after `ServiceManager:Initialize()` — and therefore `DatabaseService:Initialize()` — has already run) rather than inventing a new lifecycle event; no other file currently listens to it, but the general pattern (register at file-load time, defer real work to when the event fires) is the same convention every other framework-event listener in this codebase already uses. The four real-game-event registrations (`GROUP_ROSTER_UPDATE` etc.) were never the problem — registering a listener is pure `EventManager` bookkeeping regardless of framework state; only *invoking* `RefreshKnownUnits()` early was.

**Framework stabilization audit, full codebase, triggered by the bug above.** Every `.lua` file in the addon (105 total) was swept for the same shape of bug — an unconditional top-level statement that reaches a framework service before that service is ready — via exhaustive pattern search (every bare top-level function call, every top-level `if`/`for`/`while` block, every top-level `local` assignment referencing `AC.ConfigurationManager`/`AC.DatabaseService`/`AC.L`/`AC.LocalizationService`) cross-checked against each hit's enclosing scope. `PlayerJournalTooltip.lua` was the only confirmed violation in the entire codebase. This file (`PlayerJournalContextMenu.lua`) is the only other bare UI hook with no Service/Module registration, making it the closest structural lookalike — but its own top-level call, `RegisterContextMenuHooks()`, was confirmed correct as-is: it only reaches Blizzard's own `Menu.ModifyMenu` (a client-owned API, not one of this addon's own framework services) and `AC.Logger` (confirmed deliberately safe to call at any time — `Logger.Buffer` is populated at file-load time, not inside `Logger:Initialize()`, and `Logger:Warn`/`Error`/`Info` never touch `DatabaseService`; unlike `ConfigurationManager`, which assumes its callers already respect the lifecycle, `Logger` is intentionally self-sufficient so a logging call can never itself be the thing that crashes startup). `AddPlayerJournalSubmenu`, the callback that does reach `AC.L`/`AC.Core:GetModule`, only ever runs when a player actually right-clicks a unit — necessarily well after framework startup has finished — so it was never at risk. Every Module and Service in the codebase was also confirmed to follow the same correct shape already: top-level file code registers (`AC.Core:RegisterModule`/`AC.ServiceManager:Register`/`AC.WidgetManager:RegisterWidgetType`, all pure bookkeeping), and every call that actually reaches another framework service happens inside `Initialize()`/`Enable()`, which the framework itself only invokes after `ServiceManager:Initialize()` — and therefore `DatabaseService:Initialize()` — has already run (guaranteed by `DatabaseService.lua` being first in the `.toc`, hence first in `ServiceManager.Order`). No other confirmed or suspicious lifecycle violation was found; no dead code, duplicated initialization, or stale lifecycle comment was found either.

#### Secret Value Audit — full callback inventory, shared guard introduced

Triggered by live reports of runtime errors while hovering NPCs and interacting with Blizzard UI inside Mythic+ dungeons (e.g. Algeth'ar Academy), and by research confirming other retail addons (TooltipInfo, TooltipExtraData, Rarity, Quester) hit the same class of failure after Blizzard tightened Secret Value / `TooltipDataProcessor` restrictions. Scope: every place this addon's own code could receive a value from inside a Blizzard **secure** callback dispatch, not merely every place it calls a `Unit*` API — the distinction that structures this whole audit (see "The actual risk surface" below).

**Methodology.** Repo-wide grep for `TooltipDataProcessor`, `Menu.ModifyMenu`, `HookScript`, `SetScript(`, `securecallfunction`, `GameTooltip`, `GetUnit(`, `UnitGUID`/`UnitExists`/`UnitFullName`/`UnitIsPlayer`/`UnitName`/`UnitClass`/`UnitRace`/`UnitLevel`/`UnitFactionGroup`, `Gossip`, `Merchant`, `Inspect`, `UnitPopup`, `OnTooltipSetUnit`, `ContextData`/`contextData`, then every hit read in full context (enclosing function, what registered it, what token/value it operates on).

**The actual risk surface, precisely scoped.** A "Secret Value" is not "any Blizzard data might be untrustworthy" — it is a specific opaque type Blizzard's **secure/protected UI dispatch** can hand to an addon callback, which throws the instant addon code reads/compares/concatenates/indexes it. Secrecy is injected by *how a value reached the callback* (from inside Blizzard's own secure callback machinery), not by *which API is later called on it*. Ordinary `:RegisterEvent`/`SetScript("OnEvent", ...)` handlers and ordinary scripts on addon-owned frames (`CreateFrame(...)` then `:SetScript("OnClick"/"OnEnter"/"OnLeave", ...)`) are never secure/tainted contexts and cannot receive secret values, regardless of which `Unit*`/`GUID` call happens inside them. Only two Blizzard APIs in this entire codebase register a callback into that secure family:

1. `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, callback)` — exactly one registration, `Core/UI/PlayerJournalTooltip.lua`.
2. `Menu.ModifyMenu(tag, callback)` — exactly one registration site (looped over 9 player-related tags), `Core/UI/PlayerJournalContextMenu.lua`.

Confirmed via repo-wide grep: no other `TooltipDataProcessor`/`Menu.ModifyMenu` registration exists, no `HookScript` call exists in this addon's own code (the only two `HookScript` calls in the whole tree are inside the third-party `LibDBIcon-1.0` library, hooking `Minimap`'s `OnEnter`/`OnLeave` for its own tooltip — a standard, battle-tested library pattern, unrelated to unit identity), and this addon hooks no Gossip/Merchant/Inspect/`UnitPopup` frame at all.

**1. Complete callback inventory.**

| Callback | Registered by | Context | Unit tokens/values touched |
|---|---|---|---|
| `TooltipDataProcessor.AddTooltipPostCall(Unit)` | `PlayerJournalTooltip.lua` | Secure (Blizzard tooltip dispatch) | `data.lines[1].leftText` only |
| `Menu.ModifyMenu` (9 player/party/raid/friend/guild tags) | `PlayerJournalContextMenu.lua` | Secure (Blizzard menu dispatch) | `contextData.unit`/`.name`/`.server`/`.realm` |
| `GROUP_ROSTER_UPDATE`/`UPDATE_MOUSEOVER_UNIT`/`PLAYER_TARGET_CHANGED`/`PLAYER_FOCUS_CHANGED` | `PlayerJournalTooltip.lua` (`RefreshKnownUnits`) | Ordinary event | Literal tokens `player`/`party1-4`/`target`/`focus`/`mouseover` |
| `GROUP_ROSTER_UPDATE` (roster tracking) | `PlayerJournalModule.lua` | Ordinary event | Literal `PARTY_UNITS` tokens |
| `COMBAT_LOG_EVENT_UNFILTERED` (`SPELL_INTERRUPT`) | `MythicPlusModule.lua` | Ordinary event | Literal `"player"`, plus combat log's own `sourceGUID` (a different Blizzard data source, not secure-UI-dispatched) |
| `PLAYER_ENTERING_WORLD`/refresh triggers | `CharacterModule.lua` | Ordinary event | Literal `"player"` only |
| Character-key generation | `DatabaseService.lua` | Ordinary (called from `Initialize()`/`GetCharacterKey()`) | Literal `"player"` only |
| Error metadata capture | `ErrorCapture.lua` | Ordinary (error handler) | Literal `"player"` only |
| `HookScript("OnEnter"/"OnLeave")` on `Minimap` | `LibDBIcon-1.0` (third-party library) | Ordinary UI script | None — minimap tooltip only |
| Every other `SetScript`/`HookScript` in the codebase | Addon-owned frames (buttons, sliders, rows) | Ordinary UI script | None — no unit identity involved |

**2. Confirmed unsafe callbacks.** None currently open. Two were confirmed unsafe by real, repeated in-game Lua errors in an earlier pass (`tooltip.getUnitSecretValue` — `tooltip:GetUnit()`'s return value; `pj.tooltipDataGuid` — the postcall's own `data.guid` field) and were removed from `PlayerJournalTooltip.lua` entirely, replaced by the `KnownUnits` cache architecture described above. Neither pattern exists anywhere in the codebase today (confirmed via grep).

**3. Suspicious callbacks (`NEEDS_LIVE` in `VerificationService`).**
- **`pj.tooltipLineTextSafe`** — `data.lines[1].leftText`, read inside the `TooltipDataProcessor` postcall. Elevated priority this pass: this postcall fires for **every** unit tooltip, players and NPCs alike (`Enum.TooltipDataType.Unit` is not player-scoped), so it is exercised far more heavily in NPC-dense content like Mythic+ dungeons than in open-world play — consistent with reports of errors specifically while hovering NPCs there. Never independently confirmed either way.
- **`ctxmenu.contextDataUnitSecretValue`** — `contextData.unit`, read inside the `Menu.ModifyMenu` callback, then passed to `UnitExists`/`UnitFullName`. Structurally identical to the two already-confirmed-broken tooltip patterns (a unit-identifying value obtained from inside a secure callback, passed to a normal `Unit*` API) but for a different Blizzard callback family. Previously flagged but left unguarded while awaiting live confirmation.

**4. Recommended shared helper — built and applied this pass.** `AC.SecretValueGuard:TryRead(context, fn, ...)` (`Core/Security/SecretValueGuard.lua`, new file, no lifecycle — same shape as `Core/Presentation/Presentation.lua`) is the one place this addon now attempts a read of Blizzard secure-callback data that might be secret. `pcall`-wraps `fn(...)`, forwards every return value on success (table-packed, so it works for a one-value read or a name+realm pair without the caller special-casing arity), returns nothing on failure, and Debug-logs the caught error under a short caller-supplied `context` label. This is deliberately **not** the same thing as the nil-guards/pcall/early-returns the framework-stabilization pass explicitly rejected for this addon's own lifecycle bug: that rejection was about masking a bug in code this addon fully controls (an ordering mistake with one correct fix); this is a defensive boundary at the edge of code this addon does not control, whose secrecy policy is Blizzard's own undocumented, per-callback, per-patch decision that has already changed twice under this exact feature. There is no way to inspect a value in advance and learn whether it is secret — attempt-and-catch is the only defensible technique here, the same one every other addon hooking these same Blizzard callbacks has converged on. The guard is deliberately **not** applied to any of the ordinary-event-handler `Unit*` calls in the inventory above (`CharacterModule`, `MythicPlusModule`, `PlayerJournalModule`'s roster tracking, `DatabaseService`, `ErrorCapture`) — none of them touch a secure-callback-sourced value, so wrapping them would just be unnecessary defensive noise around code that was never at risk, exactly the kind of blanket paranoia the framework-stabilization pass's own rejection of speculative nil-guards warned against.

**5. Files changed.** New: `Core/Security/SecretValueGuard.lua` (added to `.toc` right after `Core/Presentation/Presentation.lua` — same "generic leaf utility, loads early" tier). Changed: `Core/UI/PlayerJournalTooltip.lua` (`data.lines[1].leftText` read now goes through `TryRead`), `Core/UI/PlayerJournalContextMenu.lua` (`contextData` read — both the `unit` path and the `name`/`server` fallback — now goes through one `TryRead` call), `Core/Services/VerificationService.lua` (both affected registry entries' `citation`/`expected` fields updated to describe the new guarded, graceful-degradation behavior instead of an open crash risk).

**6. Live verification checklist** (surfaced via `/ac dev` → Checklist tab, `PlayerJournalTooltip`/`PlayerJournalContextMenu` scenarios, already wired to these registry ids):
- Hover several NPCs in a Mythic+ dungeon (trash, critters, quest NPCs) with Debug logging on (`/ac trace` or equivalent) — confirm no visible Lua error, and check whether `"Secret-value read blocked (tooltip.lineText)"` appears in the log. If it never appears, `pj.tooltipLineTextSafe` can be promoted from `NEEDS_LIVE` to `WIKI`/confirmed. If it does appear, the tooltip enhancement is silently skipping for NPCs — journal info should still work correctly for real players, since the two are independent per-tooltip lookups.
- Hover several real players (party members, raid members, random players) in and out of a dungeon — confirm journal info still renders as before (no regression from the guard).
- Right-click a party member, a raid member, a guild member, and a friend — confirm the "Azeroth Companion" submenu still appears with working Quick Note/Favorite/Copy Link entries. If it silently stops appearing for one of these, check Debug logging for `"Secret-value read blocked (ctxmenu.contextData)"` — that would confirm `ctxmenu.contextDataUnitSecretValue` and settle it from `NEEDS_LIVE` to `INCORRECT`.
- Repeat both of the above inside active combat (a pull) and inside a Mythic+ dungeon specifically, not just open world — this addon's own reading of Blizzard's Secret Value system is that it is orthogonal to combat lockdown (a separate mechanism restricting protected-frame *actions*, not data *reads*), so behavior should not differ between combat/non-combat or instance/world — but this has not been independently confirmed and is exactly the kind of assumption this addon has been wrong about before.

#### Secret Value Diagnostics Hardening Pass — structured `TryRead`, a Developer Runtime capability, Developer Panel tab

A follow-up pass making the audit above a durable, self-diagnosing subsystem instead of a one-time fix — the explicit goal being that a *future* Blizzard secret-value policy change (a third or fourth field, a new secure callback family) is something this addon can see happening from the Developer Panel, not something that requires another live-error-driven investigation from scratch.

**Framework boundary, restated precisely.** `AC.SecretValueGuard` exists for exactly one purpose: bridging a read of data that arrived *from inside Blizzard's own secure callback dispatch* (currently: a `TooltipDataProcessor` postcall's own parameters, a `Menu.ModifyMenu` callback's own `contextData`). It is never used around this addon's own ordinary logic — a real bug in this addon's own code must still fail normally, exactly as the framework-stabilization pass already established for the lifecycle bug, so it can be found and fixed rather than silently absorbed. `TryRead` enforces this distinction itself now (see "Runtime behavior" below) rather than relying on every call site to reason about it correctly.

**`TryRead`'s new structured contract:** `ok, value, result = AC.SecretValueGuard:TryRead(context, fn, ...)`. `fn` should return exactly one value (wrap multiple fields in a table, e.g. `PlayerJournalContextMenu.lua`'s `{ name = ..., realm = ... }`, rather than relying on Lua's multi-return-forwarding — a deliberate simplification over the guard's first draft, which forwarded `pcall`'s full return list; a fixed, predictable arity is easier to reason about at every call site than "however many values `fn` happened to return"). `result` is a plain table: `status` (one of `SUCCESS`/`SECRET_VALUE_BLOCKED`/`CALLBACK_EXCEPTION`/`UNKNOWN_EXCEPTION`), `context`, `source` (everything before the first `.` in `context` — e.g. `"tooltip"` from `"tooltip.lineText"` — a coarser grouping for the Developer Panel and logging, derived automatically rather than a second parameter every call site would need to pass), `message`, `stack` (`debugstack()` at failure time), `timestamp`. Ordinary call sites never need to touch `result` at all — `local ok, displayName = AC.SecretValueGuard:TryRead(...)` reads exactly as simply as before; `result` exists purely for the diagnostics consumers below.

**Runtime behavior — the "do not hide bugs" guarantee, enforced in code, not just in a comment.** `TryRead` classifies every failure via `IsSecretValueError(message)` (a centralized heuristic: both real errors this addon has hit contain the word "secret" prominently — updating this one function is now the only place a future Blizzard wording change needs to be taught). If the failure IS a secret-value error, it is absorbed (`ok = false`, no error propagates) — this is the guard's entire reason to exist. If the failure is anything else (a real bug in the wrapped `fn`, e.g. `CALLBACK_EXCEPTION` for a normal Lua error, or `UNKNOWN_EXCEPTION` for a non-string error value), `TryRead` records it for diagnostic context and then **re-throws it** (`error(valueOrError, 0)`) — the bug propagates exactly as if the guard were not there, reaching the normal error pipeline (`ErrorCapture`, if installed) instead of disappearing into a diagnostics tab nobody is required to open. A `CALLBACK_EXCEPTION`/`UNKNOWN_EXCEPTION` entry therefore deliberately appears in **both** the Secret Values tab (with the secure-callback context: which boundary, which classification) and the Errors tab (the actual crash) — complementary views of the same event, not a duplicate.

**Diagnostics flow.** `TryRead` → (on any failure) → `AC.DeveloperRuntime:GetCapability("SecretValueEvents"):Record(result)` → aggregated, occurrence-counted, Debug-logged → `AC.DeveloperRuntime:NotifyUpdate("SecretValueEvents")` (combat-aware, same as `ErrorCapture`) → `AC.Events:Fire("DEVELOPER_RUNTIME_UPDATED", "SecretValueEvents")` once combat-safe → Developer Panel's Secret Values tab refreshes live if it's the currently-shown tab.

**Aggregation.** `Core/Runtime/SecretValueEvents.lua` (new file, the second Developer Runtime capability after `ErrorCapture`) keys events by `context .. "|" .. status` — the same recurring event (same call site, same failure classification) coalesces into one entry with a growing `occurrenceCount`/`lastSeen`, capped at 200 unique entries (FIFO eviction), identical shape to `ErrorCapture`'s own `MAX_UNIQUE_ERRORS` aggregation. A misbehaving tooltip hook hammering this on every NPC hover in a dungeon therefore produces one growing counter, never log or entry spam.

**Structured logging.** `SecretValueEvents:Record` Debug-logs a multi-line, labeled block per event (`[SecretValueGuard]` / `Context:` / `Status:` / `Reason:` / `Occurrences:`) instead of the prior single generic sentence — the running `occurrenceCount`, not a fixed "1", so a repeated Debug log line reads as "this keeps happening," not "this happened once."

**Developer Mode gating, matching `ErrorCapture`'s own philosophy exactly.** `SecretValueGuard`'s `pcall` protection is **never** gated — every player, Developer Mode on or off, is protected from a crash at these two boundaries at all times; that is a correctness guarantee, not a diagnostic feature. What IS gated on Developer Mode (via `SecretValueEvents:Install()`/`Remove()`, called by `DeveloperRuntime` exactly like every other capability) is only whether an event gets *recorded* for the Panel to show — a player who never opens Developer Mode pays no memory cost for a tab they will never see, the same trade-off `ErrorCapture` already makes for captured errors.

**Developer Panel integration — reused, not duplicated.** The new "Secret Values" tab (`Core/UI/DeveloperPanel.lua`) is a structural mirror of the Errors tab: same `AC.Dashboard:LayoutAccordionRows` engine, same collapsed/detail-field primitives (`SetAccordionDetailField`/`SetAccordionDetailDescription`), and direct reuse of three helpers that were Error-tab-only in name only — `TruncateErrorMessage`/`AddErrorDetailHeader`/`HideErrorDetailHeader` were renamed to `TruncateMessage`/`AddDetailHeader`/`HideDetailHeader` (their logic was already fully generic; only the name implied otherwise) so the Secret Values tab could call them directly instead of carrying a second copy. Copy JSON/Copy Text/Copy Summary needed zero new code — both tabs populate the same generic `self.CurrentTabData`/`self.CurrentTabSummaryLines` fields the shared footer buttons already read from. Columns requested (Context/Count/Last Seen/Status/Message) render as the same stacked-line collapsed-row shape the Errors tab already established, not a literal grid — consistent with every other log-style list in this file. `CALLBACK_EXCEPTION`/`UNKNOWN_EXCEPTION` rows render in the `critical` color (a real bug); `SECRET_VALUE_BLOCKED` renders `dim` (the expected, designed-for outcome, not an alarm).

**Verification.**
1. **Every place `SecretValueGuard` is currently used:** exactly two — `Core/UI/PlayerJournalTooltip.lua` (`context = "tooltip.lineText"`, guarding `data.lines[1].leftText`) and `Core/UI/PlayerJournalContextMenu.lua` (`context = "ctxmenu.contextData"`, guarding `contextData.unit`/`.name`/`.server`/`.realm`).
2. **Every place it should eventually be used:** nowhere else *today* — confirmed via the callback inventory above, no other secure-callback registration exists in this codebase. The design is explicitly ready for the day one does: any future `TooltipDataProcessor`/`Menu.ModifyMenu` hook, or a future `Gossip`/`Merchant`/`Inspect` hook (none of which this addon has built, and none of which should be built speculatively ahead of a real feature needing one) would wrap its own secure-callback-sourced reads in `TryRead` the same way, with its own `context` string, and would automatically get aggregation/logging/Panel visibility for free — no new plumbing required.
3. **Remaining Blizzard callback boundaries worth monitoring:** none currently hooked by this addon beyond the two above. If a future pass adds a Gossip/Merchant/Inspect-frame integration, that is the next boundary to wrap on day one, not after a live error.
4. **Assumptions still requiring live verification:** unchanged from the audit above — `pj.tooltipLineTextSafe` and `ctxmenu.contextDataUnitSecretValue` are both still `NEEDS_LIVE`; this pass makes them safe to leave unresolved (no crash risk either way) and, for the first time, self-reporting — the Secret Values tab is now the direct answer to "did this happen," rather than requiring a player to reproduce a crash and paste a stack trace.

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

### 2.8 Delves *(implemented after its dedicated API audit; retained here for historical ordering)*

#### Purpose
Owns authoritative Delve completion detection, active-Delve state, and tracked Delve completion statistics.

#### Intended ownership
`DelvesModule`, independent from MythicPlusModule. It writes completed Delve records through `ActivityHistoryService` and exposes active/tracked facts through public getters; the Dashboard composes those facts without taking ownership.

#### Candidate Blizzard API namespaces
`SCENARIO_COMPLETED`, `C_DelvesUI.HasActiveDelve()`, `C_ScenarioInfo.GetScenarioInfo()`, and `C_DelvesUI.GetActiveDelveTier()`. A reported tier of zero remains unknown rather than being inferred.

#### Example Dashboard information
The `Dungeons` page shows active Delve state, recent tracked Delves, tracked completion count, and highest tracked tier alongside an honest empty Dungeon Overview prepared for future general-dungeon owners. Mythic+ analysis remains on the separate `MythicPlus` page.

#### Possible Insights
None currently produced.

#### Possible Recommendations
None currently produced.

#### Out of Scope
Companion progression, Delve currencies, Bountiful Delve discovery, weekly reward interpretation, and fabricated seasonal statistics. Each requires its own authoritative API and ownership audit before inclusion.

---

## 3. Architectural Rules

These rules govern every module, existing or planned. They are not suggestions — a change that violates one of these needs to revisit the architecture first, per the project's stated philosophy, not route around it.

1. **Gameplay data has exactly one owner.** If two modules could plausibly own the same fact, that is a signal to stop and resolve the ambiguity (see Section 5, Decision Tree) before writing code — not to pick one arbitrarily or split it across both. (This is a data-ownership rule — which *module* computes a fact. For the presentation-layer sibling of this same discipline — which *screen* is the one place a player reads it — see Rule 16, One Fact, One Home.)
2. **The Dashboard never gathers gameplay data directly.** It never calls a Blizzard API or reads SavedVariables itself. Gameplay facts come from gameplay-module public APIs; cross-module chronological presentation may read `ActivityHistoryService`'s public query API because that service is the authoritative persisted stream written by those modules. This does not transfer gameplay ownership to the Dashboard or the service.
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

### Presentation & UX Architecture

Rules 1–15 above govern data and module boundaries: which module owns a fact, and how it is allowed to flow outward. The rules below govern a different layer — once a fact is owned and flowing correctly, where, how much, and in what shape any given screen should actually show it. Rules 16–17 were established following the Information Architecture Audit (2026-07-14): every duplication finding in that audit turned out, in hindsight, to be a violation of one of these two principles, which the project simply hadn't written down until then. Rules 18–20 were added during the Product Polish & UX Architecture pass (2026-07-14) that followed, extending the same layer with screen-level responsibility, component reuse, and a bias toward deletion. Reviewed against Rules 1–15 at each addition — none of the existing fifteen are obsoleted, and none overlap closely enough to merge; Rules 1–15 answer "who computes this," Rules 16–20 answer "who shows this, how much, and in what shape." Both categories stay, side by side, as this document's full architectural rule set.

16. **One Fact, One Home.** Every piece of information should have one authoritative location. Other pages may summarize, reference, or link to it, but they should not duplicate it without a clear player-facing reason. When auditing future features, treat unnecessary duplication as a design bug — the same discipline Rule 1 already applies to module ownership, applied here to screens instead of modules. A fact can have exactly one owning module (Rule 1) and still end up wrongly duplicated across three screens (Rule 16); the Information Architecture Audit's clearest findings — Mythic+'s "Best Timed" vs. "Highest Timed," Player Journal's Overview tab vs. its Statistics tab — were never data-ownership violations, since RecommendationEngine and PlayerJournal already owned those facts correctly. The bug lived entirely at the presentation layer, which is exactly why it needed its own rule.
17. **Progressive Disclosure.** Information should appear in layers. Every screen should reveal only the amount of information appropriate for its purpose:
    - **Home** — "What should I know?"
    - **Pages** — "What should I do?"
    - **Inspector ("Why?")** — "Why is this true?"
    - **Developer Panel** — "How does the system know this?"

    A field that helps a screen answer its own layer's question belongs on that screen. A field that only answers a *deeper* layer's question belongs one layer down, not on the current screen "just in case." This is the same discipline the Recommendations Information Architecture pass already applied by hand (title/description/priority/Why? on the page, everything else in the Inspector) — written down here as the general rule that pass was actually following, so the next feature doesn't have to rediscover it from scratch.
18. **Screen Ownership.** Every screen exists to answer exactly one primary question. Anything on that screen that does not directly help answer it should be removed, summarized, or relocated to the screen that owns it. This is Rule 17 applied *within* the Pages layer specifically — Progressive Disclosure says what question each *layer* answers; Screen Ownership says every individual page within the Pages layer needs its own one-sentence answer, not a shared one. Current answers, for reference during any future audit:
    - **Home** — "What do I need to know right now?"
    - **Inventory** — "What gear improvements should I make?"
    - **Accomplishments** (the module referred to as "Achievements" in earlier design conversations — see Section 1.3) — "What progress am I making?"
    - **Dungeons** — "What dungeon content am I running?" Composes general dungeon activity and Delves; may reference an active Mythic+ run as current context but does not duplicate Mythic+ history or analysis.
    - **Activity Log** — "What recorded activities have I completed over time?" Presents ActivityHistoryService's canonical chronological stream without taking ownership of gameplay facts or persistence.
    - **Mythic+** — "How am I performing in competitive dungeon content this season?"
    - **Recommendation Inspector** — "Why did the addon make this recommendation?"
    - **Developer Panel** — "How did the addon reach this internal state?"

    A screen whose content can't be traced back to its one question is a candidate for the same treatment as any other duplication finding — cut, summarize, or hand off to the screen that actually owns the answer.
19. **Shared Components over Page Fixes.** If two pages solve the same UI problem — a stat grid, a list-with-actions, a header — build one reusable component and have both consume it. A page-specific implementation is only justified when the behavior genuinely differs, not merely when the two pages were built at different times. This is Rule 7's presentation-layer counterpart: Rule 7 stops a module from re-implementing another module's logic; this stops a page from re-implementing another page's widget. `Dashboard:CreateDataPage`, `Dashboard:LayoutItemRows`, and the shared accordion infrastructure built during the Character Journey and Recommendations passes are the working examples of this rule already in the codebase, not just the aspiration.
20. **Simplicity over Density.** When a screen accumulates visual noise or duplicated widgets over time, the default fix is deletion, not addition. Before adding a new widget to a crowded screen, check whether an existing one is redundant with it and can be removed instead. Prefer fewer, denser-but-clearer sections over more, thinner ones that repeat the same shape (see the Mythic+ stat-grid finding in the Information Architecture Audit, Section 8, for a concrete case this rule now governs going forward).

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
| Recorded Activity History | ActivityHistoryService *(persistence/indexing only; gameplay modules own record contents)* | Activity Log; owner-page summaries where appropriate | — | — |
| Session Notes (this-session runs/achievements/vault gains) | SessionNotesService | Home ("Today's Companion Notes") | — | — |
| Professions (recipes, cooldowns) | Professions *(planned)* | Professions *(planned)* | Professions *(planned)* | Professions *(planned)* |
| Collections (transmog/mounts/pets/toys) | Collections *(planned)* | Collections *(planned)* | Collections *(planned)* | — *(weak fit)* |
| Raids (lockouts, attendance) | Raids *(planned, pending audit)* | TBD | TBD | TBD |
| PvP (rating, honor, season) | PvP *(planned, pending audit)* | TBD | TBD | TBD |
| Delves | Delves | Dungeons | — | — |

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
- Existing modules: Character, Inventory, Achievements, MythicPlus, Delves, Weekly, Storage.
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
| 10 | ~~Delves~~ — **Done.** Implemented after a dedicated Retail completion-pipeline audit: deterministic `SCENARIO_COMPLETED` recording, active-state getters, and tracked history/statistics. |

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
6. **Reputation, Currency, Warband, Professions, Collections, Raids, PvP** — all still-planned modules per Section 2, unchanged by this sprint. Each needs its own dedicated Blizzard API audit before implementation begins, per Rule 15.

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

#### UI Polish Pass — third confirmed Unicode font-coverage failure, real root cause of the Home page's "stray rectangle" / tofu-box report

A full visual audit of every Dashboard card and shared widget (`DashboardCard.lua`, `RecommendationInspector.lua`, `Sections.lua`, `Rows.lua`, `Layout.lua`), triggered by a live report of a colored rectangle-like artifact directly beneath the "Highest Priority" card's title. Root cause: `DashboardFormat.STAR_FILLED`/`STAR_EMPTY` (`"★"`/`"☆"`, U+2605/U+2606, Miscellaneous Symbols block) — rendered by `SetStarRating` directly under every card/row title that shows a priority — are a **third** Unicode block confirmed to render as missing-character boxes in this client, after the Geometric Shapes block (`▶`/`▼`/`▲`, the disclosure-icon and trend-arrow fixes already documented above) already established that Blizzard's client font (`FRIZQT__.TTF`) has real, non-obvious gaps. A row of gold-tinted tofu boxes sitting directly beneath a card's header reads exactly as "a stray colored rectangle behind the header," and the same glyphs repeated up to five times in a row read as "placeholder squares" — both reports were the same underlying bug, not two.

Fixed the same way the two prior Unicode failures were fixed: `STAR_FILLED`/`STAR_EMPTY` are now plain ASCII (`"*"`/`"-"`), changed once in `DashboardFormat` (`Core/UI/Dashboard/Format.lua`), the single shared source every star-rating call site already reads from — `DashboardCard:SetStarRating` (Home's Highest Priority card and every other Home card), `Rows.lua`'s `LayoutItemRows` (the standalone Recommendations page and every page's dynamic Recommendations mini-section), `RecommendationInspector.lua`'s Priority field, and the Favorite-player star marker (`RecommendationEngine.lua`, `PlayerJournalTooltip.lua`, `PlayerJournalWindow.lua`, `PlayerJournal/Tabs/Search.lua`) all picked up the fix automatically — no one-off overrides applied anywhere.

**Deliberately not blind-fixed on the same suspicion:** `Presentation.CHECK_GLYPH`/`CROSS_GLYPH`/`WARNING_GLYPH` (`"✓"`/`"✗"`/`"⚠"`) and `DashboardFormat.BULLET` (`"•"`) are three more Unicode blocks (Dingbats, Miscellaneous Symbols, General Punctuation) that were never independently confirmed either — but this pass's own visual audit did not observe them rendering as broken, so guess-changing them now would repeat the exact mistake this addon has already made three times (asserting a glyph is safe, or unsafe, without live confirmation). Flagged instead as `presentation.unverifiedGlyphs` (`NEEDS_LIVE`) in `VerificationService`'s registry, surfaced via `/ac dev` → Checklist tab, so a human can confirm or deny in a live client rather than this addon guessing a fourth time.

**Rest of the audit — no other confirmed violation found.** `DashboardCard.lua`'s backdrop is a single real bordered backdrop per card (no separate texture layer sits behind the title — the title is a plain FontString on the same backdrop as everything else); frame levels are correct (`WhyButton`/`DismissButton` explicitly bumped above their card's own level in `Home.lua`, `Rows.lua`'s pooled `DismissButton` relies on WoW's own default child-above-parent rule, explicitly documented). Every page routes through the same shared `Sections.lua`/`Rows.lua` engines and `Layout.lua` constants, so padding/title spacing/header height/corner radii/margins are already structurally identical across every card and page — a repo-wide grep for hardcoded multi-digit pixel offsets in `Pages/*.lua` found none, confirming no one-off positioning hacks remain. A full sweep for placeholder/test/`TODO`/`Lorem ipsum` text and a script-driven cross-reference of every `AC.L:Get`/`AC.L:Format` key used anywhere in the codebase against every key defined in `enUS.lua` both came back clean — zero missing localization keys, zero leftover placeholder text.

#### UI Polish Pass — Highest Priority card visual hierarchy redesign, live design review

A follow-up pass driven by a live design review of the Home page (the ASCII star-rating substitution above, while no longer rendering as tofu boxes, itself read as placeholder-looking — a row of `"*----"` still looks unfinished, not intentional). Reviewed the Highest Priority card end to end against the question "what information here actually deserves visual emphasis," not just individual spacing numbers.

**Priority rating retired entirely, not patched a second time.** `DashboardFormat.RenderStars`/`PriorityToStars`/`STAR_EMPTY` are removed outright (`Core/UI/Dashboard/Format.lua`) rather than given a fourth glyph guess. Two real problems with the star row, not one: it was the same Unicode font-coverage failure as the favorite-player marker (a repeated-glyph row directly under a card's title, a tofu-prone shape by construction regardless of which characters fill it), and — independent of that — it was genuinely redundant on the Recommendations page, where `Dashboard.RecommendationMetaFormat` already showed the identical priority as a raw number on the very same row. Replaced by `DashboardFormat.GetPriorityLabel(priority)`, a three-tier High/Medium/Low label (mirroring the retired 5-star thresholds collapsed to three) paired with a semantic color — more readable at a glance than counting filled-vs-empty glyphs, and it replaces the redundant raw number in the meta line too (`Rows.lua`'s `LayoutItemRows`). `STAR_FILLED` (`"*"`) itself is kept — it was never the problem; the *row* of five was. It remains the addon's single-character favorite-player marker (`RecommendationEngine.lua`, `PlayerJournalTooltip.lua`, `PlayerJournalWindow.lua`, `PlayerJournal/Tabs/Search.lua`), an unrelated concept that was never reported broken and reads fine as one character.

**Confidence and Priority both elevated via a new `SetDetailSections` capability, not a new widget.** `DashboardCard.lua`'s `SetDetailSections` gained an optional `color` field per section (a semantic color name, `AC.Presentation.GetSemanticColor`) rather than building a separate "badge" widget — the existing pooled Caption/Body mechanism already does everything a compact labeled value needs; it only lacked a way to say "this one matters." Priority (`critical`/`warning`/`dim` for High/Medium/Low) and Confidence (`success`/`warning`/`dim` for High/Medium/Low) now lead Home's recommendation section list, both `emphasized` (the existing bigger-font flag) and colored, while Reason/Expected Benefit/Estimated Time/Supporting Evidence stay plain — a real, deliberate hierarchy instead of five equally-weighted lines. Uncolored sections explicitly reset to plain white every call (not left alone) — these entries are pooled and reused across refreshes, so a color from a previous recommendation could otherwise silently bleed onto an unrelated field. `RecommendationInspector.lua`'s own "Priority"/"Confidence" fields (`LayoutField`) gained the identical optional `color` parameter, so the detail popup agrees with the summary card on what "important" looks like, rather than the two windows drifting into different visual dialects.

**Emphasized background softened to border-only, not removed.** `DashboardCard.lua`'s `options.emphasized` previously tinted the entire card body an olive-brown (`0.17, 0.15, 0.09`) distinct from every other card's neutral gray — flagged in review as "heavy," and it was also the one real cross-card inconsistency an audit would flag on its own (every other card shares one background). Emphasized cards now use the exact same neutral backdrop as every other card; emphasis is carried entirely by a brighter, gold-tinted border (`AC.Presentation.HIGHLIGHT_COLOR`, alpha 0.5 vs. the normal 0.28 white-ish border) plus the card's own larger title/primary-value fonts (already real, pre-existing signals) — real definition without a second background color for players to learn.

**Click-navigation indicator repositioned, and made optional.** The `>` chevron (`options.onClick`) previously anchored vertically centered on the whole card via `SetPoint("RIGHT", ...)` — fine on a short, fixed-height card, but on the Highest Priority card's tall, content-driven height it floated in empty space unrelated to any specific content, which is what read as "disconnected." It now anchors `TOPRIGHT` at the same padding the title's `TOPLEFT` uses, so it reads as part of the header on every card regardless of height. New `options.hideIndicator` lets a card that already has its own explicit action buttons in that corner (Home's Highest Priority card: Dismiss + Why?) skip the now-redundant generic chevron entirely rather than overlapping it — the card body stays clickable either way.

**Action-button alignment.** Dismiss/Why? now anchor at `Layout.CARD_PADDING_RIGHT`/`CARD_PADDING_TOP` (new shared constants) instead of independent hand-typed offsets (`-10`/`-10`/`-4`), with a new `CARD_ACTION_BUTTON_GAP` between them — so a future padding change moves these buttons too instead of silently drifting out of alignment with the title row they sit beside.

**Spacing widened one notch addon-wide, not maximized.** Every `Layout.lua` `CARD_*` gap (padding, title-to-primary, primary-to-secondary, secondary-to-detail, section-to-section, section label-to-body) increased modestly — a live review called the card interior "cramped." Values were chosen to read as deliberate breathing room, not the most spacing that still technically fits; Blizzard's own panels stay dense, not airy, and this addon's own "clean, minimal, not flashy" goal argues against overcorrecting into a spacious, over-padded layout. `RECOMMENDATION_HEIGHT` grew from 130 to 150 to give the now-two-section Priority/Confidence header room without the card's dynamic-height logic (`UpdateHeight`, unchanged) immediately having to grow past its floor.

**Shared-component discipline, not one-off overrides.** Every change above lives in `Format.lua`, `Layout.lua`, or `DashboardCard.lua` — the three shared files every card/row/inspector reads from — rather than a Home-specific patch. `Rows.lua`'s list rows and `RecommendationInspector.lua`'s detail popup picked up the priority-label and color-coding changes automatically through the same shared functions; `Rows.lua`'s `showStars` parameter was renamed `isRecommendation` throughout (`LayoutItemRows`, `AppendDynamicSection`) now that it no longer gates a star row, only dismiss/inspect/hover behavior — a positional parameter with no external call site depending on its name, so the rename is call-site-transparent.

#### UI Polish Pass — Navigation Audit: one unified page-header design

Triggered by a live review calling out the "< Back" button specifically — heavier than the page title next to it, and the leading `<` redundant with the word "Back" itself. Scoped, per the request, as a full audit of the header/navigation system before any edit, not a one-line tweak.

**Audit — every page that uses the current Back/header pattern.** Grepped the whole codebase for `Back`/`BackButton`/`GoBack` rather than assuming. Result: **exactly one shared implementation already exists** — `Dashboard:CreateDataPage(parent, pageTitle)` (`Core/UI/Dashboard/Sections.lua`) — called once each, from `Home.lua`'s `Create()`, for Profile, Inventory, Accomplishments, MythicPlus, Storage, Weekly, Recommendations, Progress, Statistics, and Journey. No second implementation exists anywhere: `SettingsWindow.lua`'s own `Back`-matching greps were all `Backdrop` (a sidebar `NavigationPanel`, a different, appropriate pattern for a settings window, not a page stack, correctly left alone); `DeveloperPanel`/`RecommendationInspector`/`PlayerJournalWindow` are standalone `BaseWindow`s with a Close button, not part of this in-window page stack, and never had a Back button to begin with. `page.BackButton` (the field `CreateDataPage` exposes) is set but never read anywhere else in the codebase, confirmed via grep — safe to change its internal construction with zero blast radius. **Conclusion: no duplication to untangle.** The architecture was already correctly centralized; the one shared implementation itself simply had the wrong visual design. This is reported plainly rather than manufacturing a duplication finding that isn't there.

**Root cause.** Three widgets built independently, each reasonable in isolation, with nobody designing the header as one hierarchy: Back used `UIPanelButtonTemplate` (a full bordered, beveled action button — the same visual weight as Home's own Settings button) reading `"< Back"`; Title used `GameFontNormalLarge`, centered; Updated used `GameFontDisableSmall`, right-aligned. Back's border/bevel and the title's own size put them at roughly comparable visual weight, so Back competed with Title for attention instead of yielding to it — exactly the complaint. A secondary, smaller inconsistency found in the same audit: Back anchored at `TOPLEFT(0, 0)` while Updated anchored at `TOPRIGHT(-4, -6)` — the two side elements didn't even share a Y offset with each other, let alone optically align with Title's larger font.

**Proposed design — one hierarchy, not three widgets.**
- **Title is the only large, bright element** — unchanged font (`GameFontNormalLarge`), still centered. The one thing a player is actually looking for on a secondary page keeps sole claim to visual weight.
- **Back and Updated share one quiet treatment** — both `GameFontDisableSmall`, both borderless, symmetric metadata flanking the title (matching the user's own mockup: `Back  ⋯  Title  ⋯  Updated HH:MM:SS`). Back is no longer a boxed button; it's a plain clickable word that brightens gold on hover — the exact "clickable text" affordance `RecommendationInspector`'s own module-link buttons already established elsewhere in this codebase, reused rather than invented.
- **`"< Back"` → `"Back"`** — the chevron is gone; a plain word reads as more finished, not less, once it's no longer trying to visually out-compete the title via a border it doesn't need.
- **A hairline divider** below the header, separating it from scrollable content on every page — the ASCII mockup's own `------` row, made real with the exact same color/alpha every other divider in this codebase already uses (`Dashboard:AddDivider`'s own `(1,1,1,0.10)`), not a new visual language.
- **Consistent, shared-constant spacing** — `Layout.PAGE_HEADER_TITLE_TOP` (4) and `Layout.PAGE_HEADER_SIDE_TOP` (8) replace four independent hand-typed offsets; the 4px difference between them approximates optical center-alignment between `GameFontNormalLarge` and `GameFontDisableSmall` (roughly half their visible height difference) rather than both starting flush at the same Y, which is what produced the original "Title floats above everything else" misalignment. `PAGE_HEADER_HEIGHT` grew 36 → 40 to give the new divider clean room without feeling tight — the same "widen one notch, not maximize" discipline the card-spacing pass already established.

**Justification for each change, tied to the audit finding it fixes:** chevron removed (redundant glyph, no informational value); Back de-bordered and demoted to the same font as Updated (the actual "draws more attention than the title" complaint — a border was the real culprit, not merely the arrow); Back/Updated's Y offsets unified via shared constants (fixes the misalignment the audit found between the two side elements); divider added (makes the header a deliberate, bounded region instead of text floating above a scroll area with no visual seam); `PAGE_HEADER_HEIGHT` widened (gives the divider room without crowding the existing content).

**Recommendations page — reviewed in full, not just the header.**
- **"Click for Why?" → "Why?"** — a real, concrete inconsistency, not a stylistic guess: Home's Highest Priority card already labels this exact same action (opening the Recommendation Inspector) `"Why?"` (`Inspector.WhyButton`). The list-row hint said something different for the identical feature. Now both say the same thing.
- **Row separation** — the audit's own question ("are recommendation cards separated enough?") had a concrete answer: no dividing line existed between one multi-line recommendation row and the next, only a 22px gap and a hover-highlight that only appears on mouseover. Fixed the same way the new header divider was — a hairline in the existing gap, not a new visual language — added once in `Rows.lua:BuildRecommendationRow`/`LayoutItemRows`, so the standalone Recommendations page AND every other page's own dynamic Recommendations/Insights mini-section (Inventory, Accomplishments, MythicPlus, Storage, Weekly) all gain clearer card-to-card separation for free, per this codebase's own "fix the shared component, not the one page" discipline.
- **Priority/Confidence/Category grouping, Updated timestamp prominence, font-size count** — reviewed, each found already appropriate, **not changed**: the meta line's three "Label: value" facts are already the addon's established dense-list convention (matching every other page's own Recommendations/Insights mini-sections, not a Recommendations-page-specific pattern); `Updated` already uses `GameFontDisableSmall`, the dimmest small font this codebase has, so no further demotion was meaningful; the page's five font templates (`GameFontNormalLarge` title, `GameFontNormal` row title, `GameFontHighlightSmall` description, `GameFontDisableSmall` details/meta, plus `GameFontHighlight` for the deliberately-exceptional "Caught Up" celebratory empty state) map to a real four-level hierarchy (page title → item title → item description → item metadata) with one intentional, already-documented exception, not unexplained drift. Per this pass's own explicit instruction — "don't redesign for the sake of redesigning, only improve what objectively improves readability" — none of these were touched.

**Shared implementation.** Everything lives in the same one place every secondary page already reads from: `Dashboard:CreateDataPage` (`Sections.lua`) for the header, `Dashboard:BuildRecommendationRow`/`LayoutItemRows` (`Rows.lua`) for row separation, new constants in `Layout.lua`. No page-specific hack was introduced anywhere; every one of the ten secondary pages picks up every change automatically the next time it's shown, with zero page-level code changes.

**Cleanup.** No obsolete code, comments, or helpers were found to remove — the header had exactly one implementation to begin with, so there was nothing duplicated to retire. The old `"< Back"` and `"Click for Why?"` strings were replaced in place in `Localization/enUS.lua` (`Dashboard.Back`, `Dashboard.ClickForWhy`) rather than left as unused dead keys alongside new ones.

#### Header Polish Pass — Back reverted to a bordered button (supersedes the Back-specific part of the Navigation Audit above)

Product direction changed: Back is now a real `UIPanelButtonTemplate` button again (matching Home's own Settings button), not the plain clickable text the Navigation Audit above deliberately introduced. Re-audited fresh rather than assumed unchanged — confirmed `Dashboard:CreateDataPage` (`Sections.lua`) is still the only implementation, still used by the same ten secondary pages (Profile, Inventory, Accomplishments, MythicPlus, Storage, Weekly, Recommendations, Progress, Statistics, Journey), so this is a one-file, zero-duplication change, the same shape the original redesign was.

**What changed:** Back's widget (`CreateFrame("Button", ..., "UIPanelButtonTemplate")`, 76×22, `AC.L:Get("Dashboard.Back")` as its label) and its own hand-rolled `OnEnter`/`OnLeave` hover-color handling — deleted, not carried forward, since the template already provides its own hover/pressed states and the old highlight-color swap became dead code the moment the widget changed. `GoBack()`'s own behavior, navigation history, and every other page element are untouched.

**What also changed, and why:** Back and Updated's own anchors moved from `X = 0` (flush against the raw window edge) to `X = Layout.PAGE_PADDING`. This wasn't introduced or fixed by the Navigation Audit above — Back/Updated sat at the window's raw edge both before and after that pass — it was only noticed during this pass and corrected against the same `PAGE_PADDING` constant the header's own divider and the content area beneath it already used, rather than a new constant. `PAGE_HEADER_HEIGHT` grew 40 → 46 to give the now-22px-tall button the same clearance before the divider that `DIVIDER_MARGIN_BOTTOM` already establishes as this codebase's standard pre-divider breathing room, rather than the taller button crowding it.

**Everything else in the Navigation Audit above remains accurate** — the divider, Title/Updated's own font and positioning, the Recommendations page's row-separation and "Why?" label changes, and that section's own shared-implementation/cleanup findings are all unaffected by this pass.

#### Recommendations Information Architecture — from "serialized object" to "action list"

The Recommendations page exists to answer one question: *what should I do next?* This pass audited every field the page rendered against that one question, rather than treating "the page has room for it" as a reason to keep showing it.

**UX audit — every field the page rendered, before this pass.** Each row rendered, in order: Title, Description, then a flat bullet dump mixing Reason, Expected Benefit, Estimated Time, and every Supporting Evidence fact (Current Rating, Current Item Level, Vault Progress, Flasks Missing, Food Missing, and whatever else a given recommendation's evidence list happened to carry), then a meta line combining Priority, Category, optionally Confidence, and a "Click for Why?" hint. Audited field by field:

| Field | Helps the player decide? | Duplicate? | Implementation detail? | Verdict |
|---|---|---|---|---|
| Title | Yes — the answer to "what should I do" | — | — | **Keep on main page** |
| Description | Yes — the one-sentence "why this, now" | — | — | **Keep on main page** |
| Priority | Yes — answers "is it important" directly | — | — | **Keep on main page** |
| Confidence | Marginal — a trust/substantiation signal, not a decision input; a player deciding whether to act needs Priority, not how well-evidenced the Companion's reasoning is | Already shown, unchanged, in the Inspector | No | **Inspector only** |
| Reason | Explains the recommendation, but `description` already does this job for the 5-second scan; a second explanatory line is redundant with the one the player already read | Yes — same information as `description`, worded differently, and already shown verbatim in the Inspector | No | **Inspector only** |
| Expected Benefit | Justification, not a decision input for "what do I do right now" | Already shown, unchanged, in the Inspector | No | **Inspector only** |
| Estimated Time | Genuinely borderline — arguably actionable ("can I fit this in right now"). Considered keeping it on the main page; not included, both because the requested main-page field set didn't call for it and because it's already covered by the Inspector, consistent with keeping the row to the smallest set that answers the three questions | Already shown, unchanged, in the Inspector | No | **Inspector only** (flagged here as the one close call in this audit) |
| Supporting Evidence (Current Rating, Item Level, Vault Progress, Flasks/Food Missing, ...) | No — these are the evidence *behind* the recommendation, not the decision itself; reading "Current Rating: 1850" doesn't change what a player does next, it justifies why the Companion suggested it | Already shown, unchanged, in the Inspector, **grouped by contributing module** (better organized there than the row's flat bullet list) | Largely yes — several of these are raw stat readouts, not player-facing guidance | **Inspector only** |
| Category (e.g. `"Preparation"`, `"Inventory"`) | No — an internal classification string; the title/description already communicate the topic in plain language | Not duplicated (never rendered as its own labeled field anywhere) | Yes — this is RecommendationEngine's own bookkeeping/grouping key, not player guidance | **Removed from presentation entirely.** The field itself is untouched in `RecommendationEngine.lua` (still used as `LayoutSupportingEvidence`'s grouping fallback when an evidence item lacks its own `module` tag) — only its display on the row is gone. Contributing Modules (Inspector) already answers "where does this come from" better, with real clickable navigation. |
| "Click for Why?" | Yes — the entry point to everything above | — | — | **Keep on main page**, reworded `"Why?"` (Navigation Audit pass, for consistency with Home's own identical button) |

**Root cause.** Every field above was added in its own pass, each with a real, defensible reason at the time (Reason/Expected Benefit/Estimated Time in the original "why" fields addition; Supporting Evidence in RecommendationEngine V2's explainability work; Confidence in V3). Nobody, across those passes, asked "does the row as a *whole* still serve its one job" — each addition was locally justified and globally accumulating. The result: a row assembled from six-plus independently-justified pieces reads as a serialized object dump, not a guided recommendation, exactly the "my eyes start parsing fields instead of reading the recommendation" complaint. This mirrors the exact same root-cause pattern the Navigation Audit found for the header immediately above — components built independently, each reasonable alone, nobody designing the whole as one thing.

**Information hierarchy, redesigned.**
- **Main page (`Rows.lua:LayoutItemRows`/`BuildRecommendationRow`)** — Title, Description, Priority, Why?. Four elements, answering "what / how important / why, if I want to know" in one glance. Nothing else competes with them.
- **Why? Inspector (`RecommendationInspector.lua`)** — audited and found to **already be exactly the "developer explanation" this pass wants it to be**: Priority/Confidence (colored, with a methodology note), Opportunity Score, Estimated Time, Reason, Expected Benefit, Supporting Evidence (grouped by contributing module), Contributing Modules (clickable links to the source page), Score Breakdown (Developer Mode only), Recommendation History, Timestamp. Every field removed from the main row above was already rendered here, unchanged — this pass did not add anything to the Inspector, because there was nothing missing. "Move information there instead of duplicating it on the main page" turned out to mean *delete from the row*, not *add to the Inspector*.

**Shared implementation, no page-specific hack.** Every change lives in `Core/UI/Dashboard/Rows.lua` — `LayoutItemRows` is the one function the standalone Recommendations page AND every other page's own dynamic Recommendations/Insights mini-section (Inventory, Accomplishments, MythicPlus, Storage, Weekly) all call. `Pages/Recommendations.lua` itself needed zero changes — it only ever calls `LayoutItemRows`, never renders a field directly. Every one of those callers gets the same simplified row automatically.

**Cleanup.** `row.DetailsText` (the FontString that rendered Reason/Expected Benefit/Estimated Time/Supporting Evidence as a bullet block) is removed entirely from `BuildRecommendationRow` — confirmed via repo-wide grep to have zero remaining references anywhere once the code reading it was gone. Four now-orphaned localization keys removed from `Localization/enUS.lua`: `Dashboard.RecommendationReasonFormat`, `Dashboard.RecommendationBenefitFormat`, `Dashboard.RecommendationTimeFormat`, `Dashboard.RecommendationMetaWithConfidenceFormat` (confirmed via grep, zero remaining references). `Dashboard.RecommendationMetaFormat` simplified from `"Priority: %s   Category: %s"` to `"Priority: %s"` rather than left with an unused second placeholder. `Dashboard.EvidenceLineFormat` and `Dashboard.ConfidenceHigh`/`Medium`/`Low` were **not** removed — both still have real, live call sites (`Home.lua`'s Highest Priority card, and the Inspector/Home card's own Confidence field respectively) — confirmed via grep before touching anything, not assumed.

**Explicitly not done this pass, flagged rather than silently touched:**
- **Home's Highest Priority card** shows a structurally similar amount of detail (Priority, Confidence, Reason, Expected Benefit, Estimated Time, Supporting Evidence, all as `DashboardCard` Detail Sections) — the same category of finding this audit made for the Recommendations page's list rows. This pass's request was explicitly scoped to "the Recommendations page"; the card was left untouched rather than redesigned unasked. Worth the same audit in a future pass.
- **The Inspector's own internal grouping** — Priority/Confidence/Score/Estimated Time/Reason/Expected Benefit currently render as a flat sequence of fields, not grouped under section headers the way Supporting Evidence and Contributing Modules already are. Restructuring that into explicit "Reasoning"/"Diagnostics" groupings (closer to this pass's own suggested Inspector shape) is a real, defensible idea — but it is a *layout* change to content already confirmed correct and complete, not an information-architecture fix, and this pass's own instruction was explicit: fix the information architecture first, defer spacing/typography/grouping. Deferred, not forgotten.

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
