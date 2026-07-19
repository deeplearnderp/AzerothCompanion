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
-- confidence: the Banker/AccountBanker interaction-type checks and the exact
-- PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE payload shape -- see the Live
-- Verification checklist in docs/DEVELOPMENT_BACKLOG.md.
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

-- Storage Knowledge Base -- bumped only when the shape/meaning of a
-- persisted LastKnownStorage (character.Storage.LastKnownStorage)
-- changes in a way that would make an old cached record unsafe to
-- display as-is. Covers the whole persisted structure (metadata,
-- snapshot, analysis alike), not just the recommendation algorithm --
-- renamed from the earlier STORAGE_ANALYSIS_VERSION for that reason. Not
-- the SavedVariables schema version (DatabaseService.SchemaVersion) --
-- this one is scoped to this single cached record, the same way
-- Global.PlayerJournal.SchemaVersion and
-- Global.DeveloperRuntime.ErrorCapture.SchemaVersion (DatabaseService.lua's
-- own Defaults) already version their own persisted shapes independently
-- of the database as a whole.
--
-- Bumped to 2 when raw per-item snapshot records (snapshot.items) were
-- added. A version-1 record has no items field at all, and loading it
-- as-is would silently leave item-level consumers with nothing rather
-- than a clear "no persisted data" state -- exactly the unsafe-to-
-- display-as-is case this version field exists to guard against.
-- Bumping forces a version-1 record to be treated as absent
-- (Initialize()'s load is version-gated) until the next real scan
-- writes a version-2 record with items included.
local STORAGE_DATA_VERSION = 2

local STORAGE_CATEGORY_ORDER =
{
    "Equipment",
    "Consumables",
    "Reagents",
    "TradeGoods",
    "QuestItems",
    "Mounts",
    "BattlePets",
    "Miscellaneous",
    "Unknown",
}

local STORAGE_CATEGORY_INDEX = {}

for index, category in ipairs(STORAGE_CATEGORY_ORDER) do
    STORAGE_CATEGORY_INDEX[category] = index
end

local STORAGE_SOURCE_INDEX =
{
    bags = 1,
    character_bank = 2,
    warband_bank = 3,
}

local STORAGE_SEARCH_SORT_OPTIONS =
{
    "name",
    "quantity",
    "category",
    "source",
}

local STORAGE_SEARCH_SORT_SET = {}

for _, sortOption in ipairs(STORAGE_SEARCH_SORT_OPTIONS) do
    STORAGE_SEARCH_SORT_SET[sortOption] = true
end

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local Defaults =
{
    enabled = true,
    activeProfileID = "MythicPlus",
    groups = {},

    -- Storage Supply Manager Sprint -- per-character recommendation
    -- mode/override storage (see GetRecommendationMode/SetRecommendationMode,
    -- below in this file). Keyed by "profileID|ruleLabel".
    recommendationOverrides = {},
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
    self.BankCacheReady = false

    -- Storage Knowledge Base -- reloaded fresh from
    -- character.Storage.LastKnownStorage in Initialize() below, right
    -- after this reset. Deliberately a separate field from every live-scan
    -- structure above/below it: never read by
    -- AnalyzeProfile/CountMatchingInBank/ExecutePreparation, only by
    -- presentation code as a fallback when nothing above is live.
    self.LastKnownStorage = nil

    self.BankOpen = false
    self.StorageSources = {}
    self.SourceSnapshotsByID = {}
    self.ActiveStorageSourceIDs = {}
    self.LastSnapshot = nil
    self.NextSnapshotID = 0
    self.ItemMetadataCache = {}
    self.ScanStatus =
    {
        state = "unknown",
        freshness = "unknown",
        hasSnapshot = false,
        refreshReason = "never_scanned",
    }

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

    -- Storage Knowledge Base -- same lazy-field load pattern
    -- InventoryModule's own Initialize()/LoadSnapshot already uses for
    -- character.Inventory. Only ever populates self.LastKnownStorage (see
    -- ResetState above), never LastSnapshot/BankItemsBySlot/StorageSources/
    -- BankOpen/BankCacheReady/ActiveStorageSourceIDs -- those stay exactly
    -- as ResetState just set them, untouched by anything persisted.
    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if character and character.Storage and character.Storage.LastKnownStorage
    and character.Storage.LastKnownStorage.metadata
    and character.Storage.LastKnownStorage.metadata.storageDataVersion == STORAGE_DATA_VERSION then
        self.LastKnownStorage = character.Storage.LastKnownStorage
    end

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

    AC.DataManagementRegistry:RegisterCleanup(
    {
        id = "storage-snapshots",
        order = 50,
        displayNameKey = "DataManagement.Storage.Name",
        descriptionKey = "DataManagement.Storage.Description",
        actionLabelKey = "DataManagement.Storage.Action",
        confirmationTitleKey = "DataManagement.Storage.ConfirmTitle",
        confirmationDescriptionKey = "DataManagement.Storage.ConfirmDescription",
        getStatus = function()

            local snapshot = self:GetSnapshot()

            if snapshot and snapshot.timestamp then
                return AC.L:Format("DataManagement.StatusLastScan", AC.Presentation.FormatDate(snapshot.timestamp, "shortTime"))
            end

            return AC.L:Get("DataManagement.StatusNoSnapshots")

        end,
        isAvailable = function()
            local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()
            return self.LastSnapshot ~= nil
                or self.LastKnownStorage ~= nil
                or (character and character.Storage and character.Storage.LastKnownStorage ~= nil)
                or false
        end,
        clear = function()
            self:ClearStorageSnapshots()
        end,
    })

end

function StorageModule:ClearStorageSnapshots()

    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if character and character.Storage then
        character.Storage.LastKnownStorage = nil
    end

    self:ResetState()
    AC.Events:Fire("STORAGE_SCAN_UPDATED")

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
    AC.Events:Register("INVENTORY_SNAPSHOT_UPDATED", self, "OnInventorySnapshotUpdated")

    -- Storage Knowledge Base -- STORAGE_SCAN_UPDATED already fires at the end of
    -- ScanBank's existing success path (and from CloseStorageAccess/
    -- FailScan/OnSettingsChanged-disable) -- reusing it here instead of
    -- adding a call inside ScanBank itself. OnStorageScanUpdated's own
    -- BankCacheReady check (read-only) is what tells a genuine fresh
    -- success apart from those other firings.
    AC.Events:Register("STORAGE_SCAN_UPDATED", self, "OnStorageScanUpdated")

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

-- Storage Supply Manager Sprint -- previously only settable through
-- Settings > Storage's own dropdown (which wrote directly to
-- ConfigurationManager). This page-level on-page switcher needed the
-- same write path exposed as a real module method instead of reaching
-- into ConfigurationManager itself -- module owns its own setting.
function StorageModule:SetActiveProfileID(profileID)

    if type(profileID) ~= "string" or profileID == "" then
        return false
    end

    AC.ConfigurationManager:SetValue("Storage", "activeProfileID", profileID)

    return true

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

    self:CloseStorageAccess("world_changed")

end

function StorageModule:OpenStorageAccess(refreshReason)

    if not self:IsModuleEnabled() then
        return
    end

    if self.BankOpen
    and self.ScanStatus
    and self.ScanStatus.state == "ready"
    and self.ScanStatus.freshness == "current" then
        return
    end

    self.BankOpen = true
    self:ScanBank(refreshReason or "storage_opened")

end

function StorageModule:CloseStorageAccess(refreshReason)

    if not self.BankOpen then
        return
    end

    self.BankOpen = false
    self.BankCacheReady = false
    self.ActiveStorageSourceIDs = {}

    if self.ScanStatus and self.ScanStatus.hasSnapshot then
        self.ScanStatus.freshness = "stale"
        self.ScanStatus.refreshReason = refreshReason or "storage_closed"
    end

    AC.Events:Fire("STORAGE_SCAN_UPDATED")

end

function StorageModule:OnBankOpened()

    self:OpenStorageAccess("bank_opened")

end

function StorageModule:OnBankClosed()

    self:CloseStorageAccess("bank_closed")

end

-- Regular bankers and the summoned Warband banker use separate interaction
-- types on current Retail. BANKFRAME_OPENED/CLOSED remain registered as the
-- primary bank lifecycle; OpenStorageAccess deduplicates whichever signal
-- arrives second.
function StorageModule:IsBankInteractionType(interactionType)

    local interactionTypes = Enum and Enum.PlayerInteractionType

    if not interactionTypes then
        return false
    end

    return interactionType == interactionTypes.Banker
        or interactionType == interactionTypes.AccountBanker

end

