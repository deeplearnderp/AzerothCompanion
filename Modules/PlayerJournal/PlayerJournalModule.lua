-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Module
--
-- Owns "who have I grouped with" -- a local, account-wide database of
-- players encountered in Mythic+ (identity, objective stats, personal
-- notes, personal tags, a bounded timeline). This is the new, explicit
-- owner of party-member facts the architecture doc's own Section 1.4
-- deferred ("this needs a deliberate decision before any code is written
-- here, not a default") -- that deferral was scoped to MythicPlusModule
-- specifically (RunTracking stays self-only there, unmodified); this is
-- a different module making that deliberate decision. See
-- docs/GameplayModuleArchitecture.md section 1.11 for the full reasoning.
--
-- Storage: DatabaseService:GetGlobal().PlayerJournal, not a
-- ConfigurationManager profile (profiles are shareable across characters
-- via profile-switching -- wrong for private data about other players)
-- and not per-character ActivityHistoryService-style storage (whether
-- you recognize a past companion is a fact about the account/person
-- playing, not about which alt you happened to be on that day -- the
-- same reasoning this addon's own VerificationService already
-- established for its account-wide VerificationLog/ChecklistLog).
--
-- Data collection: basic party-roster reads (UnitFullName/UnitGUID/
-- UnitClass/UnitGroupRolesAssigned) and a narrowly-filtered
-- COMBAT_LOG_EVENT_UNFILTERED (UNIT_DIED and SPELL_INTERRUPT only, roster
-- members only) -- NOT the heavier NotifyInspect/INSPECT_READY path the
-- architecture doc specifically called out as the thing actually being
-- deferred. No talents, no gear, no full spec resolution for companions -- identity
-- and outcome facts only.
--
-- Run outcome data (dungeon/level/timed/rating change) is never
-- recomputed here -- it is read from MythicPlusModule's own already-
-- published GetRecentRuns() after a run completes, correlated against the
-- history ID captured when that run started
-- (Architectural Rule 7: never duplicate logic the owning module already
-- provides). See FinalizeCompletedRunForRoster's own comment for why
-- that read is deferred one frame via C_Timer.After(0, ...) rather than
-- read synchronously inside the same CHALLENGE_MODE_COMPLETED
-- handler.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local time = time

local UnitExists = UnitExists
local UnitFullName = UnitFullName
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetRealmName = GetRealmName
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local strmatch = string.match

local PlayerJournalModule =
{
    Name = "PlayerJournal",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
    enableTooltips = true,
    enableEndOfRunPrompt = true,
    maximumStoredPlayers = 250,
    autoPruneInactive = false,
    autoPruneInactiveDays = 90,
}

local ROSTER_LEAVE_GRACE_SECONDS = 5
local MAX_TIMELINE_EVENTS = 200
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

-------------------------------------------------------------------------------
-- Qualifying Relationships
--
-- This is the module-owned persistence boundary for Player Journal records.
-- Callers describe WHY a player qualifies; they do not create records and
-- then scatter relationship flags across the UI. Interaction relationships
-- keep only a bounded summary here. Facts with an existing authoritative
-- home (Favorite tags, personal notes, Community observations) qualify a
-- player but are projected from that owner later rather than duplicated.
-------------------------------------------------------------------------------

PlayerJournalModule.RelationshipTypes =
{
    MythicPlus = "MythicPlus",
    Delve = "Delve",
    Raid = "Raid",
    Dungeon = "Dungeon",
    Party = "Party",
    RandomQueue = "RandomQueue",
    Whisper = "Whisper",
    Friend = "Friend",
    Guild = "Guild",
    Favorite = "Favorite",
    PersonalNote = "PersonalNote",
    CommunityObservation = "CommunityObservation",
    Explicit = "Explicit",
    PersonalTag = "PersonalTag",
}

local RELATIONSHIP_DEFINITIONS =
{
    -- Mythic+ is derived from record.runs; persisting another count would
    -- duplicate the run history's fact.
    MythicPlus = { persistSummary = false },
    Delve = { persistSummary = true },
    Raid = { persistSummary = true },
    Dungeon = { persistSummary = true },
    Party = { persistSummary = true },
    RandomQueue = { persistSummary = true },
    Whisper = { persistSummary = true },
    Friend = { persistSummary = true },
    Guild = { persistSummary = true },
    Explicit = { persistSummary = true },

    -- One Fact, One Home: these qualify persistence, but their truth is
    -- already stored by tags, notes, or CommunityModule respectively.
    Favorite = { persistSummary = false },
    PersonalNote = { persistSummary = false },
    CommunityObservation = { persistSummary = false },
    PersonalTag = { persistSummary = false },
}

local RELATIONSHIP_PRIORITY =
{
    Favorite = 100,
    PersonalNote = 90,
    CommunityObservation = 85,
    PersonalTag = 80,
    Friend = 75,
    Guild = 70,
    MythicPlus = 65,
    Raid = 60,
    Delve = 58,
    Dungeon = 55,
    RandomQueue = 52,
    Party = 50,
    Whisper = 45,
    Explicit = 20,
    Legacy = 0,
}

-------------------------------------------------------------------------------
-- Storage Access
-------------------------------------------------------------------------------

local function GetJournal()

    return AC.DatabaseService:GetGlobal().PlayerJournal

end

-- "Name-Realm", dash-separated -- deliberately the opposite format from
-- DatabaseService:GetCharacterKey()'s "Realm.Name", so a companion's key
-- and one of your own character keys can never be visually confused.
local function MakePlayerKey(name, realm)

    if not name or name == "" then
        return nil
    end

    local resolvedRealm = (realm and realm ~= "") and realm or (GetRealmName and GetRealmName()) or ""

    return name .. "-" .. resolvedRealm

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function PlayerJournalModule:Initialize()

    self:ResetRunTracking()
    self:MigrateRelationshipData()

    AC.ConfigurationManager:Register("PlayerJournal", Defaults)

    AC.Settings:RegisterPage("PlayerJournal",
    {
        title = "Player Journal",
        module = "PlayerJournal",

        -- Companion Intelligence vNext self-review: this was originally
        -- 60, the same order value StorageModule's own Settings page
        -- also uses -- an unrelated, pre-existing collision found and
        -- fixed while adding NotificationService's own new page nearby.
        order = 61,
    })

    AC.Settings:RegisterSection("PlayerJournal", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("PlayerJournal", "General",
    {
        key = "enabled",
        text = "Enable Player Journal",
        default = true,
        tooltip = "Remember players you've grouped with in Mythic+ -- objective stats, personal notes, and tags, stored locally.",
    })

    AC.Settings:AddCheckbox("PlayerJournal", "General",
    {
        key = "enableTooltips",
        text = "Show Journal Info in Tooltips",
        default = true,
        tooltip = "When hovering a player, show Runs Together, Last Seen, a note preview, and your Favorite tag if set.",
    })

    AC.Settings:AddCheckbox("PlayerJournal", "General",
    {
        key = "enableEndOfRunPrompt",
        text = "Prompt After Mythic+ Runs",
        default = true,
        tooltip = "After completing a Mythic+ run, optionally ask if you'd like to add a note about anyone from that run.",
    })

    AC.Settings:RegisterSection("PlayerJournal", "Storage",
    {
        title = "Storage",
    })

    AC.Settings:AddSlider("PlayerJournal", "Storage",
    {
        key = "maximumStoredPlayers",
        text = "Maximum Stored Players",
        default = 250,
        min = 50,
        max = 1000,
        step = 25,
        tooltip = "The oldest, non-Favorite players are pruned once this limit is exceeded.",
    })

    AC.Settings:AddCheckbox("PlayerJournal", "Storage",
    {
        key = "autoPruneInactive",
        text = "Automatically Prune Inactive Players",
        default = false,
        tooltip = "Remove non-Favorite players you haven't grouped with in a long time.",
    })

    AC.Settings:AddSlider("PlayerJournal", "Storage",
    {
        key = "autoPruneInactiveDays",
        text = "Inactive After (Days)",
        default = 90,
        min = 7,
        max = 365,
        step = 7,
        tooltip = "How long since Last Seen before a non-Favorite player is eligible for automatic pruning.",
    })

    AC.Settings:RegisterSection("PlayerJournal", "Data",
    {
        title = "Data",
    })

    -- Export/Import: real future-scope stubs, not settings values -- no
    -- `key`, matching ContentPanel.lua's own "Button and not
    -- controlDef.key" branch for a pure action button (BindControl/
    -- RefreshPageValues both special-case this so the button's own label
    -- text is never overwritten by a bound config value). SettingsManager
    -- has no `enabled=false`-at-creation support for a settings-page
    -- button today (ContentPanel.lua never reads a controlDef.enabled
    -- field) -- rather than extend shared settings framework code for
    -- two stub buttons, these stay clickable but genuinely inert, with an
    -- honest tooltip explaining why.
    AC.Settings:AddButton("PlayerJournal", "Data",
    {
        text = "Export Personal Notes",
        tooltip = "Coming in a future update.",
        onClick = function() end,
    })

    AC.Settings:AddButton("PlayerJournal", "Data",
    {
        text = "Import Personal Notes",
        tooltip = "Coming in a future update.",
        onClick = function() end,
    })

end

-------------------------------------------------------------------------------
-- Enable / Disable
-------------------------------------------------------------------------------

function PlayerJournalModule:Enable()

    AC.Events:Register("CHALLENGE_MODE_START", self)
    AC.Events:Register("CHALLENGE_MODE_COMPLETED", self)
    AC.Events:Register("CHALLENGE_MODE_RESET", self)
    AC.Events:Register("CHAT_MSG_WHISPER_INFORM", self)

end

-------------------------------------------------------------------------------
-- Relationship Schema Migration
--
-- PlayerJournal owns this nested schema. Existing records are normalized in
-- place without deleting or reclassifying any user-authored data. Mythic+,
-- Favorite, Notes, tags, and Community observations remain derived by
-- GetRelationships from their authoritative owners.
-------------------------------------------------------------------------------

function PlayerJournalModule:MigrateRelationshipData()

    local journal = GetJournal()

    journal.Players = journal.Players or {}
    journal.TotalPruned = journal.TotalPruned or 0

    for _, record in pairs(journal.Players) do
        record.stats = record.stats or {}
        record.notes = record.notes or {}
        record.tags = record.tags or {}
        record.runs = record.runs or {}
        record.timelineEvents = record.timelineEvents or {}
        record.relationships = record.relationships or {}
        record.nextNoteID = record.nextNoteID or (#record.notes + 1)
    end

    journal.SchemaVersion = 2

end

function PlayerJournalModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

    if self.RunTracking.active then
        self:ResetRunTracking()
    end

end

function PlayerJournalModule:Shutdown()

    self:Disable()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function PlayerJournalModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("PlayerJournal", "enabled") ~= false

end

-------------------------------------------------------------------------------
-- Run Tracking -- scratch state for the party's current Mythic+ attempt.
-- Reset at CHALLENGE_MODE_START, read and cleared at completion/reset.
-- Nothing here is persisted directly -- it only ever feeds each roster
-- member's PlayerRecord in FinalizeCompletedRunForRoster.
-------------------------------------------------------------------------------

function PlayerJournalModule:ResetRunTracking()

    self.RunTracking =
    {
        active = false,
        roster = {},        -- [guid] = { name=, realm=, key=, classFile=, role= }
        deathsByGUID = {},
        interruptsByGUID = {},
        missingSince = {},   -- [guid] = timestamp, cleared if the player reappears
        leftEarly = {},      -- [guid] = true once a grace-period recheck confirms a real departure
        historyBaselineCaptured = false,
        historyBaselineRunID = nil,
    }

end

-------------------------------------------------------------------------------
-- Run Tracking Events -- registered only between CHALLENGE_MODE_START and
-- the run ending, mirroring MythicPlusModule's own
-- RegisterRunTrackingEvents/UnregisterRunTrackingEvents pattern (same
-- shape, independent state -- this module tracks different facts about
-- the same run). COMBAT_LOG_EVENT_UNFILTERED is registered defensively
-- (pcall), matching MythicPlusModule's own established precedent for
-- this exact event.
-------------------------------------------------------------------------------

function PlayerJournalModule:RegisterRunTrackingEvents()

    AC.Events:Register("GROUP_ROSTER_UPDATE", self)

    local ok, err = pcall(AC.Events.Register, AC.Events, "COMBAT_LOG_EVENT_UNFILTERED", self)

    if not ok and AC.Logger then
        AC.Logger:Error(("PlayerJournalModule failed to register COMBAT_LOG_EVENT_UNFILTERED: %s"):format(tostring(err)))
    end

end

function PlayerJournalModule:UnregisterRunTrackingEvents()

    AC.Events:Unregister("GROUP_ROSTER_UPDATE", self)
    AC.Events:Unregister("COMBAT_LOG_EVENT_UNFILTERED", self)

end

-------------------------------------------------------------------------------
-- Roster Snapshot
-------------------------------------------------------------------------------

function PlayerJournalModule:SnapshotRoster()

    local roster = {}

    for _, unit in ipairs(PARTY_UNITS) do

        if UnitExists(unit) then

            local name, realm = UnitFullName(unit)
            local key = MakePlayerKey(name, realm)

            if key then

                local guid = UnitGUID(unit)
                local _, classFile = UnitClass(unit)
                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)

                if guid then

                    roster[guid] =
                    {
                        name = name,
                        realm = (realm and realm ~= "") and realm or (GetRealmName and GetRealmName()) or "",
                        key = key,
                        classFile = classFile or "",
                        role = role or "NONE",
                    }

                end

            end

        end

    end

    return roster

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function PlayerJournalModule:OnChallengeModeStart()

    if not self:IsModuleEnabled() then
        return
    end

    self:ResetRunTracking()
    self.RunTracking.active = true
    self.RunTracking.roster = self:SnapshotRoster()

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")

    if mythicPlusModule and mythicPlusModule.GetRecentRuns then

        local previousRun = mythicPlusModule:GetRecentRuns(1)[1]

        self.RunTracking.historyBaselineCaptured = true
        self.RunTracking.historyBaselineRunID = previousRun and previousRun.ID or nil

    end

    self:RegisterRunTrackingEvents()

end

-- Grace-period leave detection: a roster GUID missing from the party is
-- marked with a timestamp, then rechecked after a short delay -- still
-- missing and the run is still active means a real departure; reappearing
-- (a disconnect/reconnect, a brief instance-group hiccup) clears the
-- mark. This heuristic is not a documented Blizzard behavior -- flagged
-- as Needs Live Verification (see VerificationService's
-- pj.rosterLeaveDetection entry).
function PlayerJournalModule:OnGroupRosterUpdate()

    if not self.RunTracking.active then
        return
    end

    local currentRoster = self:SnapshotRoster()

    for guid in pairs(self.RunTracking.roster) do

        if not currentRoster[guid] then

            if not self.RunTracking.missingSince[guid] then

                self.RunTracking.missingSince[guid] = time()

                local recheckGUID = guid

                C_Timer.After(ROSTER_LEAVE_GRACE_SECONDS, function()

                    if not self.RunTracking.active then
                        return
                    end

                    local stillMissing = self.RunTracking.missingSince[recheckGUID]

                    if stillMissing then
                        self.RunTracking.leftEarly[recheckGUID] = true
                    end

                end)

            end

        else
            self.RunTracking.missingSince[guid] = nil
        end

    end

end

-- Filtered to exactly two sub-events (UNIT_DIED, SPELL_INTERRUPT), roster
-- members only -- not a general combat log parser, mirroring the same
-- restraint MythicPlusModule's own player-only SPELL_INTERRUPT filtering
-- already established (this is the same event, just also checking
-- roster GUIDs instead of only the player's own).
function PlayerJournalModule:OnCombatLogEventUnfiltered()

    if not self.RunTracking.active then
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

    if subEvent == "UNIT_DIED" and self.RunTracking.roster[destGUID] then
        self.RunTracking.deathsByGUID[destGUID] = (self.RunTracking.deathsByGUID[destGUID] or 0) + 1
    elseif subEvent == "SPELL_INTERRUPT" and self.RunTracking.roster[sourceGUID] then
        self.RunTracking.interruptsByGUID[sourceGUID] = (self.RunTracking.interruptsByGUID[sourceGUID] or 0) + 1
    end

end

function PlayerJournalModule:OnChallengeModeReset()

    -- Mirrors MythicPlusModule's own OnChallengeModeReset restraint --
    -- CHALLENGE_MODE_RESET's exact semantics (deliberate reset vs.
    -- mid-run abandonment) aren't confidently distinguishable from this
    -- event alone, so no run record is finalized on a guess. Just stop
    -- tracking so stale roster state never leaks into whatever happens
    -- next.
    if self.RunTracking.active then
        self:UnregisterRunTrackingEvents()
        self:ResetRunTracking()
    end

end

-- CHAT_MSG_WHISPER_INFORM is the outgoing-whisper event. Incoming
-- CHAT_MSG_WHISPER is deliberately not registered: unsolicited messages do
-- not qualify a player for persistence.
function PlayerJournalModule:OnChatMsgWhisperInform(_, target)

    if not self:IsModuleEnabled() or type(target) ~= "string" or target == "" then
        return
    end

    local name, realm = strmatch(target, "^([^%-]+)%-(.+)$")

    if not name then
        name = target
        realm = (GetRealmName and GetRealmName()) or ""
    end

    local key = MakePlayerKey(name, realm)

    if key then
        self:RecordRelationship(
            { key = key, name = name, realm = realm, classFile = "" },
            self.RelationshipTypes.Whisper,
            { timestamp = time(), count = 1 })
    end

end

function PlayerJournalModule:OnChallengeModeCompleted()

    if not self.RunTracking.active then
        return
    end

    -- Snapshot this module's OWN state immediately (always safe -- it's
    -- our own data), then defer the READ of MythicPlusModule's just-
    -- recorded run to next frame. EventManager dispatches listeners for
    -- the same event in registration order, which is a function of .toc
    -- load order -- relying on "MythicPlusModule's handler happens to run
    -- first" would be exactly the kind of silent, breakable coupling this
    -- addon's architecture doc warns against. A timer (even 0-delay) only
    -- ever fires on OnUpdate, strictly after the current frame's full
    -- event-dispatch loop has completed, so by the time this runs,
    -- MythicPlusModule:RecordCompletedRun() has already appended its
    -- ActivityHistoryService record regardless of registration order.
    -- Flagged as Needs Live Verification (pj.eventOrderingDefer) since
    -- this timing assumption, while standard, hasn't been watched happen
    -- in a real client.
    local snapshot = self.RunTracking

    self:UnregisterRunTrackingEvents()
    self:ResetRunTracking()

    C_Timer.After(0, function()
        self:FinalizeCompletedRunForRoster(snapshot)
    end)

