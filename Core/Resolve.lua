local ADDON, T = ...
local L = T.L
local DB = T.DB

--[[
    Resolve a user query (name or numeric ID) into a TrackedEntry.

    - Numeric input that matches BOTH an item and a currency is AMBIGUOUS:
      we surface both candidates and the UI asks the user which one.
    - Item data may be uncached on first lookup (GetItemInfo returns nil); the
      caller is told to retry after GET_ITEM_INFO_RECEIVED.
    - Name lookup currently resolves items (via GetItemInfo) and exact-name
      currencies. Collectible-by-name is a known extension point (see TODO).

    Resolve returns a result table:
      { status = "ok",        entry = <entry> }
      { status = "ambiguous", candidates = { itemEntry, currencyEntry } }
      { status = "loading" }            -- data not cached yet, retry later
      { status = "notfound" }
]]

local Resolve = {}
T.Resolve = Resolve

local function buildEntry(entryType, id, name, icon)
    -- Non-item types (currency/mount/pet/...). Item entries use itemEntry() below,
    -- which also captures the richer item detail fields.
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

-- Crafting quality (Tier 1-3) of a specific item, or nil. Reagents and crafted
-- gear expose it through different TradeSkillUI calls; try both.
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

-- Build a full item entry. `link` (when known, e.g. from a shift-click) lets us
-- read the crafting quality of that exact item; otherwise we resolve from the id.
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

-- ---- per-type lookups ------------------------------------------------------

local function tryItem(id, link)
    local instantName = C_Item.GetItemInfoInstant(id)
    if not instantName then return nil, false end -- not a valid item id at all
    local entry = itemEntry(id, link)
    if not entry then
        return nil, true -- valid id but not cached yet -> loading
    end
    return entry, false
end

local function tryCurrency(id)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info or not info.name or info.name == "" then return nil end
    return buildEntry("currency", id, info.name, info.iconFileID)
end

-- ---- public API ------------------------------------------------------------

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
    -- Item by name: GetItemInfo accepts a name string only if the item is cached
    -- (e.g. seen in a tooltip/bags this session). Returns the item link we parse.
    local _, link = C_Item.GetItemInfo(name)
    if link then
        local id = tonumber(link:match("item:(%d+)"))
        if id then
            local entry = tryItem(id, link)
            if entry then return { status = "ok", entry = entry } end
        end
    end

    -- Currency by exact name: scan the currency list.
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

    -- TODO: collectible-by-name (mount/pet/transmog) via C_MountJournal /
    --       C_PetJournal search. Tracked as a follow-up; the entry builder and
    --       Counting module already support these types by ID.
    return { status = "notfound" }
end

-- Resolve a specific item hyperlink (e.g. from a shift-click), preserving the
-- exact item id and crafting quality of the clicked item.
function Resolve:ByLink(link)
    if not link then return { status = "notfound" } end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return { status = "notfound" } end
    local entry, loading = tryItem(id, link)
    if entry then return { status = "ok", entry = entry } end
    if loading then return { status = "loading" } end
    return { status = "notfound" }
end

-- Entry point used by the add UI.
function Resolve:Query(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return { status = "notfound" } end
    local asNumber = tonumber(text)
    if asNumber then
        return self:ByID(asNumber)
    end
    return self:ByName(text)
end