function StorageModule:OnInteractionFrameShow(interactionType)

    if not self:IsModuleEnabled() then
        return
    end

    if self:IsBankInteractionType(interactionType) then
        self:OpenStorageAccess("bank_interaction_opened")
    end

end

function StorageModule:OnInteractionFrameHide(interactionType)

    if self:IsBankInteractionType(interactionType) then
        self:CloseStorageAccess("bank_interaction_closed")
    end

end

function StorageModule:OnSettingsChanged(moduleName, key, value)

    if moduleName ~= "Storage" then
        return
    end

    if key == "enabled" and not value then
        self:ResetState()
        AC.Events:Fire("STORAGE_SCAN_UPDATED")
    end

end

function StorageModule:OnInventorySnapshotUpdated()

    if self:IsModuleEnabled() then
        AC.Events:Fire("STORAGE_SCAN_UPDATED")
    end

end

-------------------------------------------------------------------------------
-- Bank Scanning
--
-- Only ever runs while the bank is actually open (self.BankOpen) -- Blizzard
-- does not guarantee container data for bank-side bag IDs is meaningful
-- otherwise. C_Bank.FetchViewableBankTypes identifies which bank sources are
-- actually exposed by the current interaction; FetchPurchasedBankTabIDs then
-- provides their containers. This preserves Character/Warband source identity
-- without guessing bag IDs. The existing legacy fallback remains isolated to
-- clients where the modern source API is absent.
-------------------------------------------------------------------------------

function StorageModule:GetStorageSourceDefinition(bankType)

    local bankTypes = Enum and Enum.BankType

    if not bankTypes then
        return nil
    end

    if bankType == bankTypes.Character then
        return { id = "character_bank", bankType = bankType, ownerType = "character" }
    end

    if bankType == bankTypes.Account then
        return { id = "warband_bank", bankType = bankType, ownerType = "account" }
    end

    return nil

end

function StorageModule:GetScanSourceDefinitions()

    local sources = {}

    if C_Bank and C_Bank.FetchViewableBankTypes and C_Bank.FetchPurchasedBankTabIDs then

        local okViewable, viewableBankTypes = pcall(C_Bank.FetchViewableBankTypes)

        if not okViewable or type(viewableBankTypes) ~= "table" then
            return nil, "bank_types_unavailable"
        end

        for _, bankType in ipairs(viewableBankTypes) do

            local source = self:GetStorageSourceDefinition(bankType)

            if source then

                local okTabs, tabIDs = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)

                if not okTabs or type(tabIDs) ~= "table" then
                    return nil, "bank_tabs_unavailable"
                end

                source.tabIDs = tabIDs
                table.insert(sources, source)

            end

        end

        return sources

    end

    -- Existing legacy fallback, retained only for clients without the modern
    -- bank source API. It is represented honestly as one character source.
    local legacySource =
    {
        id = "character_bank",
        ownerType = "character",
        tabIDs = {},
    }
    local bagIndices = Enum and Enum.BagIndex
    local legacyBank = bagIndices and bagIndices.Bank
    local legacyReagentBank = bagIndices and bagIndices.Reagentbank

    if type(legacyBank) == "number" then
        table.insert(legacySource.tabIDs, legacyBank)
    end

    if type(legacyReagentBank) == "number" then
        table.insert(legacySource.tabIDs, legacyReagentBank)
    end

    if #legacySource.tabIDs > 0 then
        table.insert(sources, legacySource)
    end

    return sources

end

function StorageModule:GetOwnedBankTabIDs()

    local tabIDs = {}
    local sources = self:GetScanSourceDefinitions()

    for _, source in ipairs(sources or {}) do
        for _, tabID in ipairs(source.tabIDs or {}) do
            table.insert(tabIDs, tabID)
        end
    end

    return tabIDs

end


function StorageModule:FailScan(reason)

    self.ScanStatus.state = "failed"
    self.ScanStatus.failureReason = reason or "scan_failed"
    self.ScanStatus.refreshReason = self.ScanStatus.failureReason
    self.ScanStatus.hasSnapshot = self.LastSnapshot ~= nil
    self.ScanStatus.freshness = self.LastSnapshot and "stale" or "unknown"
    self.ScanStatus.snapshotID = self.LastSnapshot and self.LastSnapshot.id or nil
    self.BankCacheReady = false

    AC.Events:Fire("STORAGE_SCAN_UPDATED")

    return { success = false, reason = self.ScanStatus.failureReason }

end

