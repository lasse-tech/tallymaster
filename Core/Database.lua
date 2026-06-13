local ADDON, T = ...

--[[
    Storage model
    -------------
    Entry definitions, custom names and categories are ACCOUNT-WIDE (db.global),
    even when counts are shown per character. Which entries are currently shown
    on the on-screen tracker is PER CHARACTER (db.char.visible).

    Entry key: "<type>:<id>"  e.g. "item:6948", "currency:1166".

    entry = {
        key          = "item:6948",
        type         = "item" | "currency" | "mount" | "pet" | "transmog" | "knowledge",
        id           = 6948,
        originalName = "Hearthstone",   -- immutable, captured at add time
        customName   = nil,             -- user override; nil = use original
        category     = "Other",         -- account-wide; nil/"" => Uncategorized
        icon         = 134414,          -- fileID for display

        -- Item-only details captured at add time (see Resolve:itemDetails):
        itemQuality     = 1,            -- rarity enum (Poor..Legendary)
        craftingQuality = 3,            -- crafting tier 1-3, or nil if none
        respectQuality  = false,        -- true = count only this exact tier;
                                        -- false = count any quality (by name)
        itemLevel       = 0,
        itemType        = "Tradegoods", -- localized top-level type
        itemSubType     = "Cooking",    -- localized subtype
        stackCount      = 200,          -- max stack size
        sellPrice       = 0,            -- vendor sell price (copper)
        bindType        = 0,            -- 0 none,1 BoP,2 BoE,3 BoU,4 quest
        expansionID     = 10,           -- expansion enum
    }
]]

T.dbDefaults = {
    profile = {
        scope    = "char",     -- "char" | "account"
        sortMode = "alpha",    -- "alpha" | "count"
        showCategories = true, -- group the tracker by category (false = flat list)
        showTooltip = true,    -- show a tooltip when hovering a tracker row
        showTooltipCounts = true, -- include the per-character count breakdown in it
        elvuiSkin = true,
        minimap  = { hide = false },
        -- Remembered tracker position; TOPLEFT-anchored so it resizes downward.
        tracker  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 16, y = -220 },
    },
    global = {
        entries        = {},   -- [key] = entry
        categoryFold   = {},   -- [categoryName] = true (folded)
        customCategories = {}, -- [name] = true (user-created categories, for the picker)
        charCounts     = {},   -- [charKey] = { [entryKey] = number }  (for account-wide sum)
    },
    char = {
        visible = {},          -- [key] = true  (shown on the on-screen tracker)
    },
}

local DB = {}
T.DB = DB

function DB:Get()        return T.Addon.db end
function DB:Profile()    return T.Addon.db.profile end
function DB:Global()     return T.Addon.db.global end
function DB:Char()       return T.Addon.db.char end

function DB:CharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return (name or "?") .. "-" .. (realm or "?")
end

function DB:MakeKey(entryType, id)
    return entryType .. ":" .. tostring(id)
end

function DB:GetEntry(key)
    return self:Global().entries[key]
end

function DB:AddEntry(entry)
    self:Global().entries[entry.key] = entry
    return entry
end

function DB:DeleteEntry(key)
    self:Global().entries[key] = nil
    self:Char().visible[key] = nil
    for _, counts in pairs(self:Global().charCounts) do
        counts[key] = nil
    end
end

-- Visible = shown on the on-screen tracker (per character)
function DB:IsVisible(key) return self:Char().visible[key] == true end
function DB:SetVisible(key, visible)
    self:Char().visible[key] = visible and true or nil
end

-- Display name. (Renaming was removed, so this is always the original name.)
function DB:DisplayName(entry)
    return entry.originalName
end

-- Remembered tracker position.
function DB:TrackerPos() return self:Profile().tracker end
function DB:SaveTrackerPos(point, relPoint, x, y)
    local t = self:Profile().tracker
    t.point, t.relPoint, t.x, t.y = point, relPoint, x, y
end

