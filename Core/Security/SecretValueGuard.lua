-------------------------------------------------------------------------------
-- Azeroth Companion
-- Secret Value Guard
--
-- Not a gameplay module -- no Data Ownership Matrix entry, no lifecycle
-- (Initialize/Enable/etc.), same shape as Core/Presentation/Presentation.lua.
-- A generic, addon-wide leaf utility for the one thing every hook into a
-- Blizzard secure UI callback (TooltipDataProcessor postcalls, Menu.ModifyMenu
-- callbacks, and any future callback of the same family -- Gossip, Merchant,
-- Inspect, whatever Blizzard adds next) needs: a single, correct way to
-- attempt a read of Blizzard-owned data that MIGHT be a "secret value" -- an
-- opaque type Blizzard's own secure dispatch can hand to a callback, which
-- throws the instant addon code tries to read/compare/concatenate/index it
-- ("Secret values are only allowed during untainted execution").
--
-- Why a pcall wrapper, not a nil-guard: a nil-guard defends against a value
-- that is merely absent or a known shape this addon's own code controls --
-- appropriate for this addon's own bugs, wrong for this boundary. Whether a
-- specific field is secret is Blizzard's own undocumented, per-callback,
-- per-patch policy -- this addon confirmed it wrong twice already for the
-- PlayerJournal tooltip (tooltip:GetUnit(), then the postcall's own
-- data.guid field) before landing on data.lines, and that assumption is
-- itself only NEEDS_LIVE, not proven. There is no way to inspect a value in
-- advance and learn whether it is secret -- attempt-and-catch is the only
-- defensible technique for a boundary this addon does not control and
-- cannot predict, the same pattern every other retail addon that hooks
-- these same Blizzard callbacks (TooltipInfo, Rarity, Quester, ...) has
-- converged on. This is categorically different from wrapping this addon's
-- OWN internal logic in pcall to hide a bug -- see docs/GameplayModuleArchitecture.md's
-- "Secret Value Audit" section for the full reasoning and inventory of
-- where this guard is (and deliberately is not) applied.
--
-- Diagnostics Hardening Pass -- TryRead now distinguishes THREE different
-- reasons a wrapped read can fail, not one:
--   SECRET_VALUE_BLOCKED -- the thing this guard exists for. Silently
--     absorbed: the caller gets no value back, nothing more.
--   CALLBACK_EXCEPTION / UNKNOWN_EXCEPTION -- a REAL bug (in this addon's
--     own wrapped code, not a secret value). Per this addon's own
--     explicit rule, framework bugs must fail normally so they can be
--     fixed -- these are re-thrown after being recorded for diagnostic
--     context, never silently swallowed. This guard's job is isolating
--     the Blizzard secure-callback boundary, not hiding this addon's own
--     mistakes.
-- Every failure (of any kind) is recorded into the "SecretValueEvents"
-- Developer Runtime capability (aggregated, occurrence-counted, same
-- shape as ErrorCapture) and Debug-logged in structured form -- see
-- Core/Runtime/SecretValueEvents.lua.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local SecretValueGuard = {}
AC.SecretValueGuard = SecretValueGuard

-------------------------------------------------------------------------------
-- Status Enum
-------------------------------------------------------------------------------

SecretValueGuard.Status =
{
    SUCCESS = "SUCCESS",                       -- fn(...) returned normally.
    SECRET_VALUE_BLOCKED = "SECRET_VALUE_BLOCKED", -- fn(...) threw, and the error text matches Blizzard's own secret-value wording. Absorbed silently -- this is the expected, designed-for failure mode.
    CALLBACK_EXCEPTION = "CALLBACK_EXCEPTION", -- fn(...) threw a normal Lua error (has a message) that is NOT a secret-value error -- a real bug. Re-thrown after recording.
    UNKNOWN_EXCEPTION = "UNKNOWN_EXCEPTION",   -- fn(...) threw something that isn't a plain string message (e.g. error({}) or error(nil)) -- can't even classify it as an ordinary exception. Re-thrown after recording, same as CALLBACK_EXCEPTION.
}

-------------------------------------------------------------------------------
-- Secret-Value Error Classification
--
-- Heuristic, not a Blizzard-documented contract: both real errors this
-- addon has hit ("Secret values are only allowed during untainted
-- execution" and "a secret string value, while execution tainted by...")
-- contain the word "secret" prominently. Centralizing the check here means
-- a future Blizzard wording change only needs updating in one place, not
-- re-derived at every call site.
-------------------------------------------------------------------------------

function SecretValueGuard:IsSecretValueError(message)

    if type(message) ~= "string" then
        return false
    end

    return message:lower():find("secret", 1, true) ~= nil

end

-------------------------------------------------------------------------------
-- Try Read
--
-- ok, value, result = SecretValueGuard:TryRead(context, fn, ...)
--
-- Calls fn(...). On success: ok = true, value = fn's own return value
-- (fn should return exactly one value -- wrap multiple fields in a table
-- if a read needs more than one, e.g. `return { name = ..., realm = ... }`),
-- result = { status = "SUCCESS", context = context, timestamp = ... }.
--
-- On a secret-value failure: ok = false, value = nil, result describes
-- what happened -- caller code stays exactly as simple as the success
-- path (`if not ok then return end`), never required to inspect `result`
-- at all. `result` exists for diagnostic consumers (SecretValueEvents,
-- logging), not for ordinary control flow.
--
-- On any OTHER failure (a real bug in fn, not a secret value): this
-- records the event for diagnostic context, then RE-THROWS -- see this
-- file's own header for why. Callers never see `ok = false` for a real
-- bug; they see the error propagate exactly as if this guard were not
-- there, because a real bug isn't this guard's problem to hide.
--
-- `context` is a short, stable label (this addon's own dotted
-- VerificationService-id convention, e.g. "tooltip.lineText" --
-- everything before the first "." becomes `result.source`, a coarser
-- grouping for the Developer Panel/logging).
-------------------------------------------------------------------------------

function SecretValueGuard:TryRead(context, fn, ...)

    local ok, valueOrError = pcall(fn, ...)

    local timestamp = AC.Logger and AC.Logger:GetPreciseTimestamp() or ""
    local source = tostring(context):match("^([^.]+)") or tostring(context)

    if ok then

        return true, valueOrError,
        {
            status = self.Status.SUCCESS,
            context = context,
            source = source,
            timestamp = timestamp,
        }

    end

    local message = tostring(valueOrError)
    local isSecretValue = self:IsSecretValueError(message)

    local status

    if isSecretValue then
        status = self.Status.SECRET_VALUE_BLOCKED
    elseif type(valueOrError) == "string" then
        status = self.Status.CALLBACK_EXCEPTION
    else
        status = self.Status.UNKNOWN_EXCEPTION
    end

    local result =
    {
        status = status,
        context = context,
        source = source,
        message = message,
        stack = (type(debugstack) == "function") and debugstack() or nil,
        timestamp = timestamp,
    }

    local secretValueEvents = AC.DeveloperRuntime and AC.DeveloperRuntime:GetCapability("SecretValueEvents")

    if secretValueEvents then
        secretValueEvents:Record(result)
    end

    if not isSecretValue then

        -- A real bug, not what this guard exists for -- must fail
        -- normally so it can be fixed, not disappear into a diagnostics
        -- tab nobody is required to check. error(..., 0): the message
        -- already carries its own "chunkname:line:" prefix from the
        -- original throw, so this doesn't add a second, misleading one
        -- pointing at TryRead itself.
        error(valueOrError, 0)

    end

    return false, nil, result

end

return SecretValueGuard
