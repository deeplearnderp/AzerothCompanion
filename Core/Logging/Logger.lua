-------------------------------------------------------------------------------
-- Azeroth Companion
-- Logger
--
-- The single logging surface for the whole addon. Extended with structured
-- level/category logging, a ring-buffer log store, and trace-category
-- filtering -- diagnostics tooling (slash commands, the log window, event
-- tracers) all read/write through this file; nothing else keeps its own log
-- storage, per the "Logger owns storage" architecture rule.
--
-- Existing single-argument call sites (Logger:Info(message), etc.) continue
-- to work unchanged -- category is an optional second argument everywhere,
-- defaulting to "Framework".
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local Logger = {}
AC.Logger = Logger

Logger.PREFIX = "|cff33ff99[Azeroth Companion]|r"

-------------------------------------------------------------------------------
-- Levels & Categories
--
-- Categories are advisory, not enforced -- callers may pass any string, but
-- this is the canonical list surfaced by /ac trace and any future filter UI.
-------------------------------------------------------------------------------

Logger.Levels =
{
    "INFO",
    "WARN",
    "ERROR",
    "DEBUG",
    "TRACE",
}

Logger.Categories =
{
    "Framework",
    "Services",
    "Modules",
    "Inventory",
    "Accomplishments",
    "Mythic+",
    "Events",
    "UI",
    "Recommendation Engine",
    "Settings",
}

-------------------------------------------------------------------------------
-- Ring Buffer
--
-- A plain array trimmed from the front once it exceeds MaxEntries. Volume
-- is bounded by design (TRACE entries only accumulate while a trace
-- category is active), so the O(n) trim on overflow is not a concern.
-------------------------------------------------------------------------------

Logger.MaxEntries = 1000
Logger.Buffer = {}

function Logger:SetBufferSize(size)

    size = tonumber(size)

    if not size or size < 1 then
        return
    end

    self.MaxEntries = math.floor(size)

    while #self.Buffer > self.MaxEntries do
        table.remove(self.Buffer, 1)
    end

end

function Logger:GetBufferEntries()

    return self.Buffer

end

function Logger:ClearBuffer()

    self.Buffer = {}

end

-------------------------------------------------------------------------------
-- Timestamping
--
-- HH:MM:SS from the OS wall clock (date()), fractional milliseconds from
-- GetTimePreciseSec() (falls back to GetTime() pre-Shadowlands). The two
-- clocks are not phase-locked to each other, so this is for relative event
-- ordering/delta analysis within a session, not epoch-exact timestamps --
-- exactly what "allows event ordering analysis" requires, and the standard
-- idiom other addons use for this.
-------------------------------------------------------------------------------

local function GetTimestamp()

    local clock = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
    local whole = math.floor(clock)
    local ms = math.floor((clock - whole) * 1000 + 0.5)

    if ms >= 1000 then
        ms = 999
    end

    return string.format("%s.%03d", date("%H:%M:%S"), ms)

end

-- Exposed publicly -- the same "HH:MM:SS.mmm" clock every log entry
-- already stamps itself with, for any other part of the addon that wants
-- the identical relative-ordering timestamp (e.g. DeveloperModeService's
-- Event Monitor) instead of maintaining its own copy of this clock math.
function Logger:GetPreciseTimestamp()

    return GetTimestamp()

end

-------------------------------------------------------------------------------
-- Entry Formatting
-------------------------------------------------------------------------------

function Logger:SerializeData(data)

    if data == nil then
        return ""
    end

    if type(data) ~= "table" then
        return tostring(data)
    end

    local parts = {}

    for key, value in pairs(data) do
        table.insert(parts, tostring(key) .. "=" .. tostring(value))
    end

    table.sort(parts)

    return table.concat(parts, " ")

end

local function FormatEntry(entry)
    return string.format("[%s] [%s] [%s] %s", entry.timestamp, entry.level, entry.category, entry.message)
end

Logger.FormatEntry = FormatEntry

