local ADDON, T = ...
local L = T.L
local DB = T.DB

local Resolve = {}
T.Resolve = Resolve

local function buildEntry(entryType, id, name, icon)
    return {
        key          = DB:MakeKey(entryType, id),
        type         = entryType,
        id           = id,
        originalName = name,
        customName   = nil,
        category     = T.Categories:Auto(entryType, id),
        icon         = icon,
    }
end

local function craftingQuality(itemInfo)
    if not C_TradeSkillUI then return nil end
    local q
    if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo)
    end
    if not q and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        q = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo)
    end
    return q
end

local function itemEntry(id, link)
    local info = link or id
    local name, _, quality, itemLevel, _, itemType, itemSubType, stackCount,
          _, icon, sellPrice, _, _, bindType, expacID = C_Item.GetItemInfo(info)
    if not name then return nil end
    return {
        key             = DB:MakeKey("item", id),
        type            = "item",
        id              = id,
        originalName    = name,
        customName      = nil,
        category        = T.Categories:Auto("item", id),
        icon            = icon,
        itemQuality     = quality,
        craftingQuality = craftingQuality(info),
        respectQuality  = false,
        itemLevel       = itemLevel,
        itemType        = itemType,
        itemSubType     = itemSubType,
        stackCount      = stackCount,
        sellPrice       = sellPrice,
        bindType        = bindType,
        expansionID     = expacID,
    }
end

local function tryItem(id, link)
    local instantName = C_Item.GetItemInfoInstant(id)
    if not instantName then return nil, false end
    local entry = itemEntry(id, link)
    if not entry then
        return nil, true
    end
    return entry, false
end

local function tryCurrency(id)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info or not info.name or info.name == "" then return nil end
    return buildEntry("currency", id, info.name, info.iconFileID)
end

function Resolve:ByID(id)
    local itemEntry, itemLoading = tryItem(id)
    local currencyEntry = tryCurrency(id)

    if itemEntry and currencyEntry then
        return { status = "ambiguous", candidates = { itemEntry, currencyEntry } }
    elseif itemEntry then
        return { status = "ok", entry = itemEntry }
    elseif currencyEntry then
        return { status = "ok", entry = currencyEntry }
    elseif itemLoading then
        return { status = "loading" }
    end
    return { status = "notfound" }
end

function Resolve:ByName(name)
    local _, link = C_Item.GetItemInfo(name)
    if link then
        local id = tonumber(link:match("item:(%d+)"))
        if id then
            local entry = tryItem(id, link)
            if entry then return { status = "ok", entry = entry } end
        end
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        local size = C_CurrencyInfo.GetCurrencyListSize()
        for i = 1, size do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and not info.isHeader and info.name and info.name:lower() == name:lower() then
                local clink = C_CurrencyInfo.GetCurrencyListLink(i)
                local id = clink and tonumber(clink:match("currency:(%d+)"))
                if id then
                    local entry = tryCurrency(id)
                    if entry then return { status = "ok", entry = entry } end
                end
            end
        end
    end

    return { status = "notfound" }
end

function Resolve:ByLink(link)
    if not link then return { status = "notfound" } end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return { status = "notfound" } end
    local entry, loading = tryItem(id, link)
    if entry then return { status = "ok", entry = entry } end
    if loading then return { status = "loading" } end
    return { status = "notfound" }
end

function Resolve:Query(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return { status = "notfound" } end
    local asNumber = tonumber(text)
    if asNumber then
        return self:ByID(asNumber)
    end
    return self:ByName(text)
end
