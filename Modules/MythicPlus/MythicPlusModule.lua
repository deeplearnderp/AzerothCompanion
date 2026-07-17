-------------------------------------------------------------------------------
-- Azeroth Companion
-- Mythic+ Module
--
-- Authoritative Mythic+ profile service for the current character. Owns
-- current Mythic+ gameplay (keystone, rating, best runs, active run,
-- weekly affixes, current season) AND long-term personal performance
-- history: recorded runs, season statistics, and the history-backed
-- Insights/Recommendations derived from them. Not the Weekly Vault,
-- Raids, Delves, Inventory, Character data, currencies, or a combat log
-- analytics system -- see docs/GameplayModuleArchitecture.md (Section
-- 1.4, "Long-Term Performance Tracking") for the full data flow, the
-- deliberate run-record versioning scheme, and documented future
-- extension points (party composition, missed interrupts, Valorstones/
-- Crests).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local pairs = pairs

local GetOverallDungeonScore = C_ChallengeMode.GetOverallDungeonScore
local GetSlottedKeystoneInfo = C_ChallengeMode.GetSlottedKeystoneInfo
local HasSlottedKeystone = C_ChallengeMode.HasSlottedKeystone
local GetActiveKeystoneInfo = C_ChallengeMode.GetActiveKeystoneInfo
local IsChallengeModeActive = C_ChallengeMode.IsChallengeModeActive
local GetDeathCount = C_ChallengeMode.GetDeathCount
local GetMapScoreInfo = C_ChallengeMode.GetMapScoreInfo
local GetChallengeCompletionInfo = C_ChallengeMode.GetChallengeCompletionInfo

local GetOwnedKeystoneChallengeMapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
local GetOwnedKeystoneLevel = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
local GetCurrentAffixes = C_MythicPlus and C_MythicPlus.GetCurrentAffixes
local RequestMapInfo = C_MythicPlus and C_MythicPlus.RequestMapInfo
local GetCurrentSeason = C_MythicPlus and C_MythicPlus.GetCurrentSeason

local GetMapUIInfo = C_ChallengeMode.GetMapUIInfo

local UnitGUID = UnitGUID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit
local GetPlayerMapPosition = C_Map and C_Map.GetPlayerMapPosition

local SpellData = AC.MythicPlusSpellData or {}

local MythicPlusModule =
{
    Name = "MythicPlus",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
}

-------------------------------------------------------------------------------
-- State
--
-- "Current Keystone" (hasKeystone/currentDungeonID/currentLevel) is
-- sourced from C_MythicPlus.GetOwnedKeystoneChallengeMapID()/
-- GetOwnedKeystoneLevel() -- confirmed via Blizzard's own API
-- documentation to report the keystone the player owns from anywhere,
-- not gated by location. This corrects an earlier version of this
-- module, which used C_ChallengeMode.HasSlottedKeystone()/
-- GetSlottedKeystoneInfo() as the primary source -- those only describe
-- the dungeon-entrance Font of Power receptacle and were never the
-- right function for "does the player have a keystone". They are still
-- used, but only for the narrower, genuinely receptacle-scoped
-- currentAffixIDs field.
-------------------------------------------------------------------------------

function MythicPlusModule:ResetProfile()

    self.Profile =
    {
        rating = 0,

        hasKeystone = false,
        currentDungeonID = 0,
        currentDungeonName = "",
        currentLevel = 0,
        currentAffixIDs = {},

        currentSeason = 0,

        weeklyAffixIDs = {},

        bestRuns = {},

        activeRun = nil,
        lastCompletedRun = nil,

        lastUpdated = 0,
    }

    self.Session =
    {
        initialRating = 0,
        runsCompletedThisSession = 0,
    }

    self:ResetRunTracking()

end

-------------------------------------------------------------------------------
-- Run Tracking
--
-- Scratch state for the run currently in progress -- reset at
-- CHALLENGE_MODE_START, read and cleared by RecordCompletedRun() at
-- completion. Nothing here is persisted directly; it only ever feeds the
-- Data fields RecordCompletedRun() writes to ActivityHistoryService.
-- The events that populate it (UNIT_SPELLCAST_SUCCEEDED, PLAYER_DEAD,
-- ENCOUNTER_START/END, and a narrowly-filtered COMBAT_LOG_EVENT_UNFILTERED)
-- are only registered between CHALLENGE_MODE_START and the run ending --
-- see RegisterRunTrackingEvents/UnregisterRunTrackingEvents -- so there is
-- zero listener overhead outside of an actual Mythic+ attempt.
-------------------------------------------------------------------------------

function MythicPlusModule:ResetRunTracking()

    self.RunTracking =
    {
        active = false,
        interruptCount = 0,
        defensives = {},
        consumablesAtStart = {},
        deaths = 0,
        bossDeaths = 0,
        trashDeaths = 0,
        deathLocations = {},
        inEncounter = false,
        itemCountAtStart = 0,
        itemLevelAtStart = 0,
    }

end

-------------------------------------------------------------------------------
-- Consumable Classification
--
-- Delegates to the shared AC.ItemClassification (Core/Utility/
-- ItemClassification.lua) -- consolidated there during the Product Polish
-- consumable classifier consolidation so this and StorageModule's rule
-- matching read from exactly one implementation instead of two independently
-- drifting copies. Kept as a method here (rather than removed) since this is
-- this module's existing public interface -- callers elsewhere in this file
-- (SnapshotConsumableCounts) are unaffected by where the logic actually lives.
-------------------------------------------------------------------------------

function MythicPlusModule:ClassifyConsumableItem(itemID)

    return AC.ItemClassification:ClassifyConsumable(itemID)

end

-- Reads through Inventory's existing public API (GetItems) rather than
-- scanning bags itself (Architectural Rule 7 -- never duplicate logic
-- the owning module already provides).
function MythicPlusModule:SnapshotConsumableCounts()

    local snapshot = {}

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not inventoryModule or not inventoryModule.GetItems then
        return snapshot
    end

    for _, item in ipairs(inventoryModule:GetItems()) do

        local category = self:ClassifyConsumableItem(item.itemID)

        if category then
            snapshot[item.itemID] = { category = category, count = item.count or 0 }
        end

    end

    return snapshot

end

-- Compares a start-of-run snapshot to a fresh end-of-run snapshot.
-- Approximate, not exact: a stack that also gained items mid-run (e.g.
-- looting an identical potion) could under-count what was actually
-- consumed -- an accepted limitation of lightweight bag-diffing rather
-- than a per-use event stream.
function MythicPlusModule:DiffConsumables(startSnapshot)

    local used = {}
    local endSnapshot = self:SnapshotConsumableCounts()

    for itemID, startEntry in pairs(startSnapshot) do

        local endCount = endSnapshot[itemID] and endSnapshot[itemID].count or 0
        local consumed = startEntry.count - endCount

        if consumed > 0 then
            used[startEntry.category] = (used[startEntry.category] or 0) + consumed
        end

    end

    return used

end

