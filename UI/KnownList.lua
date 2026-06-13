local ADDON, T = ...
local L = T.L
local DB = T.DB

--[[
    The storage browser: every entry ever added, regardless of tracker
    visibility. Search box + category filter + a two-column scrolling list
    (icon+name | count) with clickable, sortable column headers.
      - Shift-click a row -> paste its name into the add box.
      - Right-click a row -> context menu: Delete, Rename.
    Renaming sets entry.customName (original kept). Display here is
    "Custom (Original)" when a custom name is set.

    Built with AceGUI for a skinnable, scrollable container. Context menus use
    the modern MenuUtil API (EasyMenu is removed in modern clients).
]]

local AceGUI = LibStub("AceGUI-3.0")
local KnownList = {}
T.KnownList = KnownList

local widget          -- AceGUI Frame
local searchText = ""
local filterCategory = nil -- nil = all
local sortKey, sortAsc = "name", true -- "name" | "count"
local NAME_W, COUNT_W = 0.72, 0.28    -- relative column widths

-- Sort-direction arrows as texture markup. Unicode arrows (▲/▼) render as tofu in
-- the default UI font, so we use the built-in arrow textures instead.
local ARROW_UP   = "|TInterface\\Buttons\\Arrow-Up-Up:14:14|t"
local ARROW_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:14:14|t"

local function rowLabelText(entry)
    if entry.customName and entry.customName ~= "" then
        return ("%s |cff808080(%s)|r"):format(entry.customName, entry.originalName)
    end
    return entry.originalName
end

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

local function openRowMenu(anchor, entry)
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(DB:DisplayName(entry))
        root:CreateButton(L["Rename"], function()
            StaticPopupDialogs["TALLYMASTER_RENAME"] = StaticPopupDialogs["TALLYMASTER_RENAME"] or {
                text = L["Enter a new display name (leave empty to reset)"],
                button1 = ACCEPT, button2 = CANCEL,
                hasEditBox = true, whileDead = true, timeout = 0, hideOnEscape = true,
                OnShow = function(self) self.editBox:SetText(self.data.customName or "") end,
                OnAccept = function(self)
                    local e = DB:GetEntry(self.data.key)
                    if e then
                        local txt = self.editBox:GetText()
                        e.customName = (txt ~= "" and txt) or nil
                        T.Addon:RefreshTracker()
                        KnownList:Refresh()
                    end
                end,
            }
            local d = StaticPopup_Show("TALLYMASTER_RENAME", DB:DisplayName(entry))
            if d then d.data = entry end
        end)
        root:CreateButton(L["Delete"], function()
            DB:DeleteEntry(entry.key)
            T.Addon:RefreshTracker()
            KnownList:Refresh()
        end)
    end)
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

-- Header label text with the active-column sort arrow appended.
local function headerText(base, key)
    if sortKey ~= key then return base end
    return base .. " " .. (sortAsc and ARROW_UP or ARROW_DOWN)
end

local function setSort(key)
    if sortKey == key then
        sortAsc = not sortAsc           -- same column: flip direction
    else
        sortKey = key
        sortAsc = (key == "name")       -- name defaults A→Z; count defaults high→low
    end
    KnownList:Refresh()
end

-- One list row: icon+name in column 1, count in column 2. The whole row reacts
-- to shift-click (paste) and right-click (context menu) on either column.
local function makeRow(scroll, entry)
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local name = AceGUI:Create("InteractiveLabel")
    name:SetRelativeWidth(NAME_W)
    name:SetText(rowLabelText(entry) .. DB:TierMarkup(entry))
    name:SetImage(entry.icon or 134400)
    name:SetImageSize(18, 18)

    local count = AceGUI:Create("InteractiveLabel")
    count:SetRelativeWidth(COUNT_W)
    count:SetText(BreakUpLargeNumbers(T.Counting:DisplayCount(entry)))
    if count.label then count.label:SetJustifyH("RIGHT") end

    local function onClick(_, _, button)
        if button == "RightButton" then
            openRowMenu(name.frame, entry)
        elseif IsShiftKeyDown() then
            T.AddInput:Paste(entry.originalName)
        end
    end
    name:SetCallback("OnClick", onClick)
    count:SetCallback("OnClick", onClick)

    -- Item tooltip on hover (shared with the tracker; respects the settings).
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
    _G["TallymasterKnownListFrame"] = widget.frame -- stable name for ElvUI skinning

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

    -- Clickable column headers: click "Name" or "Count" to sort by that column;
    -- click again to flip the direction (arrow shows the active column/direction).
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

    -- Divider line so the header doesn't visually merge with the first row.
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
