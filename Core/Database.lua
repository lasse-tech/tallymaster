local ADDON, T = ...

T.dbDefaults = {
    profile = {
        scope    = "char",
        sortMode = "alpha",
        showCategories = true,
        showTooltip = true,
        showTooltipCounts = true,
        gameTooltipCounts = true,
        elvuiSkin = true,
        minimap  = { hide = false },
        tracker  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 16, y = -220 },
    },
    global = {
        entries        = {},
        categoryFold   = {},
        customCategories = {},
        charCounts     = {},
    },
    char = {
        visible = {},
    },
}

local DB = {}
T.DB = DB

local function copyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            copyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function DB:Initialize()
    local sv = _G.TallymasterDB
    if type(sv) ~= "table" then
        sv = {}
        _G.TallymasterDB = sv
    end

    local charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")

    sv.profileKeys = sv.profileKeys or {}
    local profileKey = sv.profileKeys[charKey] or "Default"
    sv.profileKeys[charKey] = profileKey

    sv.profiles = sv.profiles or {}
    sv.profiles[profileKey] = sv.profiles[profileKey] or {}
    sv.global = sv.global or {}
    sv.char = sv.char or {}
    sv.char[charKey] = sv.char[charKey] or {}

    local db = {
        profile = sv.profiles[profileKey],
        global  = sv.global,
        char    = sv.char[charKey],
    }
    copyDefaults(db.profile, T.dbDefaults.profile)
    copyDefaults(db.global, T.dbDefaults.global)
    copyDefaults(db.char, T.dbDefaults.char)

    T.Addon.db = db
    return db
end

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

function DB:IsVisible(key) return self:Char().visible[key] == true end
function DB:SetVisible(key, visible)
    self:Char().visible[key] = visible and true or nil
end

function DB:DisplayName(entry)
    return entry.originalName
end

function DB:TrackerPos() return self:Profile().tracker end
function DB:SaveTrackerPos(point, relPoint, x, y)
    local t = self:Profile().tracker
    t.point, t.relPoint, t.x, t.y = point, relPoint, x, y
end

function DB:TierMarkup(entry)
    if entry.respectQuality and entry.craftingQuality and CreateAtlasMarkup then
        return " " .. CreateAtlasMarkup("Professions-ChatIcon-Quality-Tier" .. entry.craftingQuality, 14, 14)
    end
    return ""
end

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
