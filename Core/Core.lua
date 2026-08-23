local ADDON, T = ...

local L = T.L

T.UNCATEGORIZED = L["Uncategorized"]

_G.BINDING_CATEGORY_TALLYMASTER            = L["Tallymaster"]
_G.BINDING_NAME_TALLYMASTER_OPEN_ADD       = L["Open Add window"]
_G.BINDING_NAME_TALLYMASTER_TOGGLE_TRACKER = L["Toggle tracker"]
_G.BINDING_NAME_TALLYMASTER_TOGGLE_KNOWN   = L["Toggle known items"]

local Tallymaster = T.Addon

local ICON = "Interface\\AddOns\\Tallymaster\\Media\\Satchel"

function Tallymaster:OnInitialize()
    T.DB:Initialize()

    if T.SetupOptions then T.SetupOptions() end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB then
        self.launcher = LDB:NewDataObject(ADDON, {
            type = "launcher",
            text = L["Tallymaster"],
            icon = ICON,
            OnClick = function(_, button)
                if button == "RightButton" then
                    T.Addon:OpenOptions()
                elseif IsShiftKeyDown() then
                    T.Tracker:Toggle()
                elseif IsControlKeyDown() then
                    T.KnownList:Toggle()
                else
                    T.AddInput:Toggle()
                end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine(L["Tallymaster"])
                tt:AddLine("|cffffff00" .. L["Click"] .. "|r " .. L["Add item, currency or collectible"], 1, 1, 1)
                tt:AddLine("|cffffff00" .. L["Shift-Click"] .. "|r " .. L["Toggle tracker"], 1, 1, 1)
                tt:AddLine("|cffffff00" .. L["Ctrl-Click"] .. "|r " .. L["Known items"], 1, 1, 1)
                tt:AddLine("|cffffff00" .. L["Right-Click"] .. "|r " .. L["Options"], 1, 1, 1)
            end,
        })
        if LDBIcon then
            LDBIcon:Register(ADDON, self.launcher, self.db.profile.minimap)
        end
    end

    self:RegisterChatCommand("tally", "HandleSlash")
    self:RegisterChatCommand("tallymaster", "HandleSlash")
end

function Tallymaster:OnEnable()
    if T.DB and T.DB.Relocalize then
        local pending = T.DB:Relocalize()
        if pending and #pending > 0 then
            local want = {}
            for _, id in ipairs(pending) do want[id] = true end
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            waiter:SetScript("OnEvent", function(self, _, itemID, success)
                if not want[itemID] then return end
                want[itemID] = nil
                if success then
                    local name = C_Item.GetItemInfo(itemID)
                    local e = name and T.DB:GetEntry("item:" .. itemID)
                    if e then e.originalName = name end
                end
                if not next(want) then self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
                T.Addon:RefreshTracker()
            end)
        end
    end
    if T.Counting and T.Counting.Enable then T.Counting:Enable() end
    if T.Tracker and T.Tracker.Initialize then T.Tracker:Initialize() end
    if T.SkinElvUI then T.SkinElvUI() end
    self:RefreshTracker()
end

function Tallymaster:HandleSlash(input)
    input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if input == "known" or input == "list" then
        T.KnownList:Toggle()
    elseif input == "config" or input == "options" then
        self:OpenOptions()
    elseif input == "show" or input == "tracker" then
        T.Tracker:Toggle()
    else
        T.AddInput:Toggle()
    end
end

function Tallymaster:OpenOptions()
    if T.OpenOptions then T.OpenOptions() end
end

local refreshPending = false
function Tallymaster:RefreshTracker()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.1, function()
        refreshPending = false
        local counts = T.Counting:Snapshot()
        if T.Tracker and T.Tracker.Refresh then T.Tracker:Refresh(counts) end
        if T.KnownList and T.KnownList.Refresh then T.KnownList:Refresh(counts) end
    end)
end

function Tallymaster_Binding(which)
    if which == "add" then
        T.AddInput:Toggle()
    elseif which == "tracker" then
        T.Tracker:Toggle()
    elseif which == "known" then
        T.KnownList:Toggle()
    end
end
