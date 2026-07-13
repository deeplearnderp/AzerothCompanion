# Azeroth Companion Development Backlog

This document tracks the long-term evolution of Azeroth Companion.

Its purpose is to record:

- Technical debt
- Architecture improvements
- Deferred features
- Blizzard API verification
- UX improvements
- Future modules
- Ideas discovered during development

This document is intentionally version-controlled.

Completed items should be checked off rather than deleted whenever practical.

---

# Current Milestone

**Current Branch**

feature/v1-polish

Current Focus

- v1.0 Polish & Completion Sprint -- complete. See "v1.0 Polish & Completion Sprint" under High Priority below and `docs/GameplayModuleArchitecture.md` section 1.9 for the full detail.
- Blizzard API Verification Workflow -- complete. Source/documentation pass across Weekly/Storage/MythicPlus (Blizzard Interface Source + Warcraft Wiki cited throughout Critical below).
- Live Verification & Framework Hardening sprint -- complete. Extended the same audit discipline to every remaining module (Character, Inventory, Achievements, Progress, Recommendation Engine, Notification Service, Milestone Service, Developer Panel) and built permanent tooling so this never has to be a one-off doc-writing exercise again: `Core/Services/VerificationService.lua` is now the single source of truth for every Blizzard API's classification (a real, checkable registry, not prose), backing an expanded Developer Panel Live API tab (Raw/Parsed/Expected/Confidence/Source/Last-Verified per probe, plus a read-only full-registry listing) and a new Checklist tab (the 26 guided scenarios, each naming exactly which APIs it exercises). See "Live Verification & Framework Hardening Sprint" below for the full detail and every finding.
- v1.0 Visual Polish Sprint -- complete (not to be confused with the earlier code-quality "v1.0 Polish & Completion Sprint" below). A full visual/UX audit of the Dashboard, one confirmed real bug fixed (Home page had no scrollbar and roughly half its cards were unreachable) plus the addon's biggest visual-quality gap fixed (zero window/card border anywhere in the whole addon). See "v1.0 Visual Polish Sprint" under High Priority > Dashboard below for the full audit and every change.
- Player Journal & Community Notes System -- complete. The one deliberately-scoped new flagship gameplay system for v1.0: a local, account-wide database of Mythic+ companions (objective stats, personal notes/tags, a bounded timeline) plus an optional, disabled-by-default Community Notes layer (fully local this version -- no sync backend exists yet). Two new modules, a 7-tab standalone window, and this addon's first hooks into Blizzard's own UI (a player right-click submenu, a unit tooltip extension). Designed in Plan Mode with the user resolving two real open risks directly before any code was written. See "Player Journal & Community Notes System" below and `docs/GameplayModuleArchitecture.md` section 1.11 for the full detail.
- Companion Intelligence vNext -- complete. A cross-cutting personalization pass across `RecommendationEngine` and the Companion Intelligence V4 services, plus the first integration of `PlayerJournalModule` into the rest of the addon: a stable recommendation identity + new `RecommendationHistoryService` (first/last shown, likely-completed/dismissed/not-acknowledged, score history), a Dismiss affordance, real personal recommendations/Companion Memory lines sourced from `PlayerJournalModule`, a new Home "Today's Companion Notes" card, Smart Notification cooldowns, an extended Recommendation Inspector, and a new Statistics page. Audited first (13 files); several of the brief's own illustrative examples were found not honestly buildable and skipped rather than faked (see "Companion Intelligence vNext" below). See `docs/GameplayModuleArchitecture.md` section 1.12 for the full detail.
- Accomplishments redesign -- complete. `AchievementsModule` evolved from a flat, undifferentiated cache of every completed achievement into a curated "Character Accomplishments" experience (`AccomplishmentsModule`, renamed) -- Expansion Progress (Campaign + Renown + Loremaster/Pathfinder), Raiding, Mythic+ (completion facts only), Feats of Strength, Character Milestones, Legacy Accomplishments (honest empty state). Classification is fully data-driven (category tree walk) plus a curated, documented signature name-pattern table -- no fabricated "meta achievement" flag, since Blizzard exposes none. Deliberately, with the user's explicit approval, also reads Campaign completion (`C_CampaignInfo`) and Renown (`C_MajorFactions`) even though neither is achievement data. Rename kept two literal strings unchanged for save-data compatibility (`ActivityHistoryService`'s stored `"Achievements"` Module tag, `DeveloperPanel`'s History Inspector filter). See "Accomplishments (formerly Achievements)" below and `docs/GameplayModuleArchitecture.md` section 1.3 for the full detail.
- Presentation Layer centralization -- complete. Testing surfaced a real bug: accomplishment/history dates rendered with no year (`06/23` instead of `Jun 23, 2026`), a real problem for characters played 10-20 years. Auditing found the bug duplicated at 10 call sites (not one page), plus the same "duplicated and drifted" pattern for numbers (15+ raw `string.format` sites) and semantic colors (10+ sites, with confirmed drift -- two different greens, two different reds, for the same meaning). New `AC.Presentation` (`Core/Presentation/Presentation.lua`) centralizes dates (always includes the year), a new `FormatRelativeTime` capability, numbers/percent/rating/item-level, and semantic colors -- `DashboardFormat` narrowed to Dashboard-specific composed presentation (stars/glyphs/trend arrows) with backward-compatible aliases so ~50 existing call sites needed zero changes. Typography/Icon Styling/Density/Themes/Accessibility/UI Profiles deliberately deferred -- zero duplication found for any of them. See "Presentation Layer" below and `docs/GameplayModuleArchitecture.md` section 8 for the full detail.
- Presentation System v2, Phase 1 (Token Consolidation) -- complete. A full UX/UI audit (every widget, every Dashboard page, every satellite window) went beyond the Presentation Layer pass above and found real, demonstrated duplication it hadn't reached: `DashboardCard.lua` had its own parallel design-token block that never referenced `Layout.lua`, the same semantic meaning (success/critical/dim/"link" accent/panel backdrop) hand-typed as different literals across files, three independent empty-state implementations, and identical width-remeasure boilerplate hand-copied across all 7 dynamic Dashboard pages. New `accent` semantic color and `WINDOW_BACKDROP`/`PANEL_BACKDROP` tokens added to `Presentation.lua`; `DashboardCard.lua` now consumes `Layout.CARD_*`; a new `Dashboard:MeasureAndApplyScrolling` replaces the 7-file remeasure duplication; `PlayerJournalWindow.lua`'s duplicate-title bug fixed. First of a 3-phase roadmap -- Phase 2 (promoting Dashboard's presentation primitives into a shared `PresentationWidgets.lua` for satellite windows) and Phase 3 (Themes/Density/Accessibility) both deliberately deferred, no demonstrated need yet. See "Presentation System v2" below and `docs/GameplayModuleArchitecture.md` section 8 for the full detail.
- Canonical Absolute Date Format Sweep -- complete. A follow-up repo grep beyond the Presentation Layer pass's original 10-site fix found one more real bug -- `Pages/Accomplishments.lua` displayed accomplishments as `MM/DD` with no year at all (a `string.format` call, missed by the earlier grep which only searched for `date(...)` calls) -- plus 9 duplicate hand-rolled `date("%b %d, %Y"...)` implementations across `PlayerJournalTooltip.lua`, `DeveloperPanel.lua`, `RecommendationInspector.lua`, and 4 `PlayerJournal/Tabs/*.lua` files, 3 of which used a non-canonical single-space time variant. All now route through `Presentation.FormatDate`, the addon's one canonical absolute date format (`Mon DD, YYYY`) -- no new formatting helpers or alternate styles introduced. See "Canonical Absolute Date Format Sweep" below and `docs/GameplayModuleArchitecture.md` section 8 for the full detail.
- Character Journey (Phase 1) -- complete. A brand-new signature feature: a curated, chronological "museum" of a character's meaningful lifetime moments, explicitly not another activity log. A full audit of every history-shaped system in the addon (ActivityHistoryService, Accomplishments, MythicPlus, Weekly, Progress, Recommendation History, Milestones, Session Notes, Player Journal, Community Notes) found the raw material mostly already existed -- zero new persisted state, zero new Blizzard API calls, zero new service this phase. New `Pages/Journey.lua` aggregates `AccomplishmentsModule:GetAccomplishments()` and a new `MilestoneService:GetAllAchieved()` getter into one oldest-to-newest, year-grouped accordion timeline, reusing the accordion engine and a promoted `Dashboard:SetAccordionDetailField`/`HideAccordionDetailField`. Two real fabrication risks found during the audit (Player Journal's account-wide-not-per-character data, no "notable moment" concept in Recommendation History/Community Notes) were explicitly excluded rather than worked around, with a phased roadmap (Phase 2/3/4+) describing exactly what would honestly unblock each. See "Character Journey (Phase 1)" below and `docs/GameplayModuleArchitecture.md` section 9 for the full detail.
- Accordion Polish Pass -- complete. After using the accordion pages in-game, found and fixed a real layout bug at its root cause rather than with per-page padding: `Dashboard:BeginSection`/`AddDivider` created a brand-new, never-pooled widget on every call, so accordion pages (which re-render on every row click) accumulated ghost section headers/dividers frozen at stale positions that could visually clip the following section. Fixed by pooling both directly on `scrollChild`, the same idiom `ShowEmptyLine` already used -- caught a third real victim, `RecommendationInspector.lua`, for free. Also added a Blizzard-style ▶/▼ disclosure indicator owned by the shared `LayoutAccordionRows` engine itself (automatic for MythicPlus's Recent Runs table too, zero page-level code), a deeper visual nesting for expanded detail content, and confirmed hover feedback was already adequate. MythicPlus's Recent Runs columns shift right 14px as the one explicit, pre-approved exception to staying pixel-identical. See "Accordion Polish Pass" below and `docs/GameplayModuleArchitecture.md` section 1.3 for the full detail.
- Next recommended: open `/ac dev on` then `/ac dev` -> Checklist tab in a live client and work through the scenarios still marked "Needs Live Verification" (including the 4 Player Journal scenarios and the 5 Accomplishments ones -- `GetCategoryInfo`, `C_CampaignInfo`, `C_MajorFactions`, the Renown-changed event, and the signature-pattern table's own ongoing per-expansion spot-check) -- the tab tells you exactly which ones remain and exactly which APIs each one settles. Presentation Layer centralization introduced no new Blizzard API calls, so it adds no new Checklist scenarios.

---

# Critical

These should be completed before a public release. **The Developer Panel's Live API Inspector tab (`/ac dev on`, then `/ac dev`) now exists specifically to make the items below fast to check in-game** -- it puts each system's raw Blizzard values next to the owning module's own parsed/final values, highlighting mismatches. None of these are checked off by that tool's existence; they still need someone to actually open it in a live client and look.

- [x] **Bug fixed, source-verified.** Home's "Highest Reward" card was displaying `C_WeeklyRewards.GetActivities()`'s per-slot `level` field (the Mythic+ KEY level, e.g. "15") mislabeled as an item level -- exactly the worst-case risk this item called out. Fixed in `Modules/Weekly/WeeklyModule.lua`'s new `GetActivityRewardItemLevel()`, which reproduces Blizzard's own reward-resolution chain (`activity.rewards` -> `C_Item.GetItemInfo` -> `C_WeeklyRewards.GetItemHyperlink` -> `C_Item.GetDetailedItemLevelInfo`), mirroring `WeeklyRewardActivityItemMixin:SetDisplayedItem()` in Blizzard's own `Blizzard_WeeklyRewards.lua` field-for-field, verified against Blizzard Interface Source + Warcraft Wiki. Degrades to "no reward shown" (never a guessed number) if any step returns nil. **Still Needs Live Verification**: whether `threshold`/`progress` are counted in whole dungeons completed on the current build (`vaultSlotOneRunAway` scoring term, "one more run unlocks Vault Slot N" evidence line) -- conceptually confirmed via documentation and a cross-referenced community addon (`Broker_GreatVault`), but not literally observed against a live client's actual numbers.
- [x] **Verified, no code change needed.** Storage Execute's `C_Container.PickupContainerItem(containerIndex, slotIndex)` confirmed real via Warcraft Wiki (available through "Midnight" 12.1.0, `AllowedWhenUntainted`). **Still Needs Live Verification**: the actual pickup-then-place round trip against a real bank/bag (the module already fails closed on any error, but the happy path itself hasn't been watched happen).
- [x] **Verified, no code change needed.** Warband Bank: `C_Bank.FetchPurchasedBankTabIDs`, `C_Bank.CanUseBank`, and `Enum.BankType` (`Character=0, Guild=1, Account=2`) all confirmed via Warcraft Wiki, added Patch 11.0.0. `StorageModule.lua`'s existing calls already match. **Still Needs Live Verification**: `Enum.PlayerInteractionType.Banker` and the `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` payload shape (not researched this pass).
- [x] **Verified, no code change needed.** Reagent bank was removed as a separate system in Patch 11.2.0 -- its items folded into the unified bank-tab system already covered by `StorageModule.lua`'s primary `C_Bank.FetchPurchasedBankTabIDs` path. The legacy `Enum.BagIndex.Reagentbank`/`Bank` fallback is confirmed harmless-but-vestigial on current retail, not a bug.
- [x] **Confirmed broken, decision deferred.** Favorite-item detection reads `info.isFavorite` from `C_Container.GetContainerItemInfo`'s return -- confirmed ABSENT from the documented `ContainerItemInfo` structure (Warcraft Wiki), so this field is always `false`/`nil` in practice. Also confirmed never consumed anywhere even if it were populated. Left as a documented, honestly-labeled gap (inline comment added at the read site) rather than fabricating a fix -- **real follow-up work, not "verification pending"**: either find the correct API for a "Never Move: Favorited Items" rule and wire it up for real, or remove the dead field. See `Modules/Storage/StorageModule.lua`'s header VERIFICATION STATUS.
- [ ] Test login vs `/reload` update timing.
- [x] **Events verified, ordering still open.** All 7 Challenge-Mode/Mythic-Plus events `MythicPlusModule.lua` registers (`CHALLENGE_MODE_START`, `CHALLENGE_MODE_RESET`, `CHALLENGE_MODE_COMPLETED_REWARDS`, `CHALLENGE_MODE_KEYSTONE_SLOTTED`, `CHALLENGE_MODE_DEATH_COUNT_UPDATED`, `CHALLENGE_MODE_MAPS_UPDATE`, `MYTHIC_PLUS_CURRENT_AFFIX_UPDATE`) confirmed real via Blizzard Interface Source and/or Warcraft Wiki. `CHALLENGE_MODE_COMPLETED` (distinct from `_REWARDS`) also confirmed real, resolving a stale doubt previously recorded in `Core/Diagnostics/DiagnosticsService.lua`. **Still Needs Live Verification**: the actual firing *order* of these events during a real run start/reset/completion -- confirming an event exists is not the same as confirming when it fires relative to the others.

**Live Verification Checklist** -- for the items above still marked "Needs Live Verification" (not the ones already resolved by source/doc research). Use the Developer Panel's Live API Inspector (`/ac dev on`, then `/ac dev` -> Live API tab) at each step and compare the raw Blizzard value against the module's parsed value:

- [ ] Login -- observe `C_WeeklyRewards.GetActivities()` raw slot data on the Live API tab at session start; confirm `threshold`/`progress` match what the Great Vault's own Blizzard UI shows for the same character.
- [ ] Reload UI (`/reload`) -- repeat the same Weekly observation immediately after reload; confirm no stale/zeroed values before the first real update fires (the "login vs `/reload` timing" item).
- [ ] Open Bank -- watch `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` fire with `Enum.PlayerInteractionType.Banker` on the Event Monitor tab; confirm `StorageModule`'s scan actually triggers off it.
- [ ] Open Warband Bank -- confirm `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)` returns real tab IDs on the Live API tab, and that `StorageModule`'s Warband totals match what's visually in the Warband Bank frame.
- [ ] Open Great Vault -- confirm the Highest Reward card's item level now matches the real item level Blizzard's own Great Vault frame shows for the same slot (this is the specific bug this pass fixed -- the live check that closes the loop).
- [ ] Enter Mythic+ (`CHALLENGE_MODE_START`) -- on the Event Monitor tab, note the fire order of `CHALLENGE_MODE_START` relative to `CHALLENGE_MODE_KEYSTONE_SLOTTED`/`CHALLENGE_MODE_MAPS_UPDATE` if they also fire around the same moment.
- [ ] Complete Mythic+ (`CHALLENGE_MODE_COMPLETED_REWARDS`) -- confirm the event actually fires (vs. `CHALLENGE_MODE_COMPLETED` only) and that its payload (`mapID, medal, timeMS, money, rewards`) matches what `MythicPlusModule` parses from it.
- [ ] Earn Achievement -- not part of this pass's flagged gaps; spot-check only if time allows.
- [ ] Change Spec -- not part of this pass's flagged gaps; spot-check only if time allows.

**Self-review sources cited above**: Blizzard Interface Source (`Gethe/wow-ui-source`, `Blizzard_WeeklyRewards`/`Blizzard_ChallengesUI`) for `WeeklyRewardActivityInfo` fields, `SetDisplayedItem()`'s exact resolution order, and Challenge-Mode/Mythic-Plus event registrations; Warcraft Wiki for `C_Item.GetItemInfo`/`GetDetailedItemLevelInfo` return shapes, `C_Bank`/`Enum.BankType`, `ContainerItemInfo`'s full field list (confirming `isFavorite`'s absence), `C_Container.PickupContainerItem`, and `CHALLENGE_MODE_COMPLETED_REWARDS`/`CHALLENGE_MODE_DEATH_COUNT_UPDATED`; `mega-tin/Broker_GreatVault` (community source, informal corroboration only) for the whole-dungeons-per-slot assumption.

---

# High Priority

## Dashboard

- [x] Split Dashboard.lua into logical components. (Dashboard Refactor) One 3,906-line file became 15 files under `Core/UI/Dashboard/`: `Layout.lua`/`Format.lua`/`Schemas.lua` (constants/formatting/schema data, each its own `AC.Dashboard*` table since Lua has no cross-file `local`), `Dashboard.lua` (creates the table), `Sections.lua` (page-shell + section primitives), `Rows.lua` (dynamic list/hero/grid/history builders), `Pages/*.lua` (one file per page), `Home.lua` (window shell + card construction + Home refresh), `Navigation.lua` (ShowPage/Navigate/Show/Hide/Toggle + service registration, loaded last). `AC.Dashboard` is still exactly one object with the same public methods -- external callers (`SlashCommandManager`, `MinimapIcon`, both only ever calling `AC.Dashboard:Toggle()`) needed zero changes.
- [x] Remove duplicated refresh logic. New `Dashboard:RefreshEngines(page)` (Sections.lua) replaces the "refresh Insight/Recommendation engines + update last-updated text" 3-line block that was copy-pasted at the top of all 7 `Update*Page` functions -- one of those 7 copies (Home's `UpdateContent`) was dead code, referencing an undefined `page` local; fixed by passing `nil` explicitly (Home has no `LastUpdatedText` field, so this is the exact same no-op, just no longer via a stale reference).
- [x] Remove duplicated layout helpers. New `Dashboard:GetCategorizedRecommendationsAndInsights(category)` (Sections.lua) replaces the "filter RecommendationEngine's list by category + fetch InsightEngine's matching list" block, copy-pasted 5 times differing only by the category string literal. Also relocated Storage's Execute confirmation (`StaticPopupDialogs["AZEROTHCOMPANION_STORAGE_EXECUTE"]` + `ShowExecuteResult`) out of generic Dashboard chrome into `Pages/Storage.lua`, where it actually belongs.
- [ ] Standardize spacing and padding.
- [ ] Continue improving visual hierarchy.
- [x] Improve Home page briefing. (Home Dashboard Evolution) Every card now answers "what should I do next" with real structure instead of one merged dim line: **Highest Priority** shows Reason/Expected Benefit/Estimated Time/Supporting Evidence as separately labeled blocks (`DashboardCard:SetDetailSections`, new). **Profile** gives equipped item level its own emphasized (bigger/brighter) line and adds current zone, which the card never showed before. **Mythic+** cross-reads Weekly's vault progress and, when Storage's "MythicPlus" preparation preset isn't ready, shows a real "Missing" bullet list (Storage's own missing-item categories plus a real repair check read from Inventory) instead of just a bar. **Vault Progress** gained the progress bar its own name implied but never had, plus Highest Reward (max item level among unlocked slots) and a Remaining-objectives count. **Recent Activity** is now a real chronological feed merging MythicPlus runs and Achievements (sorted by timestamp), not just the single most recent keystone. **Storage** distinguishes "Items Missing" (owned, in the bank, needs moving) from "Shopping List" (not owned anywhere, needs acquiring) instead of one ambiguous count, and adds an Execute-available hint mirroring the Storage page's own button logic exactly.
- [x] Progress Dashboard (flagship analytics). New `Pages/Progress.lua` gives `ProgressSummaryService`/`MilestoneService` a real page, answering "How am I improving?" -- Hero (rating + Last-7-Days Timed % trend), Overview (season stats + a live Preparation readiness line), Last 7/30 Days (7 stats each with a trend arrow), Lifetime (9 totals), Personal Records (7 records), Recent Milestones, Current Trends (real directions only). Computes nothing itself -- purely renders `ProgressSummaryService`/`MilestoneService`/`MythicPlusModule`/`StorageModule` public getters. One compact `Dashboard.Progress` card added to Home (rating + trend + season summary), non-redundant with the existing Mythic+/Vault/Recent Activity cards. New shared `DashboardFormat.GetTrendArrow(direction)` (one glyph per trend direction) and `Dashboard:LayoutTextLines` (`Rows.lua`) -- the latter extracted from `Pages/Achievements.lua`'s own page-local `LayoutRecentAchievements` the moment Recent Milestones needed the identical pooled-list-with-empty-state shape; Achievements' old duplicate is gone, its call site now uses the shared version.

### v1.0 Visual Polish Sprint

A full visual/UX audit of every Dashboard file (`Layout.lua`, `Format.lua`, `DashboardCard.lua`, `BaseWindow.lua`, `BaseWidget.lua`, `Home.lua`, `Sections.lua`, `Rows.lua`, `Navigation.lua`, `Pages/Achievements.lua`) before any implementation, per the sprint's own "audit first" brief -- no new gameplay systems, only presentation.

**Critical bug found and fixed:** Home.lua built its page as a plain `Frame` with no `ScrollFrame`, unlike every other page (`CreateDataPage`). Stacking all 12 Home cards at their real heights runs to roughly 1,600px of content in a ~670px usable viewport -- WoW does not clip a plain Frame's children to its own bounds, so the bottom several cards (Recent Activity onward, plus the version footer) rendered past the window's edge, unclipped and completely unreachable. Fixed by giving Home the exact same ScrollFrame/ScrollChild shape every other page already uses, with content height measured after the fact (from the greeting to the footer) since every Home card's height is dynamic, unlike a static-schema page's.

**Biggest visual-quality gap found and fixed:** zero window or card in the entire addon had any border/edge treatment -- `BaseWindow.lua`, `DashboardCard.lua`, and even `SettingsWindow.lua`'s two backdrop panels all rendered as flat, edgeless `SetColorTexture`/`bgFile`-only rectangles. This was the single biggest reason the addon read as an unfinished placeholder rather than a real UI. All four now use a real `BackdropTemplate` bordered backdrop (`Interface\Tooltips\UI-Tooltip-Border`, a thin Blizzard edge texture chosen to keep this addon's flat, modern look rather than an ornate parchment frame).

**Icons wired in, using only data already collected:** `AchievementsModule.lua` already captured each achievement's real Blizzard icon FileID and never rendered it anywhere; `CharacterModule.lua` already captured `classFile` (the non-localized class token) and never rendered a class icon. New `DashboardCard:SetIcon(texture)`/`SetClassIcon(classFile)` (the latter using the same `CLASS_ICON_TCOORDS` atlas technique the default UI's own group/raid frames use, confirmed via a real published addon's source before use) -- wired to Home's Achievements card (recent achievement's real icon) and Profile card (class icon). Purely additive to `DashboardCard`: a card that never calls either method is laid out exactly as before.

**Chart added, using only data already collected:** new `Dashboard:LayoutRunLevelChart` (`Rows.lua`) -- a small bar-timeline of recent Mythic+ runs (oldest to newest, bar height = key level, color = timed/failed), rendered on the MythicPlus page just below the Hero section, directly above the existing Recent Runs table it visualizes. Purely a different rendering of `GetRecentRuns()`'s already-recorded data -- computes nothing new.

**Animation added:** `DashboardCard:SetBarValue` now eases toward its new value over 0.35s (ease-out) instead of snapping, via a per-bar `OnUpdate` that clears itself the instant the animation finishes -- an idle card costs nothing between refreshes, and a repeated refresh with an unchanged value never restarts it.

**Also fixed while auditing:** the `.toc`'s `## Notes:` field -- the line every player sees in the in-game AddOns list -- was the placeholder text `"Framework"`, left over from before this addon had a name worth describing. Replaced with a real one-line description of what the addon does. Added `## IconTexture`, previously unset (reusing the same book icon already used for the minimap launcher, not a new asset).

**Audited and found already in good shape, not changed:** empty-state messaging (`ShowEmptyLine`, "Caught Up" wording) and hover feedback on every already-clickable element were already consistent and complete; not every priority in the sprint's brief needed a code change to satisfy.

---

## Developer Tooling

- [x] Developer Mode & Live Verification Suite. New `Core/Services/DeveloperModeService.lua` (persisted on/off flag, bounded Event Monitor ring buffer, Refresh()-timing/error instrumentation installed only while enabled and fully removed when disabled, generic `ToJSON`/`ToIndentedText` serializers) and `Core/UI/DeveloperPanel.lua` (standalone window, now six tabs -- Overview, Modules, Events, Live API, Checklist, History -- see "Live Verification & Framework Hardening Sprint" below for the Checklist tab), opened via `/ac dev on` then `/ac dev`. Presentation only throughout: every value traces to an existing public getter, `DeveloperModeService`'s own observation state, or (Live API tab only, on-demand, pcall-wrapped, mirroring `DiagnosticsService`'s established precedent) a direct Blizzard API call shown next to the owning module's own already-existing parsed value. New `ActivityHistoryService:ClearAll()` (History tab's confirmation-gated Clear). Isolation is structural: instrumentation/event registration only exist while the flag is on, and `DeveloperPanel:Show()` refuses to run at all while it's off -- see `docs/GameplayModuleArchitecture.md`'s "Developer Mode & Live Verification Suite" section for the full detail, including the one disclosed exception (`scoreBreakdown` is always computed, alongside `score`/`confidence` which already were).
- [x] Recommendation Inspector score breakdown. `RecommendationEngine:ComputeScore()` now also returns (and every recommendation stores) `scoreBreakdown` -- the named terms that actually produced its score, in order, built as bookkeeping alongside the existing scoring logic (no new computation). The Recommendation Inspector's new Score Breakdown section renders it, visible only in Developer Mode -- literally "explain exactly why one recommendation beat another."
- [ ] Localize Developer Panel/Inspector strings beyond enUS (currently enUS-only additions this pass, consistent with a developer-facing tool being lower priority for translation than player-facing UI, but flagged rather than silently assumed).