-- Crafting-quality star markup for display, shown only when this entry tracks one
-- exact tier (respectQuality). For "any quality" entries the count is an aggregate,
-- so no single tier icon is shown.
function DB:TierMarkup(entry)
    if entry.respectQuality and entry.craftingQuality and CreateAtlasMarkup then
        return " " .. CreateAtlasMarkup("Professions-ChatIcon-Quality-Tier" .. entry.craftingQuality, 14, 14)
    end
    return ""
end

-- Effective category: "" / nil => Uncategorized bucket
function DB:EffectiveCategory(entry)
    if entry.category and entry.category ~= "" then
        return entry.category
    end
    return T.UNCATEGORIZED
end

function DB:IsFolded(category) return self:Global().categoryFold[category] == true end
function DB:ToggleFold(category)
    local g = self:Global()
    g.categoryFold[category] = (not g.categoryFold[category]) or nil
end

-- Account-wide count cache (used when scope == "account")
function DB:StashCount(key, count)
    local g = self:Global()
    local ck = self:CharKey()
    g.charCounts[ck] = g.charCounts[ck] or {}
    g.charCounts[ck][key] = count
end

function DB:SumAccountCount(key)
    local total = 0
    for _, counts in pairs(self:Global().charCounts) do
        total = total + (counts[key] or 0)
    end
    return total
end

-- Per-character contributions for an entry, grouped by realm (for the tooltip).
-- Char keys are "Name-Realm"; we split on the first '-' (character names have no
-- hyphen). Returns a realm-sorted list and a map realm -> {name, count} (count desc).
function DB:AccountBreakdownByRealm(key)
    local realms, order = {}, {}
    for charKey, counts in pairs(self:Global().charCounts) do
        local n = counts[key]
        if n and n > 0 then
            local name, realm = charKey:match("^(.-)%-(.+)$")
            name = name or charKey
            realm = realm or "?"
            if not realms[realm] then realms[realm] = {}; order[#order + 1] = realm end
            table.insert(realms[realm], { name = name, count = n })
        end
    end
    table.sort(order)
    for _, list in pairs(realms) do
        table.sort(list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)
    end
    return order, realms
end

-- Current-locale display name for an entry, from its live type API. Returns nil
-- if not available yet (e.g. an item whose data isn't cached this session).
function DB:CurrentName(entry)
    local id = entry.id
    if entry.type == "item" then
        return (C_Item.GetItemInfo(id))
    elseif entry.type == "currency" then
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        if info and info.name and info.name ~= "" then return info.name end
    elseif entry.type == "mount" then
        if C_MountJournal then return (C_MountJournal.GetMountInfoByID(id)) end
    elseif entry.type == "pet" then
        if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
            return (C_PetJournal.GetPetInfoBySpeciesID(id))
        end
    end
    return nil
end

-- Re-localize stored entries to the current client language: re-derive auto
-- categories and re-resolve display names whenever the locale changed since the
-- data was last stamped (also repairs bogus numeric categories from an old bug).
-- Stored names/categories are localized strings captured at add time, so without
-- this they'd stay in the language they were first added in. Returns the item ids
-- whose names weren't cached yet, for an async second pass.
function DB:Relocalize()
    local g = self:Global()
    local locale = GetLocale()
    local switched = g.locale ~= locale
    local pending = {}
    for _, entry in pairs(g.entries) do
        local c = entry.category
        local badCat = c ~= nil and (type(c) ~= "string" or tonumber(c) ~= nil)
        if switched or badCat then
            entry.category = T.Categories:Auto(entry.type, entry.id)
        end
        if switched then
            local name = self:CurrentName(entry)
            if name then
                entry.originalName = name
            elseif entry.type == "item" and C_Item and C_Item.RequestLoadItemDataByID then
                pending[#pending + 1] = entry.id
                C_Item.RequestLoadItemDataByID(entry.id)
            end
        end
    end
    g.locale = locale
    return pending
end

-- All known categories: auto-derived from entries + user-created, sorted
function DB:AllCategories()
    local seen, list = {}, {}
    for _, entry in pairs(self:Global().entries) do
        local c = self:EffectiveCategory(entry)
        if not seen[c] then seen[c] = true; list[#list+1] = c end
    end
    for name in pairs(self:Global().customCategories) do
        if not seen[name] then seen[name] = true; list[#list+1] = name end
    end
    table.sort(list)
    return list
end
