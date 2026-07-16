-------------------------------------------------------------------------------
-- Azeroth Companion
-- Secret Value Events
--
-- A Developer Runtime capability (see DeveloperRuntime.lua's own header for
-- the ownership boundaries this follows) -- the diagnostic home for every
-- event AC.SecretValueGuard:TryRead records: a Blizzard secure-callback read
-- that was blocked as a secret value, or that failed for some other reason
-- while attempting one. Same shape as ErrorCapture (aggregated by key,
-- occurrence-counted, capped, gated on Developer Mode) deliberately -- this
-- is the second Developer Runtime capability, and the Developer Panel's
-- Secret Values tab reads it the same way the Errors tab reads ErrorCapture:
-- through this file's own public GetEvents()/ClearEvents(), no caching, no
-- second copy of the data.
--
-- Ownership boundary: this file owns captured secret-value diagnostic
-- events. SecretValueGuard owns the actual pcall/classification logic and
-- calls into this file's Record() -- it never stores anything itself. The
-- Developer Panel owns presentation; nothing here renders anything.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SecretValueEvents =
{
    Name = "SecretValueEvents",
}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local MAX_UNIQUE_EVENTS = 200

-------------------------------------------------------------------------------
-- Structured Logging
--
-- Diagnostics Hardening Pass -- a multi-line, labeled block instead of a
-- single generic "Secret-value read blocked" line, so a Debug session (or
-- a copied log) reads as a real diagnostic record rather than a vague
-- notice -- occurrenceCount is the entry's up-to-date running total, not
-- "1", so repeated hits read as "this keeps happening," not "this
-- happened once, N times."
-------------------------------------------------------------------------------

local function FormatLogMessage(entry)

    return table.concat(
    {
        "[SecretValueGuard]",
        "Context: " .. tostring(entry.context),
        "Status: " .. tostring(entry.status),
        "Reason: " .. tostring(entry.message or "N/A"),
        "Occurrences: " .. tostring(entry.occurrenceCount),
    }, "\n")

end

-------------------------------------------------------------------------------
-- Record
--
-- Called directly by SecretValueGuard:TryRead -- never by anything else.
-- Aggregates by "context|status" (the same event recurring under the same
-- classification coalesces into one entry with a growing occurrenceCount,
-- exactly like ErrorCapture's own signature-keyed aggregation) so a
-- misbehaving tooltip hook hammering this every NPC hover produces one
-- growing counter, never log/entry spam.
-------------------------------------------------------------------------------

function SecretValueEvents:Record(result)

    if not self.Enabled then
        return
    end

    local key = tostring(result.context) .. "|" .. tostring(result.status)
    local existing = self.EventsByKey[key]

    if existing then

        existing.occurrenceCount = existing.occurrenceCount + 1
        existing.lastSeen = result.timestamp
        existing.message = result.message
        existing.stack = result.stack

    else

        existing =
        {
            key = key,
            context = result.context,
            source = result.source,
            status = result.status,
            message = result.message,
            stack = result.stack,
            occurrenceCount = 1,
            firstSeen = result.timestamp,
            lastSeen = result.timestamp,
        }

        self.EventsByKey[key] = existing
        table.insert(self.Events, existing)

        while #self.Events > MAX_UNIQUE_EVENTS do

            local oldest = table.remove(self.Events, 1)
            self.EventsByKey[oldest.key] = nil

        end

    end

    if AC.Logger then
        AC.Logger:Debug(FormatLogMessage(existing), "Framework")
    end

    if AC.DeveloperRuntime then
        AC.DeveloperRuntime:NotifyUpdate("SecretValueEvents")
    end

end

-------------------------------------------------------------------------------
-- Getters (Developer Panel's read-only surface)
-------------------------------------------------------------------------------

function SecretValueEvents:GetEvents()

    return self.Events

end

function SecretValueEvents:ClearEvents()

    self.Events = {}
    self.EventsByKey = {}

end

-------------------------------------------------------------------------------
-- Install / Remove
--
-- No global hook to install (unlike ErrorCapture's seterrorhandler) --
-- SecretValueGuard calls Record() directly regardless of Developer Mode,
-- so this file just gates whether that call actually stores anything.
-- Same "diagnostic data only accumulates while a developer is watching"
-- philosophy ErrorCapture already established -- a player who never opens
-- Developer Mode pays no memory cost for a tab they'll never see, and
-- SecretValueGuard's own pcall protection is completely unaffected either
-- way (it always catches, regardless of Enabled).
-------------------------------------------------------------------------------

function SecretValueEvents:Install()

    self.Enabled = true

end

function SecretValueEvents:Remove()

    self.Enabled = false

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function SecretValueEvents:Initialize()

    self.Events = {}
    self.EventsByKey = {}
    self.Enabled = false

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.DeveloperRuntime:RegisterCapability("SecretValueEvents", SecretValueEvents)

return SecretValueEvents
