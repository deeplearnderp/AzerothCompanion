-------------------------------------------------------------------------------
-- Azeroth Companion
-- Blizzard API Explorer Service
--
-- Permanent developer-only runtime inspection utility. Resolves Blizzard API
-- functions, parses simple literal arguments, executes protected calls, and
-- formats raw return values. It never persists inspected data.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local DeveloperApiExplorerService = {}
AC.DeveloperApiExplorerService = DeveloperApiExplorerService

local unpack = unpack or table.unpack
local HISTORY_LIMIT = 30

local NAMESPACES =
{
    C_DamageMeter = { "GetAvailableCombatSessions", "GetCombatSessionFromID", "GetCombatSessionFromType", "GetCombatSessionSourceFromID", "GetCombatSessionSourceFromType", "GetSessionDurationSeconds", "IsDamageMeterAvailable" },
    C_DeathRecap = { "GetRecapEvents", "GetRecapLink", "GetRecapMaxHealth", "HasRecapEvents" },
    C_DelvesUI = { "GetActiveDelveTier", "HasActiveDelve" },
    C_MythicPlus = { "GetCurrentAffixes", "GetOwnedKeystoneChallengeMapID", "GetOwnedKeystoneLevel", "GetRunHistory" },
    C_ChallengeMode = { "GetActiveChallengeMapID", "GetActiveKeystoneInfo", "GetMapTable", "GetOverallDungeonScore" },
    C_QuestLog = { "GetInfo", "GetLogIndexForQuestID", "GetNumQuestLogEntries", "IsComplete", "IsOnQuest" },
    C_Item = { "GetItemInfo", "GetItemInfoInstant", "GetItemQualityColor", "IsItemDataCachedByID" },
    C_Container = { "GetContainerItemInfo", "GetContainerNumFreeSlots", "GetContainerNumSlots" },
}

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function SafeToString(value)
    if IsSecret(value) then
        return "<secret>"
    end

    local ok, result = pcall(tostring, value)
    return ok and result or "<tostring failed>"
end

