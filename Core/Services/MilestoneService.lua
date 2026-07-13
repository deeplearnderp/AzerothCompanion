-------------------------------------------------------------------------------
-- Azeroth Companion
-- Milestone Service
--
-- Companion Intelligence V4. Personal, account-history milestones,
-- independent of Blizzard's own achievement system -- "first time you
-- reached a +15," not "an achievement Blizzard defined."
--
-- Ownership split, the same pattern ActivityHistoryService already
-- established for itself: this service owns the GENERIC parts only --
-- the list of milestone definitions, persisted "already achieved" state,
-- and the notification when a new one unlocks. It never computes a
-- gameplay fact itself (a win streak, a highest key level, a rating
-- threshold) -- every `check` function below reads a real, already-
-- computed field from a module's own public getter
-- (MythicPlusModule:GetMilestoneStats(), added this same pass) and only
-- compares it against a fixed, documented threshold. Rule 1 (gameplay
-- data has exactly one owner) holds: MythicPlusModule owns "what is my
-- longest win streak," MilestoneService only owns "has the player's
-- longest win streak ever crossed 10."
--
-- Extensible by design: a future module (Delves, Raids, ...) that wants
-- its own personal milestones just adds more entries to
-- MILESTONE_DEFINITIONS naming its own module and stats getter -- this
-- service's Refresh()/persistence/notification logic needs no changes.
--
-- Persistence: DatabaseService:GetCharacter().Milestones -- deliberately
-- not a ConfigurationManager profile (Rule 8/9: this is gameplay
-- history, not a setting), the same "lazily create on this character
-- record" pattern ActivityHistoryService already uses for
-- .ActivityHistory. No new SavedVariables table.
--
-- "Achieved once, stays achieved": every definition here is a threshold
-- crossing (first key level N, Nth timed run, a rating floor, a streak/
-- gain floor reached at least once) rather than a continuously-updated
-- personal-best leaderboard stat -- deliberate, so "already achieved"
-- persistence stays a simple id -> timestamp map. "Fastest Dungeon" from
-- the original brief was evaluated and not implemented: fastest-across-
-- all-dungeons isn't a meaningful comparison (a +20 always takes longer
-- than a +2 regardless of skill), and a real per-dungeon-per-level
-- fastest-time milestone system is a much larger surface than this pass
-- has room for -- logged in the backlog, not silently dropped.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ipairs = ipairs
local tonumber = tonumber
local time = time
local table_sort = table.sort

local MilestoneService =
{
    Name = "MilestoneService",
}

AC.MilestoneService = MilestoneService

-------------------------------------------------------------------------------
-- Milestone Definitions
--
-- Each `check(stats)` receives exactly the table MythicPlusModule:
-- GetMilestoneStats() returns -- see that function's own comment for
-- what every field means and how it's computed.
-------------------------------------------------------------------------------

local MILESTONE_DEFINITIONS =
{
    { id = "FirstMythicPlus", titleKey = "Milestone.FirstMythicPlus.Title", descriptionKey = "Milestone.FirstMythicPlus.Description",
      check = function(stats) return stats.hasAnyRun end },

    { id = "FirstKeyLevel10", titleKey = "Milestone.FirstKeyLevel10.Title", descriptionKey = "Milestone.FirstKeyLevel10.Description",
      check = function(stats) return stats.highestLevelCompleted >= 10 end },

    { id = "FirstKeyLevel15", titleKey = "Milestone.FirstKeyLevel15.Title", descriptionKey = "Milestone.FirstKeyLevel15.Description",
      check = function(stats) return stats.highestLevelCompleted >= 15 end },

    { id = "FirstKeyLevel20", titleKey = "Milestone.FirstKeyLevel20.Title", descriptionKey = "Milestone.FirstKeyLevel20.Description",
      check = function(stats) return stats.highestLevelCompleted >= 20 end },

    { id = "TimedRuns100", titleKey = "Milestone.TimedRuns100.Title", descriptionKey = "Milestone.TimedRuns100.Description",
      check = function(stats) return stats.timedRunCount >= 100 end },

    { id = "Rating1000", titleKey = "Milestone.Rating1000.Title", descriptionKey = "Milestone.Rating1000.Description",
      check = function(stats) return stats.currentRating >= 1000 end },

    { id = "Rating2000", titleKey = "Milestone.Rating2000.Title", descriptionKey = "Milestone.Rating2000.Description",
      check = function(stats) return stats.currentRating >= 2000 end },

    { id = "NoDeathRun", titleKey = "Milestone.NoDeathRun.Title", descriptionKey = "Milestone.NoDeathRun.Description",
      check = function(stats) return stats.hasNoDeathRun end },

    { id = "WinStreak10", titleKey = "Milestone.WinStreak10.Title", descriptionKey = "Milestone.WinStreak10.Description",
      check = function(stats) return stats.longestWinStreak >= 10 end },

    { id = "BigRatingGain20", titleKey = "Milestone.BigRatingGain20.Title", descriptionKey = "Milestone.BigRatingGain20.Description",
      check = function(stats) return stats.largestRatingGain >= 20 end },

    { id = "Consumables100", titleKey = "Milestone.Consumables100.Title", descriptionKey = "Milestone.Consumables100.Description",
      check = function(stats) return stats.totalConsumablesUsed >= 100 end },

    { id = "Interrupts100", titleKey = "Milestone.Interrupts100.Title", descriptionKey = "Milestone.Interrupts100.Description",
      check = function(stats) return stats.totalInterrupts >= 100 end },
}

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function MilestoneService:Initialize()

    self.Achieved = {}

    local databaseService = AC.DatabaseService

    if not databaseService then

        if AC.Logger then
            AC.Logger:Error("MilestoneService: DatabaseService is not available.")
        end

        return

    end

    local character = databaseService:GetCharacter()

    if not character then

        if AC.Logger then
            AC.Logger:Error("MilestoneService: DatabaseService character record is not available.")
        end

        return

    end

    if type(character.Milestones) ~= "table" then
        character.Milestones = {}
    end

    self.Achieved = character.Milestones

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function MilestoneService:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function MilestoneService:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function MilestoneService:Shutdown()

    self:Disable()

