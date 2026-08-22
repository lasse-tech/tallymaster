local ADDON, T = ...

local function skinKnownList(S)
    local list = _G.TallymasterKnownListFrame
    if not list or list.__elvuiSkinned then return end
    list:StripTextures()
    list:SetTemplate("Transparent")
    if _G.TallymasterKnownListCloseButton then
        S:HandleCloseButton(_G.TallymasterKnownListCloseButton)
    end
    if _G.TallymasterKnownListSearchBox then
        S:HandleEditBox(_G.TallymasterKnownListSearchBox)
    end
    if list.filter and S.HandleDropDownBox then
        S:HandleDropDownBox(list.filter)
    end
    local bar = _G.TallymasterKnownListScrollFrameScrollBar
    if bar and S.HandleScrollBar then
        S:HandleScrollBar(bar)
    end
    list.__elvuiSkinned = true
end

local function skinAddFrame(S)
    local addFrame = _G.TallymasterAddFrame
    if not addFrame or addFrame.__elvuiSkinned then return end
    addFrame:StripTextures()
    addFrame:SetTemplate("Transparent")
    if _G.TallymasterAddFrameEditBox then S:HandleEditBox(_G.TallymasterAddFrameEditBox) end
    if _G.TallymasterAddFrameCloseButton then S:HandleCloseButton(_G.TallymasterAddFrameCloseButton) end
    if _G.TallymasterAddFrameAddButton then S:HandleButton(_G.TallymasterAddFrameAddButton) end
    addFrame.__elvuiSkinned = true
end

local function skinTracker()
    local tracker = _G.TallymasterTrackerFrame
    if not tracker or tracker.__elvuiSkinned then return end
    tracker:StripTextures()
    tracker:SetTemplate("Transparent")
    tracker.__elvuiSkinned = true
end

function T.SkinElvUI()
    if T.ApplyElvUISkin then return T.ApplyElvUISkin() end
    if not _G.ElvUI then return end
    if not T.DB:Profile().elvuiSkin then return end

    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    if not ok or not E then return end
    local S = E:GetModule("Skins", true)
    if not S then return end

    local function skin()
        if not E.private or not E.private.skins or not E.private.skins.misc
           or not E.private.skins.misc.enable then
            return
        end
        skinTracker()
        skinAddFrame(S)
        skinKnownList(S)
    end

    T.ApplyElvUISkin = skin

    local EP = LibStub("LibElvUIPlugin-1.0", true)
    if EP then
        EP:RegisterPlugin(ADDON, skin)
    else
        skin()
    end
end
