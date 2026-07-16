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

-------------------------------------------------------------------------------
-- Copy Character Link
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Quick Note
--
-- data.playerKey/data.name/data.realm/data.classFile identify who this
-- note is for -- passed through StaticPopup_Show's own data parameter,
-- the same mechanism Storage's own Execute confirmation already uses.
-- Ensures a journal record exists first (GetOrCreatePlayerRecord, the
-- same call FinalizeCompletedRunForRoster already makes) so Quick Note
-- works for any right-clicked player, not only ones already tracked via
-- a completed dungeon run.
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

        journalModule:GetOrCreatePlayerRecord({ key = data.playerKey, name = data.name, realm = data.realm, classFile = data.classFile or "" })
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

    -- Calling :CreateButton() again on the element CreateButton just
    -- returned turns it into a submenu automatically (confirmed via
    -- Warcraft Wiki's Blizzard Menu implementation guide) -- exactly one
    -- top-level entry added to Blizzard's own menu, matching the
    -- feature's own "keep the Blizzard context menu clean" requirement.
    local submenu = rootDescription:CreateButton(AC.L:Get("PlayerJournal.ContextMenuTitle"))

    submenu:CreateButton(AC.L:Get("PlayerJournal.MenuOpenJournal"), function()

        local journalWindow = AC.Core and AC.Core:GetModule("PlayerJournalWindow")

        if journalWindow then
            journalWindow:Show(playerKey)
        end

    end)

    local journalModule = AC.Core and AC.Core:GetModule("PlayerJournal")

    submenu:CreateButton(AC.L:Get("PlayerJournal.MenuQuickNote"), function()

        local dialog = StaticPopup_Show("AZEROTHCOMPANION_PLAYERJOURNAL_QUICKNOTE")

        if dialog then
            dialog.data = { playerKey = playerKey, name = name, realm = realm }
        end

    end)

    -- CreateCheckbox(text, isSelectedFunc, setSelectedFunc) is confirmed
    -- real via Warcraft Wiki's own Blizzard Menu implementation guide
    -- (used there for an in-game reputation-panel checkbox with the same
    -- 3-argument shape). Ensures a journal record exists first so
    -- toggling Favorite works for any right-clicked player, not only
    -- ones already tracked via a completed dungeon run.
    submenu:CreateCheckbox(AC.L:Get("PlayerJournal.MenuFavoritePlayer"),
        function() return journalModule and journalModule:IsFavorite(playerKey) end,
        function()

            if journalModule then
                journalModule:GetOrCreatePlayerRecord({ key = playerKey, name = name, realm = realm, classFile = "" })
                journalModule:ToggleTag(playerKey, "FavoritePlayer")
            end

        end)

    local communityModule = AC.Core and AC.Core:GetModule("Community")
    local hasCommunityNotes = communityModule and communityModule:IsModuleEnabled() and #communityModule:GetNotesForPlayer(playerKey) > 0

    if hasCommunityNotes then

        submenu:CreateCheckbox(AC.L:Get("PlayerJournal.MenuHideCommunityNotes"),
            function() return journalModule and journalModule:GetPlayerRecord(playerKey) and journalModule:GetPlayerRecord(playerKey).hideCommunityNotes == true end,
            function()

                local record = journalModule and journalModule:GetPlayerRecord(playerKey)

                if record then
                    record.hideCommunityNotes = not record.hideCommunityNotes
                end

            end)

    end

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

local TAGS_TO_HOOK =
{
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
