local ADDON, T = ...
local L = T.L

--[[
    Auto-category resolution.

    Decision: default category = the item's TOP-LEVEL type (itemType string),
    e.g. "Consumable", "Tradegoods", "Armor". Non-item types map to a fixed label.
    The user can override the category at any time; this only supplies the default
    at add time.
]]

local Categories = {}
T.Categories = Categories

local FIXED_LABELS = {
    currency  = L["Currencies"],
    mount     = L["Mounts"],
    transmog  = L["Transmog"],
    pet       = L["Battle Pets"],
    knowledge = L["Knowledge"],
}

-- Returns the default category string for a freshly resolved entry.
function Categories:Auto(entryType, id)
    if entryType == "item" then
        -- GetItemInfoInstant is synchronous (no server round-trip). Its returns are:
        --   itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
        -- The localized top-level type is the 2nd value (itemType). NOTE: the 6th
        -- value is classID, a NUMBER -- reading that by mistake stored numeric
        -- categories like "0" (classID 0 = Consumable).
        local _, itemType = C_Item.GetItemInfoInstant(id)
        if type(itemType) == "string" and itemType ~= "" then
            return itemType
        end
        return nil -- -> Uncategorized
    end

    if entryType == "currency" then
        -- Prefer the in-game currency list header if we can find it; else "Currencies".
        local header = self:CurrencyHeader(id)
        return header or FIXED_LABELS.currency
    end

    return FIXED_LABELS[entryType] -- mount/pet/transmog/knowledge -> fixed label
end

-- Walk the currency list to find the header (category) a currency lives under.
function Categories:CurrencyHeader(currencyID)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then return nil end
    local size = C_CurrencyInfo.GetCurrencyListSize()
    local currentHeader
    for i = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info then
            if info.isHeader then
                currentHeader = info.name
            else
                local link = C_CurrencyInfo.GetCurrencyListLink(i)
                local id = link and tonumber(link:match("currency:(%d+)"))
                if id == currencyID then
                    return currentHeader
                end
            end
        end
    end
    return nil
end
