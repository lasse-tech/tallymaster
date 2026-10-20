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

-- The client does not hand the keyboard state back to a freshly loaded UI, so
-- right after /reload IsShiftKeyDown() and friends answer "not held" even while
-- the key is down. The first Shift- or Ctrl-click then falls through every
-- branch and looks dead; the second works, because by then the key has been
-- pressed again with the new UI listening. MODIFIER_STATE_CHANGED does arrive,
-- so the state is tracked here.
local held = {}

Addon.RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key, down)
    if type(key) ~= "string" then return end
    held[key] = down == 1
end)

-- The API answers first: when it says the key is down, it is. Only its "no" is
-- worth doubting, and then the tracked state fills in. That way a release the
-- client swallowed cannot leave a key stuck as pressed.
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
