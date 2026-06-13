local ADDON, T = ...
local L = T.L
local DB = T.DB

-- AceConfig options table + registration into the Blizzard addon settings.
function T.SetupOptions()
    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not AceConfig or not AceConfigDialog then return end

    local function get(info) return DB:Profile()[info[#info]] end
    local function set(info, value)
        DB:Profile()[info[#info]] = value
        T.Addon:RefreshTracker()
    end

    local options = {
        type = "group",
        name = L["Tallymaster"],
        args = {
            scope = {
                type = "select", order = 1,
                name = L["Count scope"],
                desc = L["Where item counts are summed from."],
                values = {
                    char    = L["Per character"],
                    account = L["Account-wide (all characters)"],
                },
                get = get, set = set,
            },
            sortMode = {
                type = "select", order = 2,
                name = L["Sort order"],
                values = {
                    alpha = L["Alphabetical"],
                    count = L["By count"],
                },
                get = get, set = set,
            },
            showCategories = {
                type = "toggle", order = 3,
                name = L["Group by category"],
                desc = L["When off, the tracker shows a single flat list instead of category groups."],
                get = get, set = set,
            },
            showTooltip = {
                type = "toggle", order = 4,
                name = L["Show item tooltip"],
                desc = L["Show a tooltip when hovering an item in the tracker. When account-wide, it lists each character's count."],
                get = get, set = set,
            },
            minimapToggle = {
                type = "toggle", order = 5,
                name = L["Show minimap button"],
                get = function() return not DB:Profile().minimap.hide end,
                set = function(_, value)
                    DB:Profile().minimap.hide = not value
                    local LDBIcon = LibStub("LibDBIcon-1.0", true)
                    if LDBIcon then
                        if value then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
                    end
                end,
            },
            elvuiSkin = {
                type = "toggle", order = 6,
                name = L["Allow ElvUI to skin this addon"],
                desc = L["Requires a /reload to take effect."],
                get = get, set = set,
            },
        },
    }

    AceConfig:RegisterOptionsTable(ADDON, options)
    AceConfigDialog:AddToBlizOptions(ADDON, L["Tallymaster"])
end