function StorageModule:ScanBank(refreshReason)

    if not self.BankOpen then
        return self:FailScan("storage_unavailable")
    end

    local attemptedAt = time()

    self.ScanStatus.state = "scanning"
    self.ScanStatus.lastAttemptTimestamp = attemptedAt
    self.ScanStatus.failureReason = nil
    self.ScanStatus.refreshTrigger = refreshReason or "refresh_requested"

    local sources, sourceError = self:GetScanSourceDefinitions()

    if not sources then
        return self:FailScan(sourceError)
    end

    if #sources == 0 then
        return self:FailScan("no_storage_sources")
    end

    local itemsBySlot = {}
    local itemCounts = {}
    local sourceSnapshots = {}
    local activeSourceIDs = {}
    local slotsScanned = 0

    for _, source in ipairs(sources) do

        local sourceSnapshot =
        {
            id = source.id,
            bankType = source.bankType,
            ownerType = source.ownerType,
            tabCount = #(source.tabIDs or {}),
            slotsScanned = 0,
            occupiedSlots = 0,
            itemCount = 0,
            distinctItems = 0,
            items = {},
        }
        local sourceItemIDs = {}

        activeSourceIDs[source.id] = true

        for _, bagID in ipairs(source.tabIDs or {}) do

            local okSlots, numSlots = pcall(GetContainerNumSlots, bagID)

            if not okSlots or type(numSlots) ~= "number" then
                return self:FailScan("container_unavailable")
            end

            slotsScanned = slotsScanned + numSlots
            sourceSnapshot.slotsScanned = sourceSnapshot.slotsScanned + numSlots

            for slot = 1, numSlots do

                local okInfo, info = pcall(GetContainerItemInfo, bagID, slot)

                if not okInfo then
                    return self:FailScan("container_item_unavailable")
                end

                if info and info.itemID then

                    local itemID = info.itemID
                    local count = info.stackCount or 1
                    local slotKey = format("%d:%d", bagID, slot)
                    local item =
                    {
                        itemID = itemID,
                        count = count,
                        bagID = bagID,
                        slot = slot,
                        quality = info.quality,
                        name = info.itemName,
                        link = info.hyperlink,
                        iconFileID = info.iconFileID,
                        isBound = info.isBound == true,
                        sourceID = source.id,
                        ownerType = source.ownerType,

                        -- Confirmed non-functional (always false); retained
                        -- for compatibility with the existing bank cache.
                        isFavorite = info.isFavorite == true,
                    }

                    itemsBySlot[slotKey] = item
                    itemCounts[itemID] = (itemCounts[itemID] or 0) + count
                    table.insert(sourceSnapshot.items, item)

                    sourceSnapshot.occupiedSlots = sourceSnapshot.occupiedSlots + 1
                    sourceSnapshot.itemCount = sourceSnapshot.itemCount + count
                    sourceItemIDs[itemID] = true

                end

            end

        end

        for _ in pairs(sourceItemIDs) do
            sourceSnapshot.distinctItems = sourceSnapshot.distinctItems + 1
        end

        table.insert(sourceSnapshots, sourceSnapshot)

    end

    self.NextSnapshotID = self.NextSnapshotID + 1

    for _, sourceSnapshot in ipairs(sourceSnapshots) do
        sourceSnapshot.timestamp = attemptedAt
        sourceSnapshot.snapshotID = self.NextSnapshotID
        self.SourceSnapshotsByID[sourceSnapshot.id] = sourceSnapshot
    end

    local aggregateItems = {}
    local aggregateItemCounts = {}
    local aggregateSources = {}
    local aggregateSlots = 0
    local aggregateOccupiedSlots = 0
    local aggregateTotalItems = 0

    for _, sourceSnapshot in pairs(self.SourceSnapshotsByID) do

        table.insert(aggregateSources,
        {
            id = sourceSnapshot.id,
            bankType = sourceSnapshot.bankType,
            ownerType = sourceSnapshot.ownerType,
            tabCount = sourceSnapshot.tabCount,
            slotsScanned = sourceSnapshot.slotsScanned,
            occupiedSlots = sourceSnapshot.occupiedSlots,
            itemCount = sourceSnapshot.itemCount,
            distinctItems = sourceSnapshot.distinctItems,
            empty = sourceSnapshot.occupiedSlots == 0,
            timestamp = sourceSnapshot.timestamp,
            snapshotID = sourceSnapshot.snapshotID,
        })

        aggregateSlots = aggregateSlots + sourceSnapshot.slotsScanned
        aggregateOccupiedSlots = aggregateOccupiedSlots + sourceSnapshot.occupiedSlots
        aggregateTotalItems = aggregateTotalItems + sourceSnapshot.itemCount

        for _, item in ipairs(sourceSnapshot.items) do
            table.insert(aggregateItems, item)
            aggregateItemCounts[item.itemID] = (aggregateItemCounts[item.itemID] or 0) + (item.count or 0)
        end

    end

    table.sort(aggregateSources, function(left, right)
        return left.id < right.id
    end)

    local aggregateDistinctItems = 0

    for _ in pairs(aggregateItemCounts) do
        aggregateDistinctItems = aggregateDistinctItems + 1
    end

    self.BankItemsBySlot = itemsBySlot
    self.BankItemCounts = itemCounts
    self.BankSlotsScanned = slotsScanned
    self.BankCacheReady = true
    self.StorageSources = aggregateSources
    self.ActiveStorageSourceIDs = activeSourceIDs
    self.LastSnapshot =
    {
        id = self.NextSnapshotID,
        timestamp = attemptedAt,
        slotsScanned = aggregateSlots,
        occupiedSlots = aggregateOccupiedSlots,
        distinctItems = aggregateDistinctItems,
        totalItems = aggregateTotalItems,
        sources = aggregateSources,
        items = aggregateItems,
    }
    self.ScanStatus.state = "ready"
    self.ScanStatus.freshness = (#aggregateSources == #sourceSnapshots) and "current" or "stale"
    self.ScanStatus.hasSnapshot = true
    self.ScanStatus.lastSuccessfulTimestamp = attemptedAt
    self.ScanStatus.snapshotID = self.LastSnapshot.id
    self.ScanStatus.failureReason = nil
    self.ScanStatus.refreshReason = nil

    AC.Events:Fire("STORAGE_SCAN_UPDATED")

    return { success = true, snapshotID = self.LastSnapshot.id }

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
        local classInfo = AC.ItemClassification:GetItemClassInfo(itemID)

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
-- Public API -- Refresh / Bank Summary
-------------------------------------------------------------------------------

function StorageModule:RefreshStorage()

    if not self:IsModuleEnabled() then
        return { success = false, reason = "disabled" }
    end

    if not self:IsBankAccessible() then
        return { success = false, reason = "storage_unavailable" }
    end

    local result = self:ScanBank("manual_refresh")

    if not result.success then
        return result
    end

    result.summary = self:GetBankSummary()

    return result

end

function StorageModule:IsBankAccessible()

    return self:IsStorageAvailable()

end

local function CopyRecord(record)

    local copy = {}

    for key, value in pairs(record or {}) do
        copy[key] = value
    end

    return copy

end


local function CopyRecordArray(records)

    local copy = {}

    for _, record in ipairs(records or {}) do
        table.insert(copy, CopyRecord(record))
    end

    return copy

end

function StorageModule:GetScanStatus()

    local status = CopyRecord(self.ScanStatus)

    status.available = self.BankOpen == true
    status.scope = "bank_storage"

    if self.LastSnapshot then
        status.empty = self.LastSnapshot.occupiedSlots == 0
    end

    return status

end

function StorageModule:GetLastScan()

    local snapshot = self.LastSnapshot

    if not snapshot then
        return nil
    end

    return
    {
        snapshotID = snapshot.id,
        timestamp = snapshot.timestamp,
        slotsScanned = snapshot.slotsScanned,
        occupiedSlots = snapshot.occupiedSlots,
        distinctItems = snapshot.distinctItems,
        totalItems = snapshot.totalItems,
        sourceCount = #(snapshot.sources or {}),
        freshness = self.ScanStatus.freshness,
        empty = snapshot.occupiedSlots == 0,
        scope = "bank_storage",
        includesBags = false,
    }

end

-------------------------------------------------------------------------------
-- Storage Knowledge Base
--
-- Persists a single historical record -- metadata, a snapshot summary
-- (aggregate counts, source summaries, and raw per-item scan records),
-- and the RESULT of an analysis that already ran against a live,
-- verified bank scan. Item records are the minimum raw fields ScanBank
-- itself already captures, never derived presentation data (names/icons/
-- classification stay itemID-derived via GetAggregateItemMetadata/
-- ClassifyAggregateItem, unchanged and not duplicated here) -- and never
-- anything BankOpen/BankCacheReady/ActiveStorageSourceIDs-adjacent.
-- AnalyzeProfile (via GetPreparationStatus/GetInsights) is called here
-- exactly as it already is by any other presentation caller; this does
-- not introduce a second analysis path, it caches the output of the
-- existing one. One write, one record.
--
-- Triggered by STORAGE_SCAN_UPDATED rather than a call inside ScanBank
-- itself -- ScanBank's own success path already fires this event, so
-- this hooks the existing signal without modifying ScanBank. The
-- self.BankCacheReady check (read, never written, here) is what
-- distinguishes a genuine fresh success from this same event's other
-- firings (bank close, scan failure, module disable), all of which leave
-- BankCacheReady false.
-------------------------------------------------------------------------------

function StorageModule:OnStorageScanUpdated()

    if not self.BankCacheReady then
        return
    end

    local character = AC.DatabaseService and AC.DatabaseService:GetCharacter()

    if not character then
        return
    end

    local profile = self:GetActiveProfile()

    if not profile then
        return
    end

    local preparation = self:GetPreparationStatus(profile.id)

    -- "missing"/"withdrawals" entries carry a live `rule` table reference
    -- (a pointer into Modules/Storage/StorageProfiles.lua's static
    -- built-in list) that has no business in SavedVariables -- only
    -- `label`/`amount`, the two fields presentation code actually reads,
    -- are kept.
    local function StripRule(entries)

        local stripped = {}

        for _, entry in ipairs(entries or {}) do
            table.insert(stripped, { label = entry.label, amount = entry.amount })
        end

        return stripped

    end

    -- Raw scan records only -- every field here already exists on
    -- ScanBank's own item construction (self.LastSnapshot.items), nothing
    -- synthesized. Deliberately excludes `name`/`iconFileID` (item names
    -- and icons -- explicitly out of scope; GetAggregateItemMetadata
    -- already re-derives both from itemID alone, via GetItemInfo, whether
    -- the source item is live or persisted) and `isFavorite` (already
    -- documented elsewhere in this file as non-functional and read by
    -- nothing in the addon -- no reason to persist a field nobody uses).
    -- Keyed "<sourceID>:<bagID>:<slot>", not the bare "<bagID>:<slot>"
    -- self.BankItemsBySlot uses -- character_bank and warband_bank are
    -- separate sources that are not guaranteed to use disjoint bagID
    -- ranges, so the source prefix avoids a possible collision that bare
    -- bagID:slot would not.
    local function BuildRawItemRecords()

        local items = {}

        for _, item in ipairs(self.LastSnapshot and self.LastSnapshot.items or {}) do

            local key = format("%s:%d:%d", item.sourceID or "", item.bagID or 0, item.slot or 0)

            items[key] =
            {
                itemID = item.itemID,
                count = item.count,
                bagID = item.bagID,
                slot = item.slot,
                quality = item.quality,
                link = item.link,
                isBound = item.isBound,
                sourceID = item.sourceID,
                ownerType = item.ownerType,
            }

        end

        return items

    end

    local _, build = GetBuildInfo()

    character.Storage = character.Storage or {}

    character.Storage.LastKnownStorage =
    {
        metadata =
        {
            storageDataVersion = STORAGE_DATA_VERSION,
            timestamp = time(),
            profileID = profile.id,
            gameVersion = build,
        },

        snapshot =
        {
            slotsScanned = self.LastSnapshot and self.LastSnapshot.slotsScanned or 0,
            occupiedSlots = self.LastSnapshot and self.LastSnapshot.occupiedSlots or 0,
            distinctItems = self.LastSnapshot and self.LastSnapshot.distinctItems or 0,
            totalItems = self.LastSnapshot and self.LastSnapshot.totalItems or 0,
            sources = self.LastSnapshot and self.LastSnapshot.sources or {},
            items = BuildRawItemRecords(),
        },

        analysis =
        {
            preparation =
            {
                ready = preparation.ready,
                readinessPercent = preparation.readinessPercent,
                actionsNeeded = preparation.actionsNeeded,
                missing = StripRule(preparation.missing),
                withdrawals = StripRule(preparation.withdrawals),
            },

            recommendations = self:GetInsights(),
        },
    }

end

-- Presentation-facing only -- returns the cached record as-is (or nil).
-- Never consulted by AnalyzeProfile/CountMatchingInBank/ExecutePreparation.
function StorageModule:GetLastKnownStorage()

    return self.LastKnownStorage

end

function StorageModule:GetStorageSources()

    local sources = CopyRecordArray(self.StorageSources)

    for _, source in ipairs(sources) do
        source.available = self.BankOpen == true and self.ActiveStorageSourceIDs[source.id] == true
        source.freshness = source.available and self.ScanStatus.state == "ready" and "current" or "stale"
    end

    return sources

end

-- Live-preferred, persisted-fallback, never-merged: the one place
-- GetAggregateStorage()'s bank-side data is sourced from, so every
-- presentation caller downstream (Explorer, Search, Categories) gets the
-- same fallback behavior automatically, with no consumer-specific logic.
-- A live self.LastSnapshot is always authoritative when present; the
-- Storage Knowledge Base's persisted record is only ever read when
-- self.LastSnapshot is nil (never combined with it). Neither branch
-- touches BankOpen/BankCacheReady/ActiveStorageSourceIDs/BankItemsBySlot
-- -- both are read-only views over data those live structures (or their
-- persisted counterpart) already hold.
function StorageModule:GetSnapshot()

    local snapshot = self.LastSnapshot

    if snapshot then
        return
        {
            id = snapshot.id,
            timestamp = snapshot.timestamp,
            slotsScanned = snapshot.slotsScanned,
            occupiedSlots = snapshot.occupiedSlots,
            distinctItems = snapshot.distinctItems,
            totalItems = snapshot.totalItems,
            freshness = self.ScanStatus.freshness,
            available = self:IsStorageAvailable(),
            empty = snapshot.occupiedSlots == 0,
            scope = "bank_storage",
            includesBags = false,
            sources = self:GetStorageSources(),
            items = CopyRecordArray(snapshot.items),
        }
    end

    local persisted = self.LastKnownStorage and self.LastKnownStorage.snapshot

    if not persisted then
        return nil
    end

    local items = {}

    for _, item in pairs(persisted.items or {}) do
        table.insert(items, CopyRecord(item))
    end

    return
    {
        id = nil,
        timestamp = self.LastKnownStorage.metadata.timestamp,
        slotsScanned = persisted.slotsScanned,
        occupiedSlots = persisted.occupiedSlots,
        distinctItems = persisted.distinctItems,
        totalItems = persisted.totalItems,
        freshness = "stale",
        available = false,
        empty = (persisted.occupiedSlots or 0) == 0,
        scope = "bank_storage",
        includesBags = false,
        sources = CopyRecordArray(persisted.sources or {}),
        items = items,
    }

end

function StorageModule:IsStorageAvailable(sourceID)

    if self.BankOpen ~= true then
        return false
    end

    if sourceID then
        return self.ActiveStorageSourceIDs[sourceID] == true
    end

    return true

end

function StorageModule:GetRefreshReason()

    if not self.ScanStatus then
        return "never_scanned"
    end

    return self.ScanStatus.refreshReason

end

function StorageModule:GetBankSummary()

    return
    {
        accessible = self:IsStorageAvailable() and self.BankCacheReady == true,
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
-- Aggregate Storage
--
-- Composes InventoryModule's authoritative bag snapshot with StorageModule's
-- own per-source bank snapshots. The result is presentation-neutral and never
-- rescans bags or containers.
-------------------------------------------------------------------------------

function StorageModule:GetAggregateItemMetadata(item)

    local itemID = item and item.itemID

    if not itemID then
        return {}
    end

    local metadata = self.ItemMetadataCache[itemID]

    if not metadata then

        local classInfo = AC.ItemClassification:GetItemClassInfo(itemID) or {}

        metadata =
        {
            classID = classInfo.classID,
            subClassID = classInfo.subClassID,
        }

        if GetItemInfo then

            local ok, itemName, itemLink, quality, _, _, className, subClassName,
                maxStack, equipmentLocation, icon, _, classID, subClassID,
                bindType, _, _, isCraftingReagent = pcall(GetItemInfo, itemID)

            if ok and itemName then

                metadata.itemName = itemName
                metadata.itemLink = itemLink
                metadata.quality = quality
                metadata.className = className
                metadata.subclass = subClassName
                metadata.stackSize = maxStack
                metadata.equipmentLocation = equipmentLocation
                metadata.icon = icon
                metadata.classID = classID or metadata.classID
                metadata.subClassID = subClassID or metadata.subClassID
                metadata.bindType = bindType
                metadata.isCraftingReagent = isCraftingReagent == true

                self.ItemMetadataCache[itemID] = metadata

            end

        end

    end

    return
    {
        itemName = item.name or metadata.itemName,
        itemLink = item.link or metadata.itemLink,
        icon = item.iconFileID or metadata.icon,
        quality = item.quality or metadata.quality,
        classID = metadata.classID,
        className = metadata.className,
        subClassID = metadata.subClassID,
        subclass = metadata.subclass,
        equipmentLocation = metadata.equipmentLocation,
        stackSize = metadata.stackSize,
        bindType = metadata.bindType,
        isCraftingReagent = metadata.isCraftingReagent,
    }

end

function StorageModule:ClassifyAggregateItem(metadata)

    local itemClasses = Enum and Enum.ItemClass or {}
    local miscellaneous = Enum and Enum.ItemMiscellaneousSubclass or {}
    local classID = metadata.classID
    local subClassID = metadata.subClassID

    if classID == nil then
        return "Unknown"
    end

    if classID == itemClasses.Weapon or classID == itemClasses.Armor then
        return "Equipment"
    end

    if classID == itemClasses.Consumable then
        return "Consumables"
    end

    if metadata.isCraftingReagent
    or classID == itemClasses.Reagent
    or (classID == itemClasses.Miscellaneous and subClassID == miscellaneous.Reagent) then
        return "Reagents"
    end

    if classID == itemClasses.Tradegoods then
        return "TradeGoods"
    end

    if classID == itemClasses.Questitem then
        return "QuestItems"
    end

    if classID == itemClasses.Miscellaneous and subClassID == miscellaneous.Mount then
        return "Mounts"
    end

    if classID == itemClasses.Battlepet
    or (classID == itemClasses.Miscellaneous and subClassID == miscellaneous.CompanionPet) then
        return "BattlePets"
    end

    return "Miscellaneous"

end

function StorageModule:GetCurrentCharacterOwner()

    local characterModule = AC.Core and AC.Core:GetModule("Character")
    local profile = characterModule and characterModule.GetProfile and characterModule:GetProfile()

    if not profile then
        return nil
    end

    return
    {
        name = profile.name ~= "" and profile.name or nil,
        realm = profile.realm ~= "" and profile.realm or nil,
    }

end

function StorageModule:BuildAggregateItem(item, source, owner)

    local metadata = self:GetAggregateItemMetadata(item)
    local snapshotIdentity = source.snapshotID and format("%s:%s", source.id, tostring(source.snapshotID)) or nil
    local ownsItem = source.ownerType == "character" and owner or nil

    return
    {
        itemID = item.itemID,
        itemName = metadata.itemName,
        itemLink = metadata.itemLink,
        icon = metadata.icon,
        quality = metadata.quality,
        quantity = item.count,
        category = self:ClassifyAggregateItem(metadata),
        classID = metadata.classID,
        className = metadata.className,
        subClassID = metadata.subClassID,
        subclass = metadata.subclass,
        equipmentLocation = metadata.equipmentLocation,
        stackSize = metadata.stackSize,
        bindType = metadata.bindType,
        isBound = item.isBound,
        isCraftingReagent = metadata.isCraftingReagent,
        owningCharacter = ownsItem and ownsItem.name or nil,
        owningRealm = ownsItem and ownsItem.realm or nil,
        ownerType = source.ownerType,
        storageSource = source.id,
        location =
        {
            source = source.id,
            bagID = item.bagID,
            slot = item.slot,
        },
        snapshotIdentity = snapshotIdentity,
        snapshotTimestamp = source.timestamp,
        freshness = source.freshness,
        available = source.available,
    }

end

function StorageModule:GetAggregateStorage()

    local result =
    {
        enabled = self:IsModuleEnabled(),
        generatedAt = time(),
        items = {},
        sources = {},
        statistics =
        {
            itemCount = 0,
            stackCount = 0,
            quantity = 0,
            categoryCount = 0,
            sourceCount = 0,
            availableSourceCount = 0,
        },
    }

    if not result.enabled then
        result.status = { reason = "disabled" }
        return result
    end

    local owner = self:GetCurrentCharacterOwner()
    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local inventorySnapshot = inventoryModule and inventoryModule.GetInventorySnapshot and inventoryModule:GetInventorySnapshot()
    local bankSnapshot = self:GetSnapshot()
    local sourceByID = {}
    local identityParts = {}
    local latestTimestamp

    if inventorySnapshot then

        local distinctItems = {}
        local totalQuantity = 0

        for _, item in ipairs(inventorySnapshot.items or {}) do
            distinctItems[item.itemID] = true
            totalQuantity = totalQuantity + (item.count or 0)
        end

        local distinctCount = 0

        for _ in pairs(distinctItems) do
            distinctCount = distinctCount + 1
        end

        local bagSource =
        {
            id = "bags",
            ownerType = "character",
            available = inventorySnapshot.available == true,
            freshness = inventorySnapshot.freshness,
            snapshotID = inventorySnapshot.id,
            timestamp = inventorySnapshot.timestamp,
            slotsScanned = inventorySnapshot.summary and inventorySnapshot.summary.totalSlots or nil,
            occupiedSlots = inventorySnapshot.timestamp and #(inventorySnapshot.items or {}) or nil,
            itemCount = inventorySnapshot.timestamp and totalQuantity or nil,
            distinctItems = inventorySnapshot.timestamp and distinctCount or nil,
            empty = inventorySnapshot.empty,
        }

        sourceByID.bags = bagSource
        table.insert(result.sources, bagSource)

        if inventorySnapshot.id then
            table.insert(identityParts, format("bags:%s", tostring(inventorySnapshot.id)))
        end

        latestTimestamp = inventorySnapshot.timestamp

        for _, item in ipairs(inventorySnapshot.items or {}) do
            table.insert(result.items, self:BuildAggregateItem(item, bagSource, owner))
        end

    end

    for _, source in ipairs(bankSnapshot and bankSnapshot.sources or {}) do

        sourceByID[source.id] = source
        table.insert(result.sources, source)

        if source.snapshotID then
            table.insert(identityParts, format("%s:%s", source.id, tostring(source.snapshotID)))
        end

        if source.timestamp and (not latestTimestamp or source.timestamp > latestTimestamp) then
            latestTimestamp = source.timestamp
        end

    end

    for _, item in ipairs(bankSnapshot and bankSnapshot.items or {}) do

        local source = sourceByID[item.sourceID]

        if source then
            table.insert(result.items, self:BuildAggregateItem(item, source, owner))
        end

    end

    table.sort(result.sources, function(left, right)
        return (STORAGE_SOURCE_INDEX[left.id] or 99) < (STORAGE_SOURCE_INDEX[right.id] or 99)
    end)

    table.sort(result.items, function(left, right)

        local leftCategory = STORAGE_CATEGORY_INDEX[left.category] or 99
        local rightCategory = STORAGE_CATEGORY_INDEX[right.category] or 99

        if leftCategory ~= rightCategory then
            return leftCategory < rightCategory
        end

        local leftName = string.lower(left.itemName or "")
        local rightName = string.lower(right.itemName or "")

        if leftName ~= rightName then
            return leftName < rightName
        end

        if left.itemID ~= right.itemID then
            return left.itemID < right.itemID
        end

        return (STORAGE_SOURCE_INDEX[left.storageSource] or 99) < (STORAGE_SOURCE_INDEX[right.storageSource] or 99)

    end)

    local distinctItems = {}
    local categories = {}

    for _, item in ipairs(result.items) do
        distinctItems[item.itemID] = true
        categories[item.category] = true
        result.statistics.stackCount = result.statistics.stackCount + 1
        result.statistics.quantity = result.statistics.quantity + (item.quantity or 0)
    end

    for _ in pairs(distinctItems) do
        result.statistics.itemCount = result.statistics.itemCount + 1
    end

    for _ in pairs(categories) do
        result.statistics.categoryCount = result.statistics.categoryCount + 1
    end

    result.statistics.sourceCount = #result.sources

    for _, source in ipairs(result.sources) do
        if source.available then
            result.statistics.availableSourceCount = result.statistics.availableSourceCount + 1
        end
    end

    result.snapshotIdentity = #identityParts > 0 and table.concat(identityParts, "|") or nil
    result.snapshotTimestamp = latestTimestamp

    -- Explicit availability signal for presentation callers -- "do I have
    -- any real storage data to show, live or persisted, bags or bank" --
    -- so no consumer needs to infer this from live-only state
    -- (StorageModule:GetScanStatus()) as a proxy. Deliberately reuses
    -- snapshotIdentity's own truthiness rather than a new, second concept:
    -- snapshotIdentity is already exactly "did at least one real source
    -- (bags and/or bank, live and/or persisted) contribute," which is the
    -- correct definition of "storage data exists" -- an empty-but-scanned
    -- bank still has an identity and should still read as available, the
    -- same way #result.items > 0 would incorrectly say "no data" for it.
    result.hasStorageData = result.snapshotIdentity ~= nil

    result.status =
    {
        inventory = inventorySnapshot and
        {
            available = inventorySnapshot.available,
            freshness = inventorySnapshot.freshness,
            snapshotID = inventorySnapshot.id,
            timestamp = inventorySnapshot.timestamp,
        } or { available = false, freshness = "unknown" },
        bank = self:GetScanStatus(),
    }

    return result

end

function StorageModule:GetItemsByCategory(category)

    if not STORAGE_CATEGORY_INDEX[category] then
        return {}
    end

    local items = {}

    for _, item in ipairs(self:GetAggregateStorage().items) do
        if item.category == category then
            table.insert(items, item)
        end
    end

    return items

end

function StorageModule:GetCategorySummary()

    local aggregate = self:GetAggregateStorage()
    local byCategory = {}

    for _, item in ipairs(aggregate.items) do

        local category = byCategory[item.category]

        if not category then

            category =
            {
                id = item.category,
                itemCount = 0,
                stackCount = 0,
                quantity = 0,
                locations = {},
                ItemIDs = {},
                LocationsByID = {},
            }
            byCategory[item.category] = category

        end

        category.ItemIDs[item.itemID] = true
        category.stackCount = category.stackCount + 1
        category.quantity = category.quantity + (item.quantity or 0)

        local location = category.LocationsByID[item.storageSource]

        if not location then
            location = { sourceID = item.storageSource, stackCount = 0, quantity = 0 }
            category.LocationsByID[item.storageSource] = location
        end

        location.stackCount = location.stackCount + 1
        location.quantity = location.quantity + (item.quantity or 0)

    end

    local categories = {}

    for _, categoryID in ipairs(STORAGE_CATEGORY_ORDER) do

        local category = byCategory[categoryID]

        if category then

            for _ in pairs(category.ItemIDs) do
                category.itemCount = category.itemCount + 1
            end

            for _, location in pairs(category.LocationsByID) do
                table.insert(category.locations, location)
            end

            table.sort(category.locations, function(left, right)
                return (STORAGE_SOURCE_INDEX[left.sourceID] or 99) < (STORAGE_SOURCE_INDEX[right.sourceID] or 99)
            end)

            category.ItemIDs = nil
            category.LocationsByID = nil
            table.insert(categories, category)

        end

    end

    return
    {
        categories = categories,
        statistics = aggregate.statistics,
        sources = aggregate.sources,
        status = aggregate.status,
        snapshotIdentity = aggregate.snapshotIdentity,
        snapshotTimestamp = aggregate.snapshotTimestamp,
    }

end

-------------------------------------------------------------------------------
-- Aggregate Search
--
-- Search is a query over GetAggregateStorage(), never a second scan path.
-- Matching, filtering, grouping, and ordering remain StorageModule facts;
-- presentation callers receive prepared result records and filter options.
-------------------------------------------------------------------------------

function StorageModule:GetAggregateOwnerKey(item)

    if not item or not item.owningCharacter or item.owningCharacter == "" then
        return nil
    end

    return format("%s\031%s", item.owningCharacter, item.owningRealm or "")

end

function StorageModule:GetSearchFilters()

    local aggregate = self:GetAggregateStorage()
    local categorySet = {}
    local sourceSet = {}
    local ownerByKey = {}
    local qualitySet = {}
    local hasUnknownQuality = false

    for _, item in ipairs(aggregate.items) do

        categorySet[item.category] = true
        sourceSet[item.storageSource] = true

        local ownerKey = self:GetAggregateOwnerKey(item)

        if ownerKey then
            ownerByKey[ownerKey] =
            {
                key = ownerKey,
                name = item.owningCharacter,
                realm = item.owningRealm,
            }
        end

        if item.quality == nil then
            hasUnknownQuality = true
        else
            qualitySet[item.quality] = true
        end

    end

    local categories = {}
    local sources = {}
    local owners = {}
    local qualities = {}

    for _, categoryID in ipairs(STORAGE_CATEGORY_ORDER) do
        if categorySet[categoryID] then
            table.insert(categories, categoryID)
        end
    end

    for sourceID in pairs(sourceSet) do
        table.insert(sources, sourceID)
    end

    table.sort(sources, function(left, right)
        return (STORAGE_SOURCE_INDEX[left] or 99) < (STORAGE_SOURCE_INDEX[right] or 99)
    end)

    for _, owner in pairs(ownerByKey) do
        table.insert(owners, owner)
    end

    table.sort(owners, function(left, right)

        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")

        if leftName ~= rightName then
            return leftName < rightName
        end

        return string.lower(left.realm or "") < string.lower(right.realm or "")

    end)

    for quality in pairs(qualitySet) do
        table.insert(qualities, quality)
    end

    table.sort(qualities)

    local sortOptions = {}

    for _, sortOption in ipairs(STORAGE_SEARCH_SORT_OPTIONS) do
        table.insert(sortOptions, sortOption)
    end

    return
    {
        enabled = aggregate.enabled,
        categories = categories,
        sources = sources,
        owners = owners,
        qualities = qualities,
        hasUnknownQuality = hasUnknownQuality,
        sortOptions = sortOptions,
        status = aggregate.status,
        snapshotIdentity = aggregate.snapshotIdentity,
        snapshotTimestamp = aggregate.snapshotTimestamp,
    }

end

function StorageModule:NormalizeSearchText(searchText)

    local normalized = tostring(searchText or ""):match("^%s*(.-)%s*$")

    return string.lower(normalized)

end

function StorageModule:AggregateItemMatchesSearch(item, query, filters)

    local itemName = item.itemName and string.lower(item.itemName) or nil

    if not itemName or not string.find(itemName, query, 1, true) then
        return false
    end

    if filters.category ~= "All" and item.category ~= filters.category then
        return false
    end

    if filters.source ~= "All" and item.storageSource ~= filters.source then
        return false
    end

    if filters.owner ~= "All" and self:GetAggregateOwnerKey(item) ~= filters.owner then
        return false
    end

    if filters.quality == "Unknown" then

        if item.quality ~= nil then
            return false
        end

    elseif filters.quality ~= "All" then

        local quality = tonumber(filters.quality)

        if quality == nil or item.quality ~= quality then
            return false
        end

    end

    return true

end

function StorageModule:BuildSearchResultItem(item)

    return
    {
        itemID = item.itemID,
        itemName = item.itemName,
        itemLink = item.itemLink,
        icon = item.icon,
        quality = item.quality,
        category = item.category,
        classID = item.classID,
        className = item.className,
        subClassID = item.subClassID,
        subclass = item.subclass,
        equipmentLocation = item.equipmentLocation,
        stackSize = item.stackSize,
        bindType = item.bindType,
        isCraftingReagent = item.isCraftingReagent,
        owningCharacter = item.owningCharacter,
        owningRealm = item.owningRealm,
        ownerType = item.ownerType,
        storageSource = item.storageSource,
        snapshotIdentity = item.snapshotIdentity,
        snapshotTimestamp = item.snapshotTimestamp,
        freshness = item.freshness,
        available = item.available,
        quantity = 0,
        stackCount = 0,
        locations = {},
    }

end

function StorageModule:SortSearchResults(items, sortBy)

    local function CompareNames(left, right)

        local leftName = string.lower(left.itemName or "")
        local rightName = string.lower(right.itemName or "")

        if leftName ~= rightName then
            return leftName < rightName
        end

        if left.itemID ~= right.itemID then
            return left.itemID < right.itemID
        end

        return (STORAGE_SOURCE_INDEX[left.storageSource] or 99) < (STORAGE_SOURCE_INDEX[right.storageSource] or 99)

    end

    table.sort(items, function(left, right)

        if sortBy == "quantity" and left.quantity ~= right.quantity then
            return left.quantity > right.quantity
        end

        if sortBy == "category" then

            local leftCategory = STORAGE_CATEGORY_INDEX[left.category] or 99
            local rightCategory = STORAGE_CATEGORY_INDEX[right.category] or 99

            if leftCategory ~= rightCategory then
                return leftCategory < rightCategory
            end

        elseif sortBy == "source" then

            local leftSource = STORAGE_SOURCE_INDEX[left.storageSource] or 99
            local rightSource = STORAGE_SOURCE_INDEX[right.storageSource] or 99

            if leftSource ~= rightSource then
                return leftSource < rightSource
            end

        end

        return CompareNames(left, right)

    end)

end

function StorageModule:SearchItems(searchText, filters)

    local aggregate = self:GetAggregateStorage()
    local query = self:NormalizeSearchText(searchText)

    filters = filters or {}

    local normalizedFilters =
    {
        category = filters.category or "All",
        source = filters.source or "All",
        owner = filters.owner or "All",
        quality = filters.quality == nil and "All" or filters.quality,
        sortBy = STORAGE_SEARCH_SORT_SET[filters.sortBy] and filters.sortBy or "name",
    }
    local result =
    {
        state = "success",
        query = query,
        filters = normalizedFilters,
        items = {},
        statistics =
        {
            resultCount = 0,
            itemCount = 0,
            stackCount = 0,
            quantity = 0,
            sourceCount = 0,
        },
        status = aggregate.status,
        snapshotIdentity = aggregate.snapshotIdentity,
        snapshotTimestamp = aggregate.snapshotTimestamp,
    }

    if not aggregate.enabled then
        result.state = "storage_unavailable"
        return result
    end

    if query == "" then
        result.state = "empty_query"
        return result
    end

    if not aggregate.snapshotIdentity then
        result.state = "no_storage_data"
        return result
    end

    local resultByKey = {}
    local distinctItems = {}
    local matchedSources = {}

    for _, item in ipairs(aggregate.items) do

        if self:AggregateItemMatchesSearch(item, query, normalizedFilters) then

            local ownerKey = self:GetAggregateOwnerKey(item) or ""
            local resultKey = format("%s\030%s\030%s", tostring(item.itemID), item.storageSource or "", ownerKey)
            local searchItem = resultByKey[resultKey]

            if not searchItem then
                searchItem = self:BuildSearchResultItem(item)
                resultByKey[resultKey] = searchItem
                table.insert(result.items, searchItem)
            end

            searchItem.quantity = searchItem.quantity + (item.quantity or 0)
            searchItem.stackCount = searchItem.stackCount + 1

            table.insert(searchItem.locations,
            {
                bagID = item.location and item.location.bagID or nil,
                slot = item.location and item.location.slot or nil,
                quantity = item.quantity,
            })

            distinctItems[item.itemID] = true
            matchedSources[item.storageSource] = true
            result.statistics.stackCount = result.statistics.stackCount + 1
            result.statistics.quantity = result.statistics.quantity + (item.quantity or 0)

        end

    end

    for _ in pairs(distinctItems) do
        result.statistics.itemCount = result.statistics.itemCount + 1
    end

    for _ in pairs(matchedSources) do
        result.statistics.sourceCount = result.statistics.sourceCount + 1
    end

    result.statistics.resultCount = #result.items

    if #result.items == 0 then
        result.state = "no_results"
        return result
    end

    self:SortSearchResults(result.items, normalizedFilters.sortBy)

    return result

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
-- Shopping List Detail (Storage Supply Manager Sprint)
--
-- Upgrades GetShoppingList's category totals ("need 3 more Flasks") with
-- the SPECIFIC items already held that satisfy that same shortfall,
-- reusing MatchesRule -- the exact engine AnalyzeProfile already runs --
-- rather than re-deriving category membership a second way. Never
-- invents an item: a category with nothing held anywhere returns an
-- empty `items` list, and the page is expected to show an honest "none
-- currently held" line rather than guessing which item the rule means.
--
-- `analysis` is optional (Storage Sprint 1.1 -- Cleanup & Optimization):
-- Pages/Storage.lua already computes AnalyzeProfile(profile.id) once per
-- refresh for Supply Health/Bank Transfers; passing it through here
-- avoids running that same profile-wide analysis a second time. Standalone
-- callers (none today, but any future one) can still call this with just
-- a profileID and get the identical result -- the public shape is
-- unchanged, this only adds an optional shortcut.
--
-- `bagItems` is read once, before the per-rule loop below, not once per
-- rule -- InventoryModule:GetItems() builds a fresh array on every call,
-- so calling it inside the loop was redundant allocation, not a real
-- need (bag contents don't change mid-refresh). The per-rule scan itself
-- (checking every held item against that rule) is unchanged -- inherent
-- to category-based rule matching (the same shape AnalyzeProfile's own
-- CountMatchingInBags/CountMatchingInBank already have), not something
-- this pass restructures away.
-------------------------------------------------------------------------------

function StorageModule:GetShoppingListDetail(profileID, analysis)

    analysis = analysis or self:AnalyzeProfile(profileID)

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local bagItems = (inventoryModule and inventoryModule.GetItems) and inventoryModule:GetItems() or {}

    local detail = {}

    for _, entry in ipairs(analysis.missing) do

        local heldByID = {}

        local function CollectHeld(itemID, count, quality)

            if not self:MatchesRule(itemID, entry.rule, quality) then
                return
            end

            local held = heldByID[itemID]

            if not held then

                -- GetItemInfo can return nil until Blizzard's client-side
                -- item cache populates (a well-known, async quirk, not
                -- something this pass works around with a retry) -- falls
                -- back to the raw itemID as a name rather than blocking.
                local ok, name, _, _, _, _, _, _, _, icon = pcall(GetItemInfo, itemID)

                held = { itemID = itemID, name = (ok and name) or tostring(itemID), icon = ok and icon or nil, currentCount = 0 }
                heldByID[itemID] = held

            end

            held.currentCount = held.currentCount + count

        end

        for _, item in ipairs(bagItems) do
            CollectHeld(item.itemID, item.count or 0, item.quality)
        end

        for _, item in pairs(self.BankItemsBySlot) do
            CollectHeld(item.itemID, item.count or 0, item.quality)
        end

        local items = {}

        for _, held in pairs(heldByID) do
            table.insert(items, held)
        end

        detail[entry.label] = { amountMissing = entry.amount, items = items }

    end

    return detail

end

-- Presentation-safe shopping projection. This deliberately composes the
-- existing profile analysis instead of introducing a second rule engine.
-- Missing requirements and stock that can be withdrawn remain separate, and
-- a shopping instruction is only returned while GetStorageReadiness can prove
-- the underlying bank snapshot is current.
function StorageModule:GetShoppingListSummary(profileID)

    local profile = nil
    local requestedProfileID = profileID or self:GetActiveProfileID()

    for _, candidate in ipairs(Profiles) do
        if candidate.id == requestedProfileID then
            profile = candidate
            break
        end
    end

    local summary =
    {
        state = "unavailable",
        reason = "no_profile",
        profileID = requestedProfileID,
        profileLabel = profile and profile.label or nil,
        missing = {},
        availableInStorage = {},
        statistics =
        {
            requirementCount = 0,
            missingRequirementCount = 0,
            missingQuantity = 0,
            availableRequirementCount = 0,
            availableQuantity = 0,
        },
    }

    if not self:IsModuleEnabled() then
        summary.reason = "storage_disabled"
        return summary
    end

    if not profile then
        return summary
    end

    for _, rule in ipairs(profile.rules or {}) do
        if rule.action == "Maintain" or rule.action == "Keep" then
            summary.statistics.requirementCount = summary.statistics.requirementCount + 1
        end
    end

    if summary.statistics.requirementCount == 0 then
        summary.state = "known"
        summary.reason = nil
        summary.ready = true
        summary.readinessPercent = 100
        summary.freshness = self:GetScanStatus().freshness
        return summary
    end

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local inventorySnapshot = inventoryModule and inventoryModule.GetInventorySnapshot and inventoryModule:GetInventorySnapshot()

    if not inventorySnapshot or inventorySnapshot.available ~= true then
        summary.state = "unknown"
        summary.reason = "inventory_unavailable"
        summary.freshness = inventorySnapshot and inventorySnapshot.freshness or "unknown"
        return summary
    end

    local readiness = self:GetStorageReadiness(profile.id)

    summary.state = readiness and readiness.state or "unknown"
    summary.reason = readiness and readiness.reason or "readiness_unavailable"
    summary.freshness = readiness and readiness.freshness or "unknown"
    summary.snapshotID = readiness and readiness.snapshotID or nil

    if summary.state ~= "known" then
        return summary
    end

    summary.ready = readiness.ready == true
    summary.readinessPercent = readiness.readinessPercent

    local detail = self:GetShoppingListDetail(profile.id, readiness)

    for _, entry in ipairs(readiness.missing or {}) do

        local entryDetail = detail[entry.label] or {}
        local items = entryDetail.items or {}

        table.sort(items, function(left, right)
            return (left.name or "") < (right.name or "")
        end)

        table.insert(summary.missing,
        {
            label = entry.label,
            amount = entry.amount or 0,
            items = items,
        })

        summary.statistics.missingQuantity = summary.statistics.missingQuantity + (entry.amount or 0)

    end

    for _, entry in ipairs(readiness.withdrawals or {}) do

        table.insert(summary.availableInStorage,
        {
            label = entry.label,
            amount = entry.amount or 0,
        })

        summary.statistics.availableQuantity = summary.statistics.availableQuantity + (entry.amount or 0)

    end

    summary.statistics.missingRequirementCount = #summary.missing
    summary.statistics.availableRequirementCount = #summary.availableInStorage

    return summary

end

-------------------------------------------------------------------------------
-- Consumable Inventory (Storage Supply Manager Sprint)
--
-- The definitive bag+bank supply list -- every tracked consumable by
-- name/icon/bag count/bank count/total, grouped by the same category key
-- AC.ItemClassification:ClassifyConsumable already returns (the identical
-- classifier MythicPlusModule's own consumable tracking reads, so
-- GetSupplyForecast below can cross-reference this module's stock against
-- MythicPlusModule's usage history by category key with zero translation).
-- Reads InventoryModule's bags through its public API (never rescans) and
-- this module's own already-cached bank scan -- no new scanning, just a
-- new aggregation over data both modules already maintain.
-------------------------------------------------------------------------------

function StorageModule:GetConsumableInventory()

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local categories = {}

    local function AddItem(itemID, count, isBank)

        local category = AC.ItemClassification:ClassifyConsumable(itemID)

        if not category then
            return
        end

        local bucket = categories[category]

        if not bucket then
            bucket = { items = {}, itemsByID = {}, categoryTotal = 0, categoryBagTotal = 0, categoryBankTotal = 0 }
            categories[category] = bucket
        end

        local entry = bucket.itemsByID[itemID]

        if not entry then

            local ok, name, _, _, _, _, _, _, _, icon = pcall(GetItemInfo, itemID)

            entry = { itemID = itemID, name = (ok and name) or tostring(itemID), icon = ok and icon or nil, bagCount = 0, bankCount = 0, totalCount = 0 }
            bucket.itemsByID[itemID] = entry
            table.insert(bucket.items, entry)

        end

        if isBank then
            entry.bankCount = entry.bankCount + count
            bucket.categoryBankTotal = bucket.categoryBankTotal + count
        else
            entry.bagCount = entry.bagCount + count
            bucket.categoryBagTotal = bucket.categoryBagTotal + count
        end

        entry.totalCount = entry.bagCount + entry.bankCount
        bucket.categoryTotal = bucket.categoryTotal + count

    end

    if inventoryModule and inventoryModule.GetItems then
        for _, item in ipairs(inventoryModule:GetItems()) do
            AddItem(item.itemID, item.count or 0, false)
        end
    end

    for _, item in pairs(self.BankItemsBySlot) do
        AddItem(item.itemID, item.count or 0, true)
    end

    return { categories = categories }

end

-------------------------------------------------------------------------------
-- Supply Forecast (Storage Supply Manager Sprint)
--
-- "Approximately N Mythic+ runs remaining" -- current stock (this
-- module's own GetConsumableInventory, above) divided by real historical
-- per-run usage MythicPlusModule already tracks and exposes
-- (GetSeasonStatistics().consumableTotals/trackedRunCount) -- zero new
-- telemetry, this module records nothing about consumption itself. Gated
-- on the same MIN_TRACKED_RUNS threshold MythicPlusModule's own
-- Consumables Reminder Insight already uses, so this doesn't report a
-- forecast built from one or two noisy runs. Category keys match
-- GetConsumableInventory's exactly (both read the same shared
-- classifier), so no translation table is needed between the two.
--
-- Explicitly scoped, not silently overstated: this only ever reflects
-- Mythic+ consumption specifically -- MythicPlusModule doesn't track
-- consumables used in world content, raids, or anywhere else, and this
-- forecast doesn't claim to either.
--
-- `inventory` is optional (Storage Sprint 1.1 -- Cleanup & Optimization):
-- Pages/Storage.lua already computes GetConsumableInventory() once per
-- refresh for the Consumables section; passing it through here avoids
-- scanning bags+bank a second time. A standalone caller can still call
-- this with no arguments and get the identical result -- the public
-- shape is unchanged, this only adds an optional shortcut.
-------------------------------------------------------------------------------

local SUPPLY_FORECAST_MIN_TRACKED_RUNS = 5

function StorageModule:GetSupplyForecast(inventory)

    local mythicPlusModule = AC.Core and AC.Core:GetModule("MythicPlus")
    local availability =
    {
        state = "unavailable",
        reason = "mythic_plus_unavailable",
        trackedRunCount = 0,
        minimumTrackedRuns = SUPPLY_FORECAST_MIN_TRACKED_RUNS,
        empty = true,
    }

    if not mythicPlusModule or not mythicPlusModule.GetSeasonStatistics then
        return {}, availability
    end

    if mythicPlusModule.IsModuleEnabled and not mythicPlusModule:IsModuleEnabled() then
        availability.reason = "mythic_plus_disabled"
        return {}, availability
    end

    local seasonStats = mythicPlusModule:GetSeasonStatistics()

    if not seasonStats or not seasonStats.trackedRunCount then
        availability.reason = "season_data_unavailable"
        return {}, availability
    end

    availability.trackedRunCount = seasonStats.trackedRunCount

    if seasonStats.trackedRunCount < SUPPLY_FORECAST_MIN_TRACKED_RUNS then
        availability.state = "insufficient_history"
        availability.reason = "insufficient_history"
        return {}, availability
    end

    inventory = inventory or self:GetConsumableInventory()

    local forecast = {}

    for category, totalConsumed in pairs(seasonStats.consumableTotals or {}) do

        local averagePerRun = totalConsumed / seasonStats.trackedRunCount

        if averagePerRun > 0 then

            local bucket = inventory.categories[category]
            local currentStock = bucket and bucket.categoryTotal or 0

            forecast[category] =
            {
                currentStock = currentStock,
                averagePerRun = averagePerRun,
                estimatedRunsRemaining = math.floor(currentStock / averagePerRun),
            }

        end

    end

    availability.state = "available"
    availability.reason = nil
    availability.empty = next(forecast) == nil

    return forecast, availability

end

-------------------------------------------------------------------------------
-- Recommendation Mode (Storage Supply Manager Sprint)
--
-- Per-character mode/override storage for the three-mode design
-- (CompanionRecommended/Preferred/Any) -- see StorageProfiles.lua's own
-- header for why this is NOT a field on the shared built-in profile
-- data. Persisted via ConfigurationManager (a per-character setting,
-- same tier as activeProfileID), keyed by profile id + rule label.
-- "CompanionRecommended" is accepted and stored like any other mode, but
-- has no effect on what's displayed yet -- the shared
-- ItemRecommendationService it's designed to call is a reserved future
-- service, not built this pass. Every rule defaults to "Any" -- today's
-- existing behavior -- until a player explicitly sets something else.
--
-- Verified (Sprint 1.1 cleanup pass): no page reads or writes any of
-- GetRecommendationMode/GetPreferredItem/SetRecommendationMode today --
-- confirmed by a repo-wide search, not assumed. This section is data
-- model only, deliberately with no UI wired to it yet, so there is
-- nothing here for a player to see do nothing.
-------------------------------------------------------------------------------

local VALID_RECOMMENDATION_MODES =
{
    CompanionRecommended = true,
    Preferred = true,
    Any = true,
}

function StorageModule:GetRecommendationOverrides()

    return AC.ConfigurationManager:GetValue("Storage", "recommendationOverrides") or {}

end

function StorageModule:GetRecommendationMode(profileID, ruleLabel)

    if not profileID or not ruleLabel then
        return "Any"
    end

    local overrides = self:GetRecommendationOverrides()
    local key = profileID .. "|" .. ruleLabel
    local stored = overrides[key]

    return (stored and stored.mode) or "Any"

end

function StorageModule:GetPreferredItem(profileID, ruleLabel)

    if not profileID or not ruleLabel then
        return nil
    end

    local overrides = self:GetRecommendationOverrides()
    local key = profileID .. "|" .. ruleLabel
    local stored = overrides[key]

    return stored and stored.preferredItemID or nil

end

function StorageModule:SetRecommendationMode(profileID, ruleLabel, mode, preferredItemID)

    if not profileID or not ruleLabel or not VALID_RECOMMENDATION_MODES[mode] then
        return false
    end

    local overrides = AC.ConfigurationManager:GetValue("Storage", "recommendationOverrides") or {}
    local key = profileID .. "|" .. ruleLabel

    overrides[key] = { mode = mode, preferredItemID = (mode == "Preferred") and preferredItemID or nil }

    AC.ConfigurationManager:SetValue("Storage", "recommendationOverrides", overrides)

    return true

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

-- Snapshot-aware readiness for presentation callers. The existing
-- GetPreparationStatus contract remains unchanged for recommendation and
-- diagnostics consumers that already control their own evidence gating.
function StorageModule:GetStorageReadiness(profileID)

    local scanStatus = self:GetScanStatus()

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local inventorySnapshot = inventoryModule
        and inventoryModule.GetInventorySnapshot
        and inventoryModule:GetInventorySnapshot()

    if not scanStatus.hasSnapshot then

        if inventorySnapshot and inventorySnapshot.available then
            return
            {
                state = "partial",
                freshness = inventorySnapshot.freshness,
                reason = "bank_not_scanned",
            }
        end

        return
        {
            state = "unknown",
            freshness = scanStatus.freshness,
            reason = scanStatus.failureReason or scanStatus.refreshReason,
        }
    end

    if scanStatus.freshness ~= "current" then
        return
        {
            state = "unknown",
            freshness = scanStatus.freshness,
            reason = "snapshot_stale",
            snapshotID = scanStatus.snapshotID,
        }
    end

    if not self.ActiveStorageSourceIDs.character_bank then
        return
        {
            state = "unknown",
            freshness = scanStatus.freshness,
            reason = "character_bank_unavailable",
            snapshotID = scanStatus.snapshotID,
        }
    end

    local preparation = self:GetPreparationStatus(profileID)

    preparation.state = "known"
    preparation.freshness = scanStatus.freshness
    preparation.snapshotID = scanStatus.snapshotID

    return preparation

end

-- Presentation-facing FACTS only -- no localization/wording here (see
-- AC.DashboardFormat.GetStorageReadinessText, the sole place these facts
-- become words). Composes GetStorageReadiness (live, gated on a current-
-- session scan) and GetLastKnownStorage (Storage Knowledge Base's
-- persisted analysis) into the one live/historical distinction every
-- Storage readiness surface needs -- Inventory Manager, the Dashboard
-- Storage page, and the Home Dashboard's Storage card. `missing`/
-- `withdrawals` ride along unchanged from GetPreparationStatus/the
-- persisted (already StripRule-stripped) record -- only the Home card
-- reads them today (its shopping-list/withdraw-count detail sections),
-- but they are readiness facts like any other here, not a second
-- concept.
function StorageModule:GetReadinessFacts(profileID)

    if not self:IsModuleEnabled() then
        return { enabled = false }
    end

    local hasLiveScan = self:GetScanStatus().hasSnapshot == true
    local live = nil

    if hasLiveScan and profileID then

        local readiness = self:GetStorageReadiness(profileID)

        if readiness and readiness.state == "known" then

            live =
            {
                ready = readiness.ready,
                readinessPercent = readiness.readinessPercent,
                missing = readiness.missing,
                withdrawals = readiness.withdrawals,
            }

        end

    end

    local historical = nil
    local knownStorage = self:GetLastKnownStorage()
    local preparation = knownStorage and knownStorage.analysis and knownStorage.analysis.preparation

    if preparation then

        historical =
        {
            ready = preparation.ready,
            readinessPercent = preparation.readinessPercent,
            missing = preparation.missing,
            withdrawals = preparation.withdrawals,
            timestamp = knownStorage.metadata.timestamp,
        }

    end

    return
    {
        enabled = true,
        hasLiveScan = hasLiveScan,
        live = live,
        historical = historical,
    }

end

-------------------------------------------------------------------------------
-- Execute (Part 4) -- real item movement, with guardrails
--
-- Explicitly heavier scrutiny than every other write path in this addon:
-- this is the one feature that touches a player's actual items. Guardrails:
--   - Refuses outright in combat (InCombatLockdown), when the bank isn't
--     open, or when the current interaction has no successful scan cache.
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

    if not self.BankCacheReady then
        return { success = false, reason = "scan_unavailable" }
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
