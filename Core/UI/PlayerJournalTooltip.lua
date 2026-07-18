-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Tooltip
--
-- Appends Player Journal facts to Blizzard's own unit tooltip via
-- TooltipDataProcessor.AddTooltipPostCall (the current, standard
-- technique for tooltip extension -- confirmed via real published addon
-- source before use, high confidence). Gated on one master
-- "Show Journal Info in Tooltips" setting. Read-only throughout -- never
-- mutates a record, and adds only the lines that actually have real data
-- (never a placeholder for a fact that doesn't exist), the same "omit
-- rather than fabricate" discipline every other tooltip/card in this
-- addon already follows. Renders nothing at all for a player with no
-- journal record.
--
-- Stabilization pass -- two confirmed live errors, one architecture:
--
--   1. tooltip:GetUnit()'s returned unit token, passed to UnitIsPlayer():
--      "Secret values are only allowed during untainted execution."
--   2. The postcall's own `data.guid` field, passed to GetPlayerInfoByGUID():
--      "attempt to index local 'guid' (a secret string value, while
--      execution tainted by AzerothCompanion)."
--
-- Both failures are the same underlying policy, not two separate bugs:
-- Blizzard now treats every unit-identifying value reachable from inside
-- a TooltipDataProcessor postcall as "secret" -- opaque to addon code,
-- regardless of which specific field or API is used to reach it. There
-- is no "safe" identity field to find here; the correct fix is to stop
-- resolving identity from inside this callback entirely.
--
-- Redesigned architecture: identity is resolved ENTIRELY outside this
-- callback, in ordinary Blizzard game-event handlers (GROUP_ROSTER_UPDATE,
-- UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED) --
-- the same trusted UnitFullName/UnitGUID-on-a-plain-unit-token pattern
-- this addon's own roster capture already uses and has verified
-- (VerificationService's pj.rosterUnitAccessors), just generalized to a
-- few more always-legal global tokens (mouseover/target/focus, not just
-- party1-4). These handlers are ordinary addon code reacting to ordinary
-- events -- nothing here ever touches a value that originated from
-- inside a secure UI callback, so nothing here can ever be "secret."
-- Results are cached by display name into KnownUnits.
--
-- The TooltipDataProcessor postcall itself now does the one thing that
-- API is actually documented and intended for: reading the tooltip's own
-- RENDERED line text (data.lines) -- never tooltip:GetUnit(), never
-- data.guid, never any unit token at all. It cross-references the
-- tooltip's first (name) line against KnownUnits to find which
-- already-resolved player, if any, this tooltip corresponds to.
--
-- Two things this design assumes rather than has independently confirmed
-- against a live client (flagged pj.tooltipLineTextSafe in
-- VerificationService, NEEDS_LIVE): that data.lines/line text itself is
-- NOT also a secret value (high confidence -- it's TooltipDataProcessor's
-- own stated, documented purpose, unlike the supplementary guid field),
-- and that a Unit tooltip's first line is reliably just the plain name.
-- If either ever proves wrong, the honest escalation is to stop reading
-- GameTooltip's own content at all and decorate via a fully separate,
-- addon-owned frame instead -- not another attempt to parse tooltip
-- internals more cleverly.
--
-- Secret Value Audit -- that NEEDS_LIVE assumption is no longer taken on
-- faith while awaiting a human's confirmation: the actual read of
-- data.lines[1].leftText below now goes through AC.SecretValueGuard:TryRead
-- (Core/Security/SecretValueGuard.lua), the one shared, addon-wide way to
-- attempt a read of Blizzard secure-callback data that might throw. This
-- callback fires for EVERY unit tooltip (players and NPCs alike -- Enum.
-- TooltipDataType.Unit is not player-scoped), so it is exercised constantly
-- in NPC-dense content like Mythic+ dungeons -- if data.lines ever does
-- prove secret (for NPC tooltips specifically, or in some content this
-- addon hasn't hit yet), this tooltip enhancement now silently skips that
-- one tooltip instead of throwing a visible Lua error to the player. This
-- is not a nil-guard hiding this addon's own bug -- it is the same
-- attempt-and-catch technique every other addon hooking this same Blizzard
-- callback has converged on, because there is no way to know in advance
-- whether a given field is secret; see SecretValueGuard's own header.
--
-- Startup-order fix, confirmed by a real /reload Lua error: the initial
-- RefreshKnownUnits() call below is now deferred to FRAMEWORK_INITIALIZED
-- rather than running immediately at file-load time -- see the comment
-- directly above that event registration for the full explanation.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

-------------------------------------------------------------------------------
-- Known Units Cache
-------------------------------------------------------------------------------

local KNOWN_UNIT_TOKENS = { "player", "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }

local KnownUnits = {} -- display text (name, or name-realm) -> playerKey, or false if ambiguous

local function ResolveUnit(unit)

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return
    end

    local name, realm = UnitFullName(unit)

    if not name or name == "" then
        return
    end

    local resolvedRealm = (realm and realm ~= "") and realm or (GetRealmName and GetRealmName()) or ""
    local playerKey = name .. "-" .. resolvedRealm

    -- Cached under both the bare name (same-realm display) and the
    -- name-realm combo (cross-realm display) -- the tooltip's own
    -- rendered name line uses whichever form Blizzard's tooltip code
    -- itself chooses to show, not something this addon controls.
    for _, displayKey in ipairs({ name, playerKey }) do

        if KnownUnits[displayKey] == nil then
            KnownUnits[displayKey] = playerKey
        elseif KnownUnits[displayKey] ~= playerKey then

            -- Two different real players currently resolve to the same
            -- display text -- ambiguous; decline to guess which one a
            -- tooltip showing this text actually refers to, rather than
            -- silently attributing it to whichever was resolved first.
            KnownUnits[displayKey] = false

        end

    end

end

local function RefreshKnownUnits()

    KnownUnits = {}

    if AC.ConfigurationManager:GetValue("PlayerJournal", "enableTooltips") ~= true then
        return
    end

    for _, unit in ipairs(KNOWN_UNIT_TOKENS) do
        ResolveUnit(unit)
    end

end

-- Startup-order fix -- RefreshKnownUnits() (via AC.ConfigurationManager:GetValue)
-- unconditionally calls into AC.DatabaseService:GetProfile(), which throws
-- if called before DatabaseService:Initialize() has run (self.DB is nil
-- until then). This file is a bare UI hook, not a registered Service/
-- Module, so it has no Initialize()/Enable() the framework calls at the
-- right time -- its own top-level code runs the instant WoW loads this
-- file, which is a distinct, EARLIER phase than framework bootstrap
-- (Core:Initialize(), triggered by ADDON_LOADED, which only fires after
-- every .toc file has finished loading). Calling RefreshKnownUnits()
-- directly here was conflating "my file loaded" with "the framework is
-- ready." FRAMEWORK_INITIALIZED (fired once, as the last step of
-- Core:Initialize(), after DatabaseService:Initialize() has already set
-- self.DB) is the existing, already-documented "framework ready" event --
-- registered the same way every other framework-event listener in this
-- codebase already registers at file-load time (registering any of the
-- events below is always safe, regardless of framework state -- it's
-- pure EventManager bookkeeping; only INVOKING the listener early was
-- ever the problem).
AC.Events:Register("GROUP_ROSTER_UPDATE", RefreshKnownUnits)
AC.Events:Register("UPDATE_MOUSEOVER_UNIT", RefreshKnownUnits)
AC.Events:Register("PLAYER_TARGET_CHANGED", RefreshKnownUnits)
AC.Events:Register("PLAYER_FOCUS_CHANGED", RefreshKnownUnits)
AC.Events:Register("FRAMEWORK_INITIALIZED", RefreshKnownUnits)

-------------------------------------------------------------------------------
-- Tooltip Postcall -- presentation only, never touches a unit token or GUID
-------------------------------------------------------------------------------

local function StripTooltipColorCodes(text)

    if not text then
        return nil
    end

    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))

