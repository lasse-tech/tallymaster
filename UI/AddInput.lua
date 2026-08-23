local ADDON, T = ...
local L = T.L
local DB = T.DB

local AddInput = {}
T.AddInput = AddInput

local frame

function AddInput:Commit(entry)
    local existing = DB:GetEntry(entry.key)
    if existing then
        if entry.type == "item" then existing.respectQuality = entry.respectQuality end
        DB:SetVisible(existing.key, true)
        T.Addon:Print(L["Already tracking %s."]:format(existing.originalName))
    else
        DB:AddEntry(entry)
        DB:SetVisible(entry.key, true)
        T.Addon:Print(L["Now tracking %s."]:format(entry.originalName))
    end
    T.Addon:RefreshTracker()
    if T.KnownList and T.KnownList.Refresh then T.KnownList:Refresh() end
end

StaticPopupDialogs["TALLYMASTER_AMBIGUOUS"] = {
    text = L["The ID %d matches both an item and a currency. Which do you mean?"],
    button1 = L["Item"],
    button2 = L["Currency"],
    OnAccept = function(self) AddInput:Commit(self.data.candidates[1]) end,
    OnCancel = function(self, data, reason)
        if reason == "clicked" then AddInput:Commit(self.data.candidates[2]) end
    end,
    hideOnEscape = true, whileDead = true, timeout = 0,
}

local function askAmbiguous(result, id)
    local dialog = StaticPopup_Show("TALLYMASTER_AMBIGUOUS", id)
    if dialog then dialog.data = result end
end

function AddInput:Submit(text)
    local result
    if frame and frame.pending and frame.pendingText == text then
        result = { status = "ok", entry = frame.pending }
    else
        result = T.Resolve:Query(text)
    end

    if result.status == "ok" then
        local entry = result.entry
        if entry.type == "item" and entry.craftingQuality and frame and frame.respect then
            entry.respectQuality = frame.respect:GetChecked() and true or false
        end
        self:Commit(entry)
        if frame then frame.edit:SetText(""); self:Preview(nil); frame:Hide() end
    elseif result.status == "ambiguous" then
        askAmbiguous(result, tonumber(text))
    elseif result.status == "loading" then
        T.Addon:Print(L["Still loading data for that ID — try again in a moment."])
    else
        T.Addon:Print(L["Could not find anything matching '%s'."]:format(text))
    end
end

