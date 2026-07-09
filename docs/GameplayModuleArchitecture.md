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
- Bind location, current hearthstone item.
- Current zone/subzone/map.
- Time played (total and current-level).
- Session tracking: login timestamp, level/item-level gained since login.
- Insight generation for character-progression events (rested XP available, max level reached, leveled up this session, item level improved this session).

#### Blizzard APIs owned
`UnitName`, `UnitFullName`, `UnitGUID`, `UnitRace`, `UnitClass`, `UnitLevel`, `UnitFactionGroup`, `GetRealmName`, `GetSpecialization`/`GetSpecializationInfo`, `GetMaxLevelForPlayerExpansion`, `GetXPExhaustion`, `GetAverageItemLevel`, `GetGuildInfo`, `GetMoney`, `GetBindLocation`, `GetHearthstone`, `GetZoneText`/`GetSubZoneText`/`GetBestMapForUnit`, `RequestTimePlayed`, `GetAccountGUID` (warband account identifier — collected, currently unused for display).

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
- Important-item presence checks (hearthstone item possession — distinct from Character's "which hearthstone is set" fact).
- Repair status (only when a merchant is open — this is a genuine Blizzard-imposed constraint, not a design choice).
- Session tracking: net items added/removed, bag-usage percentage change since login.
- Insight generation for inventory-state events (bags almost full, bags filling up, hearthstone missing, repairs needed).

#### Blizzard APIs owned
`C_Container.GetContainerNumSlots`/`GetContainerItemInfo`/`GetContainerItemLink`, `GetInventoryItemID`/`GetInventoryItemLink`, `GetAverageItemLevel` (equipment-slot-scoped usage), `CanMerchantRepair`/`GetRepairAllCost`.

#### Dashboard responsibilities
Home page Inventory card (slots used, percent full, progress bar, status). Inventory page (Bag Summary, Equipment, Important Items, Session sections, Future Features note).

#### Insight responsibilities
"Bags Almost Full", "Bags Filling Up", "Hearthstone Missing", "Repairs Needed".

#### Recommendation responsibilities
"Visit a Vendor", "Consider Vendor Soon", "Acquire Hearthstone", "Repair Your Gear".

#### Explicitly NOT responsible for
- Character identity, progression, or gold (Character).
- Bank or Warband Bank contents (Warband module, planned) — bags and banks are distinct Blizzard systems and distinct API families.
- Equipment durability (not currently collected by any module — a real gap, not yet owned by anyone; would extend Inventory when implemented, since it's equipment-state data).
- Reagent bank, currency (Currency module, planned).

---

### 1.3 Achievements

#### Purpose
Owns achievement completion state and the derived statistics from it.

#### Responsibilities
- Total achievement points.
- Per-achievement completion state and metadata.
- Most recently earned achievement.
- Session tracking: achievements and points earned since login.
- Insight generation for achievement events (achievement earned, achievement milestone reached).

#### Blizzard APIs owned
`GetAchievementInfo` (and the `C_AchievementInfo` family where category/expansion breakdowns are added in the future).

#### Dashboard responsibilities
Home page Achievements card (total points). Achievements page (Summary, Session sections, Future Features note for Milestones/Expansion Progress/Category Breakdown/Recent History).

#### Insight responsibilities
"Achievement Earned", "Achievement Milestone".

#### Recommendation responsibilities
"Continue Achievement Hunting", "Reach Next Milestone".

#### Explicitly NOT responsible for
- Any non-achievement Blizzard system, even when an achievement rewards it (e.g., a Warband Bank tab unlocked by an achievement is Warband's data — the achievement completion itself is still Achievements' data).
- Category/expansion-completion breakdowns are listed as a documented future extension of *this* module (not a new module), since they use the same underlying achievement API family — not a new ownership boundary.

---

## 2. Planned Modules

These are architectural placeholders. Nothing below authorizes writing code — each one requires its own dedicated Blizzard API audit (matching the rigor already applied to the modules above and to the Warband investigation) before implementation begins. Namespaces marked *(confirmed)* were verified against Blizzard's own documentation this design cycle; namespaces marked *(unverified)* are named from general knowledge only and must be independently confirmed before any module design work starts on them.

### 2.1 Weekly (Great Vault)

#### Purpose
Reports Great Vault reward-slot availability. Deliberately narrow — "Weekly" as a blanket concept (all weekly-reset content) is not a single Blizzard system and would not have one natural owner; this module exists specifically for the one clean, aggregate API Blizzard already provides.

#### Intended ownership
A dedicated small module. Does not depend on MythicPlus, Raids, or PvP modules for its data — it reads Blizzard's own pre-aggregated vault-activity data directly, rather than re-deriving vault eligibility from each activity type.

#### Candidate Blizzard API namespaces
`C_WeeklyRewards` *(confirmed)* — `GetActivities`, and related availability/threshold functions.

#### Example Dashboard information
Home card: "Vault rewards ready" / slot count and highest available reward level per slot.

#### Possible Insights
"Great Vault Rewards Unclaimed."

#### Possible Recommendations
"Claim your Great Vault before weekly reset."

#### Out of Scope
Per-activity progress toward vault slots (that belongs to MythicPlus/Raids/PvP, if and when those modules exist); any weekly quest that isn't Great Vault-related.

---

### 2.2 Reputation

#### Purpose
Owns all faction standing, including Renown, regardless of whether a given faction happens to be character-scoped or account-wide.

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

### 2.3 Currency

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

### 2.4 Warband

#### Purpose
Owns the Warband Bank specifically — not "anything account-wide," which would make this a dumping ground rather than a clean domain.

#### Intended ownership
A dedicated module, scoped narrowly. Renown and non-gold currency, despite also being account-wide in some cases, belong to Reputation and Currency respectively (see above) — Warband owns only the bank itself: its gold balance, tabs, and (when accessible) contents.

#### Candidate Blizzard API namespaces
`C_Bank` *(confirmed)* — `CanUseBank`, `FetchDepositedMoney`, `FetchNumPurchasedBankTabs`, `FetchPurchasedBankTabData`/`FetchPurchasedBankTabIDs`, `FetchViewableBankTypes`, `HasMaxBankTabs`, parameterized by `Enum.BankType.Account`.

#### Example Dashboard information
Inventory-adjacent card or its own small page, explicitly labeled as only available near a bank or during the Distance Inhibitor's active window.

#### Possible Insights
None considered reliable — the bank's availability is too situational (gated by physical proximity or a time-limited spell) for a trustworthy insight trigger, consistent with the dedicated Warband API audit's conclusion.

#### Possible Recommendations
None, for the same reason.

#### Out of Scope
Renown (Reputation). Non-gold currency balances in general (Currency) — only the bank's own deposited gold is Warband's concern. Character Bank (a *different*, character-scoped bank using the same `C_Bank` namespace with a different `Enum.BankType`) — if ever implemented, that's Inventory's concern (it's per-character storage), not Warband's.

---

### 2.5 MythicPlus

#### Purpose
Owns Mythic+ keystone state, dungeon score, and run history.

#### Intended ownership
A dedicated module. Does not feed WeeklyProgress/Weekly — that module reads Blizzard's own pre-aggregated vault data directly, avoiding an invented dependency.

#### Candidate Blizzard API namespaces
`C_ChallengeMode` *(confirmed)*: `GetActiveKeystoneInfo`, `GetSlottedKeystoneInfo`, `GetOverallDungeonScore`, `GetMapUIInfo`, `GetDeathCount`. `C_MythicPlus` *(confirmed)*: reward-level calculation functions.

#### Example Dashboard information
Mythic+ page; Home card showing active keystone level/dungeon and current season score.

#### Possible Insights
"Keystone Ready to Push", "No Keystone Slotted."

#### Possible Recommendations
"Run your keystone before weekly reset."

#### Out of Scope
Great Vault eligibility derived from M+ activity (Weekly module reads its own aggregate, doesn't ask MythicPlus to compute this). Raid or PvP content.

---

### 2.6 Professions

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

### 2.7 Collections

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

### 2.8 Raids

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

### 2.9 PvP

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

### 2.10 Delves

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
6. **Recommendations consume Insights, never raw module state.** The Recommendation Engine only ever reads what `GetInsights()` produced — it does not call back into a module's other public API to gather additional context for a recommendation.
7. **A module may read another module's public API, but never its internal state, and never to duplicate logic the owning module already provides** (e.g., Professions may ask Inventory "do I have this reagent?" through Inventory's public API; it never re-implements bag scanning itself).
8. **Configuration is never gameplay data.** Settings, toggles, and preferences live in `ConfigurationManager`; a module's `Profile`/session data never doubles as a place to store a user preference, and vice versa.
9. **ConfigurationManager is the single source of truth for all settings**, read and written only through its public API — never a raw SavedVariables table accessed directly by a module or by the Dashboard.
10. **Localization never changes gameplay logic.** `AC.L:Get()`/`AC.L:Format()` affect display text only; no module's behavior, thresholds, or data collection may vary by active locale.
11. **Services own cross-cutting functionality that no single gameplay module should own** (event dispatch, widget creation, window management, settings workflow, localization) — a capability needed by multiple modules belongs in a service, not copied into each module that needs it.
12. **A new Blizzard API namespace is evaluated against existing and planned module ownership before any code is written** (see Section 5). It is never implemented inside whichever module happens to be open in the editor at the time.
13. **Account-wide scope is a property of data, not a reason to create or choose a module.** (See the Renown and Currency ownership resolutions above — the existence of an account-wide variant of a system does not mean it belongs to Warband.)
14. **A module never depends on another *planned* module's data existing.** WeeklyProgress reads Blizzard's own aggregate rather than depending on MythicPlus/Raids/PvP; this pattern — prefer Blizzard's own aggregation over inventing cross-module dependencies — applies generally.
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
| Achievements (points, completion, recent) | Achievements | Achievements, Home | Achievements | Achievements |
| Achievement Category/Expansion Breakdown | Achievements *(future extension of this module)* | Achievements *(future)* | Achievements *(future)* | Achievements *(future)* |
| Great Vault | Weekly *(planned)* | Home *(planned)* | Weekly *(planned)* | Weekly *(planned)* |
| Reputation (standard) | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* |
| Renown | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* | Reputation *(planned)* |
| Currencies (non-gold) | Currency *(planned)* | Currency *(planned)* | Currency *(planned)* | Currency *(planned)* |
| Warband Bank | Warband *(planned)* | Warband/Inventory-adjacent *(planned)* | — *(unreliable trigger, see 2.4)* | — |
| Mythic+ Keystone / Score | MythicPlus *(planned)* | MythicPlus *(planned)* | MythicPlus *(planned)* | MythicPlus *(planned)* |
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
- Existing modules: Character, Inventory, Achievements.
- Framework: Dashboard, Insight Engine, Recommendation Engine, Localization, Settings (Save/Cancel).
- Focus: polish and stabilization of what exists, not new gameplay domains.

### Version 2 — Suggested Implementation Order

| Order | Module | Justification |
|---|---|---|
| 1 | Weekly | Smallest possible new module (one confirmed namespace, no scanning loop) and highest immediate value — checked by nearly every player every week. Proves out the "new domain module" pattern at minimum cost before bigger modules are attempted. |
| 2 | Reputation | Second-cheapest to build and resolves the Renown ownership question this entire architecture exercise was built around — implementing it early keeps that resolution from becoming theoretical. |
| 3 | MythicPlus | Same API cost class as Reputation (confirmed namespaces, flat data, no special UI-state gating), with strong value for a large segment of the player base. |
| 4 | Currency | Cheap once Reputation has already established the "character-scoped + account-scoped side by side" pattern this module reuses; ranked after the higher-engagement modules since its value is more of a glance-at number than actionable weekly content. |
| 5 | Warband | Deliberately after the confirmed-easy modules: its bank-gated availability makes it the least reliable data source of the group, and it needs the same "gracefully report unavailable" handling already proven out by Inventory's repair-status check — safer to build once that pattern is well-established elsewhere. |
| 6 | Professions | Real value, especially for crafters, but a substantially larger surface (multiple professions, recipes, reagents, work orders) than anything above — appropriately placed after the smaller, cheaper wins. |
| 7 | Collections | Real but lower-urgency value (completionist browsing, not actionable weekly content); moderate effort. |
| 8 | Raids | Requires its own dedicated API audit before design work can even begin — scheduled after the fully-scoped modules above are done. |
| 9 | PvP | Same audit prerequisite as Raids. |
| 10 | Delves | Least-verified domain in this document; requires the most upfront audit work of any planned module, so it's scheduled last. |

No module on this list is authorized for implementation until its own dedicated API audit (matching the Warband investigation's rigor) confirms the real function names, return shapes, event-vs-poll behavior, and any special UI-state requirements — this document describes *where things belong*, not a green light to build them.
