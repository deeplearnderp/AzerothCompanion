-------------------------------------------------------------------------------
-- Azeroth Companion
-- Activity History Service
--
-- The long-term historical memory of Azeroth Companion. Gameplay modules
-- publish completed activity records here; this service owns storage,
-- persistence, indexing, retrieval, and pruning only -- it never
-- generates statistics, gameplay logic, Insights, or Recommendations,
-- and it never inspects or validates the module-owned "Data" payload of
-- a record.
--
-- Bounded, not literally permanent: each module's records are capped at
-- MAX_RECORDS_PER_MODULE, with the oldest trimmed once a module exceeds
-- it, so history stays useful across months/years of play without
-- growing SavedVariables forever.
--
-- Persistence: DatabaseService:GetCharacter().ActivityHistory. This is
-- deliberately NOT a ConfigurationManager profile -- profiles can be
-- shared across characters, and activity history must never be shared
-- that way. No new SavedVariables table is created; DatabaseService
-- remains the only persistence layer.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time
local date = date
local tinsert = table.insert
local tremove = table.remove

local ActivityHistoryService =
{
    Name = "ActivityHistoryService",
}

AC.ActivityHistoryService = ActivityHistoryService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local ENVELOPE_VERSION = 1

-- Pruning -- oldest records for a module are trimmed once that module
-- exceeds this many records, so history stays bounded across months and
-- years of play instead of growing forever. Per-module rather than a
-- single global cap, so one high-volume module (many M+ runs) can never
-- crowd out a lower-volume one's history. 500 is a deliberately generous
-- number for MythicPlus specifically -- even a very active pusher (5-10
-- keys/week) takes roughly a year or more to reach it -- while still
-- being a real, enforced bound rather than "unlimited."
local MAX_RECORDS_PER_MODULE = 500