end

-------------------------------------------------------------------------------
-- Finalize Completed Run
--
-- Reads MythicPlusModule's own already-recorded run for dungeon/level/
-- timed/rating-change (Architectural Rule 7 -- never duplicate logic the
-- owning module already provides) rather than recomputing any of it. The
-- record is accepted only when its ActivityHistory ID differs from the
-- latest run captured at CHALLENGE_MODE_START, proving that this run
-- produced a new stored completion instead of reusing the previous one.
-- "Average Rating Gain" is this run's overall score change applied
-- identically to every companion who was present -- no Blizzard API
-- attributes rating gain per party member, so this is a documented
-- approximation, not a per-player fact.
-------------------------------------------------------------------------------

function PlayerJournalModule:FinalizeCompletedRunForRoster(snapshot)

    if not snapshot or not snapshot.roster or next(snapshot.roster) == nil then
        return
    end

    if not snapshot.historyBaselineCaptured then
        return
    end

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local lastRun = mythicPlusModule and mythicPlusModule.GetRecentRuns and mythicPlusModule:GetRecentRuns(1)[1]

    if not lastRun
            or type(lastRun.ID) ~= "string"
            or lastRun.ID == ""
            or lastRun.ID == snapshot.historyBaselineRunID then
        return
    end

    local now = time()
    local rosterKeys = {}

    for guid, identity in pairs(snapshot.roster) do

        local record = self:RecordRelationship(identity, self.RelationshipTypes.MythicPlus,
        {
            timestamp = now,
            count = 1,
        })

        if record then

            record.lastSeen = now
            record.class = identity.classFile
            record.realm = identity.realm

            local stats = record.stats
            local leftEarly = snapshot.leftEarly[guid] == true

            stats.runsTogether = stats.runsTogether + 1

            if leftEarly then
                stats.runsLeftEarly = stats.runsLeftEarly + 1
            elseif lastRun then

                stats.runsCompleted = stats.runsCompleted + 1

                if lastRun.Success then
                    stats.runsTimed = stats.runsTimed + 1
                end

                stats.totalRatingGainSum = stats.totalRatingGainSum + ((lastRun.Data and lastRun.Data.scoreChange) or 0)

                local dungeonID = lastRun.Data and lastRun.Data.dungeonID

                if dungeonID then
                    stats.dungeonCounts[dungeonID] = (stats.dungeonCounts[dungeonID] or 0) + 1
                end

            end

            local deaths = snapshot.deathsByGUID[guid] or 0
            stats.totalDeaths = stats.totalDeaths + deaths

            local interrupts = snapshot.interruptsByGUID[guid] or 0
            stats.totalInterrupts = stats.totalInterrupts + interrupts

            local role = identity.role

            if role and stats.roleCounts[role] ~= nil then
                stats.roleCounts[role] = stats.roleCounts[role] + 1
            end

            table.insert(record.runs,
            {
                runID = lastRun and lastRun.ID or nil,
                timestamp = now,
                dungeonID = lastRun and lastRun.Data and lastRun.Data.dungeonID or nil,
                dungeonName = lastRun and lastRun.ActivityName or "",
                level = lastRun and lastRun.Data and lastRun.Data.level or 0,
                timed = lastRun and lastRun.Success or false,
                leftEarly = leftEarly,
                role = role or "NONE",
                deaths = deaths,
                interrupts = interrupts,
                ratingGain = lastRun and lastRun.Data and lastRun.Data.scoreChange or 0,
            })

            self:PushTimelineEvent(record, "run",
            {
                dungeonName = lastRun and lastRun.ActivityName or "",
                level = lastRun and lastRun.Data and lastRun.Data.level or 0,
                timed = lastRun and lastRun.Success or false,
                leftEarly = leftEarly,
            })

            table.insert(rosterKeys, identity.key)

        end

    end

    self.LastRunRosterKeys = rosterKeys

    self:PruneIfNeeded()

    -- Fires a framework event rather than calling StaticPopup_Show
    -- directly -- the same "module/service fires, UI listens" split
    -- NotificationService's own NOTIFICATION_CHANGED already established
    -- (Core/UI/PlayerJournalWindow.lua is the intended listener). This
    -- module never touches presentation directly.
    if AC.ConfigurationManager:GetValue("PlayerJournal", "enableEndOfRunPrompt") and #rosterKeys > 0 and AC.Events then
        AC.Events:Fire("PLAYER_JOURNAL_RUN_RECORDED", rosterKeys)
    end

