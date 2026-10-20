-- luacheck configuration. `make lint` fails on any warning.
-- The WoW client runs Lua 5.1; everything below only names the environment the
-- addon runs in, it does not switch any check off.
std = "lua51"
max_line_length = 120
exclude_files = { "Libs/", "dist/", "tests/" }

-- 212/self: the implicit `self` of a method, unused. The singletons here are
-- written as methods (`Addon:Print()`), so every one of them carries a `self`
-- whether it reads it or not - that is the signature, not a defect. Unused
-- arguments are still reported; only this one name is exempt. Favorkeeper
-- avoids the question by giving its singletons dot functions instead.
ignore = { "212/self" }

-- Written by the addon.
globals = {
    "TallymasterDB",
    "Tallymaster_Binding",
    "TallymasterAboutMixin",
    "BINDING_CATEGORY_TALLYMASTER",
    "BINDING_NAME_TALLYMASTER_TOGGLE_TRACKER",
    "BINDING_NAME_TALLYMASTER_OPEN_ADD",
    "BINDING_NAME_TALLYMASTER_TOGGLE_KNOWN",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UISpecialFrames",
    -- Named frames, created by the addon and looked up again by the ElvUI skin.
    "TallymasterTrackerFrame",
    "TallymasterAddFrame",
    "TallymasterKnownListFrame",
}

-- Provided by the client.
read_globals = {
    "ATTACHMENTS_MAX_RECEIVE", "BreakUpLargeNumbers", "C_AddOns", "C_Container", "C_Item",
    "C_Timer", "CreateAtlasMarkup", "CreateFrame", "CreateFramePool", "ElvUI", "Enum",
    "GameTooltip", "GetAddOnMetadata", "GetInboxItem", "GetInboxNumItems", "GetLocale",
    "GetRealmName", "hooksecurefunc", "IsControlKeyDown", "IsLoggedIn", "IsModifiedClick",
    "IsShiftKeyDown", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_USE",
    "ITEM_BIND_QUEST", "LibStub", "Settings", "StackSplitFrame", "StaticPopup_Show",
    "strjoin", "tinsert", "TOTAL", "TooltipDataProcessor", "tostringall", "UIParent",
    "UnitName", "wipe",
}