local function AppendEntry(self, level, category, message)

    local entry =
    {
        timestamp = GetTimestamp(),
        level = level,
        category = category or "Framework",
        message = message,
    }

    table.insert(self.Buffer, entry)

    if #self.Buffer > self.MaxEntries then
        table.remove(self.Buffer, 1)
    end

    return entry

end

function Logger:GetBufferText()

    local lines = {}

    for i = 1, #self.Buffer do
        table.insert(lines, FormatEntry(self.Buffer[i]))
    end

    return table.concat(lines, "\n")

end

-------------------------------------------------------------------------------
-- Debug Gate
--
-- Unchanged from the original mechanism -- AC.Debug in-memory flag, backed
-- by the profile's persisted Debug flag via DatabaseService. TRACE reuses
-- this same gate; a trace category being selected without debug mode on
-- would otherwise silently produce nothing, so /ac trace also flips this on
-- (see SlashCommandManager).
-------------------------------------------------------------------------------

function Logger:IsDebugEnabled()

    if AC.Debug then
        return true
    end

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile and profile.Debug then
            return true
        end

    end

    return false

end

function Logger:SetDebugEnabled(enabled)

    AC.Debug = enabled and true or false

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile then
            profile.Debug = AC.Debug
        end

    end

end

-------------------------------------------------------------------------------
-- Trace Category Filter
--
-- Session-only by design (not persisted) -- a diagnostic trace selection is
-- something you turn on for the investigation at hand, not a standing
-- preference.
-------------------------------------------------------------------------------

Logger.TraceAll = false
Logger.TraceCategories = {}

function Logger:SetTraceCategory(category, enabled)

    if not category then
        return
    end

    if enabled then
        self.TraceCategories[category] = true
    else
        self.TraceCategories[category] = nil
    end

end

function Logger:EnableAllTrace()

    self.TraceAll = true
    self.TraceCategories = {}

end

function Logger:DisableAllTrace()

    self.TraceAll = false
    self.TraceCategories = {}

end

function Logger:IsTraceCategoryEnabled(category)

    if self.TraceAll then
        return true
    end

    return self.TraceCategories[category] == true

end

function Logger:GetActiveTraceDescription()

    if self.TraceAll then
        return "all"
    end

    local active = {}

    for category in pairs(self.TraceCategories) do
        table.insert(active, category)
    end

    if #active == 0 then
        return "off"
    end

    table.sort(active)

    return table.concat(active, ", ")

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function Logger:Initialize()

    local database = AC.DatabaseService

    if database and database.DB then

        local profile = database:GetProfile()

        if profile then
            AC.Debug = profile.Debug == true
        end

    end

end

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------

function Logger:Info(message, category)

    AppendEntry(self, "INFO", category, tostring(message))
    print(self.PREFIX .. " " .. tostring(message))

end

function Logger:Warn(message, category)

    AppendEntry(self, "WARN", category, tostring(message))
    print("|cffffff00[Azeroth Companion]|r " .. tostring(message))

end

function Logger:Error(message, category)

    AppendEntry(self, "ERROR", category, tostring(message))
    print("|cffff3333[Azeroth Companion]|r " .. tostring(message))

end

function Logger:Debug(message, category)

    if not self:IsDebugEnabled() then
        return
    end

    AppendEntry(self, "DEBUG", category, tostring(message))
    print("|cff66ccff[Azeroth Companion][Debug]|r " .. tostring(message))

end

-------------------------------------------------------------------------------
-- Trace
--
-- Silent to chat by design -- this is the high-volume level meant for
-- ring-buffer/copy-log review, not real-time chat output. Gated on both the
-- debug master switch and the category being actively traced, so sprinkling
-- Logger:Trace() calls through any module costs nothing when tracing is off.
-------------------------------------------------------------------------------

function Logger:Trace(category, message, data)

    if not self:IsDebugEnabled() then
        return
    end

    if not self:IsTraceCategoryEnabled(category) then
        return
    end

    local text = tostring(message)
    local serializedData = self:SerializeData(data)

    if serializedData ~= "" then
        text = text .. " " .. serializedData
    end

    AppendEntry(self, "TRACE", category, text)

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.ServiceManager:Register("Logger", Logger)

return Logger
