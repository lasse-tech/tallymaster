local ADDON, T = ...
local L = T.L
local DB = T.DB

--[[
    The always-on, on-screen list (Blizzard "Track Recipe" style).
    - Only entries marked visible for this character are shown.
    - Grouped by effective category; category headers fold/unfold.
    - Within a group, sorted alphabetically or by count (profile.sortMode).
    - Shift-click a row -> hide from tracker (kept in storage).

    Rows are pooled. Built from a BackdropTemplate frame so ElvUI can skin it
    (see Skin/ElvUI.lua). Widgets use stable names for the same reason.
]]

local Tracker = {}
T.Tracker = Tracker

local ROW_H, HEADER_H, WIDTH, PAD = 20, 18, 220, 8
local frame, content, rowPool, headerPool

local function styleRow(row)
    row:SetSize(WIDTH - PAD * 2, ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 4, ROW_H - 4)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.iconBorder = row:CreateTexture(nil, "OVERLAY") -- separate border for S:HandleIcon
    row.iconBorder:SetAllPoints(row.icon)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetJustifyH("LEFT")

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.count:SetPoint("RIGHT", 0, 0)

    row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)

    row:RegisterForClicks("AnyUp")
    row:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() then
            DB:SetVisible(self.entryKey, false)
            T.Addon:RefreshTracker()
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not DB:Profile().showTooltip then return end
        local entry = DB:GetEntry(self.entryKey)
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.type == "item" then
            GameTooltip:SetItemByID(entry.id)
        elseif entry.type == "currency" then
            GameTooltip:SetCurrencyByID(entry.id)
        else
            GameTooltip:SetText(DB:DisplayName(entry))
        end
        -- Per-character counts grouped by realm, plus the total. Always shown
        -- (independent of the personal/account-wide display scope).
        local order, realms = DB:AccountBreakdownByRealm(entry.key)
        if #order > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Tallymaster"], 1, 0.82, 0)
            local total = 0
            for _, realm in ipairs(order) do
                GameTooltip:AddLine(realm, 0.6, 0.8, 1)
                for _, c in ipairs(realms[realm]) do
                    GameTooltip:AddDoubleLine("  " .. c.name, BreakUpLargeNumbers(c.count), 0.9, 0.9, 0.9, 1, 1, 1)
                    total = total + c.count
                end
            end
            GameTooltip:AddDoubleLine(TOTAL or "Total", BreakUpLargeNumbers(total), 1, 0.82, 0, 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function styleHeader(h)
    h:SetSize(WIDTH - PAD * 2, HEADER_H)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.label:SetPoint("LEFT", 2, 0)
    h:RegisterForClicks("AnyUp")
    h:SetScript("OnClick", function(self)
        DB:ToggleFold(self.category)
        T.Addon:RefreshTracker()
    end)
end

function Tracker:Initialize()
    if frame then return end
    frame = CreateFrame("Frame", "TallymasterTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 120)
    -- Restore the remembered position. TOPLEFT-anchored so growing/shrinking the
    -- list (collapse/expand) only changes height downward, never the position.
    local pos = DB:TrackerPos()
    frame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or pos.point or "TOPLEFT",
        pos.x or 16, pos.y or -220)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self.didDrag = true; self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Re-anchor by the top-left corner and remember it, so the position sticks
        -- across sessions and stays put when the list resizes.
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            DB:SaveTrackerPos("TOPLEFT", "BOTTOMLEFT", left, top)
        end
    end)
    frame:SetClampedToScreen(true)

    -- Click the tracker background/title: left-click opens the Add window,
    -- Shift+left-click hides the tracker. A drag (move) is not treated as a click.
    -- Rows keep their own shift-click behaviour (hide that single entry).
    frame:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        if self.didDrag then self.didDrag = false; return end
        if IsShiftKeyDown() then
            self:Hide()
        else
            T.AddInput:Toggle()
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", PAD, -4)
    frame.title:SetText(L["Tallymaster"])

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", PAD, -HEADER_H - 4)
    content:SetPoint("TOPRIGHT", -PAD, -HEADER_H - 4)

    -- Shown instead of the list when nothing is tracked yet.
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.empty:SetPoint("TOPLEFT", PAD, -HEADER_H - 6)
    frame.empty:SetPoint("TOPRIGHT", -PAD, -HEADER_H - 6)
    frame.empty:SetJustifyH("LEFT")
    frame.empty:SetSpacing(3)
    frame.empty:SetText(L["No items tracked yet."] .. "\n\n"
        .. L["Type /tally, click the minimap icon, or use the Add keybinding, then enter an item's name or ID."] .. "\n\n"
        .. L["Tip: with the Add window open, Shift-click an item in your bags to copy its name into the box."])
    frame.empty:Hide()

    rowPool    = CreateFramePool("Button", content, nil, function(_, r) r:Hide() end)
    headerPool = CreateFramePool("Button", content, nil, function(_, h) h:Hide() end)

    self.frame = frame
    self:Refresh()
