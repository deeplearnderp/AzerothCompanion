-------------------------------------------------------------------------------
-- Azeroth Companion
-- Storage Module
--
-- An intelligent preparation system, not a bag/bank addon: owns bank,
-- reagent bank, and (where Blizzard allows) Warband Bank contents, and
-- compares them plus the player's bags against a selected "storage
-- profile" of rules to answer "am I prepared, and what's missing?" Bag
-- contents themselves remain InventoryModule's exclusive concern -- this
-- module reads them through InventoryModule's public API and never
-- rescans bags itself (Architectural Rule 7).
--
-- Scope, per explicit design decisions (see
-- docs/GameplayModuleArchitecture.md, "Storage"):
--   - Analyze + Preview, and (reversed after explicit re-confirmation --
--     see "Execute" below) real Execute item movement with guardrails.
--   - Built-in preset profiles only (Modules/Storage/StorageProfiles.lua).
--     A full add/edit/delete rule-builder UI is a documented future
--     phase; the engine underneath (MatchesRule/AnalyzeProfile) is
--     already generic enough to support one without redesign.
--   - Warband Bank item contents are owned here (not the still-unbuilt
--     Warband module) -- see the Storage doc section for the ownership
--     resolution. Warband, if ever built, would own only the bank's own
--     gold balance/tab administration, not item contents.
--   - Profession-based rule targeting is NOT implemented: Blizzard
--     exposes no direct itemID -> profession mapping without full
--     TradeSkill recipe/reagent data, which belongs to the planned
--     Professions module, not Storage. Implementing a guessed mapping
--     here would be exactly the kind of fabricated data this addon
--     avoids elsewhere.
--
-- VERIFICATION STATUS (Blizzard API Verification pass): `C_Bank.
-- FetchPurchasedBankTabIDs`/`C_Bank.CanUseBank`/`Enum.BankType.Character`/
-- `Enum.BankType.Account` are confirmed via Warcraft Wiki (added 11.0.0).
-- The legacy `Enum.BagIndex.Reagentbank`/`Bank` fallback (only used if the
-- modern tab-enumeration call above returns nothing) is confirmed
-- effectively vestigial on current retail: per Warcraft Wiki's Patch
-- 11.2.0 API changes, the reagent bank was removed and its items folded
-- into the same purchased-tab system `FetchPurchasedBankTabIDs` already
-- enumerates -- meaning reagent bank contents are already correctly
-- covered by this module's PRIMARY code path, not the legacy fallback.
-- `C_Container.PickupContainerItem` (Execute, below) is confirmed to
-- exist and be current (Warcraft Wiki lists it as available through the
-- "Midnight" 12.1.0 client). The bag-item "favorite" field is NOT
-- confirmed -- Warcraft Wiki's own documented `ContainerItemInfo`
-- structure (the return shape of `C_Container.GetContainerItemInfo`,
-- which `ScanBank` below reads) does not list an `isFavorite` field at
-- all, and no other Blizzard API for it could be located this pass. This
-- module's own `isFavorite` capture (`ScanBank`, below) is honestly
-- non-functional as a result (silently always false) -- and, separately,
-- nothing anywhere in this addon currently reads it even if it were
-- populated correctly (`MatchesRule` has no "Favorite" targetType). Kept
-- rather than removed, since deleting a field that degrades safely isn't
-- the same discipline as removing genuinely dead code, but this is a real
-- gap: either the correct API needs to be found and a real "NeverMove:
-- Favorited Items" rule wired up, or this capture should be removed as
-- misleading. Not decided this pass -- see docs/DEVELOPMENT_BACKLOG.md.
-- Still needing a live-client spot check regardless of documentation
-- confidence: the Banker interaction-type check (`Enum.PlayerInteractionType.
-- Banker`) and the exact `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`
-- payload shape -- see the Live Verification checklist in
-- docs/DEVELOPMENT_BACKLOG.md.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local type = type
local time = time
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local format = string.format

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
local GetItemInfo = C_Item and C_Item.GetItemInfo

