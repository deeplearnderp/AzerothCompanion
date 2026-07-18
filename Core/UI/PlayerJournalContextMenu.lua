-------------------------------------------------------------------------------
-- Azeroth Companion
-- Player Journal Context Menu
--
-- The addon's first hook into a Blizzard-owned UI frame (confirmed via
-- repo-wide grep before writing this -- zero existing precedent
-- anywhere else). Adds exactly one submenu, "Azeroth Companion", to
-- Blizzard's own player right-click menu via Menu.ModifyMenu (the
-- current, post-Dragonflight menu API, confirmed via Warcraft Wiki's own
-- Blizzard Menu implementation guide).
--
-- The exact MENU_UNIT_* tag name for "any party member regardless of
-- slot" could not be pinned down without a live client -- Warcraft
-- Wiki's own guide only confirms the MENU_UNIT_<UNIT_TYPE> format with
-- PARTY1 as one example, not whether a slot-independent tag also exists.
-- Rather than guess wrong and silently fail, this registers defensively
-- against every plausible tag, each in its own pcall so one bad tag name
-- never breaks the others -- Menu.ModifyMenu registering a callback for
-- a tag that never actually fires is a harmless no-op, not an error
-- (unlike RegisterEvent on a nonexistent event, which does throw).
-- Flagged as ctxmenu.unitMenuTags (Needs Live Verification) in
-- VerificationService's registry. Nothing else in this feature depends
-- on this hook succeeding -- the Journal window opens via the minimap
-- icon, slash command, and Dashboard regardless.
--
-- MENU_UNIT_SELF -- live testing (Retail 12.0.7) showed the submenu
-- never appears when right-clicking your own player frame, or your
-- target frame while self-targeted. Traced against Blizzard's own
-- current client source rather than guessed: right-clicking yourself
-- resolves to a "SELF" which-value, a genuinely separate UnitPopup
-- registration from "PLAYER" (used for other, out-of-group players) --
-- see TAGS_TO_HOOK's own comment below for the full trace. MENU_UNIT_PLAYER
-- was never going to fire for a self-context menu; it was never wired to
-- the wrong condition, it was just never the right tag to begin with.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

-------------------------------------------------------------------------------
-- Identity Resolution
--
-- contextData's exact shape for these tags is not confirmed either --
-- tries the field names Blizzard's own documented unit-menu contextData
-- commonly carries (`unit`, then `name`/`server` as a fallback), bails
-- cleanly (no submenu added) rather than guessing at a player identity.
--
-- Secret Value Audit -- contextData.unit, read from inside a Menu.ModifyMenu
-- callback, is structurally identical to the two already-CONFIRMED-broken
-- PlayerJournal tooltip reads (tooltip:GetUnit(), the postcall's own
-- data.guid field): a unit-identifying value Blizzard's own secure menu
-- dispatch hands to this callback, which may be secret and throw the
-- instant UnitExists/UnitFullName touch it. Previously flagged
-- ctxmenu.contextDataUnitSecretValue (NEEDS_LIVE) but left unguarded while
-- awaiting a human's confirmation; now routed through the same shared
-- AC.SecretValueGuard:TryRead every secure-callback read in this addon
-- uses, covering both the unit-token path and the name/server fallback in
-- one attempt -- if either throws, this falls through to "no identity
-- resolved," the same clean bail-out this function already used for a
-- contextData shape it didn't recognize.
-------------------------------------------------------------------------------

local function ResolvePlayerKey(contextData)

    if not contextData then
        return nil
    end

    local ok, identity = AC.SecretValueGuard:TryRead("ctxmenu.contextData", function()

        if contextData.unit and UnitExists(contextData.unit) then

            local unitName, unitRealm = UnitFullName(contextData.unit)
            return { name = unitName, realm = unitRealm }

        elseif contextData.name then
            return { name = contextData.name, realm = contextData.server or contextData.realm }
        end

    end)

    local name = ok and identity and identity.name
    local realm = ok and identity and identity.realm

    if not name or name == "" then
        return nil
    end

    local resolvedRealm = (realm and realm ~= "") and realm or (GetRealmName and GetRealmName()) or ""

    return name .. "-" .. resolvedRealm, name, resolvedRealm

end

