-------------------------------------------------------------------------------
-- Azeroth Companion
-- Activity History Service
--
-- The permanent historical memory of Azeroth Companion. Gameplay modules
-- publish completed activity records here; this service owns storage,
-- persistence, indexing, and retrieval only -- it never generates
-- statistics, gameplay logic, Insights, or Recommendations, and it never
-- inspects or validates the module-owned "Data" payload of a record.
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

local ActivityHistoryService =
{
    Name = "ActivityHistoryService",
}

AC.ActivityHistoryService = ActivityHistoryService

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local ENVELOPE_VERSION = 1

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
-- the envelope, appends to history, updates indexes, and returns the
-- stored record. History is append-only -- existing records are never
-- modified.
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

    return record

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
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("ActivityHistoryService", ActivityHistoryService)

return ActivityHistoryService