end

function Tracker:Toggle()
    if not frame then self:Initialize() end
    frame:SetShown(not frame:IsShown())
end

-- Gather visible entries, grouped + sorted.
local function buildGroups()
    local groups = {}
    for key in pairs(DB:Char().visible) do
        local entry = DB:GetEntry(key)
        if entry then
            local cat = DB:EffectiveCategory(entry)
            groups[cat] = groups[cat] or {}
            table.insert(groups[cat], entry)
        end
    end

    local catNames = {}
    for cat in pairs(groups) do catNames[#catNames + 1] = cat end
    table.sort(catNames)

    local byCount = DB:Profile().sortMode == "count"
    for _, list in pairs(groups) do
        table.sort(list, function(a, b)
            if byCount then
                local ca = T.Counting:DisplayCount(a)
                local cb = T.Counting:DisplayCount(b)
                if ca ~= cb then return ca > cb end
            end
            return DB:DisplayName(a):lower() < DB:DisplayName(b):lower()
        end)
    end
    return groups, catNames
end

-- Place a single entry row at vertical offset y.
local function renderRow(entry, y)
    local row = rowPool:Acquire()
    if not row.name then styleRow(row) end
    row.entryKey = entry.key
    row.icon:SetTexture(entry.icon or 134400)
    row.name:SetText(DB:DisplayName(entry) .. DB:TierMarkup(entry))
    row.count:SetText(BreakUpLargeNumbers(T.Counting:DisplayCount(entry)))
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
end

-- Sort a flat (ungrouped) entry list by the current sort mode.
local function sortFlat(list)
    local byCount = DB:Profile().sortMode == "count"
    table.sort(list, function(a, b)
        if byCount then
            local ca, cb = T.Counting:DisplayCount(a), T.Counting:DisplayCount(b)
            if ca ~= cb then return ca > cb end
        end
        return DB:DisplayName(a):lower() < DB:DisplayName(b):lower()
    end)
end

function Tracker:Refresh()
    if not frame then return end
    rowPool:ReleaseAll()
    headerPool:ReleaseAll()

    local groups, catNames = buildGroups()

    -- Nothing tracked: show the how-to-add hint instead of an empty list.
    if #catNames == 0 then
        frame.empty:Show()
        content:SetHeight(1)
        local textH = frame.empty:GetStringHeight()
        if not textH or textH <= 0 then textH = 40 end
        frame:SetHeight(HEADER_H + textH + PAD * 2 + 6)
        return
    end
    frame.empty:Hide()

    local y = 0

    if DB:Profile().showCategories then
        for _, cat in ipairs(catNames) do
            local folded = DB:IsFolded(cat)
            local h = headerPool:Acquire()
            if not h.label then styleHeader(h) end
            h.category = cat
            h:SetPoint("TOPLEFT", 0, -y)
            local arrow = folded and "|TInterface\\Buttons\\UI-PlusButton-Up:12|t"
                                  or  "|TInterface\\Buttons\\UI-MinusButton-Up:12|t"
            h.label:SetText(arrow .. " " .. cat)
            h:Show()
            y = y + HEADER_H

            if not folded then
                for _, entry in ipairs(groups[cat]) do
                    renderRow(entry, y)
                    y = y + ROW_H
                end
            end
        end
    else
        -- Flat list: no headers, all visible entries sorted together.
        local all = {}
        for _, list in pairs(groups) do
            for _, e in ipairs(list) do all[#all + 1] = e end
        end
        sortFlat(all)
        for _, entry in ipairs(all) do
            renderRow(entry, y)
            y = y + ROW_H
        end
    end

    local total = y + HEADER_H + PAD * 2
    frame:SetHeight(math.max(total, 40))
    content:SetHeight(math.max(y, 1))
end
