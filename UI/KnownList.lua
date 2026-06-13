local ADDON, T = ...
local L = T.L
local DB = T.DB

local AceGUI = LibStub("AceGUI-3.0")
local KnownList = {}
T.KnownList = KnownList

local widget
local searchText = ""
local filterCategory = nil
local sortKey, sortAsc = "name", true
local NAME_W, COUNT_W = 0.72, 0.28

local ARROW_UP   = "|TInterface\\Buttons\\Arrow-Up-Up:14:14|t"
local ARROW_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:14:14|t"

local function matchesFilters(entry)
    if filterCategory and DB:EffectiveCategory(entry) ~= filterCategory then
        return false
    end
    if searchText ~= "" then
        local hay = (DB:DisplayName(entry) .. " " .. entry.originalName):lower()
        if not hay:find(searchText, 1, true) then return false end
    end
    return true
end

local function sortEntries(list)
    table.sort(list, function(a, b)
        if sortKey == "count" then
            local ca, cb = T.Counting:DisplayCount(a), T.Counting:DisplayCount(b)
            if ca ~= cb then
                if sortAsc then return ca < cb end
                return ca > cb
            end
            return DB:DisplayName(a):lower() < DB:DisplayName(b):lower()
        end
        local na, nb = DB:DisplayName(a):lower(), DB:DisplayName(b):lower()
        if na ~= nb then
            if sortAsc then return na < nb end
            return na > nb
        end
        return false
    end)
end

local function headerText(base, key)
    if sortKey ~= key then return base end
    return base .. " " .. (sortAsc and ARROW_UP or ARROW_DOWN)
end

local function setSort(key)
    if sortKey == key then
        sortAsc = not sortAsc
    else
        sortKey = key
        sortAsc = (key == "name")
    end
    KnownList:Refresh()
end

local function makeRow(scroll, entry)
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local name = AceGUI:Create("InteractiveLabel")
    name:SetRelativeWidth(NAME_W)
    name:SetText(DB:DisplayName(entry) .. DB:TierMarkup(entry))
    name:SetImage(entry.icon or 134400)
    name:SetImageSize(18, 18)

    local count = AceGUI:Create("InteractiveLabel")
    count:SetRelativeWidth(COUNT_W)
    count:SetText(BreakUpLargeNumbers(T.Counting:DisplayCount(entry)))
    if count.label then count.label:SetJustifyH("RIGHT") end

    local function onClick()
        if IsShiftKeyDown() then
            T.AddInput:Paste(entry)
        end
    end
    name:SetCallback("OnClick", onClick)
    count:SetCallback("OnClick", onClick)

    local function onEnter(widget) T.ShowEntryTooltip(widget.frame, entry) end
    local function onLeave() GameTooltip:Hide() end
    name:SetCallback("OnEnter", onEnter)
    name:SetCallback("OnLeave", onLeave)
    count:SetCallback("OnEnter", onEnter)
    count:SetCallback("OnLeave", onLeave)

    row:AddChild(name)
    row:AddChild(count)
    scroll:AddChild(row)
end

function KnownList:Refresh()
    if not widget or not widget:IsShown() then return end
    local scroll = widget.scroll
    scroll:ReleaseChildren()

    if widget.hName then widget.hName:SetText(headerText(L["Name"], "name")) end
    if widget.hCount then widget.hCount:SetText(headerText(L["Count"], "count")) end

    local entries = {}
    for _, entry in pairs(DB:Global().entries) do
        if matchesFilters(entry) then entries[#entries + 1] = entry end
    end
    sortEntries(entries)
    for _, entry in ipairs(entries) do makeRow(scroll, entry) end
    scroll:DoLayout()
end

function KnownList:Create()
    if widget then return end
    widget = AceGUI:Create("Frame")
    widget:SetTitle(L["Known items"])
    widget:SetLayout("Flow")
    widget:SetWidth(360); widget:SetHeight(440)
    widget:SetCallback("OnClose", function(w) w:Hide() end)
    _G["TallymasterKnownListFrame"] = widget.frame

    local search = AceGUI:Create("EditBox")
    search:SetLabel(L["Search"])
    search:SetRelativeWidth(0.55)
    search:SetCallback("OnTextChanged", function(_, _, text)
        searchText = (text or ""):lower()
        KnownList:Refresh()
    end)
    widget:AddChild(search)

    local filter = AceGUI:Create("Dropdown")
    filter:SetLabel(L["All categories"])
    filter:SetRelativeWidth(0.45)
    local list = { __all = L["All categories"] }
    local order = { "__all" }
    for _, cat in ipairs(DB:AllCategories()) do
        list[cat] = cat; order[#order + 1] = cat
    end
    filter:SetList(list, order)
    filter:SetValue("__all")
    filter:SetCallback("OnValueChanged", function(_, _, key)
        filterCategory = (key ~= "__all") and key or nil
        KnownList:Refresh()
    end)
    widget:AddChild(filter)

    local header = AceGUI:Create("SimpleGroup")
    header:SetFullWidth(true)
    header:SetLayout("Flow")

    local hName = AceGUI:Create("InteractiveLabel")
    hName:SetRelativeWidth(NAME_W)
    hName:SetColor(1, 0.82, 0)
    hName:SetCallback("OnClick", function() setSort("name") end)

    local hCount = AceGUI:Create("InteractiveLabel")
    hCount:SetRelativeWidth(COUNT_W)
    hCount:SetColor(1, 0.82, 0)
    if hCount.label then hCount.label:SetJustifyH("RIGHT") end
    hCount:SetCallback("OnClick", function() setSort("count") end)

    header:AddChild(hName)
    header:AddChild(hCount)
    widget:AddChild(header)
    widget.hName, widget.hCount = hName, hCount

    local divider = AceGUI:Create("Heading")
    divider:SetFullWidth(true)
    widget:AddChild(divider)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    widget:AddChild(scroll)
    widget.scroll = scroll
end

function KnownList:Toggle()
    self:Create()
    if widget:IsShown() then
        widget:Hide()
    else
        widget:Show()
        self:Refresh()
    end
end
