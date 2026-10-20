local ADDON, T = ...
local L = T.L
local DB = T.DB

local category, layout

-- Element height = initializer:GetExtent(), measured from the text.
local ABOUT_TEMPLATE = "TallymasterAboutTemplate"
local ABOUT_FONT = "GameFontHighlight"
local ABOUT_BOTTOM_PAD = 8

-- Not localized; ASCII "<3" (no heart glyph in the game font).
local CHIP_TEXT = "Made with <3 in Europe"
local CHIP_GAP = 6
local CHIP_HEIGHT = 18
local CHIP_PAD_X = 8

TallymasterAboutMixin = {}

function TallymasterAboutMixin:Init(initializer)
    self.Text:SetText(initializer:GetData().text)

    local chip = self.Chip
    chip.Label:SetText(CHIP_TEXT)
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", self.Text, "BOTTOMLEFT", 0, -CHIP_GAP)
    chip:SetSize(math.ceil(chip.Label:GetStringWidth()) + 2 * CHIP_PAD_X, CHIP_HEIGHT)
end

local function metadata(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local value = get and get(ADDON, field)
    if value == "" then return nil end
    return value
end

local function aboutText()
    local lines = {}

    local author = metadata("Author")
    if author then lines[#lines + 1] = L["Author: %s"]:format(author) end

    local version = metadata("Version")
    if version then lines[#lines + 1] = L["Version: %s"]:format(version) end

    local copyright = metadata("X-Copyright")
    if copyright then lines[#lines + 1] = "\194\169 " .. copyright end

    local footer = {}
    local website = metadata("X-Website")
    if website then footer[#footer + 1] = (website:gsub("^%a+://", "")) end
    local license = metadata("X-License")
    if license then footer[#footer + 1] = license .. " License" end
    if #footer > 0 then lines[#lines + 1] = table.concat(footer, " \194\183 ") end

    return table.concat(lines, "\n")
end

local measure

local function textHeight(text)
    if not measure then
        measure = UIParent:CreateFontString(nil, "ARTWORK", ABOUT_FONT)
        measure:SetJustifyH("LEFT")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringHeight()
end

local function addAbout()
    if not Settings.CreateElementInitializer then return end

    local text = aboutText()
    if text == "" then return end

    local initializer = Settings.CreateElementInitializer(ABOUT_TEMPLATE, { text = text })
    local extent = math.ceil(textHeight(text)) + CHIP_GAP + CHIP_HEIGHT + ABOUT_BOTTOM_PAD
    initializer.GetExtent = function() return extent end
    layout:AddInitializer(initializer)
end

local function refresh()
    T.Addon.RefreshTracker()
end

local function profileSetting(variableKey, variableType, name, default)
    return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. variableKey, variableKey,
        DB.Profile(), variableType, name, default)
end

function T.SetupOptions()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end
    if category then return end

    category, layout = Settings.RegisterVerticalLayoutCategory(L["Tallymaster"])

    addAbout()

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
          L["Show a tooltip when hovering an item in the tracker. When account-wide, it lists each "
            .. "character's count."] },
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
        local proxy = { showMinimap = not DB.Profile().minimap.hide }
        local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_showMinimap", "showMinimap",
            proxy, Settings.VarType.Boolean, L["Show minimap button"], true)
        setting:SetValueChangedCallback(function(_, value)
            DB.Profile().minimap.hide = not value
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

    Settings.RegisterAddOnCategory(category)
end

function T.OpenOptions()
    if not category then return end
    Settings.OpenToCategory(category:GetID())
end
