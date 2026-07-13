-------------------------------------------------------------------------------
-- Azeroth Companion
-- Recommendation History Service
--
-- Companion Intelligence vNext. RecommendationEngine is deliberately
-- stateless -- Refresh() rebuilds self.Recommendations = {} from scratch
-- every call, by design (see that file's own header). This service is the
-- one place that remembers anything ACROSS refreshes: for each real
-- recommendation `id` (a stable, English, code-level slug -- see
-- RecommendationEngine.lua, never the localized `title`), it tracks when
-- it was first/last shown, how many distinct times it's been shown, and
-- how each showing resolved (see "Cycle" below). Rule 6 pattern: this
-- reads RecommendationEngine's already-public GetRecommendations() only
-- -- it never re-derives or judges a recommendation itself.
--
-- Persistence: DatabaseService:GetCharacter().RecommendationHistory,
-- lazily created here exactly like MilestoneService's own
-- character.Milestones -- gameplay-adjacent companion-intelligence state
-- is per-character (a recommendation's relevance -- rating, keystone,
-- vault -- is itself per-character), not a ConfigurationManager setting
-- (Rule 8/9) and not account-wide (Rule 1 -- this isn't a fact about the
-- account the way PlayerJournal is).
--
-- "Cycle" mechanics -- what lets a recommendation like "Complete Your
-- Keystone" honestly disappear and reappear across weeks (a new keystone,
-- a new dungeon) without either permanently suppressing it or inflating
-- `timesShown` every time the Dashboard window happens to redraw while
-- it's still the same ongoing situation:
--   - Each `id` maps to a fixed list of `recommendation.data` field names
--     (CYCLE_FINGERPRINT_FIELDS below) that define what makes a NEW
--     instance of that recommendation, e.g. a new dungeonID/level for
--     "Complete Your Keystone". An id with no listed fields is treated as
--     one continuous, ongoing cycle for as long as it keeps appearing.
--   - Same fingerprint seen again this refresh: only lastShown/lastScore
--     update. timesShown does NOT re-increment.
--   - A new/changed fingerprint: timesShown += 1, cycle state resets, one
--     scoreHistory sample is appended.
--   - A previously-active cycle whose id is absent this refresh has
--     resolved: if it was explicitly dismissed (dismissedThisCycle,
--     stamped at click time by DismissRecommendation), nothing further
--     happens here. Otherwise, if the Inspector was opened for it this
--     cycle (acknowledgedThisCycle, stamped by MarkAcknowledged),
--     timesCompleted increments. Otherwise timesNotAcknowledged
--     increments.
--
-- Honesty requirement carried through every UI surface reading this data
-- (Recommendation Inspector, the new Statistics page): timesCompleted/
-- timesNotAcknowledged are INFERRED from disappearance, never proof the
-- underlying gameplay action happened -- every label built from them must
-- read like "Likely Completed" / "Not Acknowledged," never a bare
-- "Completed" claim. Only timesDismissed is a certain, explicit signal
-- (the player clicked Dismiss).
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local time = time

local RecommendationHistoryService =
{
    Name = "RecommendationHistoryService",
}

AC.RecommendationHistoryService = RecommendationHistoryService

-------------------------------------------------------------------------------
-- Cycle Fingerprint Fields
--
-- A small, fixed, documented map -- same "keyed table of named exceptions"
-- convention as RecommendationEngine's own PREPARATION_INSIGHT_TITLES /
-- NotificationService's NOTIFICATION_TYPE_BY_INSIGHT_TITLE. An id not
-- listed here has no fingerprint fields, i.e. every showing of it is
-- treated as the same ongoing cycle until it stops appearing.
-------------------------------------------------------------------------------

local CYCLE_FINGERPRINT_FIELDS =
{
    CompleteYourKeystone = { "dungeonID", "level" },
    RetrieveKeystone = {},
    RestockAndPrepare = {},
}

local MAX_SCORE_HISTORY = 10

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function RecommendationHistoryService:Initialize()

    self.History = {}

    local databaseService = AC.DatabaseService

    if not databaseService then

        if AC.Logger then
            AC.Logger:Error("RecommendationHistoryService: DatabaseService is not available.")
        end

        return

    end

    local character = databaseService:GetCharacter()

    if not character then

        if AC.Logger then
            AC.Logger:Error("RecommendationHistoryService: DatabaseService character record is not available.")
        end

        return

    end

    if type(character.RecommendationHistory) ~= "table" then
        character.RecommendationHistory = {}
    end

    self.History = character.RecommendationHistory

end

function RecommendationHistoryService:Enable()

