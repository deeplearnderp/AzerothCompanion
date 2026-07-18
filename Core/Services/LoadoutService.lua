-------------------------------------------------------------------------------
-- Azeroth Companion
-- Loadout Service
--
-- Owns loadout definitions, persistence, status computation, and transfer
-- planning so InventoryManager remains presentation-only.
-------------------------------------------------------------------------------

local AC = _G.AzerothCompanion

local LoadoutService = {}
AC.LoadoutService = LoadoutService

local function GetCharacterStore()

    if AC.DatabaseService and AC.DatabaseService.GetCharacter then
        local character = AC.DatabaseService:GetCharacter()

        if character then
            character.InventoryManager = character.InventoryManager or {}
            character.InventoryManager.Loadouts = character.InventoryManager.Loadouts or {}
            return character.InventoryManager.Loadouts
        end
    end

    return {}

end

local function GetItemCounts(loadout)

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    local counts = {}

    for _, item in ipairs(loadout and loadout.items or {}) do
        local itemID = tonumber(item.itemID)
        local bagCount = 0
        local bankCount = 0

        if inventoryModule and inventoryModule.GetItemCount then
            bagCount = inventoryModule:GetItemCount(itemID) or 0
        end

        if storageModule and storageModule.GetBankItemCount then
            bankCount = storageModule:GetBankItemCount(itemID) or 0
        end

        counts[item.id] =
        {
            bagCount = bagCount,
            bankCount = bankCount,
        }
    end

    return counts

end

local function GetStatusState(desiredQuantity, bagCount, bankCount)

    local desired = tonumber(desiredQuantity) or 0
    local bag = tonumber(bagCount) or 0
    local bank = tonumber(bankCount) or 0
    local total = bag + bank

    if desired <= total then
        return "ready", AC.L and AC.L:Get("InventoryManager.LoadoutStatusReady") or "Ready"
    end

    if bank > 0 and bag < desired then
        return "bank", AC.L and AC.L:Get("InventoryManager.LoadoutStatusInBank") or "In Bank"
    end

    return "missing", AC.L and AC.L:Get("InventoryManager.LoadoutStatusMissing") or "Missing"

end

local function GetLocationText(bagCount, bankCount)

    local bag = tonumber(bagCount) or 0
    local bank = tonumber(bankCount) or 0

    if bag > 0 and bank > 0 then
        return AC.L and AC.L:Get("InventoryManager.LoadoutLocationBoth") or "Bags & Bank"
    end

    if bag > 0 then
        return AC.L and AC.L:Get("InventoryManager.LoadoutLocationBags") or "In Bags"
    end

    if bank > 0 then
        return AC.L and AC.L:Get("InventoryManager.LoadoutLocationBank") or "In Bank"
    end

    return AC.L and AC.L:Get("InventoryManager.LoadoutLocationMissing") or "Missing"

end

local function GetActionText(desiredQuantity, bagCount, bankCount)

    local desired = tonumber(desiredQuantity) or 0
    local bag = tonumber(bagCount) or 0
    local bank = tonumber(bankCount) or 0
    local missing = math.max(0, desired - bag)

    if missing <= 0 then
        return AC.L and AC.L:Get("InventoryManager.LoadoutActionReady") or "Ready"
    end

    if bank > 0 then
        return AC.L and AC.L:Format("InventoryManager.LoadoutActionWithdrawFormat", missing) or ("Withdraw " .. missing)
    end

    return AC.L and AC.L:Format("InventoryManager.LoadoutActionMissingFormat", missing) or ("Missing " .. missing)

end

local function BuildItemState(loadoutItem, bagCount, bankCount)

    local desired = tonumber(loadoutItem and loadoutItem.desiredQuantity or 0) or 0
    local bag = tonumber(bagCount) or 0
    local bank = tonumber(bankCount) or 0

    local status, statusText = GetStatusState(desired, bag, bank)

    return
    {
        item = loadoutItem,
        desiredQuantity = desired,
        bagCount = bag,
        bankCount = bank,
        status = status,
        statusText = statusText,
        locationText = GetLocationText(bag, bank),
        actionText = GetActionText(desired, bag, bank),
    }

end

function LoadoutService:Initialize()

    if AC.DatabaseService and AC.DatabaseService.Initialize then
        AC.DatabaseService:Initialize()
    end

end

function LoadoutService:GetLoadouts()

    local store = GetCharacterStore()
    local loadouts = {}

    for _, loadout in pairs(store) do
        table.insert(loadouts, loadout)
    end

    table.sort(loadouts, function(left, right)
        return (left.name or "") < (right.name or "")
    end)

    return loadouts

end

function LoadoutService:GetLoadout(loadoutID)

    local store = GetCharacterStore()

    if not loadoutID then
        return nil
    end

    return store[loadoutID]

end

function LoadoutService:ValidateLoadout(loadout)

    if not loadout or type(loadout) ~= "table" then
        return false, "Invalid loadout"
    end

    if type(loadout.id) ~= "string" or loadout.id == "" then
        return false, "Missing loadout id"
    end

    if type(loadout.name) ~= "string" or loadout.name == "" then
        return false, "Missing loadout name"
    end

    if type(loadout.items) ~= "table" then
        loadout.items = {}
    end

    return true

end

function LoadoutService:SaveLoadout(loadout)

    local valid = self:ValidateLoadout(loadout)

    if not valid then
        return nil
    end

    local store = GetCharacterStore()
    local clone = {}

    for key, value in pairs(loadout) do
        if type(value) == "table" then
            local copied = {}
            for childKey, childValue in pairs(value) do
                copied[childKey] = childValue
            end
            clone[key] = copied
        else
            clone[key] = value
        end
    end

    store[clone.id] = clone

    return clone

