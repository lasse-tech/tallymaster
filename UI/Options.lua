local ADDON, T = ...
local L = T.L
local DB = T.DB

local category, layout

local CREDITS = "|cff8080802026 www.incudex.de|r"

local function refresh()
    T.Addon:RefreshTracker()
end

local function profileSetting(variableKey, variableType, name, default)
    return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. variableKey, variableKey,
        DB:Profile(), variableType, name, default)
end

function T.SetupOptions()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end
    if category then return end

    category, layout = Settings.RegisterVerticalLayoutCategory(L["Tallymaster"])

    do
        local setting = profileSetting("scope", Settings.VarType.String, L["Count scope"], "char")
        setting:SetValueChangedCallback(refresh)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("char", L["Per character"])
            container:Add("account", L["Account-wide (all characters)"])
            return container:GetData()
        end, L["Where item counts are summed from."])
    end

    do
        local setting = profileSetting("sortMode", Settings.VarType.String, L["Sort order"], "alpha")
        setting:SetValueChangedCallback(refresh)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("alpha", L["Alphabetical"])
            container:Add("count", L["By count"])
            return container:GetData()
        end)
    end

    local toggles = {
        { "showCategories", L["Group by category"],
          L["When off, the tracker shows a single flat list instead of category groups."] },
        { "showTooltip", L["Show item tooltip"],
          L["Show a tooltip when hovering an item in the tracker. When account-wide, it lists each character's count."] },
        { "showTooltipCounts", L["Show counts in tooltip"],
          L["Include each character's count (grouped by realm) in the tracker tooltip."] },
        { "gameTooltipCounts", L["Show counts on item tooltips"],
          L["Add the per-character count breakdown to the standard game item tooltip (for tracked items)."] },
    }
    for _, t in ipairs(toggles) do
        local setting = profileSetting(t[1], Settings.VarType.Boolean, t[2], true)
        setting:SetValueChangedCallback(refresh)
        Settings.CreateCheckbox(category, setting, t[3])
    end

    do
        local proxy = { showMinimap = not DB:Profile().minimap.hide }
        local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_showMinimap", "showMinimap",
            proxy, Settings.VarType.Boolean, L["Show minimap button"], true)
        setting:SetValueChangedCallback(function(_, value)
            DB:Profile().minimap.hide = not value
            local LDBIcon = LibStub("LibDBIcon-1.0", true)
            if not LDBIcon then return end
            if value then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
        end)
        Settings.CreateCheckbox(category, setting)
    end

    do
        local setting = profileSetting("elvuiSkin", Settings.VarType.Boolean,
            L["Allow ElvUI to skin this addon"], true)
        Settings.CreateCheckbox(category, setting, L["Requires a /reload to take effect."])
    end

    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(CREDITS))
    end

    Settings.RegisterAddOnCategory(category)
end

function T.OpenOptions()
    if not category then return end
    Settings.OpenToCategory(category:GetID())
end