-- "Is the right-clicked player the current character?" -- compared
-- against the already-resolved name/realm above, not a second read of
-- contextData.unit. Not every hooked tag guarantees a live unit token
-- (see ResolvePlayerKey's own name/server fallback branch), so a
-- UnitIsUnit(contextData.unit, "player") check would only work for the
-- subset that does; this covers every tag uniformly with values already
-- in hand. UnitName("player")/GetRealmName() are ordinary, always-safe
-- calls -- a literal "player" token, never a value read from inside this
-- secure callback -- unlike contextData.unit itself.
local function IsCurrentPlayer(name, realm)

    return name == UnitName("player") and realm == GetRealmName()

end

-------------------------------------------------------------------------------
-- Copy Character Link
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Quick Note
--
-- data.playerKey/data.name/data.realm/data.classFile identify who this
-- note is for -- passed through StaticPopup_Show's own data parameter,
-- the same mechanism Storage's own Execute confirmation already uses.
-- Saving a note is explicit persistence intent, so the accept handler
-- qualifies the player through PlayerJournalModule before writing the note.
-------------------------------------------------------------------------------

StaticPopupDialogs["AZEROTHCOMPANION_PLAYERJOURNAL_QUICKNOTE"] =
{
    text = "",
    button1 = _G.YES or "Save",
    button2 = _G.CANCEL or "Cancel",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)

        local data = self.data
        local text = self.editBox:GetText()

        if not data or not data.playerKey or not text or text:match("^%s*$") then
            return
        end

        local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

        if not journalModule then
            return
        end

        journalModule:RecordRelationship(
            { key = data.playerKey, name = data.name, realm = data.realm, classFile = data.classFile or "" },
            journalModule.RelationshipTypes.PersonalNote)
        journalModule:AddNote(data.playerKey, text)

    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Copy Character Link
-------------------------------------------------------------------------------

StaticPopupDialogs["AZEROTHCOMPANION_PLAYERJOURNAL_COPYLINK"] =
{
    text = "",
    button1 = _G.OKAY or "Okay",
    hasEditBox = true,
    editBoxWidth = 240,
    OnShow = function(self)

        self.editBox:SetText(self.data or "")
        self.editBox:HighlightText()
        self.editBox:SetFocus()

    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Submenu
-------------------------------------------------------------------------------

local function AddPlayerJournalSubmenu(_, rootDescription, contextData)

    local playerKey, name, realm = ResolvePlayerKey(contextData)

    if not playerKey then
        return
    end

    local isSelf = IsCurrentPlayer(name, realm)

    -- Calling :CreateButton() again on the element CreateButton just
    -- returned turns it into a submenu automatically (confirmed via
    -- Warcraft Wiki's Blizzard Menu implementation guide) -- exactly one
    -- top-level entry added to Blizzard's own menu, matching the
    -- feature's own "keep the Blizzard context menu clean" requirement.
    local submenu = rootDescription:CreateButton(AC.L:Get("PlayerJournal.ContextMenuTitle"))

    submenu:CreateButton(AC.L:Get("PlayerJournal.MenuOpenJournal"), function()

        local journalWindow = AC.Core and AC.Core:GetModule("PlayerJournalWindow")

        if journalWindow then
            journalWindow:Show(playerKey, { key = playerKey, name = name, realm = realm, classFile = "" })
        end

    end)

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")
    local communityModule = AC.Core and AC.Core:GetModule("Community")

    -- Community Observations submenu -- gated on the whole feature being
    -- enabled (not on the player already having observations, unlike the
    -- old flat "Hide Community Notes" checkbox this replaces) since
    -- "Add Observation" must be reachable for a player with zero
    -- observations too. Nested one level deeper than
    -- AddPlayerJournalSubmenu's own top-level button -- the same
    -- CreateButton-called-twice submenu-promotion mechanic (see this
    -- function's own header comment), not yet independently confirmed at
    -- this nesting depth; flagged alongside ctxmenu.modifyMenu in
    -- VerificationService.
    if communityModule and communityModule:IsModuleEnabled() then

        local communitySubmenu = submenu:CreateButton(AC.L:Get("PlayerJournal.MenuCommunityObservations"))

        -- Self-observations are a first-class case, not a special mode --
        -- "View"/"Add" call the exact same click handlers either way (a
        -- self-observation is stored, retrieved, and dialog-filled through
        -- the identical CommunityModule/ObservationDialog API as any other
        -- player's), only the label text differs. No duplicate code path.
        local viewLabel = isSelf and AC.L:Get("PlayerJournal.MenuViewMyObservations") or AC.L:Get("PlayerJournal.MenuViewObservations")
        local addLabel = isSelf and AC.L:Get("PlayerJournal.MenuAddObservationAboutMyself") or AC.L:Get("PlayerJournal.MenuAddObservation")

        communitySubmenu:CreateButton(viewLabel, function()

            local journalWindow = AC.Core and AC.Core:GetModule("PlayerJournalWindow")

            if journalWindow then
                journalWindow:Show(playerKey, { key = playerKey, name = name, realm = realm, classFile = "" })
                journalWindow:NavigateTab("CommunityObservations")
            end

        end)

        -- "No hunting through windows" -- opens AC.ObservationDialog
        -- directly, without opening the Journal or persisting a record.
        -- Saving the observation is the qualifying action, not opening it.
        communitySubmenu:CreateButton(addLabel, function()

            AC.ObservationDialog:Show(playerKey, name, realm)

        end)

        -- Hiding your own observations from yourself makes no sense --
        -- omitted entirely for self rather than shown and disabled, the
        -- same "don't show a control that can't mean anything" discipline
        -- the rest of this addon already follows.
        if not isSelf and #communityModule:GetObservationsForPlayer(playerKey) > 0 then

            -- Explicit, per-player wording -- "Hide Observations" alone is
            -- ambiguous (hide this player's observations? ignore this
            -- author? hide the whole section? disable the feature?). This
            -- toggle is specifically "don't show me THIS player's
            -- observations," so it names the player directly, the same
            -- way Blizzard's own unit-context-menu items do (Whisper
            -- <name>, Invite <name> to Party).
            communitySubmenu:CreateCheckbox(AC.L:Format("PlayerJournal.MenuHideObservationsFormat", name),
                function() return journalModule and journalModule:GetPlayerRecord(playerKey) and journalModule:GetPlayerRecord(playerKey).hideCommunityNotes == true end,
                function()

                    local record = journalModule and journalModule:GetPlayerRecord(playerKey)

                    if record then
                        record.hideCommunityNotes = not record.hideCommunityNotes
                    end

                end)

        end

    end

    submenu:CreateButton(AC.L:Get("PlayerJournal.MenuPersonalNotes"), function()

        local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_QUICKNOTE")

        if dialog then
            dialog.data = { playerKey = playerKey, name = name, realm = realm }
        end

    end)

    if journalModule and not journalModule:GetPlayerRecord(playerKey) then

        submenu:CreateButton(AC.L:Get("PlayerJournal.MenuAddToJournal"), function()

            journalModule:RecordRelationship(
                { key = playerKey, name = name, realm = realm, classFile = "" },
                journalModule.RelationshipTypes.Explicit)

        end)

    end

    -- CreateCheckbox(text, isSelectedFunc, setSelectedFunc) is confirmed
    -- real via Warcraft Wiki's own Blizzard Menu implementation guide
    -- (used there for an in-game reputation-panel checkbox with the same
    -- 3-argument shape). Favorite is explicit persistence intent, so its
    -- handler qualifies an untracked player before toggling the owned tag.
    submenu:CreateCheckbox(AC.L:Get("PlayerJournal.MenuFavoritePlayer"),
        function() return journalModule and journalModule:IsFavorite(playerKey) end,
        function()

            if journalModule then
                journalModule:RecordRelationship(
                    { key = playerKey, name = name, realm = realm, classFile = "" },
                    journalModule.RelationshipTypes.Favorite)
                journalModule:ToggleTag(playerKey, "FavoritePlayer")
            end

        end)

    submenu:CreateButton(AC.L:Get("PlayerJournal.MenuCopyCharacterLink"), function()

        local link = name .. (realm and realm ~= "" and ("-" .. realm) or "")

        local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_COPYLINK")

        if dialog then
            dialog.data = link
        end

    end)

end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------

-- MENU_UNIT_SELF -- confirmed via Blizzard's own current (12.0.7, build
-- 68182) client source, not guessed from the tag-name pattern:
-- UnitPopupManager:OpenMenu() (Interface/AddOns/Blizzard_UnitPopupShared/
-- UnitPopupShared.lua) builds the Menu.ModifyMenu tag as literally
-- "MENU_UNIT_" .. which, and UnitPopupSharedMenus.lua registers a SELF
-- menu ("SELF", UnitPopupMenuSelf) that is a genuinely separate
-- registration from PLAYER ("PLAYER", UnitPopupMenuPlayer) -- right-
-- clicking your own player frame, and right-clicking your target frame
-- while self-targeted (TargetFrame's own dropdown init explicitly checks
-- UnitIsUnit("target", "player") and switches to "SELF" instead of
-- "TARGET" when true), both resolve to this one tag. Previously missing
-- from this list entirely -- Menu.ModifyMenu on an unregistered tag is a
-- silent no-op, so the submenu never appeared for either self-context
-- case, not because AddPlayerJournalSubmenu ran and bailed out.
local TAGS_TO_HOOK =
{
    "MENU_UNIT_SELF",
    "MENU_UNIT_PARTY",
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_FRIEND",
    "MENU_UNIT_GUILD",
    "MENU_UNIT_PARTY1",
    "MENU_UNIT_PARTY2",
    "MENU_UNIT_PARTY3",
    "MENU_UNIT_PARTY4",
}

local function RegisterContextMenuHooks()

    if not Menu or not Menu.ModifyMenu then

        if AC.Logger then
            AC.Logger:Warn("Menu.ModifyMenu is not available -- Player Journal's context menu integration is disabled this session.")
        end

        return

    end

    for _, tag in ipairs(TAGS_TO_HOOK) do

        local ok, err = pcall(Menu.ModifyMenu, tag, AddPlayerJournalSubmenu)

        if not ok and AC.Logger then
            AC.Logger:Error(("PlayerJournal context menu failed to register for tag '%s': %s"):format(tag, tostring(err)))
        end

    end

end

RegisterContextMenuHooks()
