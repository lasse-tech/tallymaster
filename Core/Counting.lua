local ADDON, T = ...
local DB = T.DB

--[[
    Counting: live totals per tracked entry.

    Item count sources: bags + bank + reagent bank (via C_Item.GetItemCount,
    which the client keeps current even when the bank frame is closed, once seen
    this session) PLUS equipped slots and mail attachments (scanned/cached
    separately, since GetItemCount excludes them).

    Mail is only fully readable while the inbox is open, so its per-item counts
    are cached and refreshed on MAIL_INBOX_UPDATE.

    Other types report collection/holding counts via their own APIs.
]]

local Counting = {}
T.Counting = Counting

local mailCache = {} -- [itemID] = count, rebuilt while the inbox is open

-- ---- per-source item scanning ---------------------------------------------

local function equippedCount(itemID)
    local n = 0
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        if GetInventoryItemID("player", slot) == itemID then
            n = n + 1
        end
    end
    return n
end

local function rebuildMailCache()
    wipe(mailCache)
    local num = GetInboxNumItems and GetInboxNumItems() or 0
    for i = 1, num do
        local attachments = ATTACHMENTS_MAX_RECEIVE or 16
        for j = 1, attachments do
            local _, itemID, _, count = GetInboxItem(i, j)
            if itemID and count then
                mailCache[itemID] = (mailCache[itemID] or 0) + count
            end
        end
    end
end

-- Total of one specific item id across bags/bank/reagent bank + equipped + mail.
local function itemTotal(id)
    local n = C_Item.GetItemCount(id, true, false, true) or 0
    return n + equippedCount(id) + (mailCache[id] or 0)
end

-- Container ids to scan when discovering quality-tier siblings by name. Built
-- once; invalid/unopened bags simply report 0 slots.
local SCAN_BAGS
local function scanBags()
    if SCAN_BAGS then return SCAN_BAGS end
    SCAN_BAGS = { 0, 1, 2, 3, 4 }
    local bi = Enum and Enum.BagIndex
    if bi then
        if bi.ReagentBag then SCAN_BAGS[#SCAN_BAGS + 1] = bi.ReagentBag end
        for _, k in ipairs({ "Bank", "Reagentbank",
            "CharacterBankTab_1", "CharacterBankTab_2", "CharacterBankTab_3",
            "CharacterBankTab_4", "CharacterBankTab_5", "CharacterBankTab_6" }) do
            if bi[k] then SCAN_BAGS[#SCAN_BAGS + 1] = bi[k] end
        end
    else
        SCAN_BAGS[#SCAN_BAGS + 1] = 5
    end
    return SCAN_BAGS
end

-- Sum across every crafting quality of an item: discover sibling item ids sharing
-- the base name in the player's containers, then total each (GetItemCount keeps
-- bank amounts current). A tier held ONLY in the bank and never carried may be
-- missed until the bank is opened -- the same caching caveat as GetItemCount.
local function nameCount(entry)
    local seen = { [entry.id] = true }
    for _, bag in ipairs(scanBags()) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local sid = C_Container.GetContainerItemID(bag, slot)
            if sid and not seen[sid] and C_Item.GetItemInfo(sid) == entry.originalName then
                seen[sid] = true
            end
        end
    end
    local total = 0
    for sid in pairs(seen) do total = total + itemTotal(sid) end
    return total
end

-- ---- per-type totals -------------------------------------------------------

local typeHandlers = {
    item = function(entry)
        -- "Any quality" (default) sums all crafting tiers of the item; "respect
        -- quality", or an item with no quality, counts just this exact item id.
        if entry.craftingQuality and not entry.respectQuality then
            return nameCount(entry)
        end
        return itemTotal(entry.id)
    end,

    currency = function(entry)
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.id)
        return (info and info.quantity) or 0
    end,

    mount = function(entry)
        if not C_MountJournal then return 0 end
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(entry.id)
        return isCollected and 1 or 0
    end,

    pet = function(entry)
        if not C_PetJournal then return 0 end
        local numCollected = C_PetJournal.GetNumCollectedInfo(entry.id)
        return numCollected or 0
    end,

    transmog = function(entry)
        if not C_TransmogCollection then return 0 end
        return C_TransmogCollection.PlayerHasTransmog(entry.id) and 1 or 0
    end,

    knowledge = function() return 0 end, -- TODO: profession knowledge currency mapping
}

-- This character's live count, right now.
function Counting:LiveCount(entry)
    local handler = typeHandlers[entry.type]
    if not handler then return 0 end
    return handler(entry) or 0
end

-- Count to display, honoring the per-character / account-wide scope toggle.
function Counting:DisplayCount(entry)
    local live = self:LiveCount(entry)
    DB:StashCount(entry.key, live) -- keep this char's contribution fresh for account mode
    if DB:Profile().scope == "account" then
        return DB:SumAccountCount(entry.key)
    end
    return live
end

-- ---- events ----------------------------------------------------------------

function Counting:Enable()
    local addon = T.Addon
    local function refresh() addon:RefreshTracker() end

    addon:RegisterEvent("BAG_UPDATE_DELAYED", refresh)
    addon:RegisterEvent("PLAYERBANKSLOTS_CHANGED", refresh)
    addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", refresh)
    addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE", refresh)
    addon:RegisterEvent("NEW_MOUNT_ADDED", refresh)
    addon:RegisterEvent("PET_JOURNAL_LIST_UPDATE", refresh)
    addon:RegisterEvent("TRANSMOG_COLLECTION_UPDATED", refresh)

    addon:RegisterEvent("MAIL_INBOX_UPDATE", function()
        rebuildMailCache()
        refresh()
    end)
    addon:RegisterEvent("MAIL_CLOSED", refresh)
end
