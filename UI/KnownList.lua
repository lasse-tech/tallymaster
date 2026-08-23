local ADDON, T = ...
local L = T.L
local DB = T.DB

local KnownList = {}
T.KnownList = KnownList

local FRAME_W, FRAME_H = 360, 440
local PAD = 14
local ROW_H = 22
local SCROLLBAR_W = 22
local COUNT_W = 80
local CONTENT_W = FRAME_W - PAD * 2 - SCROLLBAR_W

local frame, rowPool
local counts = {}
local searchText = ""
local filterCategory = nil
local sortKey, sortAsc = "name", true

local ARROW_UP   = "|TInterface\\Buttons\\Arrow-Up-Up:14:14|t"
local ARROW_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:14:14|t"

local function matchesFilters(entry)
    if filterCategory and DB:EffectiveCategory(entry) ~= filterCategory then
        return false
    end
    if searchText ~= "" then
        local hay = (entry.originalName .. " " .. entry.originalName):lower()
        if not hay:find(searchText, 1, true) then return false end
    end
    return true
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

local function styleRow(row)
    row:SetSize(CONTENT_W, ROW_H)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 4, ROW_H - 4)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -2, 0)
    row.count:SetWidth(COUNT_W)
    row.count:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:RegisterForClicks("AnyUp")
    row:SetScript("OnClick", function(self)
        if not IsShiftKeyDown() then return end
        local entry = DB:GetEntry(self.entryKey)
        if entry then T.AddInput:Paste(entry) end
    end)
    row:SetScript("OnEnter", function(self)
        T.ShowEntryTooltip(self, DB:GetEntry(self.entryKey))
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function makeHeaderButton(parent, width, justify, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 18)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetAllPoints()
    button.label:SetJustifyH(justify)
    button.label:SetTextColor(1, 0.82, 0)
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnClick", onClick)
    return button
end

local function updateFilterText()
    frame.filter:SetDefaultText(filterCategory or L["All categories"])
end

function KnownList:Refresh(newCounts)
    if newCounts then counts = newCounts end
    if not frame or not frame:IsShown() then return end

    frame.hName.label:SetText(headerText(L["Name"], "name"))
    frame.hCount.label:SetText(headerText(L["Count"], "count"))
    updateFilterText()

    rowPool:ReleaseAll()

    local entries = {}
    for _, entry in pairs(DB:Global().entries) do
        if matchesFilters(entry) then entries[#entries + 1] = entry end
    end
    table.sort(entries, T.Counting:Comparator(counts, sortKey == "count", sortAsc))

    local y = 0
    for _, entry in ipairs(entries) do
        local row = rowPool:Acquire()
        if not row.name then styleRow(row) end
        row.entryKey = entry.key
        row.icon:SetTexture(entry.icon or 134400)
        row.name:SetText(entry.originalName .. DB:TierMarkup(entry))
        row.count:SetText(BreakUpLargeNumbers(counts[entry.key] or 0))
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + ROW_H
    end

    frame.content:SetSize(CONTENT_W, math.max(y, 1))
end

function KnownList:Create()
    if frame then return end

    frame = CreateFrame("Frame", "TallymasterKnownListFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -14)
    frame.title:SetText(L["Known items"])

    frame.close = CreateFrame("Button", "TallymasterKnownListCloseButton", frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", 2, 2)

    tinsert(UISpecialFrames, "TallymasterKnownListFrame")

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", PAD + 6, -42)
    searchLabel:SetText(L["Search"])

    local search = CreateFrame("EditBox", "TallymasterKnownListSearchBox", frame, "InputBoxTemplate")
    search:SetHeight(22)
    search:SetPoint("TOPLEFT", PAD + 6, -58)
    search:SetWidth(178)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        searchText = (self:GetText() or ""):lower()
        KnownList:Refresh()
    end)

    local filter = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    filter:SetPoint("TOPRIGHT", -PAD, -58)
    filter:SetSize(146, 22)
    filter:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["All categories"],
            function() return filterCategory == nil end,
            function()
                filterCategory = nil
                KnownList:Refresh()
            end)
        for _, cat in ipairs(DB:AllCategories()) do
            rootDescription:CreateRadio(cat,
                function(value) return filterCategory == value end,
                function(value)
                    filterCategory = value
                    KnownList:Refresh()
                end, cat)
        end
    end)
    frame.filter = filter

    frame.hName = makeHeaderButton(frame, CONTENT_W - COUNT_W, "LEFT", function() setSort("name") end)
    frame.hName:SetPoint("TOPLEFT", PAD, -90)
    frame.hCount = makeHeaderButton(frame, COUNT_W, "RIGHT", function() setSort("count") end)
    frame.hCount:SetPoint("TOPLEFT", frame.hName, "TOPRIGHT", 0, 0)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", PAD, -110)
    divider:SetPoint("TOPRIGHT", -PAD, -110)

    local scroll = CreateFrame("ScrollFrame", "TallymasterKnownListScrollFrame", frame,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -116)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR_W, PAD)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(content)
    frame.scroll, frame.content = scroll, content

    rowPool = CreateFramePool("Button", content, nil, function(_, row) row:Hide() end)

    frame:Hide()

    if T.SkinElvUI then T.SkinElvUI() end
end

function KnownList:Toggle()
    self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:Refresh(T.Counting:Snapshot())
    end
end