local function stripEscapes(s)
    if not s then return s end
    s = s:gsub("|A.-|a", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function linkToName(link)
    if not link then return nil end
    return stripEscapes(link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]"))
end

local BIND_LABELS = {
    [1] = ITEM_BIND_ON_PICKUP,
    [2] = ITEM_BIND_ON_EQUIP,
    [3] = ITEM_BIND_ON_USE,
    [4] = ITEM_BIND_QUEST,
}

local function greyLabel(label, value)
    return "|cff808080" .. label .. ":|r " .. value
end

local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

local function money(copper)
    if not copper or copper == 0 then return "—" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. GOLD_ICON end
    if s > 0 then parts[#parts + 1] = s .. SILVER_ICON end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COPPER_ICON end
    return table.concat(parts, " ")
end

local function formatDetails(e)
    local out = {}

    if e.itemQuality then
        local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[e.itemQuality]
        local hex = (c and c.hex) or "|cffffffff"
        local qn = _G["ITEM_QUALITY" .. e.itemQuality .. "_DESC"] or ""
        local tier = ""
        if e.craftingQuality and CreateAtlasMarkup then
            tier = " " .. CreateAtlasMarkup("Professions-ChatIcon-Quality-Tier" .. e.craftingQuality, 16, 16)
        end
        out[#out + 1] = greyLabel(L["Quality"], hex .. qn .. "|r" .. tier)
    end

    do
        local t = e.itemType or ""
        if e.itemSubType and e.itemSubType ~= "" then t = t .. " / " .. e.itemSubType end
        out[#out + 1] = greyLabel(L["Item level"], tostring(e.itemLevel or 0))
            .. "    " .. greyLabel(L["Type"], t)
    end

    out[#out + 1] = greyLabel(L["Stack"], tostring(e.stackCount or 1))
        .. "    " .. greyLabel(L["Sell"], money(e.sellPrice))

    do
        local parts = {}
        local exp = e.expansionID and _G["EXPANSION_NAME" .. e.expansionID]
        if exp then parts[#parts + 1] = greyLabel(L["Expansion"], exp) end
        local bind = BIND_LABELS[e.bindType or 0]
        if bind then parts[#parts + 1] = greyLabel(L["Bind"], bind) end
        if #parts > 0 then out[#out + 1] = table.concat(parts, "    ") end
    end

    return table.concat(out, "\n")
end

function AddInput:Preview(result)
    if not frame then return end
    if result and result.status == "ok" and result.entry.type == "item" then
        local e = result.entry
        frame.pending = e
        frame.pendingText = frame.edit:GetText()
        frame.icon:SetTexture(e.icon or 134400)
        frame.icon:Show()
        frame.details:SetText(formatDetails(e))
        if e.craftingQuality then
            frame.respect:SetChecked(false)
            frame.respect:Show()
        else
            frame.respect:Hide()
        end
    else
        frame.pending = nil
        frame.pendingText = nil
        frame.icon:Hide()
        frame.details:SetText("")
        frame.respect:Hide()
    end
end

function AddInput:SchedulePreview()
    self._previewToken = (self._previewToken or 0) + 1
    local token = self._previewToken
    C_Timer.After(0.3, function()
        if token ~= self._previewToken then return end
        if not frame or not frame:IsShown() then return end
        local text = frame.edit:GetText()
        if not text or text == "" then self:Preview(nil); return end
        self:Preview(T.Resolve:Query(text))
    end)
end

function AddInput:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TallymasterAddFrame", UIParent, "BackdropTemplate")
    frame:SetSize(440, 224)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)
    frame.title:SetText(L["Add item, currency or collectible"])

    frame.close = CreateFrame("Button", "TallymasterAddFrameCloseButton", frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", 2, 2)

    tinsert(UISpecialFrames, "TallymasterAddFrame")

    frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    frame:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" and self:IsShown()
           and self.edit and self.edit:HasFocus() and not self:IsMouseOver() then
            self.edit:ClearFocus()
        end
    end)

    local edit = CreateFrame("EditBox", "TallymasterAddFrameEditBox", frame, "InputBoxTemplate")
    edit:SetHeight(28)
    edit:SetPoint("TOPLEFT", 24, -54)
    edit:SetPoint("TOPRIGHT", -24, -54)
    edit:SetFontObject("GameFontHighlight")
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then AddInput:Submit(text) end
    end)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.edit = edit

    frame.editInstructions = edit:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.editInstructions:SetPoint("LEFT", edit, "LEFT", 6, 0)
    frame.editInstructions:SetPoint("RIGHT", edit, "RIGHT", -6, 0)
    frame.editInstructions:SetJustifyH("LEFT")
    frame.editInstructions:SetText(L["Type a name or ID, then press Enter"])
    edit:SetScript("OnTextChanged", function(self, userInput)
        frame.editInstructions:SetShown(self:GetText() == "")
        if userInput then
            frame.pending = nil
            AddInput:SchedulePreview()
        end
    end)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(40, 40)
    frame.icon:SetPoint("TOPLEFT", 26, -90)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.icon:Hide()

    frame.details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.details:SetPoint("TOPLEFT", 76, -92)
    frame.details:SetPoint("TOPRIGHT", -26, -92)
    frame.details:SetJustifyH("LEFT")
    frame.details:SetJustifyV("TOP")
    frame.details:SetSpacing(4)

    local respect = CreateFrame("CheckButton", "TallymasterAddFrameRespectQuality", frame, "UICheckButtonTemplate")
    respect:SetSize(24, 24)
    respect:SetPoint("BOTTOMLEFT", 22, 16)
    respect.text = respect:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    respect.text:SetPoint("LEFT", respect, "RIGHT", 2, 1)
    respect.text:SetText(L["Respect quality (count only this tier)"])
    respect:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["When on, this entry counts only the exact crafting quality you added. When off, it counts every quality of the item."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    respect:SetScript("OnLeave", function() GameTooltip:Hide() end)
    respect:Hide()
    frame.respect = respect

    local addBtn = CreateFrame("Button", "TallymasterAddFrameAddButton", frame, "UIPanelButtonTemplate")
    addBtn:SetSize(100, 24)
    addBtn:SetPoint("BOTTOMRIGHT", -22, 14)
    addBtn:SetText(L["Add"])
    addBtn:SetScript("OnClick", function()
        local text = frame.edit:GetText()
        if text and text ~= "" then AddInput:Submit(text) end
    end)

    if not AddInput._linkHooked then
        AddInput._linkHooked = true
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if not frame or not frame:IsShown() then return end
            if not IsModifiedClick("CHATLINK") then return end
            local name = linkToName(link)
            if not name then return end
            frame.edit:SetText(name)
            frame.edit:SetFocus()
            frame.edit:SetCursorPosition(#name)
            AddInput:Preview(T.Resolve:ByLink(link))
        end)
    end

    if StackSplitFrame and not AddInput._splitHooked then
        AddInput._splitHooked = true
        StackSplitFrame:HookScript("OnShow", function(self)
            if frame and frame:IsShown() then self:Hide() end
        end)
    end

    frame:Hide()

    if T.SkinElvUI then T.SkinElvUI() end
end

function AddInput:Paste(entryOrName)
    self:Create()
    frame:Show()
    frame:Raise()
    local isEntry = type(entryOrName) == "table"
    local name = (isEntry and entryOrName.originalName) or entryOrName or ""
    frame.edit:SetText(name)
    frame.edit:SetFocus()
    frame.edit:HighlightText()
    if isEntry then
        self:Preview({ status = "ok", entry = entryOrName })
        frame.pending = entryOrName
        frame.pendingText = name
        if entryOrName.craftingQuality and frame.respect then
            frame.respect:SetChecked(entryOrName.respectQuality and true or false)
        end
    else
        self:Preview(T.Resolve:Query(name))
    end
end

function AddInput:Toggle()
    self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame:Raise()
        frame.edit:SetText("")
        frame.edit:SetFocus()
        self:Preview(nil)
    end
end
