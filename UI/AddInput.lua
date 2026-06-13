local ADDON, T = ...
local L = T.L
local DB = T.DB

--[[
    The add box: type a name or ID, press Enter, the resolved entry is appended
    to storage and shown on the tracker. Handles:
      - ambiguous numeric IDs (item vs currency) via a choice popup,
      - uncached item data (retry shortly),
      - re-adding an already-known entry (just re-show it).

    Uses InputBoxTemplate so ElvUI's S:HandleEditBox can skin it.
]]

local AddInput = {}
T.AddInput = AddInput

local frame

-- Commit a resolved entry to storage + tracker.
function AddInput:Commit(entry)
    local existing = DB:GetEntry(entry.key)
    if existing then
        DB:SetVisible(existing.key, true)
        T.Addon:Print(L["Already tracking %s."]:format(DB:DisplayName(existing)))
    else
        DB:AddEntry(entry)
        DB:SetVisible(entry.key, true)
        T.Addon:Print(L["Now tracking %s."]:format(DB:DisplayName(entry)))
    end
    T.Addon:RefreshTracker()
    if T.KnownList and T.KnownList.Refresh then T.KnownList:Refresh() end
end

local function askAmbiguous(result, id)
    StaticPopupDialogs["TALLYMASTER_AMBIGUOUS"] = StaticPopupDialogs["TALLYMASTER_AMBIGUOUS"] or {
        text = L["The ID %d matches both an item and a currency. Which do you mean?"],
        button1 = L["Item"],
        button2 = L["Currency"],
        OnAccept = function(self) AddInput:Commit(self.data.candidates[1]) end,
        OnCancel = function(self, data, reason)
            if reason == "clicked" then AddInput:Commit(self.data.candidates[2]) end
        end,
        hideOnEscape = true, whileDead = true, timeout = 0,
    }
    local dialog = StaticPopup_Show("TALLYMASTER_AMBIGUOUS", id)
    if dialog then dialog.data = result end
end

function AddInput:Submit(text)
    local result = T.Resolve:Query(text)
    if result.status == "ok" then
        self:Commit(result.entry)
        if frame then frame.edit:SetText(""); frame:Hide() end
    elseif result.status == "ambiguous" then
        askAmbiguous(result, tonumber(text))
    elseif result.status == "loading" then
        T.Addon:Print(L["Still loading data for that ID — try again in a moment."])
    else
        T.Addon:Print(L["Could not find anything matching '%s'."]:format(text))
    end
end

-- Strip inline escape sequences WoW embeds in link text: atlas markup (crafting
-- quality stars |A...|a), textures (|T...|t) and colour codes (|c.../|r). Without
-- this, a shift-clicked quality item pastes e.g. "Name |A:...Tier3...|a" which no
-- name lookup can match.
local function stripEscapes(s)
    if not s then return s end
    s = s:gsub("|A.-|a", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Pull a readable display name out of a shift-clicked hyperlink, e.g.
-- "...|h[Greater Storm Sigil]|h..." -> "Greater Storm Sigil".
local function linkToName(link)
    if not link then return nil end
    return stripEscapes(link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]"))
end

function AddInput:Create()
    if frame then return end
    frame = CreateFrame("Frame", "TallymasterAddFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 110)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
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

    -- Escape closes the window from anywhere (even when the edit box no longer
    -- holds keyboard focus, e.g. after clicking outside).
    tinsert(UISpecialFrames, "TallymasterAddFrame")

    -- Clicking anywhere outside the window releases keyboard focus, so game
    -- keybinds (bags, etc.) work again while the window stays open. This is how
    -- most addon input frames behave; WoW does not defocus an EditBox on its own
    -- when you click away from it.
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
    -- Auto-focus OFF: with it on, the box re-grabs the keyboard so it can never be
    -- released. We focus explicitly on open (Toggle/Paste) for immediate typing,
    -- and release on outside-click or Escape.
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then AddInput:Submit(text) end
    end)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.edit = edit

    -- Placeholder text rendered inside the box; hidden as soon as anything is
    -- typed. Living inside the edit box means it can never be clipped by the frame.
    frame.editInstructions = edit:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.editInstructions:SetPoint("LEFT", edit, "LEFT", 6, 0)
    frame.editInstructions:SetPoint("RIGHT", edit, "RIGHT", -6, 0)
    frame.editInstructions:SetJustifyH("LEFT")
    frame.editInstructions:SetText(L["Type a name or ID, then press Enter"])
    edit:SetScript("OnTextChanged", function(self)
        frame.editInstructions:SetShown(self:GetText() == "")
    end)

    -- Shift-clicking an item/currency anywhere pastes its name into the box
    -- while the Add window is open.
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
        end)
    end

    -- While the Add window is open, a shift-click is "copy the name", so suppress
    -- the stack-split amount picker WoW would otherwise pop up for a stackable item.
    if StackSplitFrame and not AddInput._splitHooked then
        AddInput._splitHooked = true
        StackSplitFrame:HookScript("OnShow", function(self)
            if frame and frame:IsShown() then self:Hide() end
        end)
    end

    -- Start hidden so the first Toggle() opens (and focuses) it.
    frame:Hide()
end

-- Used by the known-items list "shift-click to paste".
function AddInput:Paste(text)
    self:Create()
    frame:Show()
    frame.edit:SetText(text or "")
    frame.edit:SetFocus()
    frame.edit:HighlightText()
end

function AddInput:Toggle()
    self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame.edit:SetText("")
        frame.edit:SetFocus()
    end
end