end

-------------------------------------------------------------------------------
-- Refresh
--
-- Checks every not-yet-achieved definition against MythicPlusModule's
-- current lifetime stats. A newly-crossed threshold is marked achieved
-- (persisted immediately -- self.Achieved IS the character's saved
-- table, not a copy) and, if NotificationService is available, becomes a
-- real "New Milestone" notification.
-------------------------------------------------------------------------------

function MilestoneService:Refresh()

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local stats = mythicPlusModule and mythicPlusModule.GetMilestoneStats and mythicPlusModule:GetMilestoneStats()

    if not stats then
        return
    end

    for _, definition in ipairs(MILESTONE_DEFINITIONS) do

        if not self.Achieved[definition.id] and definition.check(stats) then

            self.Achieved[definition.id] = time()

            if AC.NotificationService then

                local title = AC.L and AC.L:Get(definition.titleKey) or definition.id
                local description = AC.L and AC.L:Get(definition.descriptionKey) or ""

                AC.NotificationService:Notify("Milestone", title, description)

            end

        end

    end

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function MilestoneService:IsAchieved(id)

    return self.Achieved[id] ~= nil

end

function MilestoneService:GetAchievedAt(id)

    return self.Achieved[id]

end

-------------------------------------------------------------------------------
-- Get Recent
--
-- The most recently achieved milestones, newest first -- what Home's
-- "Recent Milestones" card reads. Each entry carries its own
-- titleKey/descriptionKey; Dashboard resolves those through AC.L exactly
-- like everywhere else, never hardcoding display text here.
-------------------------------------------------------------------------------

-- Every achieved milestone, newest first, untrimmed -- what Character
-- Journey reads (GetRecent's trim is wrong for "every achieved milestone,
-- chronologically"). Extracted from GetRecent below, which now just adds
-- the trim step on top -- zero behavior change for GetRecent's existing
-- callers (Progress page, Home card).
function MilestoneService:GetAllAchieved()

    local achievedList = {}

    for _, definition in ipairs(MILESTONE_DEFINITIONS) do

        local achievedAt = self.Achieved[definition.id]

        if achievedAt then

            table.insert(achievedList,
            {
                id = definition.id,
                achievedAt = achievedAt,
                titleKey = definition.titleKey,
                descriptionKey = definition.descriptionKey,
            })

        end

    end

    table_sort(achievedList, function(a, b)
        return a.achievedAt > b.achievedAt
    end)

    return achievedList

end

function MilestoneService:GetRecent(count)

    count = tonumber(count) or 5

    local achievedList = self:GetAllAchieved()

    local trimmed = {}

    for i = 1, math.min(count, #achievedList) do
        trimmed[i] = achievedList[i]
    end

    return trimmed

end

function MilestoneService:GetAllDefinitions()

    return MILESTONE_DEFINITIONS

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("MilestoneService", MilestoneService)

return MilestoneService
