-------------------------------------------------------------------------------
-- Azeroth Companion
-- Session Notes Service
--
-- Companion Intelligence vNext -- Home's "Today's Companion Notes" card.
-- Owns exactly one responsibility, the same shape as BriefingService:
-- SELECTING already-real, session-relative facts into a short list, never
-- computing a new one itself. Every line is sourced from another
-- module/service's already-public getter (Rule 6/1) -- Dashboard stays
-- presentation-only (Rule 2).
--
-- "This session," not "last session": nothing in this addon persists a
-- previous session's summary (MythicPlusModule.Session/
-- AccomplishmentsModule.Session both reset on load, with no write-out
-- beforehand) -- claiming "last session" would misrepresent CURRENT-
-- session data as being about a session that already ended. See
-- docs/DEVELOPMENT_BACKLOG.md for the deferred true "last session"
-- feature, which needs new persistence this pass doesn't add.
--
-- Skipped entirely, per the Companion Intelligence vNext audit: "you
-- normally start with a repair" -- no module records repair timing
-- relative to session start, so there is nothing real to report.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local time = time

local SessionNotesService =
{
    Name = "SessionNotesService",
}

AC.SessionNotesService = SessionNotesService

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function SessionNotesService:ResetState()

    self.Lines = {}
    self.LastRefresh = 0
    self.HasShownWelcome = false

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function SessionNotesService:Initialize()

    self:ResetState()

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function SessionNotesService:Enable()

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function SessionNotesService:Disable()

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function SessionNotesService:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function SessionNotesService:Refresh()

    self.Lines = {}

    -- "Welcome back" -- once per session, the first refresh only. Real
    -- (a real session boundary, this addon's own load), not a fabricated
    -- fact about the player.
    if not self.HasShownWelcome then
        table.insert(self.Lines, AC.L:Get("SessionNotes.WelcomeBack"))
        self.HasShownWelcome = true
    end

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local mpSessionSummary = mythicPlusModule and mythicPlusModule.GetSessionSummary and mythicPlusModule:GetSessionSummary()

    if mpSessionSummary and (mpSessionSummary.runsCompletedThisSession or 0) > 0 then
        table.insert(self.Lines, AC.L:Format("SessionNotes.RunsThisSessionFormat", mpSessionSummary.runsCompletedThisSession))
    end

    local accomplishmentsModule = AC.Core and AC.Core:GetModule("Accomplishments")
    local achievementSummary = accomplishmentsModule and accomplishmentsModule.GetSessionSummary and accomplishmentsModule:GetSessionSummary()

    if achievementSummary and (achievementSummary.achievementsEarnedThisSession or 0) > 0 then
        table.insert(self.Lines, AC.L:Format("SessionNotes.AchievementsThisSessionFormat", achievementSummary.achievementsEarnedThisSession))
    end

    local weeklyModule = AC.Core and AC.Core:GetModule("Weekly")
    local slotsGained = weeklyModule and weeklyModule.GetSlotsGainedThisSession and weeklyModule:GetSlotsGainedThisSession()

    if slotsGained and slotsGained > 0 then
        table.insert(self.Lines, AC.L:Format("SessionNotes.VaultSlotsGainedFormat", slotsGained))
    end

    self.LastRefresh = time()

end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function SessionNotesService:GetNotes()

    return self.Lines

end

function SessionNotesService:GetLastRefresh()

    return self.LastRefresh

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("SessionNotesService", SessionNotesService)

return SessionNotesService