-- Every field an ActivityRecord envelope must have before Append() will
-- accept it. ID/Timestamp/Version are filled in by Append() itself if
-- absent; every other field must already be present on the record the
-- calling module supplies. "Data" is checked for presence and that it is
-- a table -- its contents are never inspected.
local REQUIRED_FIELDS =
{
    "ID", "Version", "Timestamp", "Character", "Realm", "Module",
    "ActivityType", "ActivityName", "Difficulty", "Expansion",
    "Started", "Ended", "Completed", "Success", "Data",
}

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function ActivityHistoryService:Initialize()

    self.Sequence = 0
    self.Records = nil
    self.IndexByType = {}
    self.IndexByDate = {}

    local databaseService = AC.DatabaseService

    if not databaseService then

        if AC.Logger then
            AC.Logger:Error("ActivityHistoryService: DatabaseService is not available.")
        end

        self.Records = {}

        return

    end

    local character = databaseService:GetCharacter()

    if not character then

        if AC.Logger then
            AC.Logger:Error("ActivityHistoryService: DatabaseService character record is not available.")
        end

        self.Records = {}

        return

    end

    -- If ActivityHistory does not exist for this character yet, create it.
    -- This is the only "migration" this service performs, and it does not
    -- modify DatabaseService itself.
    if type(character.ActivityHistory) ~= "table" then
        character.ActivityHistory = {}
    end

    self.Records = character.ActivityHistory

    self:RebuildIndexes()

    if AC.Logger then
        AC.Logger:Info(string.format("ActivityHistoryService initialized (%d records loaded).", #self.Records))
    end

end

-------------------------------------------------------------------------------
-- Indexing (in-memory only -- never persisted, rebuilt every Initialize())
-------------------------------------------------------------------------------

function ActivityHistoryService:RebuildIndexes()

    self.IndexByType = {}
    self.IndexByDate = {}

    if not self.Records then
        return
    end

    for i = 1, #self.Records do
        self:IndexRecord(self.Records[i])
    end

end

function ActivityHistoryService:IndexRecord(record)

    local activityType = record.ActivityType or "Unknown"

    self.IndexByType[activityType] = self.IndexByType[activityType] or {}
    tinsert(self.IndexByType[activityType], record)

    local dateKey = date("%Y-%m-%d", record.Timestamp or time())

    self.IndexByDate[dateKey] = self.IndexByDate[dateKey] or {}
    tinsert(self.IndexByDate[dateKey], record)

end

-------------------------------------------------------------------------------
-- ID Generation
-------------------------------------------------------------------------------

function ActivityHistoryService:GenerateID()

    self.Sequence = (self.Sequence or 0) + 1

    local characterKey = "Unknown"

    if AC.DatabaseService then
        characterKey = AC.DatabaseService:GetCharacterKey() or characterKey
    end

    return string.format("%s-%d-%d", characterKey, time(), self.Sequence)

end

-------------------------------------------------------------------------------
-- Envelope Validation
--
-- Validates only the envelope fields listed in REQUIRED_FIELDS. "Data" is
-- checked for presence and table-ness only -- its contents belong
-- entirely to the gameplay module and are never inspected here.
-------------------------------------------------------------------------------

function ActivityHistoryService:ValidateEnvelope(record)

    for i = 1, #REQUIRED_FIELDS do

        local field = REQUIRED_FIELDS[i]

        if record[field] == nil then
            return false, string.format("missing envelope field '%s'", field)
        end

    end

    if type(record.Data) ~= "table" then
        return false, "'Data' must be a table"
    end

    return true

end

-------------------------------------------------------------------------------
-- Append
--
-- The only write path. Assigns ID/Timestamp/Version if absent, validates
-- the envelope, appends to history, updates indexes, prunes that
-- module's oldest records if it's now over MAX_RECORDS_PER_MODULE, and
-- returns the stored record. Existing records are never modified in
-- place -- pruning only ever removes the oldest whole records for the
-- module that just grew, never edits one.
-------------------------------------------------------------------------------

function ActivityHistoryService:Append(record)

    if type(record) ~= "table" then

        if AC.Logger then
            AC.Logger:Error("ActivityHistoryService:Append() requires a table.")
        end

        return nil

    end

    if not self.Records then

        if AC.Logger then
            AC.Logger:Error("ActivityHistoryService:Append() called before Initialize() completed successfully.")
        end

        return nil

    end

    record.ID = record.ID or self:GenerateID()
    record.Timestamp = record.Timestamp or time()
    record.Version = record.Version or ENVELOPE_VERSION

    local isValid, reason = self:ValidateEnvelope(record)

    if not isValid then

        if AC.Logger then
            AC.Logger:Error(string.format("ActivityHistoryService:Append() rejected record: %s", reason))
        end

        return nil

    end

    tinsert(self.Records, record)
    self:IndexRecord(record)
    self:PruneModule(record.Module)

    return record

end

-------------------------------------------------------------------------------
-- Prune Module
--
-- Trims the oldest records for one module once it exceeds
-- MAX_RECORDS_PER_MODULE. A linear scan/removal, but only ever runs once
-- every MAX_RECORDS_PER_MODULE appends for a given module (i.e. rarely),
-- so the cost is negligible against how infrequently it triggers.
-------------------------------------------------------------------------------

function ActivityHistoryService:PruneModule(moduleName)

    if not self.Records or type(moduleName) ~= "string" or moduleName == "" then
        return
    end

    local count = 0

    for i = 1, #self.Records do

        if self.Records[i].Module == moduleName then
            count = count + 1
        end

    end

    local excess = count - MAX_RECORDS_PER_MODULE

    if excess <= 0 then
        return
    end

    local removed = 0
    local i = 1

    while removed < excess and i <= #self.Records do

        if self.Records[i].Module == moduleName then
            tremove(self.Records, i)
            removed = removed + 1
        else
            i = i + 1
        end

    end

    self:RebuildIndexes()

end

-------------------------------------------------------------------------------
-- GetActivity
-------------------------------------------------------------------------------

function ActivityHistoryService:GetActivity(id)

    if not self.Records or type(id) ~= "string" then
        return nil
    end

    for i = 1, #self.Records do

        if self.Records[i].ID == id then
            return self.Records[i]
        end

    end

    return nil

end

-------------------------------------------------------------------------------
-- GetRecent
--
-- Most recent records first. Records are always appended chronologically,
-- so the end of the array is the most recent.
-------------------------------------------------------------------------------

function ActivityHistoryService:GetRecent(count)

    local results = {}

    if not self.Records then
        return results
    end

    count = tonumber(count) or 10

    if count < 0 then
        count = 0
    end

    local total = #self.Records
    local stopAt = total - count + 1

    if stopAt < 1 then
        stopAt = 1
    end

    for i = total, stopAt, -1 do
        tinsert(results, self.Records[i])
    end

    return results

end

-------------------------------------------------------------------------------
-- GetByType
-------------------------------------------------------------------------------

function ActivityHistoryService:GetByType(activityType)

    if not self.IndexByType or type(activityType) ~= "string" then
        return {}
    end

    return self.IndexByType[activityType] or {}

end

-------------------------------------------------------------------------------
-- GetByModule
--
-- No dedicated index exists for Module (only ActivityType and Date are
-- indexed, per the approved design) -- this is a linear scan.
-------------------------------------------------------------------------------

function ActivityHistoryService:GetByModule(moduleName)

    local results = {}

    if not self.Records or type(moduleName) ~= "string" then
        return results
    end

    for i = 1, #self.Records do

        if self.Records[i].Module == moduleName then
            tinsert(results, self.Records[i])
        end

    end

    return results

end

-------------------------------------------------------------------------------
-- GetByDateRange
--
-- A linear scan over Timestamp. The Date index exists for future
-- consumers (e.g. a future StatisticsService) but this method does not
-- require it for a simple range filter.
-------------------------------------------------------------------------------

function ActivityHistoryService:GetByDateRange(startTime, endTime)

    local results = {}

    if not self.Records then
        return results
    end

    startTime = tonumber(startTime) or 0
    endTime = tonumber(endTime) or time()

    for i = 1, #self.Records do

        local record = self.Records[i]
        local timestamp = record.Timestamp or 0

        if timestamp >= startTime and timestamp <= endTime then
            tinsert(results, record)
        end

    end

    return results

end

-------------------------------------------------------------------------------
-- Count
--
-- filter is optional: { ActivityType = "...", Module = "..." }. With no
-- filter, returns the total record count.
-------------------------------------------------------------------------------

function ActivityHistoryService:Count(filter)

    if not self.Records then
        return 0
    end

    if filter == nil then
        return #self.Records
    end

    local activityType = filter.ActivityType
    local moduleName = filter.Module

    local total = 0

    for i = 1, #self.Records do

        local record = self.Records[i]
        local matches = true

        if activityType and record.ActivityType ~= activityType then
            matches = false
        end

        if matches and moduleName and record.Module ~= moduleName then
            matches = false
        end

        if matches then
            total = total + 1
        end

    end

    return total

end

-------------------------------------------------------------------------------
-- Clear All (Developer Panel -- History Inspector)
--
-- Wipes every stored record for the current character, in place (removes
-- from the same array `character.ActivityHistory` already points to,
-- rather than replacing self.Records with a new table) so persistence
-- stays correctly linked to DatabaseService's own storage. A real,
-- deliberate, player/developer-triggered action -- never called by any
-- gameplay module.
-------------------------------------------------------------------------------

function ActivityHistoryService:ClearAll()

    if not self.Records then
        return
    end

    for i = #self.Records, 1, -1 do
        tremove(self.Records, i)
    end

    self:RebuildIndexes()

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("ActivityHistoryService", ActivityHistoryService)

return ActivityHistoryService