---

## Live Verification & Framework Hardening Sprint

Extended the Blizzard API Verification Workflow to every remaining module (Character, Inventory, Achievements, Progress, Recommendation Engine, Notification Service, Milestone Service, Developer Panel itself) and replaced one-off doc audits with permanent, queryable tooling. Full per-API citation list lives in `Core/Services/VerificationService.lua`'s `REGISTRY`, not duplicated here -- this is the "documentation as data" the sprint asked for; this entry summarizes the findings and code changes only.

- [x] Built `Core/Services/VerificationService.lua` -- single source of truth for every Blizzard API's classification (Blizzard Source / Warcraft Wiki / Live Client / Needs Live / Incorrect), a citation, expected behavior, and confidence, plus a persisted log (`DatabaseService:GetGlobal().VerificationLog`/`.ChecklistLog`, account-wide) written only by an explicit human action -- never automatically. 37 registry entries across all 11 modules; 26 guided checklist scenarios, each naming exactly which registry ids it exercises (several deliberately name none, with an honest "nothing to check" note rather than padding).
- [x] Expanded the Developer Panel's Live API tab into a real validation suite: a Verification Summary line (counts by status), each of the 4 existing probes (Weekly/Storage/MythicPlus/Affixes) now shows Expected/Confidence/Source/Last-Verified alongside the existing Raw/Final comparison, with new "Mark Verified"/"Mark Failed" buttons per probe that write to the persisted log -- and a read-only Full Verification Registry section listing all 37 entries, not just the 4 with a live-comparable probe.
- [x] Built the Developer Panel's new Checklist tab -- all 26 guided scenarios from the sprint brief (Login, Reload UI, Character Select, Spec Swap, Hearthstone, Zone Change, Flight Path, Death, Resurrection, Dungeon Enter/Leave, Keystone Insert/Complete/Fail, Great Vault, Bank, Reagent Bank, Warband Bank, Mailbox, Vendor, Auction House, Achievement Earned, Inventory Full, Equipment Change, Currency Gain, Weekly Reset), each showing its related APIs' current status glyphs and a Mark Done/Not Done toggle that records a timestamp. Marking a scenario done never changes an API's own verification status by itself -- that's a deliberately separate action (the Live API tab's own buttons) so "I did the thing" and "I confirmed the result was correct" can't be conflated.
- [x] **Real bug found and fixed:** `AchievementsModule:RefreshCompletedAchievements()` looped a hardcoded `for achievementID = 1, 20000` -- confirmed stale (real achievement IDs already exceed 20000; Wowhead achievement 42045 is a real current-expansion achievement), meaning every achievement above that ceiling, including the entire current expansion's, was silently invisible to this addon. Fixed to match Blizzard's own Achievement UI enumeration pattern instead of a magic number: `GetCategoryList()` -> `GetCategoryNumAchievements(categoryID, true)` -> `GetAchievementInfo(categoryID, index)`, which has no fixed ceiling to go stale again.
- [x] **Real bug found and fixed:** `CharacterModule.lua` used the global `GetSpecialization()`/`GetSpecializationInfo()`, both confirmed deprecated since Patch 11.2.0 (Warcraft Wiki: "will be removed in the future"). Migrated to `C_SpecializationInfo.GetSpecialization()`/`GetSpecializationInfo()`, confirmed to return the same values in the same order -- a safe drop-in, not a guess.
- [x] **Confirmed-nonexistent APIs removed:** `C_Hearthstone.GetHearthstone` and `C_PlayerInfo.GetAccountGUID` are both absent from Blizzard's own generated API documentation and from Warcraft Wiki's full API index -- confirmed fabricated (predating this session's research tooling), and confirmed dead (their resulting fields, `hearthstoneItemID`/`warband.accountGUID`, were never read anywhere in the codebase). Removed entirely from `CharacterModule.lua` rather than patched, since there was nothing real to patch.
- [x] **Pre-existing bug found and fixed while in the area:** `DeveloperPanel:CopyCurrentTab`'s "Copy Summary" mode called `table.concat` on lines that the Live API tab stores as `{text=...}` tables (for per-line coloring), not plain strings -- would have thrown a Lua error the first time someone clicked "Copy Summary" while on that tab. Fixed by normalizing either shape before concatenating.
- [x] Confirmed clean, no changes needed: `InventoryModule.lua` (`C_Container.*`, `Enum.BagIndex.ReagentBag`, `GetRepairAllCost` -- already correctly gated behind a merchant-window check), `AchievementsModule.lua`'s `GetAchievementInfo` field order, and every framework service (`ProgressSummaryService`, `RecommendationEngine`, `MilestoneService`, `BriefingService` compute nothing from Blizzard APIs directly; `NotificationService`'s only direct call, `C_Timer.NewTicker`, is a foundational stable API).
- [ ] `ach.categoryEnumeration`'s `GetCategoryNumAchievements(categoryID, true)` `includeAll` parameter semantics are not documented on Warcraft Wiki -- passed `true` on a reasonable but unconfirmed assumption. See the Checklist tab's "Achievement Earned" scenario.
- [ ] `storage.bankerInteraction` (`Enum.PlayerInteractionType.Banker`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE` payload shape) was not researched this pass -- lowest-confidence entry in the registry. See the Checklist tab's "Bank" scenario.
- [ ] `mp.eventOrdering` (relative firing order of the 7 Challenge-Mode/Mythic-Plus events during a real run) remains open -- confirming an event exists is not the same as confirming when it fires. See the Checklist tab's "Keystone Insert/Complete/Fail" and "Dungeon Leave" scenarios.

---

## v1.0 Polish & Completion Sprint

A full-codebase audit (every Dashboard page, service, gameplay module, reusable widget) followed by consolidation and bug fixes -- no new gameplay logic. Full detail in `docs/GameplayModuleArchitecture.md` section 1.9.

- [x] Fix real bugs found by the audit. MythicPlus page's "Best Timed" stat was permanently hardcoded to "Unknown" instead of reading `seasonStats.highestTimedLevel` (real data already used elsewhere on the same page). Home's Recent Activity Card always navigated to MythicPlus even when its newest entry was an Achievement record -- now reads a `TargetPage` field set fresh every refresh. Three dead localization keys removed (superseded by `Dashboard.FeedMythicPlusTimedFormat`/`FeedMythicPlusFailedFormat` in an earlier pass, never cleaned up at the time).
- [x] Consolidate duplication the audit found. `Dashboard:ShowEmptyLine` now shared by `Rows.lua`'s `LayoutItemRows`/`LayoutTextLines` (previously each hand-rolled the same cached empty-state block). New `Logger:GetPreciseTimestamp()` replaces a line-for-line duplicate clock function in `DeveloperModeService.lua`. New `BaseWindow:AddCloseButton` replaces identical five-line close-button setup copy-pasted across all 4 standalone windows. New `DashboardFormat.HIGHLIGHT_COLOR`/`SetHighlightColor` replaces the gold accent color hand-typed 14 times across 7 files (one documented load-order exception in `Layout.lua`); also unified one stray status-green variant. New `AC.HEARTHSTONE_ITEM_ID` replaces item ID 6948 hardcoded independently 4 times across `InventoryModule.lua`/`StorageProfiles.lua`. New `ServiceManager:GetAll()`/`ModuleManager:GetAll()` replace `DeveloperModeService`/`DeveloperPanel` reaching into `.Services`/`.Modules`/`.Order` directly.
- [x] Remove dead PlayerModule. Confirmed via repo-wide grep to have zero consumers anywhere -- a "framework validation module" (its own header's words) with a live Settings page (checkboxes that did nothing observable) and a 1-second ticker. Removed entirely, `.toc` entry included. Closes the longstanding "Remove dead PlayerModule if no longer required" item under Technical Debt below.
- [x] Eliminate duplicated hearthstone detection. See `AC.HEARTHSTONE_ITEM_ID` above. Closes the matching Technical Debt item below.
- [x] Add missing hover feedback where a sibling widget of the same kind already had it. `Rows.lua`'s `BuildHistoryRow` (MythicPlus Recent Runs' expandable rows) gained the same hover highlight `BuildRecommendationRow` already had. `ColorPicker.lua`'s clickable swatch gained a highlight texture -- previously the one clickable swatch/card/link in the addon with no hover cue at all.
- [x] Repo hygiene. Removed several stray 0-byte `New Text Document.txt` files scattered across `Core/` subdirectories (untracked filesystem litter).

**Audited and deliberately left alone, each for a real reason (not silently dropped):**
- [ ] A handful of service methods came back "confirmed unused anywhere in the repo" (`MilestoneService:IsAchieved`/`GetAchievedAt`/`GetAllDefinitions`, `ActivityHistoryService:GetActivity`/`GetByType`/`Count`, `EventManager:HasSubscribers`, `Logger:SetBufferSize`) -- kept as reasonable, intentional public API surface (the same category `ActivityHistoryService:GetByDateRange` was in for an entire prior pass before `ProgressSummaryService` became its first consumer), not deleted.
- [ ] `NotificationService:GetHistory(count)` vs. `ActivityHistoryService`/`MilestoneService`'s `GetRecent(count)` -- same "most recent N" shape, different name. Real, minor, not renamed this pass (would touch a live `Home.lua` call site for a purely cosmetic gain).
- [ ] `DashboardCard`'s still-missing `Enable`/`Disable`/`Destroy`/`SetEnabled` and the `SetTooltip`/`SetEnabled` duplication across all 7 `BaseWidget` widgets -- both re-confirmed real, both left as tracked debt (see Technical Debt below); both are architecture changes, not polish.
- [ ] `CharacterModule`/`InventoryModule` independently calling `GetAverageItemLevel()` for overlapping data (see "Consolidate average item level calculation" below, re-confirmed still open), `MythicPlusModule:GetDashboardSummary()` and `RunTracking.itemLevelAtStart` (both confirmed unread anywhere) -- real findings, left as backlog items rather than an ownership change this late in a polish-only pass.

---

## Recommendation Engine

- [x] Improve scoring algorithm. (Companion Intelligence V3) `ComputeScore` gained three real terms beyond V2's four: `vaultSlotOneRunAway` (+10, a real Vault slot exactly one run from unlocking, derived from Weekly's own per-slot threshold/progress), `preparationReady`/`preparationLacking` (+8/-8, Storage's own `readinessPercent` for the Mythic+ preset -- previously informational-only, now a real deterministic scoring signal since it's StorageModule's own computed number, not a guess), and `averageRatingGain` (+min(floor(gain/5),10), the same historical rating-gain-per-run already used for `expectedBenefit`'s wording, now also a scoring input). Still fully deterministic, still zero contribution for any factor a branch doesn't supply.
- [x] Add more supporting evidence. "Complete Your Keystone" now also surfaces a real repair-status check (read from Inventory's own public getter) and a "one more run unlocks Vault Slot N" fact when real, computable (Weekly's threshold - progress == 1).
- [x] Build "Why?" dialog. `Core/UI/RecommendationInspector.lua` -- a standalone window (not a Dashboard page) showing Priority/Confidence (+ a plain-language explanation of what that level means)/Opportunity Score/Estimated Time/Reason/Expected Benefit/Supporting Evidence (grouped by contributing module)/Contributing Modules (each a real link navigating to that module's own Dashboard page)/Timestamp for one Recommendation. Computes nothing -- every field already existed on the Recommendation object; the only data-model change is `supportingEvidence` entries gaining a `module` tag (additive) so evidence can be grouped without the Inspector guessing which module a fact came from. Opened via a new "Why?" button on Home's Highest Priority card and via every recommendation row addon-wide (one shared change to `Rows.lua:LayoutItemRows`, gated on `showStars`).
- [x] Add deterministic priority explanation. `RecommendationEngine:ComputeConfidence()` (Companion Intelligence V3) -- High/Medium/Low, derived from contributing-module count, supporting-evidence count, and whether a real historical-success-rate factor is present. Rendered on every recommendation row addon-wide via the shared `Rows.lua:LayoutItemRows` (one change, every page gets it) plus Home's hand-built Highest Priority card.
- [x] Reduce duplicate recommendations / merge related recommendations. (Companion Intelligence V3) New pipeline in `RecommendationEngine:Refresh()`: Collect (InsightEngine, unchanged) -> Group (`GroupInsights` -- partitions a "Preparation" group: Inventory's Bags Almost Full/Filling Up/Hearthstone Missing/Repairs Needed + Storage's Missing/Excess Items) -> Merge (`MergePreparationGroup` -- 2+ real Preparation insights become one "Restock & Prepare" recommendation instead of several scattered ones; a lone one is left exactly as before) -> Score -> Prioritize -> Present (Dashboard, unchanged). When "Keystone Ready" is active the same refresh, `GroupInsights` omits "Storage Missing/Excess Items" and "Repairs Needed" from grouping entirely -- not dropped, genuinely subsumed, since "Complete Your Keystone"'s own evidence already carries the same two facts (see above), so a second card repeating them was real, avoidable duplication.
- [x] Reuse WeeklyModule's own vault-slot math instead of duplicating it. (Companion Intelligence V4) "Complete Your Keystone"'s "one more run away" evidence previously re-scanned `vaultProgress.slots` inline (V3); now calls `WeeklyModule:GetNextLockedSlot()`, the same shared getter the new "Vault Slot Progress" Insight uses -- the "which slot is next, how much more" logic exists in exactly one place, owned by Weekly.

---

## Storage

- [ ] Custom profile editor.
- [ ] Custom rule editor.
- [ ] Partial stack movement.
- [ ] Profile inheritance.
- [ ] User-defined groups.
- [ ] Shopping execution.
- [ ] Better preparation scoring.

---

## Mythic+

- [x] Continue expanding run history. `GetStatisticsForRange(startTime, endTime)` (Companion Intelligence V4) generalizes the season-scoped aggregation to any date window, powering `ProgressSummaryService`'s Last 7 Days/Last 30 Days/Lifetime buckets.
- [ ] Add dungeon performance comparisons.
- [x] Improve seasonal statistics. `GetSeasonStatistics()`'s whole aggregation loop is now a shared private `BuildStatisticsFromRecords()`, also used by `GetStatisticsForRange()` -- one aggregation core, not two copies -- and gained `strongestDungeon`/`longestWinStreak`/`largestRatingGain`/`hasNoDeathRun`/`totalInterrupts` in the same single pass (no new scan for any of them).
- [x] Better performance trends. `ProgressSummaryService:GetTrends()` -- runs/rating gain/deaths/timed rate/key level/consumables-per-run/interrupts-per-run, Last 7 vs. prior 7 days and Last 30 vs. prior 30, a fixed 10% threshold to call it a real trend rather than noise. Surfaced on the Progress page's Last 7/30 Days grids and Current Trends list -- see "Progress Dashboard" above.
- [ ] Continue recommendation improvements.

---

## Player Journal & Community Notes System

The one deliberately-scoped new flagship gameplay system for v1.0 -- a local, account-wide database of Mythic+ companions plus an optional, disabled-by-default Community Notes layer. Designed in Plan Mode before any code was written; full detail in `docs/GameplayModuleArchitecture.md` section 1.11.

- [x] `PlayerJournalModule` -- new module owning "who have I grouped with." Storage: `DatabaseService:GetGlobal().PlayerJournal` (account-wide, not per-character, not a `ConfigurationManager` profile -- a companion is a fact about the account, not about which alt was logged in). Player key: `"Name-Realm"`. Basic party-roster reads (`UnitFullName`/`UnitGUID`/`UnitClass`/`UnitGroupRolesAssigned`) plus a narrowly-filtered `COMBAT_LOG_EVENT_UNFILTERED` (`UNIT_DIED`/`SPELL_INTERRUPT`, roster members only) -- this is the deliberate decision `docs/GameplayModuleArchitecture.md` section 1.4's own "Party composition" note asked for, made in a new module rather than by modifying `MythicPlusModule` (which remains unmodified, self-only). Objective stats tracked per companion: Runs Together/Completed/Timed/Left Early, Average Deaths, Average Rating Gain (the run's overall score change applied identically to every companion present -- no Blizzard API attributes rating gain per player, documented inline as an approximation), Total Interrupts, Most Played Dungeon Together, Favorite Role. Unlimited personal notes (timestamped, editable) and 11 preset personal tags (including Favorite Player, the single source of truth for favorite status -- no separate boolean field). A bounded (last 200) unified timeline. Favorites are exempt from both the storage hard cap and inactivity auto-pruning.
- [x] `CommunityModule` -- new, fully independent module. Its own top-level storage key (`Global.PlayerJournalCommunity`, never nested under `PlayerJournal`'s own table -- this is what makes "`PlayerJournalModule` works with `CommunityModule` disabled" structural, not just currently-true), its own Settings page, disabled by default. Fully local this version: no sync backend, no server, so a Community Note is only ever visible to its own author regardless of its own `visibility` field (captured for a future backend, zero effect today). Helpful/Not Helpful/Report/Hide exist as real functions with real local counters (per the feature's own "moderation hooks should exist" requirement) but the UI controls calling them are disabled with a "Coming soon" tooltip, not clickable -- a working-looking vote/report button with no real crowd behind it would misrepresent the feature. A Code of Conduct confirmation gates first-ever submission.
- [x] `PlayerJournalWindow` -- new standalone `BaseWindow`, 7 tabs (Overview, History, Statistics, Personal Notes + Tags, Community Notes, Timeline, Search), spine-plus-per-tab-file split matching `Dashboard.lua`/`Pages/*.lua`. Statistics tab uses a distinct blue accent from Personal Notes/Tags' gold, per the feature's own "objective data always visually separate from opinion" requirement. `Show(playerKey)` takes a stable id (a deliberate, documented divergence from `RecommendationInspector:Show(recommendation)`'s live-object parameter). End-of-run prompt wired via a new `PLAYER_JOURNAL_RUN_RECORDED` framework event (added to `EventManager.FrameworkEvents`) rather than the module calling `StaticPopup_Show` directly -- the same "module fires, UI listens" split `NotificationService`'s own `NOTIFICATION_CHANGED` already established.
- [x] This addon's first two hooks into Blizzard's own UI (confirmed via repo-wide grep beforehand that zero precedent existed anywhere else). `Core/UI/PlayerJournalContextMenu.lua`: `Menu.ModifyMenu` adds exactly one "Azeroth Companion" submenu to the player right-click menu (Player Journal / Quick Note / Favorite Player / Hide Community Notes / Copy Character Link), registered defensively against every plausible `MENU_UNIT_*` tag (the exact tag for "any party member" couldn't be confirmed without a live client) since a `Menu.ModifyMenu` registration for a tag that never fires is a harmless no-op. `Core/UI/PlayerJournalTooltip.lua`: `TooltipDataProcessor.AddTooltipPostCall` adds Runs Together/Last Seen/a note preview/a Favorite glyph/a Community Note count to unit tooltips, gated on one setting, only ever showing lines that have real data.
- [x] Developer Panel: appended a "Player Journal" subsection to the existing Overview tab (Stored Players, Favorite Players, Total Notes, Community Notes, Oldest/Newest Entry, Database Size, Pruned Entries) rather than a new tab -- these are flat facts matching that tab's own style exactly.
- [x] `VerificationService`: 8 new registry rows and 4 new Checklist scenarios for this feature's genuinely new/unconfirmed Blizzard API surface (see Blizzard API Verification below).

**Explicitly not built this version, real stubs not fabricated features:**
- [ ] Export/Import Personal Notes -- Settings buttons exist, correctly labeled, but inert (`SettingsManager` has no `enabled=false`-at-creation support for a settings-page button today; a real, minor, documented framework gap, not worth extending for two stub buttons).
- [ ] Community Notes sync/voting/reporting backend, Trusted Sources -- structural stubs only, per the feature's own brief.
- [ ] Rich text formatting in notes -- this addon has no rich-text framework; notes are plain multi-line text, not a fabricated formatting toolbar.

---

## Companion Intelligence vNext

A cross-cutting personalization pass across `RecommendationEngine` and the Companion Intelligence V4 services, plus the first integration of `PlayerJournalModule` into the rest of the addon. Preceded by a full audit of 13 files; full detail in `docs/GameplayModuleArchitecture.md` section 1.12.

- [x] Recommendation identity: every recommendation now carries a stable, code-level `id` (not the localized `title`) -- foundation for everything below.
- [x] `RecommendationHistoryService` -- new service tracking, per recommendation `id`: first/last shown, times shown (real "cycles," not raw refreshes), likely-completed/not-acknowledged (both inferred from disappearance, always labeled as inferred, never a bare "Completed" claim), dismissed (the one certain, explicit signal), a capped score history. Persisted on `DatabaseService:GetCharacter().RecommendationHistory`, same lazy-field pattern as `MilestoneService.Achieved`.
- [x] Dismiss -- new buttons on Recommendations page rows and Home's Highest Priority card. Presentation-layer filtering only (`Dashboard:FilterDismissedRecommendations`) -- `RecommendationEngine` itself never learns a recommendation was dismissed and keeps generating it every refresh; a dismissed recommendation reappears the moment its underlying situation genuinely changes, never permanently.
- [x] Personal recommendations (Goal 1): "Frequent Companion In Party" and "Reconnect With Favorite" (new `PlayerJournalModule` insights, both gated on a real minimum sample size), "Untimed This Season" (new `MythicPlusModule` insight -- the honest, narrower version of "haven't completed this dungeon this season"; the unbounded version would need a new "enumerate every dungeon in the season pool" Blizzard API this pass doesn't introduce, logged below).
- [x] Companion Memory (Goal 2): `BriefingService` gained two real, capped observation lines -- most frequent companion, typical consumables used per run. Both independently omitted when the underlying module has no real data yet.
- [x] Today's Companion Notes (Goal 3): new `SessionNotesService` + Home card. "This session," never "last session" -- nothing in this addon persists a previous session's summary; true "last session" support is logged below as a real follow-up.
- [x] Player Journal -> RecommendationEngine (Goal 6): new `PlayerJournalModule:GetCurrentPartyJournalMatches()`, read as display-only supporting evidence on "Complete Your Keystone" (Rule 6 pattern) -- no new opinion generated about any player, and deliberately excluded from Contributing Modules (PlayerJournal has no Dashboard page to navigate to).
- [x] Smart Notifications (Goal 5): `NotificationService` gained its first-ever Settings page (a configurable cooldown, default 20 minutes) and a session-scoped `LastNotifiedAt` map, so an Insight that toggles off and back on within a session (e.g. Bags Almost Full after buying then selling items) no longer re-notifies every single crossing.
- [x] Recommendation Inspector extension (Goal 7): a new History section (last generated, times generated, completion history, completion rate, score history) reading `RecommendationHistoryService`. Opening the Inspector now calls `MarkAcknowledged(id)`.
- [x] Statistics page (Goal 8): new Dashboard page + Home entry card, following `Pages/Progress.lua`'s template, aggregating `RecommendationHistoryService`'s own real counters -- total generated/completed/dismissed/not-acknowledged, average time-to-resolve, per-category breakdown.
- [x] Polish (Goal 9): consolidated `ProgressSummaryService`'s locally-duplicated consumables/interrupts-per-run math into `MythicPlusModule:BuildStatisticsFromRecords`; removed `RecommendationEngine.lua`'s locally-duplicated `FormatDuration` in favor of `AC.DashboardFormat.FormatClock` once Statistics' average-completion-time stat gave it a real third call site; fixed a pre-existing, unrelated Settings-page `order = 60` collision between `PlayerJournalModule` and `StorageModule`.
- [x] Real bug found and fixed during self-review: `SessionNotesService` initially read `mythicPlusModule.Session` directly (an internal table, Rule 4 violation) -- fixed by adding `MythicPlusModule:GetSessionSummary()`, a real public getter, before this shipped.

**Evaluated and declined this pass, each for a real reason (audited against the user's own brief before implementation, not discovered after):**
- [ ] "Usually logs in Tuesday night" -- not buildable. Nothing in this addon records login events anywhere.
- [ ] "Usually completes Vault Wednesday" -- not buildable. `WeeklyModule` only ever reports the current week's live vault progress; it never writes to `ActivityHistoryService` (same reason `ProgressSummaryService`'s own header already declined a "Vaults Completed" trend).
- [ ] "Always repairs before raid" -- not buildable. No raid concept/module exists anywhere in this addon.
- [ ] "Usually carries 40 potions before raid" -- only partially real. Only consumed-during-run is ever recorded, never carried-in-at-start; built the honest substitute instead ("typically uses N potions per run," Companion Memory above).
- [ ] "Haven't completed this dungeon this season" (unbounded version) -- would need a new "enumerate every dungeon in the current season's pool" Blizzard API this pass doesn't introduce; built the honest, narrower "attempted but never timed this season" instead.
- [ ] True "last session" summary (vs. "this session") -- needs a new persisted `Character.LastSessionSummary`, written at the point the NEXT session's own tracking begins. Real, buildable follow-up, just not built this pass.

---

## Companion Intelligence V4 -- Player Briefing & Notifications

- [x] Build a true "Player Briefing" system. `BriefingService` -- pure curation over `InsightEngine`/`RecommendationEngine`'s already-real output (highest-priority recommendation + up to 4 insights, one per category), never generates or rephrases a fact. Rendered on Home as the "Today's Briefing" card.
- [x] Build a Notification system. `NotificationService` -- queued, one-at-a-time, auto-dismissing (1s `C_Timer` ticker) toast notifications with a bounded history, plus `Core/UI/Dashboard/Notifications.lua`'s standalone toast widget (event-driven via a new `NOTIFICATION_CHANGED` framework event, not polling). Auto-fires for a fixed set of real Insight titles (Personal Best, Rating Increased, Vault Slot Unlocked, Vault Reward Available, Achievement Earned, Achievement Milestone, Bags Almost Full) plus a Recommendation-changed detector and direct `MilestoneService` calls.
- [x] Build Personal Milestones. `MilestoneService` -- 12 definitions (First Mythic+, First +10/+15/+20, 100 Timed Runs, 1000/2000 Rating, Flawless Run, 10-Run Win Streak, Big Rating Gain, 100 Consumables, 100 Interrupts), persisted on `DatabaseService:GetCharacter().Milestones` (same pattern as `ActivityHistoryService`'s `.ActivityHistory`), each checked against a real field from `MythicPlusModule:GetMilestoneStats()` (new). "Fastest Dungeon" from the original brief evaluated and declined -- see below.
- [x] Build Long-Term Progression. `ProgressSummaryService:GetSummary()` -- Last 7 Days/Last 30 Days/Season/Lifetime, each a real `MythicPlusModule` statistics call. Surfaced on the Progress page -- see "Progress Dashboard" above.
- [x] Trend analysis. See "Better performance trends" above.
- [x] Home page: Today's Briefing / Recent Milestones / Recent Notifications / Highest Priority Recommendation, in that order, ahead of the existing Profile/Mythic+/Vault/etc. cards -- the greeting text is kept (small header above all four) rather than removed, since it's cheap and still a nice framing.

**Evaluated and declined this pass, each for a real reason (see `docs/GameplayModuleArchitecture.md`'s "Companion Intelligence V4" section for the full detail):**
- [ ] "Vaults Completed" / "Preparation improving" progress trends -- no historical record exists (`WeeklyModule`/`StorageModule` never write to `ActivityHistoryService`). Needs real historical recording added to those modules first.
- [ ] "Fastest Dungeon" milestone -- not a meaningful single comparison across different key levels; a real per-dungeon-per-level system is a larger surface than this pass scoped for.
- [ ] "Preparation Complete"/"Storage Ready"/"Bank Ready" notifications -- no session-relative "just became ready" state transition exists in `StorageModule` yet (unlike MythicPlus/Weekly's own session-relative Insights).

**New follow-ups discovered during this pass:**
- [x] Give `ProgressSummaryService`'s data a real Dashboard home -- done, see "Progress Dashboard" under High Priority > Dashboard above.
- [ ] The toast widget's position (`Core/UI/Dashboard/Notifications.lua`, `TOP_OFFSET = -80`, anchored `TOP` of `UIParent`) needs a real in-game visual check -- no live client available in this environment to confirm it doesn't overlap Blizzard's own objective tracker/alert frames at various UI scales.
- [ ] `NotificationService`'s Insight-diffing only runs when `Dashboard:RefreshEngines()` runs (i.e. whenever a Dashboard page is shown/refreshed), not on a fully independent background loop -- a notification-worthy Insight that appears and disappears between two Dashboard refreshes would never be seen. Acceptable for a first version; a fully independent poll (or, better, each module pushing its own session-relative events directly) is real future work if this turns out to miss things in practice.

---

# Medium Priority

## Character

- [ ] Character progression timeline.
- [ ] Played time history.
- [ ] More profile statistics.

## Inventory

- [ ] Recent loot.
- [ ] Vendor suggestions.
- [ ] Duplicate item analysis.
- [ ] Interesting item detection.

## Accomplishments (formerly Achievements)

Redesigned from a flat, undifferentiated cache of every completed achievement into a curated "Character Accomplishments" experience -- Blizzard's own Achievement UI already represents every achievement exhaustively, so this module now deliberately caches only what defines a character's story. Full detail in `docs/GameplayModuleArchitecture.md` section 1.3.

- [x] `AccomplishmentsModule` (renamed from `AchievementsModule`, `Modules/Accomplishments/AccomplishmentsModule.lua`) -- classifies completed achievements into ExpansionProgress/Raiding/MythicPlus/FeatsOfStrength/CharacterMilestones via two real mechanisms: a fully data-driven category tree walk (`GetCategoryList`/`GetCategoryInfo`, no hardcoded category IDs -- identifies "Feats of Strength" by its own Blizzard-provided title) and a curated signature name-pattern table (`Modules/Accomplishments/AccomplishmentsPatterns.lua` -- Loremaster/Pathfinder/Ahead of the Curve/Cutting Edge/Keystone Master+Hero/Glory of the X/Heritage of the X). Only a classified achievement is ever cached -- exploration/fishing/cooking/holiday/misc achievements are never stored, which is the entire point of the redesign.
- [x] Rename kept two literal strings unchanged for save-data compatibility: `ActivityHistoryService`'s stored `Module` tag (still `"Achievements"`) and `DeveloperPanel.lua`'s History Inspector filter list -- existing players' saved history isn't orphaned.
- [x] Campaign completion (`C_CampaignInfo`) and Renown (`C_MajorFactions`) included this pass as a deliberate, user-approved scope decision -- neither is achievement data, and Renown specifically collides with the already-planned (not yet built) Reputation module (section 2.1), which the addon has explicitly accepted as a future migration if that module ever gets built. Kept structurally separate from the accomplishments cache (`self.CampaignProgress`/`self.RenownProgress`, own refresh functions/getters) so that migration is a clean cut.
- [x] New fully-dynamic Dashboard page (`Core/UI/Dashboard/Pages/Accomplishments.lua`, replacing the old static-schema Achievements page) -- Hero (count/points/next milestone) -> Expansion Progress -> Raiding -> Mythic+ (completion facts only -- `MythicPlusModule` remains the sole owner of run/rating data) -> Feats of Strength (given prominence, a primary section per the feature's own brief) -> Character Milestones -> Legacy Accomplishments (honest empty state) -> Recent History -> Recommendations/Insights.
- [x] `VerificationService.lua`: 5 new registry rows for the genuinely new API surface this pass (`GetCategoryInfo`, `C_CampaignInfo.*`, `C_MajorFactions.*`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`) plus one for the signature-pattern table itself, explicitly flagged as an ONGOING per-expansion content-drift risk rather than a one-time API-shape confirmation -- qualitatively different from every other row in that registry.
- [x] Real bug found and fixed during self-review: an early draft of `SessionNotesService` (Companion Intelligence vNext, previous pass) referenced `mythicPlusModule.Session` directly (an internal table) -- unrelated to this pass but caught while auditing session-summary call sites for the rename; already fixed before this pass, noted here for completeness.

**Explicitly not built this version, real gaps not fabricated features:**
- [ ] "Legacy Accomplishments" auto-population -- no Blizzard signal exists to detect "historically interesting"; would need a maintained curated ID list, the same discipline as the signature-pattern table but with even less API support. Ships with an honest empty state.
- [ ] Per-criterion progress on incomplete achievements (`GetAchievementNumCriteria`/`GetAchievementCriteriaInfo`) -- exists but unaudited this pass; would enable "3 of 10 dungeons timed toward Keystone Master"-style recommendations. Real follow-up, needs its own audit pass first.
- [ ] The unbounded "haven't completed this dungeon this season" / true expansion-completion-percentage detection -- would need a new "enumerate every achievement in the season's pool" Blizzard API surface this pass doesn't introduce.
- [ ] Non-English locale support for the Feats of Strength category match -- currently matches the English literal "Feats of Strength" title; Blizzard returns that title already localized with no other signal to identify the category by.

### Accordion / Character Story Redesign

After using the page in-game, the flat static list was replaced with an accordion experience -- the first step toward a "Character Journey" direction, now built (see "Character Journey" below). Full detail in `docs/GameplayModuleArchitecture.md` section 1.3's "Dashboard responsibilities — Accordion Redesign" subsection.

- [x] Collapsed accomplishment rows show **only the name** (no more baked-in earned date, e.g. was `"Immortal Spelunker (Jun 23, 2026)"`, now just `"Immortal Spelunker"`) at a higher visual weight (`GameFontNormal` + gold highlight) than any metadata -- the core ask.
- [x] Clicking a row expands it in place with Earned date / Category / Expansion (omitted, never fabricated, when unresolved) / Blizzard's own achievement Description. Only one accomplishment expanded **page-wide** at a time via a single shared `page.ExpandedAccomplishmentID` -- expanding a new one anywhere on the page collapses whatever was previously expanded.
- [x] New `Dashboard:LayoutAccordionRows` engine (`Core/UI/Dashboard/Rows.lua`) generalizes the accordion mechanic (pooling, single-expanded-item toggle, dynamic row height, detail show/hide) that previously existed only as `Dashboard:LayoutHistoryRows`, hardcoded to MythicPlus's Recent Runs table. `LayoutHistoryRows` is now a thin, formula-verified output-identical wrapper over the same engine -- `Pages/MythicPlus.lua` needed zero code changes. New `Dashboard:BuildAccomplishmentRow` (generic single-line clickable row) plugs into the shared engine for Accomplishments.
- [x] New `expansion` field on every cached accomplishment, inferred (never fabricated) via a new `Modules/Accomplishments/AccomplishmentsExpansionNames.lua` data file -- same "trust Blizzard's own category title" precedent already used for Feats of Strength, same living-document/ongoing-verification framing already used for the signature-pattern table (`VerificationService`'s new `acc.expansionNames` entry).
- [x] `Pages/Accomplishments.lua` restructure: `BuildExpansionProgressLines` split into `BuildCampaignAndRenownLines` (plain text, unchanged -- Campaign/Renown aren't achievements) + real `ExpansionProgress`-category accomplishments now rendered as accordion rows alongside it under the same section header.
- [x] Loc keys: added `Accomplishments.FieldEarned`/`FieldCategory`/`FieldExpansion` (expanded-view field labels) and `Accomplishments.NoCampaignOrRenownProgress` (new empty state, can now appear on a fresh character with zero campaign/renown data); reworded `Accomplishments.NoExpansionAccomplishments` (narrowed scope, a real visible string change); deleted `Accomplishments.AccomplishmentLineFormat` (`"%s (%s)"`, the literal date-baked-in format this whole change removes).

**Explicitly not built this version:**
- [ ] Recent History section stays plain text, not accordion rows -- its stored `ActivityHistoryService` records don't carry description/expansion inline; converting it would need a per-row `AccomplishmentsModule:GetAccomplishment()` lookup. A real Phase 2 follow-up, not an oversight.
- [ ] Timeline integration, Player Journal references, related-accomplishment cross-links inside the expanded accordion view -- the "Character Journey" direction this architecture now accommodates (the expanded section is exactly where these would live), and Character Journey itself is now built (see below) -- but these specific cross-links are not implemented yet.
- [ ] Accomplishment icon rendering -- already captured in data (`accomplishment.icon`, a Blizzard texture ID) but never rendered anywhere in `Rows.lua`; a real future addition, kept out of this pass to stay scoped to what was asked.

---

## Character Journey (Phase 1)

A brand-new signature feature: a curated, chronological "museum" of a character's meaningful lifetime moments -- explicitly not another activity log. Answers "who has this character become," not "what happened yesterday." A full audit of every history-shaped system in the addon found the raw material mostly already existed; the real work was aggregation and presentation, not new tracking. Full detail in `docs/GameplayModuleArchitecture.md` section 9.

- [x] New `Core/UI/Dashboard/Pages/Journey.lua` -- **zero new persisted state, zero new Blizzard API calls, zero new service.** Pure aggregation over `AccomplishmentsModule:GetAccomplishments()` (Blizzard's own earned date, re-derived live, no pruning) and a new `MilestoneService:GetAllAchieved()` getter (every achieved milestone, untrimmed -- `GetRecent(count)` now just adds the trim on top, zero behavior change for its existing callers).
- [x] Applies **no additional curation filter** on top of what `AccomplishmentsModule` already classifies -- a Journey-local filter stricter than its own sibling Accomplishments page would make the same fact "signature enough" on one page and not the other, a real inconsistency rather than an improvement.
- [x] Ordering is **oldest-to-newest, grouped by year** -- a deliberate, explicit departure from every other Dashboard list (all newest-first), since this page tells a story arc, not "what's new." Direct existing precedent: `Rows.lua`'s `LayoutRunLevelChart` already ships this exact "oldest on the left, newest on the right" reasoning. A new pooled `LayoutYearSeparator` (page-local) is used instead of a full `BeginSection`/`EndSection`, the wrong tool for a per-year runtime string.
- [x] Rows reuse `Dashboard:LayoutAccordionRows` (once per year-bucket) and `Dashboard:BuildAccomplishmentRow` unchanged. One shared `page.ExpandedJourneyEntryID` gives page-wide accordion behavior across every year for free (record IDs are globally unique across sources).
- [x] Promoted `Dashboard:SetAccordionDetailField`/`HideAccordionDetailField` out of `Pages/Accomplishments.lua` into `Rows.lua` (byte-identical bodies, zero behavior change for Accomplishments) the moment Journey needed the identical cached label/value mechanic -- the same "shared the moment a second real caller needs it" discipline `LayoutTextLines`/`LayoutAccordionRows` themselves were promoted under.
- [x] Home page Journey card (entry count, most recent moment) added between the Accomplishments and Storage cards.
- [x] Loc keys: `Dashboard.Journey`/`TooltipJourney`/`JourneyEntryCountFormat`/`RecentJourneyEntryFormat`/`JourneyUnavailable`, `Journey.HeroHeadline`/`HeroCaptionFormat`/`EmptyHeroCaption`/`EmptyStateBody`/`EntryLineFormat`/`UndatedSectionLabel`/`FieldRecorded`/`CategoryPersonalMilestone` (reuses `Accomplishments.FieldEarned`/`FieldCategory`/`FieldExpansion` for the shared fields rather than duplicating them).

**Two real fabrication risks found during the audit and explicitly excluded, not worked around:**
- [ ] Player Journal-sourced entries ("first met a favorite player," "50 runs together") -- `PlayerJournalModule`'s storage is account-wide with no field recording which of the account's characters met a companion or logged a run. Attributing an account-wide fact to "this character's journey" without that field would be a guess. Honest unblock: a per-character attribution field written once alongside the existing `firstSeen = time()`, plus a per-character runs-together counter -- additive, no migration step, a real future module change.
- [ ] Recommendation History / Community Notes-sourced entries -- neither has any "notable moment" concept today, only routine engagement counters. Buildable later from existing getters (`timesCompleted`, `GetTotalNoteCount()`) once a real threshold definition is designed.

**Explicitly not built this version:**
- [ ] Phase 2 -- `MilestoneService`'s `check(stats)` → `check()` generalization (only once actually needed to add a non-MythicPlus definition) + new threshold definitions unblocked by the two exclusions above (50-runs-together, Nth Community Note, Recommendations Completed milestone).
- [ ] Phase 3 -- "highest Mythic+ ever, with a date" -- a genuinely different "record can be broken again" pattern, structurally incompatible with `MilestoneService`'s achieve-once model. Belongs to `MythicPlusModule` (Rule 1), a small new persisted map updated only when a new max is detected inside the existing run-recording path.
- [ ] Phase 4+ -- expansion "chapter" summary cards (the year-grouped data model re-slices by expansion later without a data-model change), exportable/shareable Journey, accomplishment icon rendering (already logged above).

---

# Technical Debt

## Presentation Layer

Centralizes formatting primitives (dates, numbers, durations, semantic colors) that were duplicated -- and, for dates and colors, already drifted -- across the addon. Full detail in `docs/GameplayModuleArchitecture.md` section 8.

- [x] New `AC.Presentation` (`Core/Presentation/Presentation.lua`) -- `FormatDate(timestamp, style)` (`"short"`/`"shortTime"`, always includes a 4-digit year -- the actual bug fix), `FormatRelativeTime(timestamp)` (new capability -- "Today"/"Yesterday"/"N days ago", falls back to `FormatDate` past 30 days rather than a fabricated "N months ago"), `FormatNumber`/`FormatPercent`/`FormatRating`/`FormatItemLevel`, `FormatNumberWithCommas`/`FormatDuration`/`FormatMoney`/`FormatClock` (moved verbatim from `DashboardFormat`), `GetSemanticColor(name)` (`"success"`/`"warning"`/`"critical"`/`"dim"`/`"highlight"`).
- [x] Fixed the real bug: 10 confirmed `date("%b %d", ...)` (no year) call sites across `Rows.lua` (History Table row + Run Level Chart tooltip), `Pages/Accomplishments.lua`, `Pages/Progress.lua`, `Pages/MythicPlus.lua` (x2), `RecommendationInspector.lua`, `PlayerJournal/Tabs/History.lua`, `DeveloperPanel.lua`, `Pages/Profile.lua`. The 11 already-correct `%Y`-including sites were deliberately left untouched this pass (see deferred items below).
- [x] `DashboardFormat` narrowed to Dashboard/Recommendation-specific composed presentation only (`RenderStars`/`PriorityToStars`, `CHECK_SUCCESS`/`CHECK_FAILURE`, `GetTrendArrow`) -- a real category boundary, not arbitrary. `FormatNumberWithCommas`/`FormatDuration`/`FormatMoney`/`FormatClock`/`HIGHLIGHT_COLOR` became thin backward-compatible aliases to `AC.Presentation`, so the ~50 pre-existing `AC.DashboardFormat.X(...)` call sites across the codebase needed zero changes.
- [x] Consolidated 15+ raw `string.format("%.0f"/"%.0f%%", ...)` call sites (rating/item-level/percent) across `RecommendationEngine.lua`, `Home.lua`, `Pages/Inventory.lua`, `Pages/Profile.lua`, `DeveloperPanel.lua`, `PlayerJournal/Tabs/Statistics.lua`, `Pages/MythicPlus.lua`, `Pages/Progress.lua`. Deliberately did NOT touch the 3 signed `+/-` sites (see existing Architecture item below) -- folding them in would have silently resolved that item's still-open `>= 0` vs `> 0` boundary question without doing the in-game verification it explicitly requires.
- [x] Consolidated drifted semantic color literals into one canonical value each: `success`/`warning`/`critical` (Home.lua's bar colors, `Notifications.lua`'s toast colors, `Rows.lua`'s Run Level Chart -- the latter two had genuinely different literals for the same meaning, now visually identical everywhere) and `dim` (6 byte-identical `0.7, 0.7, 0.7` "label" sites across `Rows.lua`, `Sections.lua`, `Pages/Storage.lua`, `RecommendationInspector.lua`).

**Explicitly deferred, not built this pass:**
- [ ] Migrate `PlayerJournalModule.lua`'s `GetStaleFavorites` hand-rolled day-since math to `Presentation.FormatRelativeTime`.
- [ ] Broader text-color semantic audit -- `DashboardCard.lua`'s other grays (secondary/indicator/caption, each a slightly different literal) and `DeveloperPanel.lua`'s grays were found during the audit but deliberately scoped out this pass (see section 8's "dim" scoping note) -- narrower and more ambiguous than the 6 byte-identical sites actually consolidated.
- [ ] `Sections.lua`'s `LastUpdatedFormat` (`date("%H:%M:%S", lastRefresh)`) migrating to a future `Presentation.FormatTime` -- no year component, so no urgency.
- [ ] Typography, Icon Styling, Density, Themes, Accessibility, UI Profiles namespaces -- zero existing duplication found for any of them; would be speculative scaffolding, not centralization of a real pattern. Revisit when a real second theme, font-scaling requirement, or accessibility need exists.

---

## Presentation System v2 -- Phase 1 (Token Consolidation)

A full UX/UI audit (every widget, every Dashboard page, every satellite window) beyond the Presentation Layer pass above -- found real, demonstrated duplication a first pass hadn't reached: `DashboardCard.lua` had its own parallel constant block that never referenced `Layout.lua`, the same semantic meaning rendered as different literal colors across files, three independent empty-state implementations, and identical width-remeasure boilerplate hand-copied across 7 page files. Full detail in `docs/GameplayModuleArchitecture.md` section 8's "Presentation System v2" subsection. First of a 3-phase roadmap (see that section for Phase 2/3).

- [x] New `Presentation.SEMANTIC_COLORS.accent` (`{0.55, 0.75, 1}`) -- canonicalizes `PlayerJournal/Tabs/Statistics.lua`'s own already-deliberate cool-blue value; `RecommendationInspector.lua`'s link-button blue and `PlayerJournal/Tabs/Overview.lua`'s Tags-section blue migrated to it (real, visible color change on both -- three unrelated "info" blues unified into one meaning).
- [x] New `Presentation.WINDOW_BACKDROP`/`PANEL_BACKDROP` tables. `BaseWindow.lua` and `SettingsWindow.lua`'s `navigationHost` migrated with zero visual change (values kept verbatim). `SettingsWindow.lua`'s `contentHost` panel, which previously disagreed with its own sibling panel, now matches it -- a real, visible darkening.
- [x] `DashboardCard.lua`'s full padding/gap/icon constant block moved into `Layout.lua` as `Layout.CARD_*` fields (pure relocation, zero visual change) -- fixes the single largest "parallel design-token file" violation found in the whole audit. Read inline at point-of-use to respect the `.toc` load order (`DashboardCard.lua` loads before `Layout.lua`).
- [x] Real color migrations to existing `success`/`critical`/`dim`/`warning` tokens across `Sections.lua`, `DashboardCard.lua`, `Rows.lua`, `RecommendationInspector.lua`, `PlayerJournal/Tabs/Overview.lua`, `DeveloperPanel.lua` (4 separate sites). `PlayerJournal/Tabs/Statistics.lua` and `PlayerJournal/Tabs/History.lua`'s "left early" red were already byte-identical to the canonical token -- pure refactors, zero visual change.
- [x] Deleted a dead `section.emptyText` branch in `Sections.lua`'s `BuildFieldRows` (confirmed via grep: no schema ever sets it).
- [x] `Pages/Recommendations.lua`'s "Caught Up" empty state kept its deliberate celebratory styling but had its two real bugs fixed: an untied gray color (now `GetSemanticColor("success")`) and hardcoded width/height that bypassed real measurement (now uses real string-height measurement).
- [x] New `Dashboard:MeasureAndApplyScrolling(page, scrollChild, measureFn)` (`Sections.lua`) replaces a byte-identical remeasure block hand-copied across all 7 dynamic pages (`Pages/Recommendations.lua`, `Storage.lua`, `Weekly.lua`, `MythicPlus.lua`, `Accomplishments.lua`, `Progress.lua`, `Statistics.lua`).
- [x] `PlayerJournalWindow.lua` had a real duplicate-title bug -- a separate `GameFontNormalLarge` identity FontString layered on top of `BaseWindow`'s own default `frame.Title`. Fixed by mirroring `Home.lua`'s own precedent: reposition and reuse `frame.Title` instead of creating a second one.

**Explicitly deferred, not built this pass:**
- [ ] Phase 2 -- promote `Sections.lua`/`Rows.lua`'s presentation primitives (`BeginSection`/`ShowEmptyLine`/`BuildHeroSection`/pooled-row layout) into a shared, addon-wide `PresentationWidgets.lua` that `DeveloperPanel.lua`/`PlayerJournalWindow.lua` call instead of each hand-rolling their own near-duplicate `LayoutLines`-style helper. The real fix for why those windows still read as a slightly different visual dialect from the Dashboard.
- [ ] `DashboardCard.lua`'s remaining unaudited grays (Detail Section caption, `SetStatus` else-branch, hover-indicator) and `DeveloperPanel.lua`'s `LayoutLines` default text color/one metadata-line gray -- found during the audit, deliberately left alone as judgment calls rather than confirmed duplication.
- [ ] Phase 3 -- Themes/Density/Accessibility/UI Profiles/Animations. Same reasoning as the Presentation Layer section above: one visual treatment exists addon-wide, so this would be speculative scaffolding.

---

## Canonical Absolute Date Format Sweep

A full repo grep for date-display call sites (not just the 10 no-year bugs the Presentation Layer pass already fixed) found one more real bug and 9 duplicate hand-rolled implementations of the addon's own canonical `Presentation.FormatDate` styles. Full detail in `docs/GameplayModuleArchitecture.md` section 8.

- [x] **Real bug fixed:** `Pages/Accomplishments.lua`'s `FormatEarnedDate` displayed accomplishments as `MM/DD` with no year at all (`string.format("%02d/%02d", month, day)`) -- the exact "month/day-only" presentation bug the Presentation Layer pass was meant to eliminate, missed because it was a `string.format`, not a `date(...)` call. Fixed by building a real timestamp (`time({year = 2000 + accomplishment.year, month, day})`, using Blizzard's documented 2-digit year-offset convention for `GetAchievementInfo`) and routing it through `Presentation.FormatDate(timestamp, "short")`.
- [x] Migrated 9 remaining hand-rolled `date("%b %d, %Y"...)` call sites to `Presentation.FormatDate` instead of duplicating the format string: `PlayerJournalTooltip.lua`, `DeveloperPanel.lua` (x2, Player Journal oldest/newest entry), `RecommendationInspector.lua` (x2), `PlayerJournal/Tabs/Overview.lua` (`FormatRelativeDate`, kept as a thin wrapper -- still handles the "Unknown" fallback its 2 call sites need), `PlayerJournal/Tabs/CommunityNotes.lua`, `PlayerJournal/Tabs/Search.lua`. These already displayed the correct `Mon DD, YYYY` text -- no visual change, just removing 9 independent copies of the same format string that could have silently drifted from the canonical one.
- [x] `PlayerJournal/Tabs/Timeline.lua` and `PlayerJournal/Tabs/PersonalNotes.lua` (x2) previously used `"%b %d, %Y %H:%M"` -- a single space before the time, a third variant distinct from both the no-time `"short"` style and the double-space `"shortTime"` style. Migrated to `Presentation.FormatDate(timestamp, "shortTime")` -- a real, minor visual change (single space becomes the canonical double space), called out rather than silently absorbed.
- [x] Left deliberately untouched: `MythicPlusModule.lua`/`ActivityHistoryService.lua`'s `date("%Y-%m-%d", ...)` internal day-bucketing keys (never displayed to the player), `Logger.lua`/`DeveloperPanel.lua`'s `HH:MM:SS` clock-time formatting (not a date), and `DeveloperPanel.lua`'s History Inspector single-line debug listing (`date("%Y-%m-%d %H:%M", ...)`, a dense machine-readable dev-tool log line, consistent with that panel's already-established "different visual dialect, out of Dashboard-consistency scope" precedent).

---

## Accordion Polish Pass

After using the Accomplishments/Journey accordion pages in-game, a real layout bug and three UX gaps were found and fixed at the shared engine level (`Core/UI/Dashboard/Sections.lua`/`Rows.lua`), not with per-page padding hacks -- every fix automatically benefits Accomplishments, Journey, MythicPlus's Recent Runs table, and any future accordion page. Full detail in `docs/GameplayModuleArchitecture.md` section 1.3's "Accordion Polish Pass" subsection.

- [x] **Real bug fixed -- root cause of section headers occasionally clipping the following section:** `Dashboard:BeginSection`/`Dashboard:AddDivider` created a brand-new, never-pooled FontString/Texture on every call. Every dynamic page's `Layout_` re-runs this on every refresh -- on accordion pages, on every single row click -- so old ghost headers/dividers from earlier layout passes never got hidden, froze at stale Y positions, and could visually intrude into a section that had since become shorter. Fixed by pooling both directly on `scrollChild` (`scrollChild.SectionHeaders[titleKey]`/`scrollChild.Dividers[cacheKey]`), the same "cache on the object that owns it" idiom `ShowEmptyLine` already used -- zero call-site changes needed for `BeginSection` anywhere in the codebase. `RecommendationInspector.lua` turned out to be a third real (previously unnoticed) victim of the same bug -- fixed for free, plus one small explicit-hide addition for its one conditional `BeginSection` call site (`Inspector.ScoreHistory`).
- [x] **Secondary real bug, same area:** `ShowEmptyLine` and all three `layoutCollapsed` implementations returned a hardcoded height constant regardless of real (possibly word-wrapped) text height -- a long accomplishment/achievement name wrapping to 2 lines silently under-reported its height. All four now measure real `GetStringHeight()` with the original constant kept as a safe fallback.
- [x] **Disclosure indicator, owned by the shared engine, not any page:** `Dashboard:LayoutAccordionRows` itself now creates/updates a pooled ▶/▼ glyph (new `DashboardFormat.DISCLOSURE_COLLAPSED`/`DISCLOSURE_EXPANDED`) on every row, reusing the exact toggle-state boolean the engine already computes -- MythicPlus's Recent Runs table gets it automatically with zero MythicPlus-authored code. New `Layout.ACCORDION_DISCLOSURE_WIDTH` (14px) reserves the left column.
- [x] **Deeper expanded-detail hierarchy:** new `Layout.ACCORDION_DETAIL_INDENT` (30px) -- `Dashboard:SetAccordionDetailField` now nests expanded fields visibly under the row's own title instead of flush with it. The byte-identical `row.DescriptionText` block duplicated independently in both `Pages/Accomplishments.lua` and `Pages/Journey.lua` is promoted into new `Dashboard:SetAccordionDetailDescription`/`HideAccordionDetailDescription` (`Rows.lua`).
- [x] **Hover feedback audited, found already adequate:** `BuildHistoryRow`/`BuildAccomplishmentRow` already tinted the full row background on hover, matching `BuildRecommendationRow`'s established subtle value. No new mechanism added.

**Explicit visible change, flagged not silent:** MythicPlus's Recent Runs columns (Status/Date/Level/Name) shift right 14px to make room for the shared disclosure icon -- the one intentional, pre-approved exception to "MythicPlus stays pixel-identical" this pass, since the user explicitly asked for the shared improvements to extend to it.

---

## Architecture

- [x] Remove dead PlayerModule if no longer required. (v1.0 Polish Sprint) Confirmed via repo-wide grep to have zero consumers; removed entirely.
- [x] Eliminate duplicated hearthstone detection. (v1.0 Polish Sprint) New `AC.HEARTHSTONE_ITEM_ID` (`InventoryModule.lua`), replacing item ID 6948 hardcoded independently in `InventoryModule.lua` (x2) and `StorageProfiles.lua` (x2).
- [ ] Consolidate average item level calculation. Re-confirmed still open (v1.0 Polish Sprint audit) -- `CharacterModule.lua` and `InventoryModule.lua` each independently call `GetAverageItemLevel()` for overlapping data instead of Inventory reading Character's already-computed value. Not changed this pass (an ownership question between two gameplay modules, not in scope for a polish-only sprint).
- [x] Continue reducing duplicated Dashboard code. (Dashboard Refactor, see High Priority > Dashboard above.)
- [ ] Consolidate the 3 remaining separate "+/-" signed-number formatting call sites (Profile's `itemLevelGained`, Inventory's `bagUsageChange`, MythicPlus's run rating-change detail line) into a shared `DashboardFormat.FormatSignedNumber`. Originally logged as 4 sites; the 4th ("Home's Recent Activity rating-change") was confirmed dead code during the v1.0 Polish Sprint audit -- its localization key (`Dashboard.RatingChangeFormat`) was unused anywhere, a leftover from before Home Dashboard Evolution replaced that display with the check/cross feed, and has been removed. The remaining 3 still differ on whether exactly `0` earns a "+" prefix (`>= 0` vs. `> 0`) -- collapsing them needs an `includeZero` parameter and an in-game check that boundary behavior is preserved exactly, not just verified by reading the code.
- [ ] Decide whether `DashboardCard` (`Core/UI/Widgets/DashboardCard.lua`) should conform to the `BaseWidget`/`WidgetManager` contract every other widget in that folder uses. It currently bypasses both (constructed via `AC.DashboardCard:Create`, no `Enable`/`Disable`/`Destroy`/`SetEnabled`). **Higher priority than when this was first logged** -- the Home Dashboard Evolution pass just gave it a second major capability (`SetDetailSections`, a pooled label/value block renderer with its own bar-repositioning logic), making it a meaningfully richer, more bespoke widget than it was. The longer this stays unresolved, the more there is to retrofit later.
- [ ] `DashboardCard:SetDetailSections`' pooled `Caption`/`Body` FontStrings are never destroyed, only hidden, for the lifetime of the card (consistent with every other pooled list in this codebase, e.g. `Rows.lua`'s history/statistics pools) -- fine at Home's scale (6 cards, at most ~4 sections each), worth a second look only if a future page pools many more cards than Home ever will.
- [ ] `SetTooltip`/`SetEnabled` are reimplemented near-identically across all 7 `BaseWidget`-derived widgets (Button/Checkbox/ColorPicker/Dropdown/EditBox/Label/Slider) instead of being hoisted onto `BaseWidget` itself. Unrelated to the Dashboard split; a future Widgets cleanup pass.
- [x] Consolidate the priority-to-stars star string, previously written inline in two places -- `Rows.lua:LayoutItemRows` (via `DashboardFormat.PriorityToStars`) and `DashboardCard:SetStarRating` (its own undocumented duplicate of the same `math.ceil(priority/20)` formula, never actually routed through `PriorityToStars`). Found while wiring up the Recommendation Inspector's own Priority field, which would have been a third copy. New `DashboardFormat.RenderStars(priority)` is now the one place this exists; `DashboardCard.lua`'s now-dead local `STAR_FILLED`/`STAR_EMPTY` constants were removed with it.

## Performance

- [ ] Improve ActivityHistory pruning performance.
- [ ] Review repeated Blizzard API calls.
- [ ] Review widget allocations.
- [ ] Continue reducing garbage generation.

## Persistence

- [x] Versioned migration system.
- [ ] Add migration tests.
- [ ] Add schema upgrade documentation.

---

# Blizzard API Verification

**This section is no longer the authoritative list -- `Core/Services/VerificationService.lua`'s `REGISTRY` is.** That file is real, loaded, queryable Lua data (45 entries across all 11 gameplay modules plus Player Journal/Community), rendered live in the Developer Panel's Live API tab (full registry listing, status glyphs, citations, confidence, persisted last-verified timestamps) and its Checklist tab (30 guided in-game scenarios, each naming exactly which registry ids it settles). A markdown list next to that would only drift out of sync with it, so this section is intentionally kept short: open `/ac dev on` then `/ac dev` in-game for the current, real state.

Player Journal & Community Notes added 8 new registry rows this pass: `pj.rosterUnitAccessors`/`pj.unitDiedCombatLog`/`tooltip.postCall` (wiki-confirmed, high confidence), `ctxmenu.modifyMenu`/`ctxmenu.createCheckbox` (wiki-confirmed, medium -- the mechanism is real, exact contextData shape isn't), and three genuinely open items: `pj.rosterLeaveDetection` (the grace-period leave heuristic is addon-side, not a documented Blizzard behavior), `pj.eventOrderingDefer` (the one-frame-defer fix is correct by inspection of `EventManager.lua`'s own dispatch order, not yet watched happen live), `ctxmenu.unitMenuTags` (the exact `MENU_UNIT_*` tag name for "any party member" -- registered defensively against every plausible tag in the meantime).

As of the Live Verification & Framework Hardening sprint, the registry contains zero entries with no citation and zero generic "needs verification, unspecified" items -- every `needsLive`-status entry names the exact API, the exact reason source/docs couldn't settle it, and (via the Checklist tab) the exact in-game scenario that would settle it. See "Live Verification & Framework Hardening Sprint" under High Priority above for the summary of what this pass found and fixed.

---

# UX Improvements

- [ ] Better card spacing.
- [x] Better typography. `DashboardCard:SetDetailSections`' `emphasized` flag renders a section's value in a bigger/brighter font than plain detail text -- used for Profile's Item Level and Vault's Highest Reward, the two numbers on Home actually worth calling out. Not applied addon-wide yet (only the 6 redesigned Home cards).
- [x] More informative icons. Recent Activity feed lines use the same green-check/red-cross glyphs as the Mythic+ history table (now shared via `DashboardFormat.CHECK_SUCCESS`/`CHECK_FAILURE` instead of being duplicated).
- [x] Progress bars where appropriate. Vault Progress card gained the bar its name always implied but never had (`showBar` was never set on it before this pass).
- [ ] Better empty states.
- [x] More consistent section layouts. `DashboardCard:SetDetailSections` gives every Home card the same "label caption, then value" layout primitive instead of each card hand-formatting its own detail blob.

---

# Future Modules

- [ ] Delves
- [ ] Raids
- [ ] Currency
- [ ] Professions
- [ ] Reputation
- [ ] Collections
- [ ] PvP
- [ ] Warband
- [ ] Mounts
- [ ] Pets

---

# Long-Term Vision

## Advisor

A layer above RecommendationEngine.

Purpose:

Convert gameplay data into a personalized session plan.

Example:

Good Evening.

Today's Focus

★★★★★

Complete your +13 Mythic+.

Why?

- Highest upgrade opportunity.
- Vault progress.
- Historical success rate.

Preparation

✓ Ready

Estimated Session

38 minutes.

---

# Ideas

Record ideas here before they are forgotten.

- [ ] Death heat maps.
- [ ] Session summaries.
- [ ] Weekly planning.
- [ ] Preparation percentage improvements.
- [ ] Dungeon routing history.
- [ ] Consumable analytics.
- [ ] Historical performance graphs.
- [ ] Alt comparisons.
- [ ] Drag-and-drop Home dashboard customization.
- [ ] Achievement-to-dungeon/criteria mapping. Evaluated during Companion Intelligence V3 for a "Mythic+ + Achievements -> complete your personal best dungeon achievement" merge and deliberately not built -- `AchievementsModule` only exposes achievement id/name/points, with no structured link from an achievement to the dungeon or criteria it's actually about. Blizzard's achievement API surface for this (`GetAchievementCriteriaInfo` and similar) hasn't been audited; needs its own audit before any merge like this could use real data instead of guessing.

---

# Completed

Move completed items here instead of deleting them.

## 2026

- [x] Modular Dashboard
- [x] Recommendation Engine
- [x] Insight Engine
- [x] Activity History
- [x] Mythic+ Module
- [x] Weekly Module
- [x] Storage Module
- [x] Dashboard card redesign
- [x] Database migration framework
- [x] Dashboard component split (`Core/UI/Dashboard.lua` -> 15 files under `Core/UI/Dashboard/`)
- [x] Home Dashboard Evolution -- flagship Home page redesign (`DashboardCard:SetDetailSections`, cross-module Mythic+/Vault context, real chronological Recent Activity feed, Storage Items-Missing/Shopping-List split)
- [x] Companion Intelligence V3 -- explicit Collect/Group/Merge/Score/Prioritize/Present pipeline in `RecommendationEngine`, "Restock & Prepare" smart merge with Keystone Ready subsumption to reduce duplicates, deterministic Confidence (High/Medium/Low), 3 new real Opportunity Score terms, addon-wide Confidence display via one shared rendering change
- [x] Companion Intelligence V4 -- 4 new Core services (`BriefingService`, `NotificationService` + standalone toast widget, `MilestoneService`, `ProgressSummaryService`), `MythicPlusModule`'s shared statistics core (`BuildStatisticsFromRecords`) powering a new `GetStatisticsForRange`/`GetMilestoneStats`/Strongest Dungeon Insight, `WeeklyModule:GetNextLockedSlot` (also de-duplicating `RecommendationEngine`'s own V3 vault-slot scan), a new `NOTIFICATION_CHANGED` framework event, and 3 new Home cards (Today's Briefing/Recent Milestones/Recent Notifications)
- [x] Progress Dashboard -- new flagship `Pages/Progress.lua` (Hero/Overview/Last 7 Days/Last 30 Days/Lifetime/Personal Records/Recent Milestones/Current Trends), purely rendering `ProgressSummaryService`/`MilestoneService`/`MythicPlusModule`/`StorageModule` public getters; `MythicPlusModule`'s statistics core extended with `totalDeaths`/`minDeaths`/`totalConsumables`, `ProgressSummaryService:GetTrends()` extended to 7 metrics (added runs/ratingGain/interrupts), new shared `DashboardFormat.GetTrendArrow`/`Dashboard:LayoutTextLines` widgets (the latter replacing `Pages/Achievements.lua`'s former page-local duplicate), one compact `Dashboard.Progress` card on Home
- [x] Recommendation Inspector ("Why?") -- new standalone `Core/UI/RecommendationInspector.lua` window making every field a Recommendation already carries (reason/expectedBenefit/supportingEvidence/confidence/sourceModules/estimatedTime/score/timestamp) actually inspectable: Supporting Evidence grouped by contributing module, Contributing Modules each a real link to that module's own Dashboard page, a plain-language explanation of what High/Medium/Low Confidence means. Computes nothing -- the only data-model change is `supportingEvidence` entries gaining an additive `module` tag. Opened via a new "Why?" button on Home's Highest Priority card and via every recommendation row addon-wide (`Rows.lua:LayoutItemRows`). Found and fixed one real pre-existing duplication along the way: `DashboardCard:SetStarRating` had its own undocumented copy of the priority-to-stars formula instead of reusing `DashboardFormat.PriorityToStars`; both it and `Rows.lua` now share a new `DashboardFormat.RenderStars(priority)`
- [x] Developer Mode & Live Verification Suite -- new `DeveloperModeService` (persisted flag, Event Monitor, Refresh() instrumentation installed/removed only on toggle, generic JSON/text serializers) and a five-tab `DeveloperPanel` window (Overview, Modules, Events, Live API Inspector, History Inspector), `/ac dev on|off`. Live API Inspector puts raw Blizzard values next to each module's own parsed/final values (Weekly/Vault, Storage/Bank+Warband, Mythic+, Affixes) to make the addon's existing Blizzard-API-verification backlog fast to actually check in-game. New `ActivityHistoryService:ClearAll()`. `RecommendationEngine:ComputeScore()` now also returns/stores a `scoreBreakdown`, rendered by a new Developer-Mode-only section on the Recommendation Inspector. Structurally isolated -- zero registered hooks/instrumentation exist while the flag is off, `DeveloperPanel:Show()` refuses to run while disabled
- [x] v1.0 Polish & Completion Sprint -- full-codebase audit (every Dashboard page, service, gameplay module, widget), 3 real bugs fixed (MythicPlus "Best Timed" stat, Home Recent Activity's onClick routing, 3 dead localization keys), 6 duplications consolidated into new shared helpers (`Dashboard:ShowEmptyLine` reuse, `Logger:GetPreciseTimestamp`, `BaseWindow:AddCloseButton`, `DashboardFormat.HIGHLIGHT_COLOR`/`SetHighlightColor`, `AC.HEARTHSTONE_ITEM_ID`, `ServiceManager`/`ModuleManager:GetAll()`), dead `PlayerModule` removed (confirmed zero consumers), 2 missing hover-feedback gaps closed, stray filesystem litter removed -- see `docs/GameplayModuleArchitecture.md` section 1.9 for the full detail including everything audited and deliberately left alone
- [x] Blizzard API Verification Workflow -- source/documentation verification pass over Weekly/Storage/MythicPlus against Blizzard Interface Source + Warcraft Wiki. Real bug fixed: Home's "Highest Reward" card showed the Mythic+ key level mislabeled as an item level, now resolves the real item level via Blizzard's own `WeeklyRewardActivityItemMixin:SetDisplayedItem()` chain. Real gap documented instead of guessed at: Storage's favorite-item detection reads a field absent from `ContainerItemInfo`.
- [x] Live Verification & Framework Hardening Sprint -- extended the same audit to Character/Inventory/Achievements/Progress/Recommendation Engine/Notification Service/Milestone Service/Developer Panel, and built permanent tooling instead of one-off prose: new `Core/Services/VerificationService.lua` (37-entry registry, persisted human-confirmed verification log), Developer Panel Live API tab expanded into a real validation suite (Expected/Confidence/Source/Last-Verified per probe, Mark Verified/Failed buttons, full read-only registry listing), new Developer Panel Checklist tab (26 guided scenarios). 3 real bugs found and fixed: Achievements' hardcoded `1..20000` ID loop (real IDs already exceed 20000; replaced with Blizzard's own category-enumeration pattern), Character's use of the deprecated `GetSpecialization()`/`GetSpecializationInfo()` globals (migrated to `C_SpecializationInfo`), and a pre-existing `CopyCurrentTab` crash-on-click bug on the Live API tab. 2 confirmed-nonexistent APIs removed (`C_Hearthstone.GetHearthstone`, `C_PlayerInfo.GetAccountGUID`, both absent from Blizzard's own generated docs and both already-dead fields)
- [x] v1.0 Visual Polish Sprint -- full visual/UX audit of the Dashboard before any implementation. Critical bug fixed: Home page had no `ScrollFrame` (unlike every other page), so roughly half its 12 cards rendered past the window's bottom edge, unclipped and unreachable -- given the same ScrollFrame/ScrollChild shape every other page uses. Biggest visual-quality gap fixed: zero window or card anywhere in the addon had a border (`BaseWindow`, `DashboardCard`, `SettingsWindow`'s two panels all rendered as flat edgeless rectangles) -- all four now use a real bordered `BackdropTemplate` backdrop. New `DashboardCard:SetIcon`/`SetClassIcon`, wired to real already-collected data (achievement icon FileIDs, `classFile`) on Home's Achievements/Profile cards. New `Dashboard:LayoutRunLevelChart` (`Rows.lua`) -- a visual bar-timeline of recent Mythic+ runs on the MythicPlus page, rendering `GetRecentRuns()`'s already-recorded data, nothing new computed. Progress bars now animate toward their value (ease-out, 0.35s) instead of snapping. Also fixed while auditing: the `.toc`'s player-visible `## Notes:` field was the leftover placeholder text "Framework"; replaced with a real description, and added a previously-unset `## IconTexture`
- [x] Player Journal & Community Notes System -- the one deliberately-scoped new flagship gameplay system for v1.0, designed in Plan Mode before any code was written. New `PlayerJournalModule` (account-wide `"Name-Realm"`-keyed database of Mythic+ companions -- objective stats, unlimited personal notes, 11 preset personal tags including the single-source-of-truth Favorite Player tag, a bounded timeline) makes the deliberate party-composition-tracking decision `docs/GameplayModuleArchitecture.md` section 1.4 had explicitly deferred, in a new module rather than by modifying `MythicPlusModule` (unchanged, still self-only). New, fully independent `CommunityModule` (own storage key, own Settings page, disabled by default, fully local -- no sync backend exists yet, so Helpful/Not Helpful/Report/Hide render but stay disabled rather than misrepresent themselves as real crowd feedback). New standalone 7-tab `PlayerJournalWindow` (`Core/UI/PlayerJournal/`, spine + per-tab files matching `Dashboard.lua`/`Pages/*.lua`'s own split), with a distinct accent color separating the Statistics tab's objective data from Personal Notes/Tags' subjective content. This addon's first two hooks into Blizzard's own UI (confirmed zero prior precedent via repo-wide grep): a `Menu.ModifyMenu` player-right-click submenu and a `TooltipDataProcessor.AddTooltipPostCall` unit-tooltip extension, both new territory flagged in `VerificationService`'s registry (8 new rows, 4 new Checklist scenarios) rather than assumed correct. One real gap found and fixed while building the context menu's "Hide Community Notes" checkbox: it wrote a flag nothing read until the Community Notes tab was updated to actually respect it