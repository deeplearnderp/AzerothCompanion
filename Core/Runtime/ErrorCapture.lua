-------------------------------------------------------------------------------
-- Azeroth Companion
-- Error Capture
--
-- The first Developer Runtime capability (see DeveloperRuntime.lua's own
-- header for the ownership boundaries this follows). Hooks the global Lua
-- error handler while Developer Mode is on, so real errors are preserved
-- instead of scrolling past unread or forcing a player to click through
-- dozens of popups during Mythic+/raids/combat -- the purpose is to keep
-- information, never to hide it.
--
-- Interception point: geterrorhandler()/seterrorhandler(), the same
-- long-standing technique !BugGrabber uses. The previous handler (Blizzard's
-- own default, or another error-capture addon's if one is installed) is
-- captured once at install time and ALWAYS called afterward, success or
-- failure of our own capture logic -- this file never suppresses Blizzard's
-- real error handling by default, and the one opt-in exception
-- (SuppressBlizzardPopups) only ever applies on our own successful capture
-- path, never when our own logic itself throws. A bug in this file can
-- therefore never cause an error to go completely unseen anywhere --
-- "immediately fall back to Blizzard's default error handling" is the
-- literal, unconditional final line of the installed handler.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local ErrorCapture =
{
    Name = "ErrorCapture",
}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local MAX_UNIQUE_ERRORS = 200

-------------------------------------------------------------------------------
-- Settings
--
-- Profile-scoped, same lightweight "read/default-fill/write directly on
-- the profile table" convention DeveloperModeService's own DeveloperMode
-- flag and Logger's own Debug flag already use -- no DatabaseService
-- schema-defaults entry needed, this file owns its own sub-table shape.
-------------------------------------------------------------------------------

local SETTING_DEFAULTS =
{
    CaptureLuaErrors = true,
    SuppressBlizzardPopups = false,
    AggregateDuplicates = true,
    DelayNotificationsUntilOutOfCombat = true,
    CaptureStackTraces = true,
    ShowRawStackTraces = false,
}

function ErrorCapture:GetSettings()

    local database = AC.DatabaseService

    if not database or not database.DB then
        return SETTING_DEFAULTS
    end

    local profile = database:GetProfile()

    if not profile then
        return SETTING_DEFAULTS
    end

    profile.DeveloperRuntime = profile.DeveloperRuntime or {}
    profile.DeveloperRuntime.ErrorCapture = profile.DeveloperRuntime.ErrorCapture or {}

    local settings = profile.DeveloperRuntime.ErrorCapture

    for key, default in pairs(SETTING_DEFAULTS) do

        if settings[key] == nil then
            settings[key] = default
        end

    end

    return settings

end

function ErrorCapture:SetSetting(key, value)

    if SETTING_DEFAULTS[key] == nil then
        return
    end

    local settings = self:GetSettings()

    settings[key] = value and true or false

    -- Live-apply without waiting for the next Developer Mode transition --
    -- CaptureLuaErrors is the one setting that gates whether the error
    -- hook itself is installed.
    if key == "CaptureLuaErrors" and AC.DeveloperModeService and AC.DeveloperModeService:IsEnabled() then

        if settings.CaptureLuaErrors then
            self:Install()
        else
            self:Remove()
        end

    end

end

-------------------------------------------------------------------------------
-- Signature / Location / Origin
--
-- Stabilization pass -- root cause of a real, live-confirmed bug: the
-- previous design picked the signature/location/module from whichever
-- stack line was the FIRST addon-owned, non-self frame found in
-- debugstack()'s own output. Live testing showed this frequently lands on
-- the wrong frame -- for a /ac dev testerror thrown from
-- SlashCommandManager.lua:177 (inside HandleDev), it reported
-- module/location/signature as DeveloperPanel.lua:1226 (the Generate Test
-- Error button's own OnClick handler, which merely CALLED HandleDev).
-- debugstack()'s exact frame-preservation behavior when read from inside
-- an installed seterrorhandler callback is not something this addon can
-- verify without a live client (still flagged NEEDS_LIVE in
-- GameplayModuleArchitecture.md) -- but this observed failure means it
-- cannot be trusted as the PRIMARY source of "where did this happen."
--
-- The message itself can be. Lua's error() (default level, the level
-- both this addon's own error() calls and every native Lua runtime fault
-- use) unconditionally prepends "chunkname:line: " to the message before
-- an addon's error handler ever sees it -- this is universal, guaranteed
-- Lua behavior, not something specific to this addon's own test-error
-- command, and requires no stack-depth assumption or line-skip guess at
-- all: it's a fixed prefix format on a string this addon already has.
-- ExtractMessageLocation below is the new PRIMARY source of truth for
-- location/module/origin; the raw stack trace is now only a SECONDARY
-- source, cross-referenced solely to add a function name for readability
-- -- never depended on for correctness.
--
-- Graceful degradation, unchanged in spirit: if the message has no
-- parseable "chunkname:line:" prefix at all (rare -- e.g. error() called
-- with an explicit level of 0, or a non-string message), this still falls
-- back to the raw message text as the signature rather than refusing to
-- capture.
-------------------------------------------------------------------------------

-- Parses Lua's own auto-prepended location prefix off an error message.
--
-- Verification pass -- audited for false positives: a bare "^(.-):(%d+):"
-- pattern would also match a message that merely CONTAINS an early
-- "word:digits:" substring with no real chunkname behind it at all (e.g.
-- a hypothetical "Failed at step 12:34: retrying" message) and mistake it
-- for a genuine location prefix. Every real WoW chunkname is path-shaped
-- (Interface/AddOns/.../File.lua, or an XML-inline handler's own
-- path-shaped chunk identifier) -- requiring a path separator in the
-- captured segment is a real, low-cost correctness check against that
-- false-positive class, not a narrowing that could miss a genuine prefix.
local function ExtractMessageLocation(message)

    local path, line = message:match("^(.-):(%d+):")

    if not path or not line then
        return nil, nil, nil, nil
    end

    if not path:find("[/\\]") then
        return nil, nil, nil, nil
    end

    local file = path:match("([%w_]+%.lua)$") or path:match("([^/\\]+)$") or path

    return path .. ":" .. line, file, path, tonumber(line)

end

-- Classifies which addon a source path belongs to.
--
-- Verification pass -- audited for ambiguity: the previous check
-- (path:find(AC.Name)) was a substring search over the WHOLE path, which
-- would misclassify a hypothetical third party addon whose own folder
-- name merely CONTAINS "AzerothCompanion" (e.g. "AzerothCompanionPlus")
-- as this addon's own code. Fixed by extracting the addon folder name
-- first and comparing it EXACTLY -- eliminates that ambiguity outright
-- rather than leaving a substring match that happens to usually be right.
--
-- Blizzard's own UI ships as a family of "Blizzard_*" sub-addons in
-- current clients (and, on older ones, under Interface/FrameXML) --
-- neither pattern is a guess, both are long-standing, stable path
-- conventions, not invented for this addon. A path with no recognizable
-- AddOns-folder segment at all falls back to "Blizzard" -- every real
-- addon (third party or this one) is always shipped under an AddOns
-- folder, so the absence of one most likely means core Blizzard client
-- code that isn't part of the addon system at all. A third party addon
-- literally naming its own folder with Blizzard's reserved "Blizzard_"
-- prefix would still be misclassified -- WoW's addon-folder conventions
-- make this an accepted, negligible-probability edge case, not something
-- further hardening can meaningfully close.
local function ClassifyOrigin(path)

    if not path then
        return nil, nil
    end

    if path:find("FrameXML", 1, true) then
        return "Blizzard", nil
    end

    local addonFolder = path:match("[Aa]dd[Oo]ns[/\\]([^/\\]+)")

    if not addonFolder then
        return "Blizzard", nil
    end

    if addonFolder == AC.Name then
        return "Azeroth Companion", nil
    end

    if addonFolder:match("^Blizzard_") then
        return "Blizzard", nil
    end

    return "Third Party", addonFolder

end

-- Cross-references the message's own (reliable) location against the raw
-- stack trace purely to recover the containing function's name for
-- readability -- location/module/origin never depend on this succeeding,
-- only the signature's optional "-- FuncName()" suffix does.
--
-- Verification pass -- audited debugstack()'s line formats: a named
-- function shows as "in function 'Name'"; an anonymous one as
-- "in function <chunkname:linedefined>"; top-level code as "in main
-- chunk". Only the quoted-name form is matched -- the anonymous <...>
-- form previously matched too, but surfacing the raw "chunkname:line"
-- text as a fake "function name" (e.g. a signature ending in
-- "...lua:45()") was misleading rather than merely incomplete; omitting
-- it entirely (falls through to nil, same as "in main chunk" already
-- does) is more honest than a technically-non-nil but meaningless value.
local function FindFunctionName(stackTrace, location)

    if not stackTrace or not location then
        return nil
    end

    for line in stackTrace:gmatch("[^\n]+") do

        if line:find(location, 1, true) then
            return line:match("in function ['\"]([^'\"]+)['\"]")
        end

    end

    return nil

end

-- Stabilization pass -- Developer Runtime's own frames (ErrorCapture.lua,
-- DeveloperRuntime.lua) are the machinery that caught an error, never the
-- bug itself, and were never meant to be part of what a developer reads
-- while diagnosing one. Filtered from the developer-facing stack by
-- default; the unfiltered trace is preserved separately regardless (see
-- BuildEntry's rawStackTrace) so ShowRawStackTraces can reveal it without
-- needing to re-capture anything.
local RUNTIME_FILES = { "ErrorCapture.lua", "DeveloperRuntime.lua" }

local function CleanStackTrace(stackTrace)

    if not stackTrace then
        return nil
    end

    local kept = {}

    for line in stackTrace:gmatch("[^\n]+") do

        local isRuntimeFrame = false

        for _, fileName in ipairs(RUNTIME_FILES) do

            if line:find(fileName, 1, true) then
                isRuntimeFrame = true
                break
            end

        end

        if not isRuntimeFrame then
            table.insert(kept, line)
        end

    end

    return table.concat(kept, "\n")

end

-- Returns signature, module (bare filename), location (file:line), origin
-- ("Azeroth Companion"/"Blizzard"/"Third Party"), thirdPartyAddon (only
-- set when origin is "Third Party"), functionName, lineNumber.
--
-- functionName/lineNumber are already computed here as part of building
-- the signature/location strings -- verification pass found they weren't
-- being surfaced as their own entry fields, only embedded inside the
-- signature/location strings, which would force any future consumer
-- (e.g. sorting/filtering by line number) to re-parse those strings for
-- data this function already has in hand. Returned as their own values so
-- BuildEntry can store them directly instead.
--
-- Signature itself stays a single line ("File.lua:NNN -- FuncName()")
-- rather than embedding a literal newline -- Developer Panel's
-- SetAccordionDetailField (a shared Dashboard primitive used by other
-- accordion pages too) assumes a fixed-height, single-line value; this
-- keeps the Errors tab's own detail view correct without needing to touch
-- that shared layout contract for one field.
function ErrorCapture:ComputeSignature(message, stackTrace)

    local location, file, path, lineNumber = ExtractMessageLocation(message)

    if not location then
        return message, nil, nil, nil, nil, nil, nil
    end

    local origin, thirdPartyAddon = ClassifyOrigin(path)
    local functionName = FindFunctionName(stackTrace, location)

    local signature = location

    if functionName then
        signature = signature .. " -- " .. functionName .. "()"
    end

    return signature, file, location, origin, thirdPartyAddon, functionName, lineNumber

end

-------------------------------------------------------------------------------
-- Context Gathering
--
-- Every field is a direct Blizzard getter result or explicitly omitted --
-- never fabricated. mapID/instance fields are only set when the
-- corresponding Blizzard call actually returns something usable.
-------------------------------------------------------------------------------

function ErrorCapture:BuildEntry(message, stackTrace, moduleFile, location, origin, thirdPartyAddon, functionName, lineNumber, settings, timestamp)

    local entry =
    {
        message = message,
        module = moduleFile,
        location = location,
        origin = origin,
        thirdPartyAddon = thirdPartyAddon,
        functionName = functionName,
        lineNumber = lineNumber,
        occurrenceCount = 1,
        firstSeen = timestamp,
        lastSeen = timestamp,
        playerName = UnitName("player"),
        realm = GetRealmName(),
        addonVersion = AC.Version,
        inCombat = InCombatLockdown() == true,
    }

    -- rawStackTrace is always the true, unfiltered trace (when captured
    -- at all); stackTrace -- the field Developer Panel actually displays
    -- -- is the developer-facing one: cleaned of this file's own
    -- ErrorCapture.lua/DeveloperRuntime.lua frames by default, or the raw
    -- trace verbatim if ShowRawStackTraces is explicitly on. Runtime
    -- frames never become part of what's shown unless asked for.
    if settings.CaptureStackTraces and stackTrace then

        entry.rawStackTrace = stackTrace
        entry.stackTrace = settings.ShowRawStackTraces and stackTrace or CleanStackTrace(stackTrace)

    end

    local _, build = GetBuildInfo()
    entry.wowBuild = build

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")

    if ok and mapID then
        entry.mapID = mapID
    end

    if IsInInstance() then

        local instanceName, _, difficultyID = GetInstanceInfo()

        if instanceName and instanceName ~= "" then
            entry.instanceName = instanceName
            entry.difficultyID = difficultyID
        end

    end

    return entry

end

-------------------------------------------------------------------------------
-- Capture
-------------------------------------------------------------------------------

function ErrorCapture:OnError(message)

    message = tostring(message)

    local settings = self:GetSettings()

    -- Stack trace + signature isolated in their own protective boundary --
    -- a throw here would otherwise silently discard the ENTIRE capture
    -- (message/context never stored either) with zero visibility --
    -- exactly the "never swallow errors silently" gap this runtime is
    -- supposed to close, just relocated to its own internal boundary. A
    -- failure here now degrades to a message-only signature (still
    -- better than losing the error) and logs why, instead of capture
    -- failing completely and invisibly. debugstack() is called with no
    -- level argument -- location/module/origin come from the message's
    -- own auto-prepended prefix (see ComputeSignature), never from
    -- guessing a stack skip count; the raw trace is only cross-referenced
    -- afterward for an optional function-name suffix.
    local signature, moduleFile, location, origin, thirdPartyAddon, functionName, lineNumber = message, nil, nil, nil, nil, nil, nil
    local stackTrace

    local traceOk, traceErr = pcall(function()

        if type(debugstack) == "function" then
            stackTrace = debugstack()
        end

        signature, moduleFile, location, origin, thirdPartyAddon, functionName, lineNumber = self:ComputeSignature(message, stackTrace)

    end)

    if not traceOk then

        if AC.Logger then
            AC.Logger:Error(("Error Capture: signature computation failed, falling back to a message-only signature: %s"):format(tostring(traceErr)))
        end

        stackTrace = nil
        signature, moduleFile, location, origin, thirdPartyAddon, functionName, lineNumber = message, nil, nil, nil, nil, nil, nil

    end

    local key = signature

    if not settings.AggregateDuplicates then

        self.SequenceCounter = (self.SequenceCounter or 0) + 1
        key = signature .. "#" .. self.SequenceCounter

    end

    -- Error History persistence -- firstSeen/lastSeen are now absolute
    -- epoch seconds (time()), not AC.Logger's session-relative
    -- HH:MM:SS.mmm clock string, since persisted entries need to remain
    -- meaningful across sessions. Formatted only at display/export time
    -- (Developer Panel's FormatErrorTimestamp), never stored pre-formatted.
    local timestamp = time()
    local existing = self.ErrorsByKey[key]
    local occurrenceCount

    if existing then

        existing.occurrenceCount = existing.occurrenceCount + 1
        existing.lastSeen = timestamp
        occurrenceCount = existing.occurrenceCount

    else

        local entry = self:BuildEntry(message, stackTrace, moduleFile, location, origin, thirdPartyAddon, functionName, lineNumber, settings, timestamp)

        entry.key = key
        occurrenceCount = entry.occurrenceCount

        self.ErrorsByKey[key] = entry
        table.insert(self.Errors, entry)

        while #self.Errors > MAX_UNIQUE_ERRORS do

            local oldest = table.remove(self.Errors, 1)
            self.ErrorsByKey[oldest.key] = nil

        end

    end

    -- One consolidated line covers signature generation (key), aggregation
    -- (new vs. existing + resulting count), and storage (implied by
    -- reaching this line at all) -- easier to scan than one Debug call per
    -- pipeline stage for what is, in the common case, a single fast path.
    if AC.Logger then
        AC.Logger:Debug(("Error Capture: %s (module=%s, origin=%s, location=%s, occurrences=%d, total unique=%d)."):format(
            existing and "aggregated into existing entry" or "captured as new entry",
            moduleFile or "unknown", origin or "unknown", location or "unknown", occurrenceCount, #self.Errors), "Framework")
    end

    if AC.DeveloperRuntime then

        if settings.DelayNotificationsUntilOutOfCombat then

            if AC.Logger then
                AC.Logger:Debug("Error Capture: notifying Developer Runtime (combat-aware, deferred if in combat).", "Framework")
            end

            AC.DeveloperRuntime:NotifyUpdate("ErrorCapture")

        else

            if AC.Logger then
                AC.Logger:Debug("Error Capture: notifying Developer Runtime (immediate, DelayNotificationsUntilOutOfCombat is off).", "Framework")
            end

            AC.Events:Fire("DEVELOPER_RUNTIME_UPDATED", "ErrorCapture")

        end

    elseif AC.Logger then
        AC.Logger:Warn("Error Capture: AC.DeveloperRuntime unavailable -- captured entry stored, but no UI refresh notification could be sent.")
    end

end

-------------------------------------------------------------------------------
-- Getters (Developer Panel's read-only surface)
-------------------------------------------------------------------------------

function ErrorCapture:GetErrors()

    return self.Errors

end

function ErrorCapture:ClearErrors()

    -- Clears self.Errors in place rather than reassigning it -- self.Errors
    -- is the same table object Global.DeveloperRuntime.ErrorCapture.Errors
    -- holds (see Initialize()), so replacing the reference here would
    -- leave the old, uncleared array sitting in SavedVariables, silently
    -- undoing the clear on the next reload. self.ErrorsByKey is a purely
    -- derived index, never itself persisted, so reassigning it is fine.
    for index = #self.Errors, 1, -1 do
        table.remove(self.Errors, index)
    end

    self.ErrorsByKey = {}

end

-- Ground truth (is the handler actually installed right now), distinct
-- from GetSettings().CaptureLuaErrors (the persisted intent) -- Developer
-- Panel Errors tab addition, so presentation reads one honest boolean
-- instead of reaching into OriginalHandler directly.
function ErrorCapture:IsInstalled()

    return self.OriginalHandler ~= nil

end

-------------------------------------------------------------------------------
-- Global Error Handler (Re-Entrancy Protected)
--
-- This is the one function actually registered via seterrorhandler --
-- Install() below just wires it up. IsHandlingError guards the entire
-- operation (both our own capture attempt AND the chained call to
-- whatever handler was previously installed), not just the capture half:
-- if calling through to the original handler itself throws (a genuinely
-- uncertain area -- see the "NEEDS_LIVE" note in GameplayModuleArchitecture.md),
-- treating that as "still handling" is what prevents a second, nested
-- invocation of this same function from re-running OnError. A re-entrant
-- call (IsHandlingError already true when this runs again) never touches
-- capture logic at all -- it goes straight to the original handler,
-- pcall-wrapped, and nothing more. Every branch below returns normally;
-- this function is designed to never itself throw, under any internal
-- failure, so it can never become the second error in "an error while
-- handling an error."
-------------------------------------------------------------------------------

function ErrorCapture:HandleGlobalError(message)

    if AC.Logger then

        pcall(function()
            AC.Logger:Debug("Error Capture: global error handler invoked.", "Framework")
        end)

    end

    if self.IsHandlingError then

        if AC.Logger then

            pcall(function()
                AC.Logger:Error("Error Capture: re-entrant error detected while already handling one -- skipping capture, falling back to the original handler.")
            end)

        end

        local _, result = pcall(self.OriginalHandler, message)
        return result

    end

    self.IsHandlingError = true

    local captureOk, captureErrOrSuppress = pcall(function()
        self:OnError(message)
        return self:GetSettings().SuppressBlizzardPopups
    end)

    if not captureOk and AC.Logger then

        pcall(function()
            AC.Logger:Error(("Error Capture: failed to capture an error, falling back to the original handler: %s"):format(tostring(captureErrOrSuppress)))
        end)

    end

    local suppress = captureOk and captureErrOrSuppress
    local result

    if not (captureOk and suppress) then

        pcall(function()
            result = self.OriginalHandler(message)
        end)

    end

    self.IsHandlingError = false

    return result

end

-------------------------------------------------------------------------------
-- Install / Remove
--
-- Reinstall-safe (OriginalHandler guard mirrors DeveloperModeService's own
-- WrapRefresh guard) -- toggling Developer Mode off/on repeatedly in one
-- session can't stack wrappers. Only ever installs while CaptureLuaErrors
-- is on; a developer can keep Developer Mode on for other tooling while
-- independently declining the error hook.
--
-- Remove() additionally guards against a third party (another
-- error-capture addon, e.g. BugGrabber, loading and installing its own
-- handler after ours) having replaced the global handler since our own
-- install -- restoring our stored OriginalHandler in that case would
-- silently clobber whatever is now active. InstalledHandler records
-- exactly which function object we last installed, so Remove() can tell
-- the difference between "still ours, safe to restore" and "someone else
-- is on top now, leave it alone."
-------------------------------------------------------------------------------

function ErrorCapture:Install()

    if type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then

        if AC.Logger then
            AC.Logger:Warn("Error Capture: geterrorhandler/seterrorhandler unavailable on this client -- capture cannot install.")
        end

        return

    end

    if not self:GetSettings().CaptureLuaErrors then

        if AC.Logger then
            AC.Logger:Debug("Error Capture: install skipped -- CaptureLuaErrors is off.", "Framework")
        end

        return

    end

    if self.OriginalHandler then

        if AC.Logger then
            AC.Logger:Debug("Error Capture: install skipped -- already installed.", "Framework")
        end

        return

    end

    self.OriginalHandler = geterrorhandler()
    self.IsHandlingError = false

    local wrapper = function(message)
        return self:HandleGlobalError(message)
    end

    self.InstalledHandler = wrapper

    seterrorhandler(wrapper)

    if AC.Logger then
        AC.Logger:Debug("Error Capture: handler installed.", "Framework")
    end

end

function ErrorCapture:Remove()

    if not self.OriginalHandler then
        return
    end

    if type(geterrorhandler) == "function" and self.InstalledHandler and geterrorhandler() ~= self.InstalledHandler then

        if AC.Logger then
            AC.Logger:Warn("Error Capture: another addon replaced the global error handler after installation -- leaving it in place rather than overwriting it.")
        end

        self.OriginalHandler = nil
        self.InstalledHandler = nil

        return

    end

    local ok, err = pcall(seterrorhandler, self.OriginalHandler)

    if ok then

        self.OriginalHandler = nil
        self.InstalledHandler = nil

        if AC.Logger then
            AC.Logger:Debug("Error Capture: handler removed, original restored.", "Framework")
        end

    elseif AC.Logger then
        AC.Logger:Error(("Error Capture: failed to restore original error handler, leaving capture installed: %s"):format(tostring(err)))
    end

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

-- Error History persistence -- self.Errors is wired to the same table
-- object Global.DeveloperRuntime.ErrorCapture.Errors holds, not a copy, so
-- every existing table.insert/table.remove in OnError's aggregation and
-- eviction logic already mutates the persisted SavedVariables table with
-- no separate "save" step. Safe by construction: DatabaseService registers
-- before DeveloperRuntime in the .toc, and ServiceManager:Initialize()
-- runs every registered service's Initialize() in that same registration
-- order, so AC.DatabaseService.DB is always populated before this runs.
-- The else branch is a defensive fallback only (matching this file's own
-- GetSettings() guard earlier) for the case where that guarantee is
-- somehow violated -- capture still works for the current session, just
-- without persistence, rather than failing outright.
function ErrorCapture:Initialize()

    local database = AC.DatabaseService

    if database and database.DB then

        local globalData = database:GetGlobal()

        globalData.DeveloperRuntime = globalData.DeveloperRuntime or {}
        globalData.DeveloperRuntime.ErrorCapture = globalData.DeveloperRuntime.ErrorCapture or { SchemaVersion = 1, Errors = {} }

        self.Errors = globalData.DeveloperRuntime.ErrorCapture.Errors

    else
        self.Errors = {}
    end

    self.ErrorsByKey = {}

    for _, entry in ipairs(self.Errors) do
        self.ErrorsByKey[entry.key] = entry
    end

    self.SequenceCounter = 0
    self.OriginalHandler = nil
    self.InstalledHandler = nil
    self.IsHandlingError = false

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.DeveloperRuntime:RegisterCapability("ErrorCapture", ErrorCapture)

return ErrorCapture
