local _, T = ...
local L = T.L
local Compat = T.Compat

local Categories = {}
T.Categories = Categories

local FIXED_LABELS = {
    currency  = L["Currencies"],
    mount     = L["Mounts"],
    transmog  = L["Transmog"],
    pet       = L["Battle Pets"],
    knowledge = L["Knowledge"],
}

function Categories.Auto(entryType, id)
    if entryType == "item" then
        local _, itemType = C_Item.GetItemInfoInstant(id)
        if type(itemType) == "string" and itemType ~= "" then
            return itemType
        end
        return nil
    end

    if entryType == "currency" then
        local header = Categories.CurrencyHeader(id)
        return header or FIXED_LABELS.currency
    end

    return FIXED_LABELS[entryType]
end

-- Currency tab header; nil on Classic Era.
function Categories.CurrencyHeader(currencyID)
    if not Compat.hasCurrencyList then return nil end
    local currentHeader
    for i = 1, Compat.GetCurrencyListSize() do
        local info = Compat.GetCurrencyListInfo(i)
        if info then
            if info.isHeader then
                currentHeader = info.name
            else
                local link = Compat.GetCurrencyListLink(i)
                local id = link and tonumber(link:match("currency:(%d+)"))
                if id == currencyID then
                    return currentHeader
                end
            end
        end
    end
    return nil
end