-------------------------------------------------------------------------------
-- Run Tracking Events
--
-- Registered only between CHALLENGE_MODE_START and the run ending, so
-- there is no listener overhead outside of an actual Mythic+ attempt.
-- COMBAT_LOG_EVENT_UNFILTERED is registered defensively (pcall) even
-- though it is one of the most stable, universally-used Blizzard events,
-- consistent with how this addon treats every dynamic event registration
-- elsewhere (see DiagnosticsService) -- and it is filtered to exactly one
-- sub-event (SPELL_INTERRUPT, sourced from the player) in
-- OnCombatLogEventUnfiltered below, not used to reconstruct a combat log.
-------------------------------------------------------------------------------

function MythicPlusModule:RegisterRunTrackingEvents()

    AC.Events:Register("UNIT_SPELLCAST_SUCCEEDED", self)
    AC.Events:Register("PLAYER_DEAD", self)
    AC.Events:Register("ENCOUNTER_START", self)
    AC.Events:Register("ENCOUNTER_END", self)

    local ok, err = pcall(AC.Events.Register, AC.Events, "COMBAT_LOG_EVENT_UNFILTERED", self)

    if not ok and AC.Logger then
        AC.Logger:Error(("MythicPlusModule failed to register COMBAT_LOG_EVENT_UNFILTERED: %s"):format(tostring(err)))
    end

end

function MythicPlusModule:UnregisterRunTrackingEvents()

    AC.Events:Unregister("UNIT_SPELLCAST_SUCCEEDED", self)
    AC.Events:Unregister("PLAYER_DEAD", self)
    AC.Events:Unregister("ENCOUNTER_START", self)
    AC.Events:Unregister("ENCOUNTER_END", self)
    AC.Events:Unregister("COMBAT_LOG_EVENT_UNFILTERED", self)

end

function MythicPlusModule:OnUnitSpellcastSucceeded(unit, castGUID, spellID)

    if unit ~= "player" or not self.RunTracking.active then
        return
    end

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()
    local classFile = characterProfile and characterProfile.classFile

    local classDefensives = classFile and SpellData.Defensives and SpellData.Defensives[classFile]
    local name = classDefensives and classDefensives[spellID]

    if name then
        self.RunTracking.defensives[name] = (self.RunTracking.defensives[name] or 0) + 1
    end

end

-- Filtered to exactly one sub-event, sourced only from the player -- see
-- the file-level note above on why this one event is justified despite
-- "do not recreate combat logs."
function MythicPlusModule:OnCombatLogEventUnfiltered()

    if not self.RunTracking.active then
        return
    end

    local _, subEvent, _, sourceGUID = CombatLogGetCurrentEventInfo()

    if subEvent == "SPELL_INTERRUPT" and sourceGUID == UnitGUID("player") then
        self.RunTracking.interruptCount = self.RunTracking.interruptCount + 1
    end

end

function MythicPlusModule:OnEncounterStart()

    if self.RunTracking.active then
        self.RunTracking.inEncounter = true
    end

end

function MythicPlusModule:OnEncounterEnd()

    if self.RunTracking.active then
        self.RunTracking.inEncounter = false
    end

end

-- Death location is "if practical" (Part: Death Analysis) -- capturing
-- the player's own map position on their own death is a single, cheap
-- C_Map read, not combat log or inspection of anyone else.
function MythicPlusModule:OnPlayerDead()

    if not self.RunTracking.active then
        return
    end

    self.RunTracking.deaths = self.RunTracking.deaths + 1

    if self.RunTracking.inEncounter then
        self.RunTracking.bossDeaths = self.RunTracking.bossDeaths + 1
    else
        self.RunTracking.trashDeaths = self.RunTracking.trashDeaths + 1
    end

    if GetBestMapForUnit and GetPlayerMapPosition then

        local mapID = GetBestMapForUnit("player")
        local position = mapID and GetPlayerMapPosition(mapID, "player")

        if position then

            local x, y = position:GetXY()

            table.insert(self.RunTracking.deathLocations,
            {
                mapID = mapID,
                x = x,
                y = y,
                isBoss = self.RunTracking.inEncounter,
            })

        end

    end

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function MythicPlusModule:Initialize()

    self:ResetProfile()

    -- ConfigurationManager remains the single source of truth for the
    -- "enabled" flag even though no Settings UI is registered yet --
    -- Phase 1 scope explicitly excludes Settings. A visible toggle can
    -- be added in a later phase without touching this module's data
    -- layer at all.
    AC.ConfigurationManager:Register("MythicPlus", Defaults)

end