end

-------------------------------------------------------------------------------
-- Timeline
-------------------------------------------------------------------------------

function PlayerJournalModule:PushTimelineEvent(record, eventType, data)

    table.insert(record.timelineEvents, { type = eventType, timestamp = time(), data = data or {} })

    local overflow = #record.timelineEvents - MAX_TIMELINE_EVENTS

    for _ = 1, overflow do
        table.remove(record.timelineEvents, 1)
    end

end

-------------------------------------------------------------------------------
-- Player Records
-------------------------------------------------------------------------------

-- Private storage constructor. RecordRelationship below is the only public
-- qualification boundary; presentation code cannot create records directly.
local function GetOrCreatePlayerRecord(self, identity)

    local journal = GetJournal()
    local record = journal.Players[identity.key]

    if not record then

        record =
        {
            name = identity.name,
            realm = identity.realm,
            class = identity.classFile,
            faction = "",
            guild = "",
            firstSeen = time(),
            lastSeen = time(),
            stats =
            {
                runsTogether = 0, runsCompleted = 0, runsTimed = 0, runsLeftEarly = 0,
                totalDeaths = 0, totalInterrupts = 0, totalRatingGainSum = 0,
                dungeonCounts = {}, roleCounts = { TANK = 0, HEALER = 0, DAMAGER = 0 },
            },
            notes = {},
            tags = {},
            relationships = {},
            runs = {},
            timelineEvents = {},
            nextNoteID = 1,

            -- Set only via the context menu's "Hide Observations"
            -- checkbox (Core/UI/PlayerJournalContextMenu.lua) -- read by
            -- the Community Observations tab (Core/UI/PlayerJournal/Tabs/
            -- CommunityObservations.lua) to skip rendering that player's
            -- observations. A per-viewer preference, not a moderation
            -- action -- it never affects what CommunityModule itself
            -- stores or what any other account would see from a real
            -- sync backend. Field name kept as hideCommunityNotes (an
            -- internal, never-displayed identifier) rather than renamed
            -- to match Community Observations Phase 1's terminology --
            -- renaming it would need its own PlayerJournal schema
            -- migration, unrelated to Community's own.
            hideCommunityNotes = false,
        }

        journal.Players[identity.key] = record

        self:PushTimelineEvent(record, "met", {})

    end

    return record

