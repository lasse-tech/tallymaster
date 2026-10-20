local _, T = ...
local DB = T.DB
local Compat = T.Compat

local Counting = {}
T.Counting = Counting

local mailCache = {}

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

-- GetItemCount includes equipped items.
local function itemTotal(id)
    local n = C_Item.GetItemCount(id, true, false, true, true) or 0
    return n + (mailCache[id] or 0)
end

local function nameCount(entry)
    local seen = { [entry.id] = true }
    for _, bag in ipairs(Compat.ScanBags()) do
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

local typeHandlers = {
    item = function(entry)
        if entry.craftingQuality and not entry.respectQuality then
            return nameCount(entry)
        end
        return itemTotal(entry.id)
    end,

    currency = function(entry)
        local info = Compat.GetCurrencyInfo(entry.id)
        return (info and info.quantity) or 0
    end,

    mount = function(entry)
        return Compat.MountCollected(entry.id) and 1 or 0
    end,

    pet = function(entry)
        return Compat.PetsCollected(entry.id)
    end,

    transmog = function(entry)
        return Compat.HasTransmog(entry.id) and 1 or 0
    end,

    knowledge = function() return 0 end,
}

function Counting.LiveCount(entry)
    local handler = typeHandlers[entry.type]
    if not handler then return 0 end
    return handler(entry) or 0
end

-- Shared by the whole account: counted once, not per character.
local ACCOUNT_WIDE = { mount = true, pet = true, transmog = true }

local function isAccountWide(entry)
    if entry.type == "currency" then
        local info = Compat.GetCurrencyInfo(entry.id)
        return info and info.isAccountWide or false
    end
    return ACCOUNT_WIDE[entry.type] or false
end

function Counting.Snapshot()
    local entries = DB.Global().entries
    local shared = {}
    for key, entry in pairs(entries) do
        local n = Counting.LiveCount(entry)
        if isAccountWide(entry) then
            shared[key] = n
            DB.ForgetCounts(key)
        else
            DB.StashCount(key, n)
        end
    end

    local account = DB.Profile().scope == "account"
    local counts = {}
    for key in pairs(entries) do
        counts[key] = shared[key] or (account and DB.SumAccountCount(key) or DB.CharCount(key))
    end
    return counts
end

function Counting.Comparator(counts, byCount, ascending)
    return function(a, b)
        if byCount then
            local ca, cb = counts[a.key] or 0, counts[b.key] or 0
            if ca ~= cb then
                if ascending then return ca < cb end
                return ca > cb
            end
            return a.originalName:lower() < b.originalName:lower()
        end
        local na, nb = a.originalName:lower(), b.originalName:lower()
        if na == nb then return false end
        if ascending then return na < nb end
        return na > nb
    end
end

function Counting.Enable()
    local addon = T.Addon
    local function refresh() addon.RefreshTracker() end

    addon.RegisterEvent("BAG_UPDATE_DELAYED", refresh)
    addon.RegisterEvent("PLAYERBANKSLOTS_CHANGED", refresh)
    addon.RegisterEvent("BANK_TABS_CHANGED", refresh)
    addon.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", refresh)
    addon.RegisterEvent("CURRENCY_DISPLAY_UPDATE", refresh)
    addon.RegisterEvent("NEW_MOUNT_ADDED", refresh)
    addon.RegisterEvent("PET_JOURNAL_LIST_UPDATE", refresh)
    addon.RegisterEvent("TRANSMOG_COLLECTION_UPDATED", refresh)

    addon.RegisterEvent("MAIL_INBOX_UPDATE", function()
        rebuildMailCache()
        refresh()
    end)
    addon.RegisterEvent("MAIL_CLOSED", refresh)
end
