std = "lua51"
max_line_length = 120
exclude_files = { "Libs/", "dist/", "tests/" }

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
    -- named frames (ElvUI skin)
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