end

function LoadoutService:CreateLoadout(name)

    local id = "loadout-" .. tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
    local loadout =
    {
        id = id,
        name = name or AC.L and AC.L:Get("InventoryManager.LoadoutDefaultName") or "New Loadout",
        description = "",
        items = {},
    }

    return self:SaveLoadout(loadout)

end

function LoadoutService:DeleteLoadout(loadoutID)

    local store = GetCharacterStore()

    if not loadoutID or not store[loadoutID] then
        return false
    end

    store[loadoutID] = nil
    return true

end

function LoadoutService:GetLoadoutViewState(loadout)

    local valid = self:ValidateLoadout(loadout)

    if not valid then
        return
        {
            loadout = loadout or {},
            items = {},
            itemCounts = {},
            planWithdraw = {},
            planDeposit = {},
        }
    end

    local counts = GetItemCounts(loadout)
    local states = {}

    for _, item in ipairs(loadout.items or {}) do
        local countSet = counts[item.id] or {}
        states[#states + 1] = BuildItemState(item, countSet.bagCount, countSet.bankCount)
    end

    return
    {
        loadout = loadout,
        items = states,
        itemCounts = counts,
        planWithdraw = self:PlanWithdraw(loadout),
        planDeposit = self:PlanDeposit(loadout),
    }

end

function LoadoutService:PlanWithdraw(loadout)

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")
    local storageModule = AC.Core and AC.Core:GetModule("Storage")

    if not loadout or not inventoryModule or not storageModule then
        return {}
    end

    local counts = GetItemCounts(loadout)
    local plan = {}

    for _, item in ipairs(loadout.items or {}) do
        local desired = tonumber(item.desiredQuantity) or 0
        local bagCount = tonumber(counts[item.id] and counts[item.id].bagCount or 0) or 0
        local bankCount = tonumber(counts[item.id] and counts[item.id].bankCount or 0) or 0
        local missing = math.max(0, desired - bagCount)

        if missing > 0 and bankCount > 0 then
            table.insert(plan,
            {
                itemID = tonumber(item.itemID),
                desiredQuantity = desired,
                amount = math.min(missing, bankCount),
                bagCount = bagCount,
                bankCount = bankCount,
            })
        end
    end

    return plan

end

function LoadoutService:PlanDeposit(loadout)

    local inventoryModule = AC.Core and AC.Core:GetModule("Inventory")

    if not loadout or not inventoryModule then
        return {}
    end

    local counts = GetItemCounts(loadout)
    local plan = {}

    for _, item in ipairs(loadout.items or {}) do
        local desired = tonumber(item.desiredQuantity) or 0
        local bagCount = tonumber(counts[item.id] and counts[item.id].bagCount or 0) or 0
        local extra = math.max(0, bagCount - desired)

        if extra > 0 then
            table.insert(plan,
            {
                itemID = tonumber(item.itemID),
                desiredQuantity = desired,
                amount = extra,
                bagCount = bagCount,
            })
        end
    end

    return plan

end

function LoadoutService:IsBankTransferAvailable()

    if IsBankFrameVisible then
        return IsBankFrameVisible() == true
    end

    return BankFrame and BankFrame:IsVisible() == true

end

function LoadoutService:FindContainerItemSlot(containerID, itemID, count)

    local numSlots = GetContainerNumSlots(containerID)

    if not numSlots then
        return nil, nil
    end

    for slot = 1, numSlots do
        local slotItemID = select(1, GetContainerItemInfo(containerID, slot))

        if slotItemID and slotItemID == itemID then
            local stackCount = select(8, GetContainerItemInfo(containerID, slot)) or 0
            if count <= (tonumber(stackCount) or 0) then
                return containerID, slot
            end
        end
    end

    return nil, nil

end

function LoadoutService:Withdraw(loadout)

    if not self:IsBankTransferAvailable() then
        return false
    end

    local plan = self:PlanWithdraw(loadout)
    local withdrew = false

    for _, entry in ipairs(plan) do
        local containerID, slotID = self:FindContainerItemSlot(-1, entry.itemID, entry.amount)

        if containerID and slotID then
            local stackCount = select(8, GetContainerItemInfo(containerID, slotID)) or 0
            if entry.amount < (tonumber(stackCount) or 0) then
                SplitContainerItem(containerID, slotID, entry.amount)
            else
                PickupContainerItem(containerID, slotID)
            end

            PutItemInBackpack()
            withdrew = true
        end
    end

    return withdrew

end

function LoadoutService:Deposit(loadout)

    if not self:IsBankTransferAvailable() then
        return false
    end

    local plan = self:PlanDeposit(loadout)
    local deposited = false

    for _, entry in ipairs(plan) do
        local containerID, slotID = self:FindContainerItemSlot(0, entry.itemID, entry.amount)

        if containerID and slotID then
            local stackCount = select(8, GetContainerItemInfo(containerID, slotID)) or 0
            if entry.amount < (tonumber(stackCount) or 0) then
                SplitContainerItem(containerID, slotID, entry.amount)
            else
                PickupContainerItem(containerID, slotID)
            end

            DepositCursorItem()
            deposited = true
        end
    end

    return deposited

end

AC.ServiceManager:Register("LoadoutService", LoadoutService)

return LoadoutService