end

local function OnUnitTooltip(tooltip, data)

    if tooltip ~= GameTooltip then
        return
    end

    if AC.ConfigurationManager:GetValue("PlayerJournal", "enableTooltips") ~= true then
        return
    end

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    if not journalModule then
        return
    end

    local ok, displayName = AC.SecretValueGuard:TryRead("tooltip.lineText", function()

        local firstLine = data and data.lines and data.lines[1]
        return firstLine and StripTooltipColorCodes(firstLine.leftText)

    end)

    if not ok or not displayName then
        return
    end

    local playerKey = KnownUnits[displayName]

    if not playerKey then
        return
    end

    local record = journalModule:GetPlayerRecord(playerKey)

    if not record then
        return
    end

    tooltip:AddLine(" ")

    if record.tags["FavoritePlayer"] then
        tooltip:AddLine(AC.L:Format("PlayerJournal.TooltipFavorite", AC.DashboardFormat.STAR_FILLED), 1, 0.82, 0)
    end

    if record.stats.runsTogether > 0 then
        tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipRunsTogether"), tostring(record.stats.runsTogether), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    end

    if record.lastSeen and record.lastSeen > 0 then
        tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipLastSeen"), AC.Presentation.FormatDate(record.lastSeen, "short"), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    end

    local latestNote = record.notes[#record.notes]

    if latestNote and latestNote.text and latestNote.text ~= "" then

        local preview = latestNote.text

        if #preview > 60 then
            preview = preview:sub(1, 60) .. "..."
        end

        tooltip:AddLine(AC.L:Format("PlayerJournal.TooltipNotePreviewFormat", preview), 0.6, 0.85, 1, true)

    end

    local communityModule = AC.Core and AC.Core:GetModule("Community")

    if communityModule and communityModule:IsModuleEnabled() and not record.hideCommunityNotes then

        local communityObservationCount = #communityModule:GetObservationsForPlayer(playerKey)

        if communityObservationCount > 0 then
            tooltip:AddDoubleLine(AC.L:Get("PlayerJournal.TooltipCommunityObservations"), tostring(communityObservationCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
        end

    end

    tooltip:Show()

end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
