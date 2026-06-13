local ADDON, T = ...
local L = T.L

local Categories = {}
T.Categories = Categories

local FIXED_LABELS = {
    currency  = L["Currencies"],
    mount     = L["Mounts"],
    transmog  = L["Transmog"],
    pet       = L["Battle Pets"],
    knowledge = L["Knowledge"],
}

function Categories:Auto(entryType, id)
    if entryType == "item" then
        local _, itemType = C_Item.GetItemInfoInstant(id)
        if type(itemType) == "string" and itemType ~= "" then
            return itemType
        end
        return nil
    end

    if entryType == "currency" then
        local header = self:CurrencyHeader(id)
        return header or FIXED_LABELS.currency
    end

    return FIXED_LABELS[entryType]
end

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