local function Trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function SplitArguments(text)
    local tokens = {}
    local startIndex = 1
    local quote
    local escaped = false

    for index = 1, #text do
        local character = text:sub(index, index)

        if escaped then
            escaped = false
        elseif character == "\\" and quote then
            escaped = true
        elseif quote then
            if character == quote then
                quote = nil
            end
        elseif character == "\"" or character == "'" then
            quote = character
        elseif character == "," then
            tokens[#tokens + 1] = text:sub(startIndex, index - 1)
            startIndex = index + 1
        end
    end

    if quote then
        return nil, "Unterminated quoted string."
    end

    tokens[#tokens + 1] = text:sub(startIndex)
    return tokens
end

local function ParseQuotedString(token)
    local quote = token:sub(1, 1)
    local value = token:sub(2, -2)

    value = value:gsub("\\n", "\n")
    value = value:gsub("\\t", "\t")
    value = value:gsub("\\" .. quote, quote)
    value = value:gsub("\\\\", "\\")

    return value
end

local function ParseArgument(token, index)
    token = Trim(token)

    if token == "" or token == "nil" then
        return true, nil
    elseif token == "true" then
        return true, true
    elseif token == "false" then
        return true, false
    end

    local numberValue = tonumber(token)

    if numberValue ~= nil then
        return true, numberValue
    end

    local first = token:sub(1, 1)
    local last = token:sub(-1)

    if #token >= 2
    and (first == "\"" or first == "'")
    and last == first then
        return true, ParseQuotedString(token)
    end

    return false, ("Argument %d is not a supported literal: %s"):format(index, token)
end

local function BuildNode(key, value, visited, path, parent)
    local node = { key = SafeToString(key), valueType = type(value), path = path, expanded = false, parent = parent }
    if IsSecret(value) then node.value = "<secret>" return node end
    node.value = SafeToString(value)
    if node.valueType ~= "table" and node.valueType ~= "userdata" then return node end
    if visited[value] then node.value = node.value .. " <cycle>" return node end
    visited[value] = true
    node.children = {}
    if node.valueType == "table" then
        for childKey, childValue in pairs(value) do
            node.children[#node.children + 1] = BuildNode(childKey, childValue, visited, path .. "." .. SafeToString(childKey), node)
        end
    end
    local ok, metatable = pcall(getmetatable, value)
    if ok and metatable then
        local metaNode = BuildNode("<metatable>", metatable, visited, path .. ".<metatable>", node)
        node.children[#node.children + 1] = metaNode
        node.methods = {}
        if type(metatable) == "table" then
            local methodSource = type(metatable.__index) == "table" and metatable.__index or metatable
            for methodName, method in pairs(methodSource) do
                if type(method) == "function" then node.methods[#node.methods + 1] = SafeToString(methodName) end
            end
            table.sort(node.methods)
        end
    end
    return node
end

local function FlattenNode(node, lines, depth, visibleOnly)
    local prefix = node.children and #node.children > 0 and (node.expanded and "v " or "> ") or "  "
    lines[#lines + 1] = string.rep("  ", depth) .. prefix .. node.key .. " | " .. node.valueType .. " | " .. node.value
    if node.methods and #node.methods > 0 then lines[#lines + 1] = string.rep("  ", depth + 1) .. "Known Methods | " .. table.concat(node.methods, ", ") end
    if node.children and (not visibleOnly or node.expanded) then
        for _, child in ipairs(node.children) do FlattenNode(child, lines, depth + 1, visibleOnly) end
    end
end

local function SearchNode(node, query, matches)
    local haystack = (node.key .. " " .. node.valueType .. " " .. node.value):lower()
    if haystack:find(query, 1, true) then matches[#matches + 1] = node end
    for _, child in ipairs(node.children or {}) do SearchNode(child, query, matches) end
end

function DeveloperApiExplorerService:Initialize()
    self.History = {}
    self.CurrentResult = nil
end

function DeveloperApiExplorerService:GetNamespaces() return NAMESPACES end
function DeveloperApiExplorerService:GetHistory() return self.History end
function DeveloperApiExplorerService:GetCurrentResult() return self.CurrentResult end
function DeveloperApiExplorerService:RecordHistory(functionName, arguments)
    self.History[#self.History + 1] = { functionName=functionName, arguments=arguments, timestamp=date("%Y-%m-%d %H:%M:%S") }
    while #self.History > HISTORY_LIMIT do table.remove(self.History, 1) end
end

function DeveloperApiExplorerService:GetFavorites()
    local profile = AC.DatabaseService:GetProfile()
    profile.DeveloperApiExplorer = profile.DeveloperApiExplorer or { Favorites = {} }
    profile.DeveloperApiExplorer.Favorites = profile.DeveloperApiExplorer.Favorites or {}
    return profile.DeveloperApiExplorer.Favorites
end

function DeveloperApiExplorerService:IsFavorite(name)
    for _, favorite in ipairs(self:GetFavorites()) do if favorite == name then return true end end
    return false
end

function DeveloperApiExplorerService:ToggleFavorite(name)
    name = Trim(name or "")
    if name == "" then return false end
    local favorites = self:GetFavorites()
    for index, favorite in ipairs(favorites) do
        if favorite == name then table.remove(favorites, index) return false end
    end
    favorites[#favorites + 1] = name
    table.sort(favorites)
    return true
end

function DeveloperApiExplorerService:GetVisibleLines()
    local lines = {}
    for _, node in ipairs(self.CurrentResult and self.CurrentResult.roots or {}) do FlattenNode(node, lines, 0, true) end
    return lines
end

function DeveloperApiExplorerService:GetVisibleNodes()
    local output = {}
    local function append(node, depth)
        output[#output + 1] = { node = node, depth = depth }
        if node.expanded then for _, child in ipairs(node.children or {}) do append(child, depth + 1) end end
    end
    for _, node in ipairs(self.CurrentResult and self.CurrentResult.roots or {}) do append(node, 0) end
    return output
end

function DeveloperApiExplorerService:GetNodeCount()
    local count = 0
    local function countNode(node)
        count = count + 1
        for _, child in ipairs(node.children or {}) do countNode(child) end
    end
    for _, node in ipairs(self.CurrentResult and self.CurrentResult.roots or {}) do countNode(node) end
    return count
end

function DeveloperApiExplorerService:Search(query)
    local matches = {}
    query = Trim(query or ""):lower()
    if query == "" then return matches end
    for _, node in ipairs(self.CurrentResult and self.CurrentResult.roots or {}) do SearchNode(node, query, matches) end
    return matches
end

function DeveloperApiExplorerService:ExportCurrent()
    local result = self.CurrentResult
    if not result then return "No API result." end
    local lines = { "Blizzard API Explorer", "Function: " .. result.functionName, "Arguments: " .. result.arguments, "Timestamp: " .. result.timestamp, "Status: " .. result.metadata.status, "Execution Time: " .. result.metadata.executionTimeMs .. " ms", "Return Count: " .. result.metadata.returnCount }
    if result.metadata.error then lines[#lines + 1] = "Error: " .. result.metadata.error end
    lines[#lines + 1] = ""
    for _, node in ipairs(result.roots or {}) do FlattenNode(node, lines, 0, false) end
    return table.concat(lines, "\n")
end

function DeveloperApiExplorerService:ResolveFunction(functionName)
    functionName = Trim(functionName or "")

    if functionName == "" then
        return nil, "Enter a Blizzard API function name."
    end

    local leafName = functionName:match("([%a_][%w_]*)$") or ""
    local inspectionPrefix = leafName:match("^(Get)") or leafName:match("^(Is)")
        or leafName:match("^(Has)") or leafName:match("^(Can)")
        or leafName:match("^(Does)") or leafName:match("^(Should)")
        or leafName:match("^(Find)") or leafName:match("^(Calculate)")
        or leafName:match("^(Fetch)")
    if not inspectionPrefix then
        return nil, "Only read-only inspection functions are allowed."
    end

    local current = _G

    for part in functionName:gmatch("[^%.]+") do
        if not part:match("^[%a_][%w_]*$") then
            return nil, "Function names may contain only identifiers separated by periods."
        end

        if type(current) ~= "table" then
            return nil, ("Cannot resolve '%s' through a non-table value."):format(functionName)
        end

        current = current[part]

        if current == nil then
            return nil, ("Function not found: %s"):format(functionName)
        end
    end

    if type(current) ~= "function" then
        return nil, ("Resolved value is %s, not a function: %s"):format(type(current), functionName)
    end

    return current
end


function DeveloperApiExplorerService:ParseArguments(argumentText)
    argumentText = Trim(argumentText or "")

    if argumentText == "" then
        return { n = 0 }
    end

    local tokens, splitError = SplitArguments(argumentText)

    if not tokens then
        return nil, splitError
    end

    local arguments = { n = #tokens }

    for index = 1, #tokens do
        local ok, valueOrError = ParseArgument(tokens[index], index)

        if not ok then
            return nil, valueOrError
        end

        arguments[index] = valueOrError
    end

    return arguments
end


function DeveloperApiExplorerService:Execute(functionName, argumentText)
    local started = debugprofilestop and debugprofilestop() or (GetTime() * 1000)
    functionName, argumentText = Trim(functionName or ""), argumentText or ""
    self:RecordHistory(functionName, argumentText)
    local apiFunction, resolveError = self:ResolveFunction(functionName)

    if not apiFunction then
        local elapsed = (debugprofilestop and debugprofilestop() or (GetTime()*1000)) - started
        self.CurrentResult = { functionName=functionName, arguments=argumentText, timestamp=date("%Y-%m-%d %H:%M:%S"), roots={}, metadata={status="Failed", returnCount=0, executionTimeMs=string.format("%.3f", elapsed), error=resolveError} }
        return false, resolveError, { resolveError }
    end

    local arguments, argumentError = self:ParseArguments(argumentText)

    if not arguments then
        local elapsed = (debugprofilestop and debugprofilestop() or (GetTime()*1000)) - started
        self.CurrentResult = { functionName=functionName, arguments=argumentText, timestamp=date("%Y-%m-%d %H:%M:%S"), roots={}, metadata={status="Failed", returnCount=0, executionTimeMs=string.format("%.3f", elapsed), error=argumentError} }
        return false, argumentError, { argumentError }
    end

    local execution = Pack(pcall(apiFunction, unpack(arguments, 1, arguments.n)))

    if not execution[1] then
        local errorText = SafeToString(execution[2])
        local message = "API error: " .. errorText
        local elapsed = (debugprofilestop and debugprofilestop() or (GetTime()*1000)) - started
        self.CurrentResult = { functionName=functionName, arguments=argumentText, timestamp=date("%Y-%m-%d %H:%M:%S"), roots={}, metadata={status="Failed", returnCount=0, executionTimeMs=string.format("%.3f", elapsed), error=message} }
        return false, message, { message }
    end

    local returnCount = execution.n - 1
    local roots, visited = {}, {}
    local inspection = Pack(pcall(function()
        for index = 1, returnCount do roots[#roots + 1] = BuildNode("Return " .. index, execution[index + 1], visited, "Return " .. index) end
    end))
    if not inspection[1] then
        local message = "Result inspection error: " .. SafeToString(inspection[2])
        local elapsed = (debugprofilestop and debugprofilestop() or (GetTime()*1000)) - started
        self.CurrentResult = { functionName=functionName, arguments=argumentText, timestamp=date("%Y-%m-%d %H:%M:%S"), roots={}, metadata={status="Failed", returnCount=returnCount, executionTimeMs=string.format("%.3f", elapsed), error=message} }
        return false, message, { message }
    end
    local elapsed = (debugprofilestop and debugprofilestop() or (GetTime()*1000)) - started
    self.CurrentResult = { functionName=functionName, arguments=argumentText, timestamp=date("%Y-%m-%d %H:%M:%S"), roots=roots, metadata={status="Success", returnCount=returnCount, executionTimeMs=string.format("%.3f", elapsed)} }
    return true, ("Executed successfully with %d return value(s)."):format(returnCount), self:GetVisibleLines()
end


AC.ServiceManager:Register("DeveloperApiExplorerService", DeveloperApiExplorerService)

return DeveloperApiExplorerService