end

-- The only supported entry point for a new qualifying relationship. It
-- deliberately stores no arbitrary evidence payload: detailed run, note,
-- tag, and observation facts remain with their existing owners. The bounded
-- summary answers only what relationship exists, how often it was recorded,
-- and when it was first/last meaningful.
function PlayerJournalModule:RecordRelationship(identity, relationshipType, evidence)

    if type(identity) ~= "table" or type(identity.key) ~= "string" or identity.key == "" then
        return nil
    end

    local definition = RELATIONSHIP_DEFINITIONS[relationshipType]

    if not definition then
        return nil
    end

    local record = GetOrCreatePlayerRecord(self, identity)

    if not record then
        return nil
    end

    record.relationships = record.relationships or {}

    record.name = identity.name or record.name
    record.realm = identity.realm or record.realm

    if identity.classFile and identity.classFile ~= "" then
        record.class = identity.classFile
    end

    evidence = type(evidence) == "table" and evidence or {}

    local occurredAt = tonumber(evidence.timestamp) or time()
    record.lastSeen = math.max(tonumber(record.lastSeen) or occurredAt, occurredAt)

    if definition.persistSummary then
        local increment = math.max(tonumber(evidence.count) or 1, 1)
        local relationship = record.relationships[relationshipType]

        if not relationship then

            relationship =
            {
                count = 0,
                firstAt = occurredAt,
                lastAt = occurredAt,
            }

            record.relationships[relationshipType] = relationship

        end

        relationship.count = (tonumber(relationship.count) or 0) + increment
        relationship.firstAt = math.min(tonumber(relationship.firstAt) or occurredAt, occurredAt)
        relationship.lastAt = math.max(tonumber(relationship.lastAt) or occurredAt, occurredAt)

    end

    return record

