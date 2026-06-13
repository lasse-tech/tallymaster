local ADDON, T = ...
local L = T.L
local DB = T.DB

--[[
    The storage browser: every entry ever added, regardless of tracker
    visibility. Search box + category filter + scrolling list.
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

local function makeRow(scroll, entry)
    local label = AceGUI:Create("InteractiveLabel")
    label:SetFullWidth(true)
    label:SetText(rowLabelText(entry))
    label:SetImage(entry.icon or 134400)
    label:SetImageSize(18, 18)
    label:SetCallback("OnClick", function(_, _, button)
        if button == "RightButton" then
            openRowMenu(label.frame, entry)
        elseif IsShiftKeyDown() then
            T.AddInput:Paste(entry.originalName)
        end
    end)
    scroll:AddChild(label)
end

function KnownList:Refresh()
    if not widget or not widget:IsShown() then return end
    local scroll = widget.scroll
    scroll:ReleaseChildren()

    local entries = {}
    for _, entry in pairs(DB:Global().entries) do
        if matchesFilters(entry) then entries[#entries + 1] = entry end
    end
    table.sort(entries, function(a, b)
        return DB:DisplayName(a):lower() < DB:DisplayName(b):lower()
    end)
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