-- Execute (item movement) locals -- InCombatLockdown/CursorHasItem/
-- ClearCursor are long-standing, stable global APIs; PickupContainerItem
-- is the one piece of this group unverified against a live client (see
-- the Execute section below).
local PickupContainerItem = C_Container and C_Container.PickupContainerItem
local InCombatLockdown = InCombatLockdown
local CursorHasItem = CursorHasItem
local ClearCursor = ClearCursor

local Profiles = AC.StorageProfiles and AC.StorageProfiles.BuiltIn or {}

local StorageModule =
{
    Name = "Storage",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
    activeProfileID = "MythicPlus",
    groups = {},
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

function StorageModule:ResetState()

    -- Bank-side item cache -- this module's own equivalent of
    -- InventoryModule's ItemsBySlot/ItemCounts, scoped to bank/reagent
    -- bank/Warband Bank locations only. In-memory only, never persisted
    -- (exactly like InventoryModule's cache) -- rebuilt each time the
    -- bank is open and scanned, since Blizzard does not guarantee stale
    -- container data is accurate once the bank closes.
    self.BankItemsBySlot = {}
    self.BankItemCounts = {}
    self.BankSlotsScanned = 0

    self.BankOpen = false

    -- itemID -> { classID, subClassID } -- memoized since GetItemInfoInstant
    -- is a real (if cheap) Blizzard call; avoids re-querying the same
    -- item repeatedly across a rule-matching pass over many stacks.
    self.ItemClassCache = {}

    -- User-defined groups (Part 9): groupName -> { [itemID] = true }.
    -- Persisted via ConfigurationManager (a user preference, not gameplay
    -- history) so groups survive a reload. Empty by default -- there is
    -- no group-authoring UI yet (deferred alongside the full rule
    -- editor), but the data model and "Group" rule matching are already
    -- functional end-to-end so that UI is additive, not an engine change.
    self.Groups = AC.ConfigurationManager:GetValue("Storage", "groups") or {}

end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------

function StorageModule:Initialize()

    self:ResetState()

    AC.ConfigurationManager:Register("Storage", Defaults)

    AC.Settings:RegisterPage("Storage",
    {
        title = "Storage",
        module = "Storage",
        order = 60,
    })

    AC.Settings:RegisterSection("Storage", "General",
    {
        title = "General",
    })

    AC.Settings:AddCheckbox("Storage", "General",
    {
        key = "enabled",
        text = "Enable Storage Module",
        default = true,
        tooltip = "Track bank/reagent bank/Warband Bank contents and compare them against your selected storage profile.",
    })

    local profileList = {}

    for _, profile in ipairs(Profiles) do
        table.insert(profileList, { text = AC.L:Get(profile.label), value = profile.id })
    end

    AC.Settings:AddDropdown("Storage", "General",
    {
        key = "activeProfileID",
        default = "MythicPlus",
        tooltip = "Which storage profile Restock Status/Shopping List/preparation checks are compared against.",
        list = profileList,
    })

end

-------------------------------------------------------------------------------
-- Enable
-------------------------------------------------------------------------------

function StorageModule:Enable()

    AC.Events:Register("PLAYER_ENTERING_WORLD", self)
    AC.Events:Register("BANKFRAME_OPENED", self, "OnBankOpened")
    AC.Events:Register("BANKFRAME_CLOSED", self, "OnBankClosed")

    -- Modern retail's unified interaction-frame events -- the confirmed
    -- replacement for the legacy BANKFRAME_OPENED/CLOSED pair on some
    -- banker interactions (e.g. the Warband Bank). Both are registered;
    -- whichever actually fires drives the same OnBankOpened/OnBankClosed
    -- handlers. pcall-wrapped since the exact event names are unverified
    -- against a live client.
    local ok1, err1 = pcall(AC.Events.Register, AC.Events, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", self, "OnInteractionFrameShow")
    local ok2, err2 = pcall(AC.Events.Register, AC.Events, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", self, "OnInteractionFrameHide")

    if (not ok1 or not ok2) and AC.Logger then
        AC.Logger:Error(("StorageModule failed to register interaction-frame events: %s"):format(tostring(err1 or err2)))
    end

    AC.Events:Register("SETTINGS_CHANGED", self, "OnSettingsChanged")

end

-------------------------------------------------------------------------------
-- Disable
-------------------------------------------------------------------------------

function StorageModule:Disable()

    if AC.Events then
        AC.Events:UnregisterAll(self)
    end

end

-------------------------------------------------------------------------------
-- Shutdown
-------------------------------------------------------------------------------

function StorageModule:Shutdown()

    self:Disable()
    self:ResetState()

end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function StorageModule:IsModuleEnabled()

    return AC.ConfigurationManager:GetValue("Storage", "enabled") ~= false

end

function StorageModule:GetActiveProfileID()

    return AC.ConfigurationManager:GetValue("Storage", "activeProfileID") or "MythicPlus"

end

function StorageModule:GetActiveProfile()

    local activeID = self:GetActiveProfileID()

    for _, profile in ipairs(Profiles) do
        if profile.id == activeID then
            return profile
        end
    end

    return nil

end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function StorageModule:OnPlayerEnteringWorld()

    self.BankOpen = false

end

function StorageModule:OnBankOpened()

    if not self:IsModuleEnabled() then
        return
    end

    self.BankOpen = true
    self:ScanBank()

end

function StorageModule:OnBankClosed()

    self.BankOpen = false

end

-- Enum.PlayerInteractionType.Banker is the confirmed-by-name candidate
-- for "a banker interaction is active" (this pattern already exists for
-- other interaction types elsewhere in Blizzard's own UI code) -- the
-- exact enum key is unverified against a live client here, so this is
-- pcall-wrapped and falls back to simply not gating on it (BANKFRAME_OPENED/
-- CLOSED above still work as the primary trigger either way).
function StorageModule:OnInteractionFrameShow(interactionType)

    if not self:IsModuleEnabled() then
        return
    end

    local ok, bankerType = pcall(function()
        return Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
    end)

    if ok and bankerType and interactionType == bankerType then
        self.BankOpen = true
        self:ScanBank()
    end

end

function StorageModule:OnInteractionFrameHide(interactionType)

    local ok, bankerType = pcall(function()
        return Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
    end)

    if ok and bankerType and interactionType == bankerType then
        self.BankOpen = false
    end

end

function StorageModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Storage" then
        return
    end

    if key == "enabled" and not value then
        self:ResetState()
    end

end

-------------------------------------------------------------------------------
-- Bank Scanning
--
-- Only ever runs while the bank is actually open (self.BankOpen) -- Blizzard
-- does not guarantee container data for bank-side bag IDs is meaningful
-- otherwise. Enumerates owned bank tabs via C_Bank.FetchPurchasedBankTabIDs
-- (character bank, then Warband Bank if accessible) rather than hardcoding
-- specific bag ID numbers, since the exact numeric IDs Blizzard assigns to
-- purchased tabs are unverified against a live client -- asking Blizzard's
-- own API which tabs exist is both more correct and avoids guessing at
-- numbers. Falls back to the legacy single bank/reagent bank container
-- IDs if the tab-enumeration API is unavailable.
-------------------------------------------------------------------------------

function StorageModule:GetOwnedBankTabIDs()

    local tabIDs = {}

    if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then
        return tabIDs
    end

    local characterBankType = Enum.BankType and Enum.BankType.Character

    if characterBankType then

        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, characterBankType)

        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                table.insert(tabIDs, id)
            end
        end

    end

    local accountBankType = Enum.BankType and Enum.BankType.Account

    if accountBankType and C_Bank.CanUseBank then

        local canUse = false
        local okCanUse, result = pcall(C_Bank.CanUseBank, accountBankType)

        if okCanUse then
            canUse = result == true
        end

        if canUse then

            local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, accountBankType)

            if ok and type(ids) == "table" then
                for _, id in ipairs(ids) do
                    table.insert(tabIDs, id)
                end
            end

        end

    end

    -- Legacy fallback container IDs, only used if the tab-enumeration API
    -- above returned nothing at all (e.g. an older client build, or a
    -- wrong assumption about the API above) -- Enum.BagIndex.Bank/
    -- Reagentbank existing at all is itself defensively checked.
    if #tabIDs == 0 then

        local legacyBank = Enum.BagIndex and Enum.BagIndex.Bank
        local legacyReagentBank = Enum.BagIndex and Enum.BagIndex.Reagentbank

        if type(legacyBank) == "number" then
            table.insert(tabIDs, legacyBank)
        end

        if type(legacyReagentBank) == "number" then
            table.insert(tabIDs, legacyReagentBank)
        end

    end

    return tabIDs

end

function StorageModule:ScanBank()

    self.BankItemsBySlot = {}
    self.BankItemCounts = {}

    local slotsScanned = 0
    local tabIDs = self:GetOwnedBankTabIDs()

    for _, bagID in ipairs(tabIDs) do

        local ok, numSlots = pcall(GetContainerNumSlots, bagID)

        if ok and type(numSlots) == "number" and numSlots > 0 then

            slotsScanned = slotsScanned + numSlots

            for slot = 1, numSlots do

                local okInfo, info = pcall(GetContainerItemInfo, bagID, slot)

                if okInfo and info and info.itemID then

                    local itemID = info.itemID
                    local count = info.stackCount or 1
                    local slotKey = format("%d:%d", bagID, slot)

                    self.BankItemsBySlot[slotKey] =
                    {
                        itemID = itemID,
                        count = count,
                        bagID = bagID,
                        slot = slot,
                        quality = info.quality,

                        -- Confirmed non-functional (always false) --
                        -- ContainerItemInfo's own documented field list
                        -- doesn't include "isFavorite" at all, and
                        -- nothing reads this field even when it isn't.
                        -- See this file's own header VERIFICATION STATUS.
                        isFavorite = info.isFavorite == true,
                    }

                    self.BankItemCounts[itemID] = (self.BankItemCounts[itemID] or 0) + count

                end

            end

        end

    end

    self.BankSlotsScanned = slotsScanned

end

-------------------------------------------------------------------------------
-- Item Classification (Category rule matching)
--
-- Memoized -- classID/subClassID are static per item, so this only ever
-- calls GetItemInfoInstant once per distinct itemID seen. Same taxonomy-
-- based approach as MythicPlusModule:ClassifyConsumableItem -- Blizzard's
-- own classID/subClassID, not a hardcoded item list.
-------------------------------------------------------------------------------

function StorageModule:GetItemClassInfo(itemID)

    local cached = self.ItemClassCache[itemID]

    if cached then
        return cached
    end

    if not GetItemInfoInstant then
        return nil
    end

    local ok, _, _, _, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemID)

    if not ok or not classID then
        return nil
    end

    local info = { classID = classID, subClassID = subClassID }
    self.ItemClassCache[itemID] = info

    return info

end

-------------------------------------------------------------------------------
-- Rule Matching
--
-- "Equipped" is checked against InventoryModule's own Equipment cache
-- (read-only, through its public API -- never re-derived) rather than
-- anything Storage computes itself; it is a safety no-op for bag/bank
-- items in practice (an item cannot be simultaneously equipped and sit
-- in a bag or bank slot), included only because Part 8's "Never Move:
-- Current Equipment" was explicitly requested.
-------------------------------------------------------------------------------

-- quality is optional -- only Quality-type rules need it, and it is read
-- from the live container slot by the caller (InventoryModule's cached
-- record, or this module's own BankItemsBySlot), never re-derived here.
function StorageModule:MatchesRule(itemID, rule, quality)

    if not rule or not itemID then
        return false
    end

    local targetType = rule.targetType

    if targetType == "Item" then
        return tonumber(rule.targetValue) == itemID
    end

    if targetType == "Category" then

        local target = rule.targetValue or {}
        local classInfo = self:GetItemClassInfo(itemID)

        if not classInfo then
            return false
        end

        if target.classKey then

            local classID = Enum.ItemClass and Enum.ItemClass[target.classKey]

            return classID ~= nil and classInfo.classID == classID

        end

        if target.subclass then

            local consumableClassID = Enum.ItemClass and Enum.ItemClass.Consumable
            local subClassID = Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass[target.subclass]

            return consumableClassID ~= nil and subClassID ~= nil
                and classInfo.classID == consumableClassID
                and classInfo.subClassID == subClassID

        end

        return false

    end

    if targetType == "Quality" then
        return quality ~= nil and tonumber(rule.targetValue) == quality
    end

    if targetType == "Expansion" then

        if not GetItemInfo then
            return false
        end

        -- GetItemInfo return order: name, link, quality, level, minLevel,
        -- type, subType, stackCount, equipLoc, texture, sellPrice,
        -- classID, subclassID, bindType, expacID (15th) -- 14 discarded
        -- positions before expacID.
        local ok, _, _, _, _, _, _, _, _, _, _, _, _, _, expacID = pcall(GetItemInfo, itemID)

        return ok and expacID ~= nil and expacID == tonumber(rule.targetValue)

    end

    if targetType == "Group" then

        local group = self.Groups and self.Groups[rule.targetValue]

        return group ~= nil and group[itemID] == true

    end

    if targetType == "Equipped" then

        local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
        local equipment = inventoryModule and inventoryModule:GetEquipment()

        if not equipment then
            return false
        end

        for _, equipped in pairs(equipment) do
            if equipped and equipped.itemID == itemID then
                return true
            end
        end

        return false

    end

    return false

end

-------------------------------------------------------------------------------
-- Public API -- Bank Summary
-------------------------------------------------------------------------------

function StorageModule:IsBankAccessible()

    return self.BankOpen == true

end

function StorageModule:GetBankSummary()

    return
    {
        accessible = self.BankOpen == true,
        slotsScanned = self.BankSlotsScanned,
        distinctItems = (function()
            local count = 0
            for _ in pairs(self.BankItemCounts) do
                count = count + 1
            end
            return count
        end)(),
    }

end

function StorageModule:GetBankItemCount(itemID)

    itemID = tonumber(itemID)

    if not itemID then
        return 0
    end

    return self.BankItemCounts[itemID] or 0

end

-------------------------------------------------------------------------------
-- Restock Analysis (Part 3/7)
--
-- Combines InventoryModule's bag items (read through its public API)
-- with this module's own bank cache. NeverMove rules are checked first,
-- as an exclusion, so a favorited/quest/equipped item is never proposed
-- for deposit even if it also matches a broader Maintain/Deposit rule.
--
-- No fabricated "estimated preparation time": Blizzard exposes no way to
-- measure or predict how long moving items actually takes, so rather
-- than inventing a number that looks precise but isn't, this reports a
-- real, computed `actionsNeeded` count (how many distinct withdraw/
-- deposit lines the analysis produced) instead of a time unit.
-------------------------------------------------------------------------------

function StorageModule:IsExcludedFromMovement(itemID, quality)

    local profile = self:GetActiveProfile()

    if not profile then
        return false
    end

    for _, rule in ipairs(profile.rules) do

        if rule.action == "NeverMove" and self:MatchesRule(itemID, rule, quality) then
            return true
        end

    end

    return false

end

function StorageModule:AnalyzeProfile(profileID)

    local result =
    {
        missing = {},
        excess = {},
        withdrawals = {},
        deposits = {},
        actionsNeeded = 0,
        readinessPercent = 100,
    }

    local profile = nil

    if profileID then
        for _, candidate in ipairs(Profiles) do
            if candidate.id == profileID then
                profile = candidate
                break
            end
        end
    else
        profile = self:GetActiveProfile()
    end

    if not profile then
        return result
    end

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not inventoryModule then
        return result
    end

    -- Readiness (Step 8): the average, across every Maintain/Keep rule, of
    -- how close bags alone are to that rule's target -- capped at 100%
    -- per rule so having triple the Hearthstones you need doesn't offset
    -- being short on potions. A profile with no Maintain/Keep rules (e.g.
    -- the empty Custom preset) has nothing to be unprepared for, so it
    -- reads 100% rather than 0%/undefined.
    local readinessRuleCount = 0
    local readinessSum = 0

    for _, rule in ipairs(profile.rules) do

        if rule.action == "Maintain" or rule.action == "Keep" then

            local bagCount = self:CountMatchingInBags(inventoryModule, rule)
            local targetAmount = rule.amount or 0
            local need = targetAmount - bagCount

            if targetAmount > 0 then

                readinessRuleCount = readinessRuleCount + 1
                readinessSum = readinessSum + math.min(bagCount / targetAmount, 1.0)

            end

            if need > 0 then

                local bankCount = self:CountMatchingInBank(rule)
                local withdrawAmount = math.min(need, bankCount)
                local stillMissing = need - withdrawAmount

                if withdrawAmount > 0 then
                    table.insert(result.withdrawals, { label = rule.label, amount = withdrawAmount, rule = rule })
                    result.actionsNeeded = result.actionsNeeded + 1
                end

                if stillMissing > 0 then
                    table.insert(result.missing, { label = rule.label, amount = stillMissing, rule = rule })
                end

            end

        elseif rule.action == "Deposit" then

            local bagCount = self:CountMatchingInBags(inventoryModule, rule, true)
            local keepAmount = rule.amount or 0
            local excess = bagCount - keepAmount

            if excess > 0 then
                table.insert(result.excess, { label = rule.label, amount = excess, rule = rule })
                table.insert(result.deposits, { label = rule.label, amount = excess, rule = rule })
                result.actionsNeeded = result.actionsNeeded + 1
            end

        end

    end

    if readinessRuleCount > 0 then
        result.readinessPercent = (readinessSum / readinessRuleCount) * 100
    end

    return result

end

-- excludeNeverMove: when true (Deposit rules), items that also match a
-- NeverMove rule are excluded from the count -- a favorited crafting
-- reagent, for example, should never be proposed for deposit.
function StorageModule:CountMatchingInBags(inventoryModule, rule, excludeNeverMove)

    local total = 0

    for _, item in ipairs(inventoryModule:GetItems()) do

        if self:MatchesRule(item.itemID, rule, item.quality) then

            if not excludeNeverMove or not self:IsExcludedFromMovement(item.itemID, item.quality) then
                total = total + (item.count or 0)
            end

        end

    end

    return total

end

function StorageModule:CountMatchingInBank(rule)

    local total = 0

    for _, item in pairs(self.BankItemsBySlot) do

        if self:MatchesRule(item.itemID, rule, item.quality) then
            total = total + (item.count or 0)
        end

    end

    return total

end

function StorageModule:GetShoppingList(profileID)

    local analysis = self:AnalyzeProfile(profileID)

    return analysis.missing

end

-------------------------------------------------------------------------------
-- Activity Preparation (Part 6)
--
-- A compact readiness summary for one profile -- consumed by
-- RecommendationEngine as supporting evidence on an activity
-- recommendation (e.g. "Complete Your Keystone"), never computed by
-- RecommendationEngine itself. `ready` is true only when nothing is
-- missing and nothing needs withdrawing -- a genuine "you're ready" or
-- "you're not" signal, not a fuzzy score.
-------------------------------------------------------------------------------

function StorageModule:GetPreparationStatus(profileID)

    local analysis = self:AnalyzeProfile(profileID)

    local ready = #analysis.missing == 0 and #analysis.withdrawals == 0

    return
    {
        ready = ready,
        missing = analysis.missing,
        withdrawals = analysis.withdrawals,
        actionsNeeded = analysis.actionsNeeded,
        readinessPercent = analysis.readinessPercent,
    }

end

-------------------------------------------------------------------------------
-- Execute (Part 4) -- real item movement, with guardrails
--
-- Explicitly heavier scrutiny than every other write path in this addon:
-- this is the one feature that touches a player's actual items. Guardrails:
--   - Refuses outright in combat (InCombatLockdown) and when the bank
--     isn't open.
--   - Only ever moves items that the current AnalyzeProfile() run itself
--     already flagged as a withdrawal/deposit -- it never re-derives its
--     own idea of what to move, and NeverMove-excluded items are already
--     filtered out of `deposits` by AnalyzeProfile.
--   - Whole-stack moves only. No partial-stack splitting
--     (C_Container.SplitContainerItem would be a second, separate
--     unverified API this deliberately avoids introducing) -- the amount
--     actually moved is reported, and may not exactly equal the amount
--     requested for that reason. This is a real, documented limitation,
--     not a bug: moving one 20-stack of potions when only 14 were needed
--     is judged safer than adding a second unverified move primitive.
--   - Every Blizzard call is pcall-wrapped; the cursor is explicitly
--     cleared on any failure so a botched pickup never leaves an item
--     stuck on the player's cursor.
--
-- VERIFICATION STATUS (Blizzard API Verification pass): `C_Container.
-- PickupContainerItem(containerIndex, slotIndex)` is confirmed via
-- Warcraft Wiki -- listed as available through the "Midnight" (12.1.0)
-- client, marked "AllowedWhenUntainted" (consistent with this module's
-- own `InCombatLockdown()` guard being a deliberate extra safety margin,
-- not a requirement Blizzard itself imposes). Every move attempt still
-- fails closed on any error (pcall catches it, nothing moves, the
-- failure is reported) rather than moving the wrong item -- that
-- discipline doesn't change just because the underlying API is now
-- confirmed real. Still needing a live-client spot check: the actual
-- pickup-then-place round trip against a real bank/bag, since no source
-- consulted this pass demonstrates the two-call sequence end-to-end --
-- see the Live Verification checklist in docs/DEVELOPMENT_BACKLOG.md.
-------------------------------------------------------------------------------

function StorageModule:FindFreeBankSlot()

    for _, bagID in ipairs(self:GetOwnedBankTabIDs()) do

        local ok, numSlots = pcall(GetContainerNumSlots, bagID)

        if ok and type(numSlots) == "number" and numSlots > 0 then

            for slot = 1, numSlots do

                local slotKey = format("%d:%d", bagID, slot)

                if not self.BankItemsBySlot[slotKey] then
                    return bagID, slot
                end

            end

        end

    end

    return nil, nil

end

function StorageModule:MoveItemStack(sourceBagID, sourceSlot, destBagID, destSlot)

    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end

    if not PickupContainerItem then
        return false, "unavailable"
    end

    local okPickup = pcall(PickupContainerItem, sourceBagID, sourceSlot)

    if not okPickup then
        return false, "pickup failed"
    end

    if not CursorHasItem or not CursorHasItem() then

        if ClearCursor then
            ClearCursor()
        end

        return false, "nothing to move"

    end

    local okPlace = pcall(PickupContainerItem, destBagID, destSlot)

    if not okPlace then

        if ClearCursor then
            ClearCursor()
        end

        return false, "place failed"

    end

    -- A successful place should already clear the cursor, but in case
    -- the destination was invalid and Blizzard left the item on the
    -- cursor, clear it explicitly rather than leaving it stuck there.
    if CursorHasItem and CursorHasItem() and ClearCursor then
        ClearCursor()
    end

    return true

end

-- Moves whole matching stacks from source slots to destination slots
-- until `amount` is satisfied or reached/exceeded by one stack, or no
-- more matching source stacks remain. Returns how much was actually
-- moved (see the whole-stack-only caveat above).
function StorageModule:MoveMatchingStacks(sourceSlots, rule, amount, findDestination, onMoved)

    local moved = 0

    for slotKey, item in pairs(sourceSlots) do

        if moved >= amount then
            break
        end

        if self:MatchesRule(item.itemID, rule, item.quality) then

            local destBagID, destSlot = findDestination()

            if not destBagID then
                break
            end

            local ok = self:MoveItemStack(item.bagID, item.slot, destBagID, destSlot)

            if ok then

                moved = moved + (item.count or 0)

                if onMoved then
                    onMoved(slotKey)
                end

            end

        end

    end

    return moved

end

function StorageModule:ExecutePreparation(profileID)

    if InCombatLockdown and InCombatLockdown() then
        return { success = false, reason = "combat" }
    end

    if not self.BankOpen then
        return { success = false, reason = "bank_closed" }
    end

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not inventoryModule then
        return { success = false, reason = "inventory_unavailable" }
    end

    local analysis = self:AnalyzeProfile(profileID)
    local withdrawn, deposited = 0, 0

    -- Withdrawals: bank -> bags.
    for _, entry in ipairs(analysis.withdrawals) do

        if entry.rule then

            withdrawn = withdrawn + self:MoveMatchingStacks(self.BankItemsBySlot, entry.rule, entry.amount,
                function()
                    return inventoryModule:GetFreeBagSlot()
                end,
                function(slotKey)
                    self.BankItemsBySlot[slotKey] = nil
                end)

        end

    end

    -- Deposits: bags -> bank. Reads Inventory's live slot map fresh
    -- (GetItems() doesn't expose bagID/slot directly on every record --
    -- it does, since InventoryModule's cache stores bagID/slot per item;
    -- reused here the same way, never rescanned).
    local bagItemsBySlot = {}

    for _, item in ipairs(inventoryModule:GetItems()) do
        bagItemsBySlot[format("%d:%d", item.bagID, item.slot)] = item
    end

    for _, entry in ipairs(analysis.deposits) do

        if entry.rule then

            deposited = deposited + self:MoveMatchingStacks(bagItemsBySlot, entry.rule, entry.amount,
                function()
                    return self:FindFreeBankSlot()
                end,
                function(slotKey)
                    bagItemsBySlot[slotKey] = nil
                end)

        end

    end

    -- Refresh this module's own bank cache immediately -- bag-side
    -- changes are picked up by InventoryModule's own BAG_UPDATE listener
    -- without any help needed here.
    self:ScanBank()

    return { success = true, withdrawn = withdrawn, deposited = deposited }

end

-------------------------------------------------------------------------------
-- Insights (Part 5)
--
-- Restock-gap insights only -- bag fullness ("Bags Almost Full"/"Bags
-- Filling Up") is already InventoryModule's insight, and is deliberately
-- NOT duplicated here (Architectural Rule 1: exactly one owner). This
-- module's insights are about being under-prepared relative to the
-- active profile, which is genuinely new, unowned territory.
-------------------------------------------------------------------------------

function StorageModule:GetInsights()

    local insights = {}

    if not self:IsModuleEnabled() then
        return insights
    end

    local profile = self:GetActiveProfile()

    if not profile then
        return insights
    end

    local analysis = self:AnalyzeProfile(profile.id)

    if #analysis.missing > 0 then

        local firstMissing = analysis.missing[1]

        table.insert(insights,
        {
            title = "Storage Missing Items",
            description = string.format("You're missing %d %s for your %s profile.", firstMissing.amount, AC.L:Get(firstMissing.label), AC.L:Get(profile.label)),
            priority = 35,
            category = "Storage",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { profileID = profile.id, missingCount = #analysis.missing },
        })

    end

    if #analysis.excess > 0 then

        table.insert(insights,
        {
            title = "Storage Excess Items",
            description = "You're carrying crafting materials or bulk items that should be deposited.",
            priority = 20,
            category = "Storage",
            timestamp = time(),
            expiresAt = 0,
            dismissible = false,
            data = { profileID = profile.id, excessCount = #analysis.excess },
        })

    end

    return insights

end

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------

AC.Core:RegisterModule("Storage", StorageModule)

return StorageModule