end

-------------------------------------------------------------------------------
-- Relationship Projection
--
-- Normalizes stored summaries and derived facts without copying Favorite,
-- Notes, Mythic+ runs, tags, or Community observations into another store.
-------------------------------------------------------------------------------

local function AddProjectedRelationship(results, relationshipType, count, firstAt, lastAt, source)

    table.insert(results,
    {
        type = relationshipType,
        count = tonumber(count) or 1,
        firstAt = tonumber(firstAt),
        lastAt = tonumber(lastAt),
        source = source,
        priority = RELATIONSHIP_PRIORITY[relationshipType] or 0,
    })

end

function PlayerJournalModule:GetRelationships(playerKey)

    local record = self:GetPlayerRecord(playerKey)

    if not record then
        return {}
    end

    local results = {}
    local tags = record.tags or {}
    local notes = record.notes or {}
    local runs = record.runs or {}

    if tags.FavoritePlayer then
        AddProjectedRelationship(results, self.RelationshipTypes.Favorite, 1, nil, nil, "tags")
    end

    if #notes > 0 then
        AddProjectedRelationship(results, self.RelationshipTypes.PersonalNote, #notes,
            notes[1] and notes[1].timestamp, notes[#notes] and notes[#notes].timestamp, "notes")
    end

    local personalTagCount = 0

    for tagID, enabled in pairs(tags) do
        if enabled and tagID ~= "FavoritePlayer" then
            personalTagCount = personalTagCount + 1
        end
    end

    if personalTagCount > 0 then
        AddProjectedRelationship(results, self.RelationshipTypes.PersonalTag, personalTagCount, nil, nil, "tags")
    end

    local runCount = #runs > 0 and #runs or tonumber(record.stats and record.stats.runsTogether) or 0

    if runCount > 0 then
        AddProjectedRelationship(results, self.RelationshipTypes.MythicPlus, runCount,
            runs[1] and runs[1].timestamp or record.firstSeen,
            runs[#runs] and runs[#runs].timestamp or record.lastSeen, #runs > 0 and "runs" or "stats")
    end

    local communityModule = AC.Core and AC.Core:GetModule("Community")
    local observations = communityModule and communityModule.GetObservationsForPlayer
        and communityModule:GetObservationsForPlayer(playerKey) or {}

    if #observations > 0 then
        AddProjectedRelationship(results, self.RelationshipTypes.CommunityObservation, #observations,
            observations[1] and observations[1].createdDate,
            observations[#observations] and observations[#observations].createdDate, "community")
    end

    for relationshipType, summary in pairs(record.relationships or {}) do
        if relationshipType ~= self.RelationshipTypes.MythicPlus
        and RELATIONSHIP_DEFINITIONS[relationshipType]
        and RELATIONSHIP_DEFINITIONS[relationshipType].persistSummary then
            AddProjectedRelationship(results, relationshipType, summary.count,
                summary.firstAt, summary.lastAt, "relationships")
        end
    end

    if #results == 0 then
        AddProjectedRelationship(results, "Legacy", 1, record.firstSeen, record.lastSeen, "legacy")
    end

    table.sort(results, function(a, b)
        if a.priority == b.priority then
            return (a.lastAt or 0) > (b.lastAt or 0)
        end
        return a.priority > b.priority
    end)

    return results

end

function PlayerJournalModule:HasRelationship(playerKey, relationshipType)

    for _, relationship in ipairs(self:GetRelationships(playerKey)) do
        if relationship.type == relationshipType then
            return true
        end
    end

    return false

end

function PlayerJournalModule:GetAvailableRelationshipTypes()

    local available = {}

    for playerKey in pairs(GetJournal().Players) do
        for _, relationship in ipairs(self:GetRelationships(playerKey)) do
            if relationship.type ~= "Legacy" then
                available[relationship.type] = true
            end
        end
    end

    return available

end

function PlayerJournalModule:GetIncidentalPlayerKeys()

    local incidental = {}

    for playerKey in pairs(GetJournal().Players) do
        local relationships = self:GetRelationships(playerKey)

        if #relationships == 1 and relationships[1].type == "Legacy" then
            table.insert(incidental, playerKey)
        end
    end

    return incidental

end

-------------------------------------------------------------------------------
-- Public API -- Records / Stats
-------------------------------------------------------------------------------

function PlayerJournalModule:GetPlayerRecord(playerKey)

    if not playerKey then
        return nil
    end

    return GetJournal().Players[playerKey]

end

function PlayerJournalModule:GetAllPlayerKeys()

    local keys = {}

    for key in pairs(GetJournal().Players) do
        table.insert(keys, key)
    end

    return keys

end

-- Best-effort dungeon name lookup for "Most Played Dungeon Together" --
-- reads whichever dungeonID appears most often in this record's own
-- dungeonCounts, resolved to a display name via MythicPlusModule's
-- public GetDungeonName (never re-implemented here).
function PlayerJournalModule:GetPlayerStatsSummary(playerKey)

    local record = self:GetPlayerRecord(playerKey)

    if not record then
        return nil
    end

    local stats = record.stats
    local averageDeaths = stats.runsTogether > 0 and (stats.totalDeaths / stats.runsTogether) or 0
    local averageRatingGain = stats.runsCompleted > 0 and (stats.totalRatingGainSum / stats.runsCompleted) or 0
    local totalInterrupts = stats.totalInterrupts or 0

    local favoriteDungeonID, favoriteDungeonCount = nil, 0

    for dungeonID, count in pairs(stats.dungeonCounts) do
        if count > favoriteDungeonCount then
            favoriteDungeonID, favoriteDungeonCount = dungeonID, count
        end
    end

    local favoriteDungeonName = nil

    if favoriteDungeonID then

        local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
        favoriteDungeonName = mythicPlusModule and mythicPlusModule.GetDungeonName and mythicPlusModule:GetDungeonName(favoriteDungeonID)

    end

    local favoriteRole, favoriteRoleCount = nil, 0

    for role, count in pairs(stats.roleCounts) do
        if count > favoriteRoleCount then
            favoriteRole, favoriteRoleCount = role, count
        end
    end

    return
    {
        runsTogether = stats.runsTogether,
        runsCompleted = stats.runsCompleted,
        runsTimed = stats.runsTimed,
        runsLeftEarly = stats.runsLeftEarly,
        averageDeaths = averageDeaths,
        averageRatingGain = averageRatingGain,
        totalInterrupts = totalInterrupts,
        favoriteDungeonName = favoriteDungeonName,
        favoriteRole = favoriteRole,
    }

end

-------------------------------------------------------------------------------
-- Public API -- Notes
-------------------------------------------------------------------------------

function PlayerJournalModule:AddNote(playerKey, text)

    local record = self:GetPlayerRecord(playerKey)

    if not record or not text or text == "" then
        return nil
    end

    local note = { id = record.nextNoteID, timestamp = time(), editedTimestamp = nil, text = text }

    record.nextNoteID = record.nextNoteID + 1
    table.insert(record.notes, note)

    self:PushTimelineEvent(record, "note", {})

    return note

end

function PlayerJournalModule:EditNote(playerKey, noteID, text)

    local record = self:GetPlayerRecord(playerKey)

    if not record or not text or text == "" then
        return false
    end

    for _, note in ipairs(record.notes) do

        if note.id == noteID then
            note.text = text
            note.editedTimestamp = time()
            return true
        end

    end

    return false

end

function PlayerJournalModule:DeleteNote(playerKey, noteID)

    local record = self:GetPlayerRecord(playerKey)

    if not record then
        return false
    end

    for index, note in ipairs(record.notes) do

        if note.id == noteID then
            table.remove(record.notes, index)
            return true
        end

    end

    return false

end

-------------------------------------------------------------------------------
-- Public API -- Tags / Favorite
--
-- "Favorite Player" is one of these tags, not a separate boolean --
-- IsFavorite reads the exact same map ToggleTag writes to, so the
-- context-menu checkbox, tooltip glyph, and Personal Tags tab can never
-- desync from each other.
-------------------------------------------------------------------------------

function PlayerJournalModule:ToggleTag(playerKey, tagID)

    local record = self:GetPlayerRecord(playerKey)

    if not record then
        return false
    end

    local nowSet = not record.tags[tagID]
    record.tags[tagID] = nowSet or nil

    self:PushTimelineEvent(record, "tag", { tagID = tagID, added = nowSet })

    return nowSet

end

function PlayerJournalModule:IsFavorite(playerKey)

    local record = self:GetPlayerRecord(playerKey)

    return record ~= nil and record.tags["FavoritePlayer"] == true

end

-------------------------------------------------------------------------------
-- Public API -- Search
-------------------------------------------------------------------------------

function PlayerJournalModule:SearchPlayers(query, filters)

    filters = filters or {}
    query = query and query:lower() or nil

    local results = {}

    for key, record in pairs(GetJournal().Players) do

        local matches = true

        if query and query ~= "" then

            local haystack = (record.name .. " " .. record.realm .. " " .. record.guild):lower()
            matches = haystack:find(query, 1, true) ~= nil

        end

        if matches and filters.favoritesOnly and not record.tags["FavoritePlayer"] then
            matches = false
        end

        if matches and filters.tagID and not record.tags[filters.tagID] then
            matches = false
        end

        if matches then
            table.insert(results, key)
        end

    end

    table.sort(results, function(a, b)

        local recordA = GetJournal().Players[a]
        local recordB = GetJournal().Players[b]

        return (recordA.lastSeen or 0) > (recordB.lastSeen or 0)

    end)

    return results

end

-------------------------------------------------------------------------------
-- Public API -- Companion Intelligence vNext
--
-- Real, personal facts this module already owns, exposed for the first
-- time to RecommendationEngine/BriefingService -- display/evidence only,
-- never a new judgment computed on their behalf (Rule 6).
-------------------------------------------------------------------------------

-- "A pattern, not a data point" -- same discipline as MythicPlusModule's
-- WEAKEST_DUNGEON_MIN_SAMPLES: one shared run with someone isn't a
-- "frequent companion."
local MIN_RUNS_TOGETHER_FOR_FREQUENT = 5

-- The player you've most often run Mythic+ with, gated on a real minimum
-- sample size -- nil if nobody clears that bar yet.
function PlayerJournalModule:GetMostFrequentCompanion()

    local journal = GetJournal()
    local bestKey, bestRecord, bestCount = nil, nil, MIN_RUNS_TOGETHER_FOR_FREQUENT - 1

    for key, record in pairs(journal.Players) do

        local runsTogether = record.stats.runsTogether or 0

        if runsTogether > bestCount then
            bestKey, bestRecord, bestCount = key, record, runsTogether
        end

    end

    if not bestRecord then
        return nil
    end

    return { key = bestKey, name = bestRecord.name, runsTogether = bestCount }

end

-- Favorites (only) whose lastSeen is older than thresholdDays -- sorted
-- stalest-first, so a caller that only wants "the one most worth
-- surfacing" can just take the first entry. Never scans non-Favorites --
-- "haven't played with this player in a while" is only meaningful praise/
-- nudge for someone the player already marked as worth remembering.
local STALE_FAVORITE_THRESHOLD_DAYS = 42

function PlayerJournalModule:GetStaleFavorites(thresholdDays)

    thresholdDays = tonumber(thresholdDays) or STALE_FAVORITE_THRESHOLD_DAYS

    local journal = GetJournal()
    local cutoff = time() - (thresholdDays * 86400)
    local stale = {}

    for key, record in pairs(journal.Players) do

        if record.tags["FavoritePlayer"] and (record.lastSeen or 0) < cutoff then
            table.insert(stale, { key = key, name = record.name, lastSeen = record.lastSeen or 0 })
        end

    end

    table.sort(stale, function(a, b)
        return a.lastSeen < b.lastSeen
    end)

    return stale

end

-- Journal records for whoever is CURRENTLY in the player's party --
-- reuses SnapshotRoster (already used for run tracking, safe to call
-- anytime -- it has no dependency on RunTracking state) rather than a new
-- Blizzard read of its own. Players with no journal record are omitted
-- entirely, never fabricated.
function PlayerJournalModule:GetCurrentPartyJournalMatches()

    local roster = self:SnapshotRoster()
    local matches = {}

    for _, identity in pairs(roster) do

        local record = self:GetPlayerRecord(identity.key)

        if record then

            table.insert(matches,
            {
                key = identity.key,
                name = record.name,
                isFavorite = record.tags["FavoritePlayer"] == true,
                runsTogether = record.stats.runsTogether,
                runsTimed = record.stats.runsTimed,
                lastSeen = record.lastSeen,
                noteCount = #record.notes,
            })

        end

    end

    return matches

end

-------------------------------------------------------------------------------
-- Insights (Companion Intelligence vNext)
--
-- Objective, real, gated facts only -- both insights below are omitted
-- entirely when nothing in the journal actually clears their real
-- threshold, never a fabricated "you have no companions yet" filler.
-------------------------------------------------------------------------------

function PlayerJournalModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    -- Frequent Companion In Party -- only when the player's real most-
    -- frequent companion is actually present in the current party right
    -- now (GetCurrentPartyJournalMatches), not a standing reminder every
    -- refresh regardless of who's grouped.
    local frequentCompanion = self:GetMostFrequentCompanion()

    if frequentCompanion then

        local inParty = false

        for _, match in ipairs(self:GetCurrentPartyJournalMatches()) do

            if match.key == frequentCompanion.key then
                inParty = true
                break
            end

        end

        if inParty then
            table.insert(insights,
            {
                title = "Frequent Companion In Party",
                description = string.format("You're grouped with %s again -- your most frequent Mythic+ companion (%d runs together).", frequentCompanion.name, frequentCompanion.runsTogether),
                priority = 15,
                category = "PlayerJournal",
                timestamp = time(),
                expiresAt = 0,
                dismissible = false,
                data = { playerKey = frequentCompanion.key, runsTogether = frequentCompanion.runsTogether },
            })
        end

    end

    -- Reconnect With Favorite -- the single stalest Favorite, capped at
    -- one per refresh so this never floods the list with every Favorite
    -- the player hasn't seen in a while.
    local staleFavorites = self:GetStaleFavorites()

    if #staleFavorites > 0 then

        local stalest = staleFavorites[1]
        local daysSince = math.floor((time() - stalest.lastSeen) / 86400)

        table.insert(insights,
        {
            title = "Reconnect With Favorite",
            description = string.format("You haven't grouped with %s, a Favorite, in %d days.", stalest.name, daysSince),
            priority = 12,
            category = "PlayerJournal",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { playerKey = stalest.key, daysSince = daysSince },
        })

    end

    return insights

end

-------------------------------------------------------------------------------
-- Pruning
--
-- Favorites are exempt from both the hard cap and inactivity pruning --
-- the one thing the feature's own spec explicitly calls out as
-- protected. TotalPruned is a lifetime counter (Developer Panel's
-- "Pruned Entries"), never reset by an individual prune pass.
-------------------------------------------------------------------------------

function PlayerJournalModule:PruneIfNeeded()

    local journal = GetJournal()
    local maxStored = tonumber(AC.ConfigurationManager:GetValue("PlayerJournal", "maximumStoredPlayers")) or 250
    local autoPruneInactive = AC.ConfigurationManager:GetValue("PlayerJournal", "autoPruneInactive")
    local inactiveDays = tonumber(AC.ConfigurationManager:GetValue("PlayerJournal", "autoPruneInactiveDays")) or 90

    local candidates = {}

    for key, record in pairs(journal.Players) do

        if not record.tags["FavoritePlayer"] then
            table.insert(candidates, key)
        end

    end

    if autoPruneInactive then

        local cutoff = time() - (inactiveDays * 86400)

        for _, key in ipairs(candidates) do

            local record = journal.Players[key]

            if record and (record.lastSeen or 0) < cutoff then
                journal.Players[key] = nil
                journal.TotalPruned = journal.TotalPruned + 1
            end

        end

    end

    -- Hard cap: oldest-by-lastSeen non-Favorite entries first.
    local remaining = {}

    for key in pairs(journal.Players) do
        table.insert(remaining, key)
    end

    if #remaining > maxStored then

        table.sort(remaining, function(a, b)
            return (journal.Players[a].lastSeen or 0) < (journal.Players[b].lastSeen or 0)
        end)

        local overflow = #remaining - maxStored

        for i = 1, overflow do

            local key = remaining[i]
            local record = journal.Players[key]

            if record and not record.tags["FavoritePlayer"] then
                journal.Players[key] = nil
                journal.TotalPruned = journal.TotalPruned + 1
            end

        end

    end

end

-------------------------------------------------------------------------------
-- Developer Panel Stats
-------------------------------------------------------------------------------

function PlayerJournalModule:GetDeveloperStats()

    local journal = GetJournal()

    local storedPlayers, favoritePlayers, totalNotes = 0, 0, 0
    local oldestEntry, newestEntry = nil, nil

    for _, record in pairs(journal.Players) do

        storedPlayers = storedPlayers + 1
        totalNotes = totalNotes + #record.notes

        if record.tags["FavoritePlayer"] then
            favoritePlayers = favoritePlayers + 1
        end

        if not oldestEntry or (record.firstSeen or 0) < oldestEntry then
            oldestEntry = record.firstSeen
        end

        if not newestEntry or (record.firstSeen or 0) > newestEntry then
            newestEntry = record.firstSeen
        end

    end

    local databaseSize = 0

    if AC.DeveloperModeService and AC.DeveloperModeService.ToJSON then

        local ok, json = pcall(AC.DeveloperModeService.ToJSON, AC.DeveloperModeService, journal)

        if ok and json then
            databaseSize = #json
        end

    end

    local communityModule = AC.Core and AC.Core:GetModule("Community")
    local communityObservationCount = communityModule and communityModule.GetTotalObservationCount and communityModule:GetTotalObservationCount() or 0

    return
    {
        storedPlayers = storedPlayers,
        favoritePlayers = favoritePlayers,
        totalNotes = totalNotes,
        communityObservations = communityObservationCount,
        oldestEntry = oldestEntry,
        newestEntry = newestEntry,
        databaseSize = databaseSize,
        prunedEntries = journal.TotalPruned or 0,
    }

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("PlayerJournal", PlayerJournalModule)

return PlayerJournalModule