-------------------------------------------------------------------------------
-- Enable
--
-- VERIFICATION STATUS (Blizzard API Verification Workflow pass):
-- CHALLENGE_MODE_START, CHALLENGE_MODE_RESET, CHALLENGE_MODE_KEYSTONE_SLOTTED,
-- CHALLENGE_MODE_MAPS_UPDATE, and MYTHIC_PLUS_CURRENT_AFFIX_UPDATE are all
-- confirmed directly from Blizzard's own FrameXML source (Blizzard Interface
-- Source, Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua). Also
-- separately confirmed via Warcraft Wiki. CHALLENGE_MODE_COMPLETED is
-- confirmed directly from Blizzard's Retail FrameXML completion banner.
-- CHALLENGE_MODE_DEATH_COUNT_UPDATED is confirmed via its own
-- dedicated Warcraft Wiki page (not seen in the one Blizzard FrameXML file
-- checked directly, but that only means that particular Blizzard addon
-- doesn't consume it -- the event itself is real). No API in this
-- registration block remains in "Needs Live Verification" status.
-------------------------------------------------------------------------------

function MythicPlusModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("CHALLENGE_MODE_START", self)
    AC.Events:Register("CHALLENGE_MODE_RESET", self)
    AC.Events:Register("CHALLENGE_MODE_COMPLETED", self)
    AC.Events:Register("CHALLENGE_MODE_KEYSTONE_SLOTTED", self)
    AC.Events:Register("CHALLENGE_MODE_DEATH_COUNT_UPDATED", self)
    AC.Events:Register("CHALLENGE_MODE_MAPS_UPDATE", self)
    AC.Events:Register("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", self)
    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

    if self:IsModuleEnabled() then

        self:Refresh()

        if RequestMapInfo then
            RequestMapInfo()
        end

    end

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function MythicPlusModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function MythicPlusModule:Shutdown()

    self:Disable()
    self:ResetProfile()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function MythicPlusModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("MythicPlus", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Diagnostics
--
-- Investigation-only instrumentation for the login-refresh bug (see
-- DiagnosticsService for the independent raw-Blizzard-API tracer this is
-- meant to be cross-checked against). Reports what THIS module's own
-- Profile cache holds immediately after handling the named event, tagged
-- "(module)" to distinguish it from DiagnosticsService's "(Mythic+)"-
-- category raw snapshots at the same event. Delegates all storage to
-- Logger -- this is one Trace() call, not a second logging system.
-------------------------------------------------------------------------------

local function TraceState(self, eventName)

    if not AC.Logger:IsDebugEnabled() then
        return
    end

    if not AC.Logger:IsTraceCategoryEnabled("Mythic+") then
        return
    end

    local profile = self.Profile

    AC.Logger:Trace("Mythic+", eventName .. " (module)",
    {
        MapID = profile.currentDungeonID,
        Level = profile.currentLevel,
        HasKeystone = profile.hasKeystone,
        Rating = profile.rating,
        Season = profile.currentSeason,
        Dungeon = profile.currentDungeonName,
    })

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function MythicPlusModule:OnPlayerEnteringWorld(isInitialLogin)

    if not self:IsModuleEnabled() then
        return
    end

    self:Refresh()

    if isInitialLogin then
        self.Session.initialRating = self.Profile.rating
    end

    if RequestMapInfo then
        RequestMapInfo()
    end

    TraceState(self, "PLAYER_ENTERING_WORLD")

end

function MythicPlusModule:OnChallengeModeStart()

    if self:IsModuleEnabled() then

        self:RefreshActiveRun()

        self:ResetRunTracking()
        self.RunTracking.active = true
        self.RunTracking.consumablesAtStart = self:SnapshotConsumableCounts()

        local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

        if inventoryModule and inventoryModule.GetTotalItemCount then
            self.RunTracking.itemCountAtStart = inventoryModule:GetTotalItemCount()
        end

        local characterModule = AC.Core and AC.Core:GetModule("Character")
        local characterProfile = characterModule and characterModule:GetProfile()

        if characterProfile then
            self.RunTracking.itemLevelAtStart = characterProfile.equippedItemLevel or 0
        end

        self:RegisterRunTrackingEvents()

    end

    TraceState(self, "CHALLENGE_MODE_START")

end

function MythicPlusModule:OnChallengeModeReset()

    if self:IsModuleEnabled() then

        self.Profile.activeRun = nil

        -- CHALLENGE_MODE_RESET's exact semantics (deliberate reset before
        -- starting vs. mid-run abandonment vs. other legitimate resets)
        -- are not confidently distinguishable from this event alone, so
        -- this does NOT record an ActivityHistoryService entry here --
        -- recording an "Abandoned" run on a guess would be exactly the
        -- fabricated data this module avoids elsewhere. It does still
        -- stop run tracking so a stale in-progress state never leaks
        -- into whatever the player does next.
        if self.RunTracking.active then
            self:UnregisterRunTrackingEvents()
            self:ResetRunTracking()
        end

    end

    TraceState(self, "CHALLENGE_MODE_RESET")

end

function MythicPlusModule:OnChallengeModeCompleted()
    if not self:IsModuleEnabled() then
        return
    end

    local completionInfo = GetChallengeCompletionInfo()

    if completionInfo then
        local dungeonID = completionInfo.mapChallengeModeID or 0
        local completionTimeSeconds = (completionInfo.time or 0) / 1000

        -- Captured here, before RefreshOwnedKeystone()/activeRun is
        -- cleared below, since the death count, active affixes, and this
        -- run's tracked defensives/interrupts/consumables are only
        -- available from this module's own live state, not from
        -- GetChallengeCompletionInfo() itself.
        local timeRemaining = 0
        local timeLimit = select(3, GetMapUIInfo(dungeonID))

        if timeLimit and timeLimit > 0 then
            timeRemaining = timeLimit - completionTimeSeconds
        end

        local characterModule = AC.Core and AC.Core:GetModule("Character")
        local characterProfile = characterModule and characterModule:GetProfile()

        local consumablesUsed = {}

        if self.RunTracking.active then
            consumablesUsed = self:DiffConsumables(self.RunTracking.consumablesAtStart)
        end

        local itemCountDelta = 0
        local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

        if self.RunTracking.active and inventoryModule and inventoryModule.GetTotalItemCount then
            itemCountDelta = inventoryModule:GetTotalItemCount() - self.RunTracking.itemCountAtStart
        end

        self.Profile.lastCompletedRun =
        {
            dungeonID = dungeonID,
            dungeonName = self:GetDungeonName(dungeonID),
            level = completionInfo.level or 0,
            time = completionTimeSeconds,
            timeRemaining = timeRemaining,
            onTime = completionInfo.onTime == true,
            oldScore = completionInfo.oldOverallDungeonScore or 0,
            newScore = completionInfo.newOverallDungeonScore or 0,
            isMapRecord = completionInfo.isMapRecord == true,
            deathCount = (self.Profile.activeRun and self.Profile.activeRun.deathCount) or 0,
            affixIDs = self.Profile.weeklyAffixIDs or {},

            -- Added for long-term performance tracking (see
            -- RecordCompletedRun) -- all sourced from this module's own
            -- RunTracking state or CharacterModule's public API, never
            -- fabricated.
            spec = characterProfile and characterProfile.specName or "",
            itemLevel = characterProfile and characterProfile.equippedItemLevel or 0,
            interruptCount = self.RunTracking.interruptCount,
            defensives = self.RunTracking.defensives,
            bossDeaths = self.RunTracking.bossDeaths,
            trashDeaths = self.RunTracking.trashDeaths,
            deathLocations = self.RunTracking.deathLocations,
            consumables = consumablesUsed,
            itemCountDelta = itemCountDelta,
        }

        self.Session.runsCompletedThisSession = (self.Session.runsCompletedThisSession or 0) + 1

        self:RecordCompletedRun()

    end

    self:UnregisterRunTrackingEvents()
    self:ResetRunTracking()

    self.Profile.activeRun = nil

    self:RefreshRating()
    self:RefreshBestRuns()
    self:RefreshOwnedKeystone()

end

-------------------------------------------------------------------------------
-- Activity History
--
-- The only place MythicPlusModule writes to ActivityHistoryService --
-- MythicPlusModule owns this gameplay data (Section on MythicPlus in
-- GameplayModuleArchitecture.md: "Run history"), ActivityHistoryService
-- only owns its storage/persistence. Character/Realm come through
-- CharacterModule's public API rather than calling Blizzard's UnitName/
-- GetRealmName a second time here (Architectural Rule 7 -- never
-- duplicate logic the owning module already provides). Silently skips
-- recording (rather than fabricating a placeholder identity) if
-- CharacterModule's data isn't available yet.
-------------------------------------------------------------------------------

function MythicPlusModule:RecordCompletedRun()
    local run = self.Profile.lastCompletedRun

    if not AC.ActivityHistoryService then
        return
    end

    if not run then
        return
    end

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local characterProfile = characterModule and characterModule:GetProfile()

    if not characterProfile or not characterProfile.name or characterProfile.name == "" then
        return
    end

    local now = time()
    local scoreChange = run.newScore - run.oldScore

    AC.ActivityHistoryService:Append(
    {
        Character = characterProfile.name,
        Realm = characterProfile.realm or "",
        Module = "MythicPlus",
        ActivityType = "Dungeon",
        ActivityName = run.dungeonName or "",
        Difficulty = "Mythic+",
        Expansion = GetExpansionLevel and GetExpansionLevel() or 0,
        Started = now - (run.time or 0),
        Ended = now,
        Completed = true,
        Success = run.onTime,
        Data =
        {
            -- Unchanged since the previous schema version -- existing
            -- readers (GetSeasonStatistics, the Dashboard) keep working
            -- unmodified against both old and new records.
            dungeonID = run.dungeonID,
            level = run.level,
            time = run.time,
            onTime = run.onTime,
            scoreChange = scoreChange,
            isMapRecord = run.isMapRecord,
            season = self.Profile.currentSeason,
            deathCount = run.deathCount or 0,
            affixIDs = run.affixIDs or {},

            -- Added this version (recordVersion 2) -- purely additive,
            -- so a reader written against version 1 never breaks: it
            -- simply never looks at these fields. A reader that wants
            -- them checks recordVersion (or just nil-guards, as every
            -- reader in this module already does) rather than assuming
            -- they exist on every record, since older recorded runs
            -- won't have them.
            recordVersion = 2,
            spec = run.spec or "",
            itemLevel = run.itemLevel or 0,
            timeRemaining = run.timeRemaining or 0,
            interruptCount = run.interruptCount or 0,
            defensives = run.defensives or {},
            bossDeaths = run.bossDeaths or 0,
            trashDeaths = run.trashDeaths or 0,
            deathLocations = run.deathLocations or {},
            consumables = run.consumables or {},
            itemCountDelta = run.itemCountDelta or 0,
        },
    })

end

function MythicPlusModule:OnChallengeModeKeystoneSlotted()

    if self:IsModuleEnabled() then
        self:RefreshOwnedKeystone()
    end

    TraceState(self, "CHALLENGE_MODE_KEYSTONE_SLOTTED")

end

function MythicPlusModule:OnChallengeModeDeathCountUpdated()

    if self:IsModuleEnabled() then
        self:RefreshActiveRun()
    end

    TraceState(self, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")

end

function MythicPlusModule:OnChallengeModeMapsUpdate()

    if not self:IsModuleEnabled() then

        if AC.Logger
                and AC.Logger:IsDebugEnabled()
                and AC.Logger:IsTraceCategoryEnabled("Mythic+") then

            AC.Logger:Trace("Mythic+", "RETURN: Module disabled")
        end

        return
    end

    -- CHALLENGE_MODE_MAPS_UPDATE was previously assumed to be Blizzard's
    -- signal that season map data (requested via RequestMapInfo() in
    -- Enable()/OnPlayerEnteringWorld) has arrived, on the theory that a
    -- fresh login's initial Refresh() runs before that data lands. That
    -- assumption did NOT resolve the reported bug in practice -- the
    -- refreshes below are kept because they are still correct/harmless
    -- (re-reading map-data-dependent fields once this event fires is
    -- never wrong), but this is no longer believed to be the actual fix.
    -- See DiagnosticsService/TraceState -- "/ac trace mythic" plus a
    -- fresh login capture is how the real event sequence gets found,
    -- instead of guessing again.
    self:RefreshCurrentSeason()
    self:RefreshRating()
    self:RefreshOwnedKeystone()
    self:RefreshBestRuns()

    self.Profile.lastUpdated = time()

    TraceState(self, "CHALLENGE_MODE_MAPS_UPDATE")

end

function MythicPlusModule:OnMythicPlusCurrentAffixUpdate()

    if self:IsModuleEnabled() then
        self:RefreshWeeklyAffixes()
    end

    TraceState(self, "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")

end

function MythicPlusModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "MythicPlus" then
        return
    end

    if key ~= "enabled" then
        return
    end

    if value then
        self:Refresh()
    else
        self:ResetProfile()
    end

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function MythicPlusModule:Refresh()

    if not self:IsModuleEnabled() then
        return
    end

    self:RefreshCurrentSeason()
    self:RefreshRating()
    self:RefreshOwnedKeystone()
    self:RefreshWeeklyAffixes()
    self:RefreshBestRuns()
    self:RefreshActiveRun()

    self.Profile.lastUpdated = time()

end

function MythicPlusModule:RefreshRating()

    self.Profile.rating = GetOverallDungeonScore() or 0

end

function MythicPlusModule:RefreshCurrentSeason()

    if not GetCurrentSeason then
        self.Profile.currentSeason = 0
        return
    end

    -- Passed through verbatim (including Blizzard's -1 "no active
    -- season" sentinel) rather than clamped -- this module reports
    -- what Blizzard says, it does not invent a season number.
    self.Profile.currentSeason = GetCurrentSeason() or 0

end

-------------------------------------------------------------------------------
-- Dungeon Name Resolution
-------------------------------------------------------------------------------

function MythicPlusModule:GetDungeonName(dungeonID)

    if not dungeonID or dungeonID == 0 then
        return ""
    end

    local name = GetMapUIInfo(dungeonID)

    return name or ""

end

-------------------------------------------------------------------------------
-- Affix Display Info
--
-- Resolves a recorded affix ID to its Blizzard-provided name/description/
-- icon via C_ChallengeMode.GetAffixInfo -- confirmed namespace per
-- docs/GameplayModuleArchitecture.md's Phase 2 API audit, previously
-- flagged as "not yet built" (the Dashboard rendered raw affix ID
-- numbers). Memoized since an affix's display info is static for the
-- life of the session. Returns nil rather than a guessed name if the
-- call fails or the affix ID is unrecognized -- the Dashboard falls back
-- to the raw ID in that case, exactly as it already did before this
-- existed.
-------------------------------------------------------------------------------

function MythicPlusModule:GetAffixDisplayInfo(affixID)

    affixID = tonumber(affixID)

    if not affixID then
        return nil
    end

    self.AffixDisplayCache = self.AffixDisplayCache or {}

    local cached = self.AffixDisplayCache[affixID]

    if cached then
        return cached
    end

    if not C_ChallengeMode.GetAffixInfo then
        return nil
    end

    local ok, name, description, icon = pcall(C_ChallengeMode.GetAffixInfo, affixID)

    if not ok or not name or name == "" then
        return nil
    end

    local info = { name = name, description = description or "", icon = icon }
    self.AffixDisplayCache[affixID] = info

    return info

end

function MythicPlusModule:RefreshOwnedKeystone()

    local profile = self.Profile

    if not GetOwnedKeystoneChallengeMapID or not GetOwnedKeystoneLevel then

        profile.hasKeystone = false
        profile.currentDungeonID = 0
        profile.currentDungeonName = ""
        profile.currentLevel = 0

    else

        local dungeonID = GetOwnedKeystoneChallengeMapID()
        local level = GetOwnedKeystoneLevel()

        if dungeonID and dungeonID > 0 then
            profile.hasKeystone = true
            profile.currentDungeonID = dungeonID
            profile.currentDungeonName = self:GetDungeonName(dungeonID)
            profile.currentLevel = level or 0
        else
            profile.hasKeystone = false
            profile.currentDungeonID = 0
            profile.currentDungeonName = ""
            profile.currentLevel = 0
        end

    end

    -- currentAffixIDs is a narrower, genuinely receptacle-scoped bonus --
    -- only available while interacting with a Font of Power. It is
    -- deliberately decoupled from hasKeystone/currentDungeonID/
    -- currentLevel above, which are now correct from anywhere.
    if HasSlottedKeystone() then
        local _, affixIDs = GetSlottedKeystoneInfo()
        profile.currentAffixIDs = affixIDs or {}
    else
        profile.currentAffixIDs = {}
    end

end

function MythicPlusModule:RefreshWeeklyAffixes()

    if not GetCurrentAffixes then
        self.Profile.weeklyAffixIDs = {}
        return
    end

    -- Returns nil until RequestMapInfo() has been called at least once
    -- this session. Enable()/OnPlayerEnteringWorld() request it; this
    -- refresh runs again when MYTHIC_PLUS_CURRENT_AFFIX_UPDATE fires.
    local affixes = GetCurrentAffixes()

    self.Profile.weeklyAffixIDs = affixes or {}

end

function MythicPlusModule:RefreshBestRuns()

    local bestRuns = {}

    local scores = GetMapScoreInfo and GetMapScoreInfo()

    if type(scores) == "table" then

        for i = 1, #scores do

            local scoreInfo = scores[i]

            if type(scoreInfo) == "table" and scoreInfo.mapChallengeModeID then

                bestRuns[scoreInfo.mapChallengeModeID] =
                {
                    level = scoreInfo.level or 0,
                    score = scoreInfo.dungeonScore or 0,
                }

            end

        end

    end

    self.Profile.bestRuns = bestRuns

end

function MythicPlusModule:RefreshActiveRun()

    if not IsChallengeModeActive() then
        self.Profile.activeRun = nil
        return
    end

    local keystoneLevel, affixIDs, wasCharged = GetActiveKeystoneInfo()
    local numDeaths, timeLost = GetDeathCount()

    self.Profile.activeRun =
    {
        keystoneLevel = keystoneLevel or 0,
        affixIDs = affixIDs or {},
        wasCharged = wasCharged == true,
        deathCount = numDeaths or 0,
        timeLost = timeLost or 0,
    }

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function MythicPlusModule:GetProfile()

    return self.Profile

end

function MythicPlusModule:GetBestOverallLevel()

    local best = 0

    for _, run in pairs(self.Profile.bestRuns) do

        if run.level and run.level > best then
            best = run.level
        end

    end

    return best

end

-------------------------------------------------------------------------------
-- Recent Runs
--
-- Reads back through ActivityHistoryService's public API (GetByModule) --
-- MythicPlusModule never touches ActivityHistoryService's storage
-- directly, matching how it wrote the records in the first place. Newest
-- first, since GetByModule returns chronological (oldest-first) order.
-- Only ever reflects runs completed since this recording feature shipped
-- -- there is no historical backfill, since Blizzard exposes no run log
-- to backfill from.
-------------------------------------------------------------------------------

function MythicPlusModule:GetRecentRuns(count)

    count = tonumber(count) or 10

    local results = {}

    if not AC.ActivityHistoryService then
        return results
    end

    local records = AC.ActivityHistoryService:GetByModule("MythicPlus")
    local total = #records

    for i = total, math.max(1, total - count + 1), -1 do
        table.insert(results, records[i])
    end

    return results

end

-------------------------------------------------------------------------------
-- Season / Range Statistics (Companion Intelligence V4: shared core)
--
-- Aggregated entirely from recorded ActivityHistoryService records --
-- never fabricated, and empty (runsCompleted == 0) until the player
-- completes their first run after this feature shipped. "Timed" here
-- means Blizzard's own onTime/Success flag from GetChallengeCompletionInfo(), not
-- a threshold this module invents.
--
-- "Weakest/strongest dungeon" are distinct from "least/most-run dungeon":
-- they are the dungeons with the lowest/highest TIMED rate among dungeons
-- run at least WEAKEST_DUNGEON_MIN_SAMPLES times in the record set being
-- aggregated -- a dungeon run once is a single data point, not a
-- verdict, so it's excluded rather than reported as a false signal.
--
-- averageItemLevelByKeyLevel is the honest alternative to a hardcoded
-- "recommended item level" table: Blizzard exposes no such API (see
-- docs/GameplayModuleArchitecture.md), so instead of guessing at one,
-- this reports the player's OWN historical average equipped item level
-- at each key level they have actually succeeded at -- entirely
-- self-referential, sourced from data.itemLevel captured at each run's
-- completion (recordVersion 2+; absent/nil on older records, which are
-- simply excluded from this particular figure).
--
-- BuildStatisticsFromRecords(records) is the shared aggregation core
-- both GetSeasonStatistics() (filters to the current season) and
-- GetStatisticsForRange() (filters to a date range, Companion
-- Intelligence V4 -- ProgressSummaryService's "Last 7 Days"/"Last 30
-- Days"/"Lifetime" buckets) call, each with a different pre-filtered
-- record list -- one aggregation loop, not two copies of it.
-------------------------------------------------------------------------------

local WEAKEST_DUNGEON_MIN_SAMPLES = 2

local function BuildStatisticsFromRecords(records)

    local stats =
    {
        runsCompleted = 0,
        timedRuns = 0,
        failedRuns = 0,
        successRate = 0,
        averageKeyLevel = 0,
        averageDeaths = 0,
        totalDeaths = 0,
        minDeaths = nil,
        highestTimedLevel = 0,
        highestCompletedLevel = 0,
        fastestRun = nil,
        slowestRun = nil,
        averageCompletionTime = 0,
        mostRunDungeon = nil,
        leastRunDungeon = nil,
        weakestDungeon = nil,
        weakestDungeonRate = 0,
        strongestDungeon = nil,
        strongestDungeonRate = 0,
        ratingGained = 0,
        averageItemLevelByKeyLevel = {},
        consumableTotals = {},
        totalConsumables = 0,
        totalInterrupts = 0,
        trackedRunCount = 0,
        averageConsumablesPerRun = 0,
        averageInterruptsPerRun = 0,
        dungeonBreakdown = {},

        -- Companion Intelligence V4 -- lifetime-flavored facts
        -- MilestoneService reads via GetMilestoneStats(), and the
        -- Progress page (Progress Dashboard) reads directly for
        -- Personal Records: a win streak and "any zero-death run" only
        -- mean something computed over records in chronological order
        -- (which GetByModule/GetByDateRange both already preserve --
        -- records are always appended chronologically), so these are
        -- computed in the same single pass as everything else here
        -- rather than a second scan.
        longestWinStreak = 0,
        largestRatingGain = 0,
        hasNoDeathRun = false,
    }

    if not records then
        return stats
    end

    local totalKeyLevels = 0
    local totalCompletionTime = 0
    local dungeonRunCounts = {}
    local dungeonTimedCounts = {}
    local itemLevelTotalsByKeyLevel = {}
    local currentStreak = 0

    -- Keyed by dungeonID rather than name -- used by GetDungeonStatistics()
    -- below so RecommendationEngine can attach a specific dungeon's own
    -- historical success rate/completion time as supporting evidence
    -- without duplicating this aggregation itself (Part 2/4 of
    -- RecommendationEngine V2 -- see docs/GameplayModuleArchitecture.md).
    local dungeonBreakdownTotals = {}

    for _, record in ipairs(records) do

        local data = record.Data or {}

        stats.runsCompleted = stats.runsCompleted + 1

        if record.Success then
            stats.timedRuns = stats.timedRuns + 1
            currentStreak = currentStreak + 1

            if currentStreak > stats.longestWinStreak then
                stats.longestWinStreak = currentStreak
            end

        else
            stats.failedRuns = stats.failedRuns + 1
            currentStreak = 0
        end

        local level = data.level or 0
        local deathCount = data.deathCount or 0

        totalKeyLevels = totalKeyLevels + level
        stats.totalDeaths = stats.totalDeaths + deathCount

        if not stats.minDeaths or deathCount < stats.minDeaths then
            stats.minDeaths = deathCount
        end

        if deathCount == 0 then
            stats.hasNoDeathRun = true
        end

        if record.Success and level > stats.highestTimedLevel then
            stats.highestTimedLevel = level
        end

        if level > stats.highestCompletedLevel then
            stats.highestCompletedLevel = level
        end

        local completionTime = data.time or 0

        if completionTime > 0 then

            totalCompletionTime = totalCompletionTime + completionTime

            if not stats.fastestRun or completionTime < stats.fastestRun.time then
                stats.fastestRun = { dungeonName = record.ActivityName, level = level, time = completionTime }
            end

            if not stats.slowestRun or completionTime > stats.slowestRun.time then
                stats.slowestRun = { dungeonName = record.ActivityName, level = level, time = completionTime }
            end

        end

        local dungeonName = record.ActivityName or ""

        if dungeonName ~= "" then

            dungeonRunCounts[dungeonName] = (dungeonRunCounts[dungeonName] or 0) + 1

            if record.Success then
                dungeonTimedCounts[dungeonName] = (dungeonTimedCounts[dungeonName] or 0) + 1
            end

        end

        local dungeonID = data.dungeonID

        if dungeonID and dungeonID > 0 then

            local breakdown = dungeonBreakdownTotals[dungeonID]

            if not breakdown then
                breakdown = { runsCompleted = 0, timedRuns = 0, totalTime = 0, timeSamples = 0 }
                dungeonBreakdownTotals[dungeonID] = breakdown
            end

            breakdown.runsCompleted = breakdown.runsCompleted + 1

            if record.Success then
                breakdown.timedRuns = breakdown.timedRuns + 1
            end

            if completionTime > 0 then
                breakdown.totalTime = breakdown.totalTime + completionTime
                breakdown.timeSamples = breakdown.timeSamples + 1
            end

        end

        local scoreChange = data.scoreChange or 0

        stats.ratingGained = stats.ratingGained + scoreChange

        if scoreChange > stats.largestRatingGain then
            stats.largestRatingGain = scoreChange
        end

        -- recordVersion 2+ only -- older records have no itemLevel.
        if record.Success and data.itemLevel and data.itemLevel > 0 and level > 0 then

            local bucket = itemLevelTotalsByKeyLevel[level]

            if not bucket then
                bucket = { total = 0, count = 0 }
                itemLevelTotalsByKeyLevel[level] = bucket
            end

            bucket.total = bucket.total + data.itemLevel
            bucket.count = bucket.count + 1

        end

        -- recordVersion 2+ only -- older records were never tracked for
        -- consumables/interrupts at all, so they're excluded here rather
        -- than silently counted as zero usage.
        if data.recordVersion and data.recordVersion >= 2 then

            stats.trackedRunCount = stats.trackedRunCount + 1
            stats.totalInterrupts = stats.totalInterrupts + (data.interruptCount or 0)

            for category, count in pairs(data.consumables or {}) do
                stats.consumableTotals[category] = (stats.consumableTotals[category] or 0) + count
                stats.totalConsumables = stats.totalConsumables + count
            end

        end

    end

    if stats.runsCompleted > 0 then
        stats.averageKeyLevel = totalKeyLevels / stats.runsCompleted
        stats.averageCompletionTime = totalCompletionTime / stats.runsCompleted
        stats.averageDeaths = stats.totalDeaths / stats.runsCompleted
        stats.successRate = (stats.timedRuns / stats.runsCompleted) * 100
    end

    -- Companion Intelligence vNext -- per-run averages of the same
    -- trackedRunCount-scoped totals above (recordVersion 2+ only, same
    -- gate as totalConsumables/totalInterrupts themselves). Computed here,
    -- once, so BriefingService's Companion Memory line and
    -- ProgressSummaryService's trend comparison both read one real number
    -- instead of each dividing totalConsumables/totalInterrupts by
    -- trackedRunCount a second time (Rule 7).
    if stats.trackedRunCount > 0 then
        stats.averageConsumablesPerRun = stats.totalConsumables / stats.trackedRunCount
        stats.averageInterruptsPerRun = stats.totalInterrupts / stats.trackedRunCount
    end

    local mostCount, leastCount = 0, math.huge

    for dungeonName, count in pairs(dungeonRunCounts) do

        if count > mostCount then
            stats.mostRunDungeon = dungeonName
            mostCount = count
        end

        if count < leastCount then
            stats.leastRunDungeon = dungeonName
            leastCount = count
        end

    end

    local weakestRate, strongestRate = nil, nil

    for dungeonName, count in pairs(dungeonRunCounts) do

        if count >= WEAKEST_DUNGEON_MIN_SAMPLES then

            local timedCount = dungeonTimedCounts[dungeonName] or 0
            local rate = timedCount / count

            if not weakestRate or rate < weakestRate then
                weakestRate = rate
                stats.weakestDungeon = dungeonName
                stats.weakestDungeonRate = rate * 100
            end

            if not strongestRate or rate > strongestRate then
                strongestRate = rate
                stats.strongestDungeon = dungeonName
                stats.strongestDungeonRate = rate * 100
            end

        end

    end

    for level, bucket in pairs(itemLevelTotalsByKeyLevel) do
        stats.averageItemLevelByKeyLevel[level] = bucket.total / bucket.count
    end

    for dungeonID, breakdown in pairs(dungeonBreakdownTotals) do

        stats.dungeonBreakdown[dungeonID] =
        {
            runsCompleted = breakdown.runsCompleted,
            timedRuns = breakdown.timedRuns,
            successRate = (breakdown.timedRuns / breakdown.runsCompleted) * 100,
            averageCompletionTime = breakdown.timeSamples > 0 and (breakdown.totalTime / breakdown.timeSamples) or 0,
        }

    end

    return stats

end

function MythicPlusModule:GetSeasonStatistics()

    if not AC.ActivityHistoryService then
        return BuildStatisticsFromRecords(nil)
    end

    local currentSeason = self.Profile.currentSeason
    local allRecords = AC.ActivityHistoryService:GetByModule("MythicPlus")
    local filtered = {}

    for _, record in ipairs(allRecords) do

        if (record.Data or {}).season == currentSeason then
            table.insert(filtered, record)
        end

    end

    return BuildStatisticsFromRecords(filtered)

end

-------------------------------------------------------------------------------
-- Statistics For Range (Companion Intelligence V4)
--
-- The same aggregation as GetSeasonStatistics(), scoped to a date range
-- instead of a season -- what ProgressSummaryService's "Last 7 Days"/
-- "Last 30 Days"/"Lifetime" buckets are built from. Reuses
-- ActivityHistoryService:GetByDateRange(), previously-scaffolded
-- infrastructure with no caller until now (its own comment already
-- named "a future StatisticsService" as the intended consumer).
-------------------------------------------------------------------------------

function MythicPlusModule:GetStatisticsForRange(startTime, endTime)

    if not AC.ActivityHistoryService then
        return BuildStatisticsFromRecords(nil)
    end

    local records = AC.ActivityHistoryService:GetByDateRange(startTime, endTime)
    local filtered = {}

    for _, record in ipairs(records) do

        if record.Module == "MythicPlus" then
            table.insert(filtered, record)
        end

    end

    return BuildStatisticsFromRecords(filtered)

end

-------------------------------------------------------------------------------
-- Dungeon Statistics
--
-- A single dungeon's own slice of GetSeasonStatistics()'s dungeonBreakdown
-- -- exists so a consumer that only cares about one specific dungeon (the
-- one currently keyed, for example) doesn't need to read the whole
-- season's aggregate to get it. Returns nil rather than a zeroed table
-- when nothing has been recorded for this dungeon yet, so callers can
-- distinguish "no data" from "0% success".
-------------------------------------------------------------------------------

function MythicPlusModule:GetDungeonStatistics(dungeonID)

    dungeonID = tonumber(dungeonID)

    if not dungeonID or dungeonID <= 0 then
        return nil
    end

    local seasonStats = self:GetSeasonStatistics()

    return seasonStats.dungeonBreakdown and seasonStats.dungeonBreakdown[dungeonID]

end

-------------------------------------------------------------------------------
-- Milestone Stats (Companion Intelligence V4)
--
-- The real, lifetime-scoped facts MilestoneService compares against its
-- own fixed thresholds to decide which personal milestones (first key
-- level reached, timed-run count, longest win streak, ...) have been
-- achieved. This module computes and owns every fact here (Rule 1 --
-- these are all Mythic+ gameplay data); MilestoneService only owns the
-- generic threshold/achieved-state bookkeeping, never derives a fact
-- like "longest win streak" itself. GetStatisticsForRange(0, now) reuses
-- the exact same shared aggregation core as everything else in this
-- file -- no separate lifetime-scan is written for this.
-------------------------------------------------------------------------------

function MythicPlusModule:GetMilestoneStats()

    -- totalConsumables (Progress Dashboard) is BuildStatisticsFromRecords'
    -- own running sum, computed in the same pass as consumableTotals --
    -- this used to re-sum consumableTotals itself; now it just reads the
    -- field, one less duplicate calculation.
    local lifetime = self:GetStatisticsForRange(0, time())

    return
    {
        hasAnyRun = lifetime.runsCompleted > 0,
        highestLevelCompleted = lifetime.highestCompletedLevel,
        timedRunCount = lifetime.timedRuns,
        hasNoDeathRun = lifetime.hasNoDeathRun,
        longestWinStreak = lifetime.longestWinStreak,
        largestRatingGain = lifetime.largestRatingGain,
        totalConsumablesUsed = lifetime.totalConsumables,
        totalInterrupts = lifetime.totalInterrupts,
        currentRating = self.Profile.rating or 0,
    }

end

function MythicPlusModule:GetDashboardSummary()

    local profile = self.Profile

    return
    {
        hasKeystone = profile.hasKeystone,
        currentDungeonID = profile.currentDungeonID,
        currentDungeonName = profile.currentDungeonName,
        currentLevel = profile.currentLevel,
        currentSeason = profile.currentSeason,
        rating = profile.rating,
        bestOverallLevel = self:GetBestOverallLevel(),
    }

end

-- Companion Intelligence vNext -- the real, session-scoped fact
-- SessionNotesService's "This session you've completed N Mythic+
-- dungeon(s)" line reads (Rule 4: a public getter, never self.Session
-- read directly by a consumer) -- same naming/shape convention as
-- AccomplishmentsModule's own GetSessionSummary().
function MythicPlusModule:GetSessionSummary()

    return
    {
        runsCompletedThisSession = self.Session.runsCompletedThisSession or 0,
    }

end

-------------------------------------------------------------------------------
-- Insights
--
-- Objective only -- each of these is a direct fact (a missing keystone,
-- Blizzard's own IsMapRecord flag, a session-relative rating delta, an
-- active-run boolean), not a threshold or judgment this module invents.
-------------------------------------------------------------------------------

function MythicPlusModule:GetInsights()

    local insights = {}
    local profile = self.Profile
    local session = self.Session

    if not profile or not session then
        return insights
    end

    -- No keystone slotted (only knowable near a Font of Power -- see
    -- the note above RefreshOwnedKeystone/ResetProfile)
    if not profile.hasKeystone then
        table.insert(insights,
        {
            title = "No Keystone",
            description = "You do not have a keystone slotted.",
            priority = 30,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Keystone ready to run -- an objective fact (an owned keystone and
    -- no run currently in progress), not a judgment. Priority scales
    -- gently with level so a higher key nudges ahead of a lower one, but
    -- is capped well below truly urgent signals like Deaths Today.
    -- RecommendationEngine (see "Complete Your Keystone") is the one that
    -- attaches cross-module supporting evidence to this -- this insight
    -- itself only reports the Mythic+-owned fact.
    if profile.hasKeystone and not profile.activeRun then

        local level = profile.currentLevel or 0
        local dungeonName = profile.currentDungeonName or ""

        table.insert(insights,
        {
            title = "Keystone Ready",
            description = string.format("Your %s +%d keystone is ready to run.", dungeonName ~= "" and dungeonName or "dungeon", level),
            priority = math.min(50 + level, 65),
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data =
            {
                dungeonID = profile.currentDungeonID,
                dungeonName = dungeonName,
                level = level,
            },
        })

    end

    -- Personal best -- sourced directly from Blizzard's own IsMapRecord
    -- flag, not a level threshold this module invents.
    if profile.lastCompletedRun and profile.lastCompletedRun.isMapRecord then
        table.insert(insights,
        {
            title = "Personal Best",
            description = string.format("You set a new personal best at level %d.", profile.lastCompletedRun.level or 0),
            priority = 60,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data =
            {
                level = profile.lastCompletedRun.level or 0,
                dungeonName = profile.lastCompletedRun.dungeonName or "",
            },
        })
    end

    -- Rating increased this session
    local ratingChange = profile.rating - (session.initialRating or profile.rating)

    if ratingChange > 0 then
        table.insert(insights,
        {
            title = "Rating Increased",
            description = string.format("Your Mythic+ rating increased by %.1f this session.", ratingChange),
            priority = 40,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -- Current run active
    if profile.activeRun then
        table.insert(insights,
        {
            title = "Current Run Active",
            description = "You are currently in an active Mythic+ run.",
            priority = 20,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = {},
        })
    end

    -----------------------------------------------------------------------
    -- History-backed insights -- sourced from recorded runs
    -- (ActivityHistoryService via GetRecentRuns/GetSeasonStatistics), not
    -- fabricated. Each is gated on having enough recorded runs that the
    -- figure is meaningful rather than noise from a run or two -- there is
    -- no historical backfill, so these stay quiet until enough real data
    -- has accumulated since this feature shipped.
    -----------------------------------------------------------------------

    local recentRuns = self:GetRecentRuns(10)

    if #recentRuns >= 3 then

        local timedCount = 0

        for _, run in ipairs(recentRuns) do

            if run.Success then
                timedCount = timedCount + 1
            end

        end

        table.insert(insights,
        {
            title = "Recent Timed Rate",
            description = string.format("You timed %d of your last %d runs.", timedCount, #recentRuns),
            priority = 35,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { timedCount = timedCount, totalRuns = #recentRuns },
        })

    end

    local seasonStats = self:GetSeasonStatistics()

    if seasonStats.runsCompleted >= 3 then
        table.insert(insights,
        {
            title = "Season Success Rate",
            description = string.format("Your success rate this season is %.0f%%.", seasonStats.successRate),
            priority = 25,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { successRate = seasonStats.successRate, runsCompleted = seasonStats.runsCompleted },
        })
    end

    -- Untimed This Season (Companion Intelligence vNext) -- the honest,
    -- buildable version of "haven't completed this dungeon this season":
    -- there is no enumerated "every dungeon in the current pool" getter
    -- anywhere in this module (that would need a new Blizzard API this
    -- module doesn't call), so this reports the real, narrower fact --
    -- the currently-owned dungeon has been attempted this season but
    -- never once timed. Gated on hasKeystone/currentDungeonID being the
    -- SAME dungeon these attempts were against.
    if profile.hasKeystone and profile.currentDungeonID and profile.currentDungeonID > 0 then

        local currentDungeonStats = self:GetDungeonStatistics(profile.currentDungeonID)

        if currentDungeonStats and currentDungeonStats.runsCompleted > 0 and currentDungeonStats.timedRuns == 0 then
            table.insert(insights,
            {
                title = "Untimed This Season",
                description = string.format("You've attempted %s %d time(s) this season without timing it.", profile.currentDungeonName ~= "" and profile.currentDungeonName or "this dungeon", currentDungeonStats.runsCompleted),
                priority = 18,
                category = "MythicPlus",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = { dungeonID = profile.currentDungeonID, dungeonName = profile.currentDungeonName, attempts = currentDungeonStats.runsCompleted },
            })
        end

    end

    -- Weakest dungeon this season -- only reported once GetSeasonStatistics
    -- has enough samples for a given dungeon to call it that (see
    -- WEAKEST_DUNGEON_MIN_SAMPLES).
    if seasonStats.weakestDungeon then
        table.insert(insights,
        {
            title = "Weakest Dungeon",
            description = string.format("%s is your weakest dungeon this season.", seasonStats.weakestDungeon),
            priority = 30,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { dungeonName = seasonStats.weakestDungeon, successRate = seasonStats.weakestDungeonRate },
        })
    end

    -- Strongest dungeon this season (Companion Intelligence V4) -- the
    -- same WEAKEST_DUNGEON_MIN_SAMPLES gate, mirrored: a dungeon run once
    -- with a lucky time isn't "your strongest," it's a single data point.
    -- Lower priority than Weakest Dungeon -- "you're doing great at X" is
    -- worth knowing but less actionable than "you're weak at Y".
    if seasonStats.strongestDungeon then
        table.insert(insights,
        {
            title = "Strongest Dungeon",
            description = string.format("%s is your strongest dungeon this season (%.0f%% success rate).", seasonStats.strongestDungeon, seasonStats.strongestDungeonRate),
            priority = 20,
            category = "MythicPlus",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { dungeonName = seasonStats.strongestDungeon, successRate = seasonStats.strongestDungeonRate },
        })
    end

    -- Average deaths in the currently-owned dungeon this season -- only
    -- once there are enough recorded runs of that specific dungeon for
    -- an average to mean anything.
    if AC.ActivityHistoryService and profile.hasKeystone and profile.currentDungeonID and profile.currentDungeonID > 0 then

        local dungeonRuns, dungeonDeaths = 0, 0

        for _, record in ipairs(AC.ActivityHistoryService:GetByModule("MythicPlus")) do

            local data = record.Data or {}

            if data.season == profile.currentSeason and data.dungeonID == profile.currentDungeonID then
                dungeonRuns = dungeonRuns + 1
                dungeonDeaths = dungeonDeaths + (data.deathCount or 0)
            end

        end

        if dungeonRuns >= 2 then
            table.insert(insights,
            {
                title = "Dungeon Average Deaths",
                description = string.format("You average %.1f deaths in %s.", dungeonDeaths / dungeonRuns, profile.currentDungeonName ~= "" and profile.currentDungeonName or "this dungeon"),
                priority = 22,
                category = "MythicPlus",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = { averageDeaths = dungeonDeaths / dungeonRuns, dungeonID = profile.currentDungeonID },
            })
        end

    end

    -- Deaths today -- a same-day sum across all recorded runs, regardless
    -- of season (a death today is a death today even right at a season
    -- boundary).
    if AC.ActivityHistoryService then

        local today = date("%Y-%m-%d")
        local deathsToday = 0

        for _, record in ipairs(AC.ActivityHistoryService:GetByModule("MythicPlus")) do

            if date("%Y-%m-%d", record.Timestamp or 0) == today then
                deathsToday = deathsToday + ((record.Data or {}).deathCount or 0)
            end

        end

        if deathsToday >= 5 then
            table.insert(insights,
            {
                title = "Deaths Today",
                description = string.format("You have died %d times today.", deathsToday),
                priority = 45,
                category = "MythicPlus",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = { deathsToday = deathsToday },
            })
        end

    end

    -- Success rate trend -- compares the timed rate of the earlier half
    -- of this season's recorded runs against the later half. Requires at
    -- least 6 runs so each half has a meaningful sample.
    if AC.ActivityHistoryService then

        local seasonRuns = {}

        for _, record in ipairs(AC.ActivityHistoryService:GetByModule("MythicPlus")) do

            if (record.Data or {}).season == profile.currentSeason then
                table.insert(seasonRuns, record)
            end

        end

        if #seasonRuns >= 6 then

            local half = math.floor(#seasonRuns / 2)
            local olderTimed, newerTimed = 0, 0

            for i = 1, half do
                if seasonRuns[i].Success then
                    olderTimed = olderTimed + 1
                end
            end

            for i = half + 1, #seasonRuns do
                if seasonRuns[i].Success then
                    newerTimed = newerTimed + 1
                end
            end

            local olderRate = olderTimed / half
            local newerRate = newerTimed / (#seasonRuns - half)

            if newerRate - olderRate >= 0.2 then
                table.insert(insights,
                {
                    title = "Success Rate Improving",
                    description = "Your success rate is improving.",
                    priority = 20,
                    category = "MythicPlus",
                    timestamp = time(),
                    expiresAt = 0,
                    dismissible = false,
                    data = { olderRate = olderRate * 100, newerRate = newerRate * 100 },
                })
            end

        end

    end

    -- Consumables reminder -- only counts runs that actually tracked
    -- consumables (recordVersion 2+; older runs simply have no signal
    -- either way and are excluded rather than assumed to mean "none
    -- used"). Flags a low flask/food usage rate, not potion usage, since
    -- flask/food are the ones typically expected before every pull.
    if AC.ActivityHistoryService then

        local trackedRuns, runsWithPrep = 0, 0

        for _, record in ipairs(AC.ActivityHistoryService:GetByModule("MythicPlus")) do

            local data = record.Data or {}

            if data.season == profile.currentSeason and data.recordVersion and data.recordVersion >= 2 then

                trackedRuns = trackedRuns + 1

                local consumables = data.consumables or {}

                if (consumables.flask or 0) > 0 or (consumables.food or 0) > 0 then
                    runsWithPrep = runsWithPrep + 1
                end

            end

        end

        if trackedRuns >= 5 and (runsWithPrep / trackedRuns) < 0.5 then
            table.insert(insights,
            {
                title = "Consumables Reminder",
                description = "You often start Mythic+ runs without a flask or food buff.",
                priority = 28,
                category = "MythicPlus",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = { trackedRuns = trackedRuns, runsWithPrep = runsWithPrep },
            })
        end

    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("MythicPlus", MythicPlusModule)

return MythicPlusModule
