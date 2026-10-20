local ADDON, T = ...

local Addon = {}
T.Addon = Addon

local PREFIX = "|cff33ff99" .. ADDON .. "|r: "

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

function Addon.RegisterEvent(event, handler)
    local list = handlers[event]
    if not list then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return end
        list = {}
        handlers[event] = list
    end
    list[#list + 1] = handler
end

--------------------------------------------------------------------------------
-- Modifier keys
--------------------------------------------------------------------------------

-- After /reload IsShiftKeyDown() etc. report "not held" until the key is pressed again.
local held = {}

Addon.RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key, down)
    if type(key) ~= "string" then return end
    held[key] = down == 1
end)

-- API "yes" wins; tracked state only fills in an API "no".
local function anyHeld(left, right, api)
    if api and api() then return true end
    return held[left] == true or held[right] == true
end

function Addon.ShiftDown()
    return anyHeld("LSHIFT", "RSHIFT", IsShiftKeyDown)
end

function Addon.ControlDown()
    return anyHeld("LCTRL", "RCTRL", IsControlKeyDown)
end

function Addon.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

local SLASH_PREFIX = ADDON:upper()

function Addon.RegisterChatCommand(command, method)
    local id = SLASH_PREFIX .. command:upper()
    _G["SLASH_" .. id .. "1"] = "/" .. command
    SlashCmdList[id] = function(input)
        Addon[method](input)
    end
end

local loader = CreateFrame("Frame")
local initialized, enabled = false, false

local function initialize()
    if initialized then return end
    initialized = true
    if Addon.OnInitialize then Addon.OnInitialize() end
end

local function enable()
    if enabled then return end
    enabled = true
    if Addon.OnEnable then Addon.OnEnable() end
end

loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(frame, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        frame:UnregisterEvent("ADDON_LOADED")
        initialize()
        if IsLoggedIn() then
            frame:UnregisterEvent("PLAYER_LOGIN")
            enable()
        end
    elseif event == "PLAYER_LOGIN" then
        frame:UnregisterEvent("PLAYER_LOGIN")
        initialize()
        enable()
    end
end)