end

function RecommendationHistoryService:Disable()

end

function RecommendationHistoryService:Shutdown()

    self:Disable()

end

-------------------------------------------------------------------------------
-- Fingerprint
-------------------------------------------------------------------------------

local function BuildCycleKey(id, data)

    local fields = CYCLE_FINGERPRINT_FIELDS[id]

    if not fields or #fields == 0 then
        return id
    end

    data = data or {}

    local parts = { id }

    for _, fieldName in ipairs(fields) do
        table.insert(parts, tostring(data[fieldName]))
    end

    return table.concat(parts, ":")

end

-------------------------------------------------------------------------------
-- Refresh -- called every engine-refresh cycle, right after
-- RecommendationEngine:Refresh() (Sections.lua's RefreshEngines), so this
-- always reasons over this cycle's already-current recommendation list.
-------------------------------------------------------------------------------

function RecommendationHistoryService:Refresh()

    if not AC.RecommendationEngine then
        return
    end

    local now = time()
    local seenThisRefresh = {}

    for _, recommendation in ipairs(AC.RecommendationEngine:GetRecommendations()) do

        local id = recommendation.id

        if id then

            seenThisRefresh[id] = true

            local record = self.History[id]

            if not record then

                record =
                {
                    category = recommendation.category,
                    firstShown = now,
                    lastShown = now,
                    timesShown = 0,
                    timesCompleted = 0,
                    timesNotAcknowledged = 0,
                    timesDismissed = 0,
                    totalResolvedDurationSeconds = 0,
                    activeCycleKey = nil,
                    cycleStartedAt = nil,
                    acknowledgedThisCycle = false,
                    dismissedThisCycle = false,
                    lastResolvedAt = nil,
                    lastDismissedAt = nil,
                    lastScore = nil,
                    scoreHistory = {},
                }

                self.History[id] = record

            end

            local cycleKey = BuildCycleKey(id, recommendation.data)

            record.lastShown = now
            record.lastScore = recommendation.score

            if record.activeCycleKey ~= cycleKey then

                -- A genuinely new instance of this recommendation (or the
                -- first time it's ever been seen) -- a new counted
                -- showing, not just another refresh of an ongoing one.
                record.timesShown = record.timesShown + 1
                record.activeCycleKey = cycleKey
                record.cycleStartedAt = now
                record.acknowledgedThisCycle = false
                record.dismissedThisCycle = false

                table.insert(record.scoreHistory, { timestamp = now, score = recommendation.score })

                while #record.scoreHistory > MAX_SCORE_HISTORY do
                    table.remove(record.scoreHistory, 1)
                end

            end

        end

    end

    -- Any id with an active cycle that did NOT appear this refresh has
    -- resolved -- see this file's header for what each outcome means.
    for id, record in pairs(self.History) do

        if record.activeCycleKey and not seenThisRefresh[id] then

            if not record.dismissedThisCycle then

                if record.acknowledgedThisCycle then
                    record.timesCompleted = record.timesCompleted + 1
                    record.totalResolvedDurationSeconds = record.totalResolvedDurationSeconds + (now - (record.cycleStartedAt or now))
                    record.lastResolvedAt = now
                else
                    record.timesNotAcknowledged = record.timesNotAcknowledged + 1
                end

            end

            record.activeCycleKey = nil
            record.cycleStartedAt = nil
            record.acknowledgedThisCycle = false
            record.dismissedThisCycle = false

        end

    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function RecommendationHistoryService:GetHistoryFor(id)

    if not id then
        return nil
    end

    return self.History[id]

end

function RecommendationHistoryService:GetAllHistory()

    return self.History

end

-- Called by RecommendationInspector:Show() -- opening the Inspector for a
-- recommendation is the one real, observable signal this addon has that
-- the player actually looked at it, short of proving the underlying
-- gameplay action happened.
function RecommendationHistoryService:MarkAcknowledged(id)

    local record = self.History[id]

    if record and record.activeCycleKey then
        record.acknowledgedThisCycle = true
    end

end

-- Called by the Dismiss button (Recommendations page rows, Home's
-- Highest Priority card) -- the one CERTAIN outcome this service tracks,
-- since it's a direct player action, not an inference from disappearance.
function RecommendationHistoryService:DismissRecommendation(id)

    local record = self.History[id]

    if not record then
        return
    end

    record.timesDismissed = record.timesDismissed + 1
    record.lastDismissedAt = time()
    record.dismissedThisCycle = true

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("RecommendationHistoryService", RecommendationHistoryService)

return RecommendationHistoryService
