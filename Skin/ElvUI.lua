local ADDON, T = ...

--[[
    ElvUI integration. No-op when ElvUI is absent. When present, we register a
    plugin via LibElvUIPlugin-1.0 so our skin function runs at the right time and
    we respect the user's settings (both ElvUI's "skin misc frames" toggle and
    our own profile.elvuiSkin toggle).

    Handlers used: StripTextures / SetTemplate, S:HandleButton, S:HandleEditBox,
    S:HandleCloseButton, S:HandleTrimScrollBar, S:HandleIcon.
]]

function T.SkinElvUI()
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

        -- Tracker frame
        local tracker = _G.TallymasterTrackerFrame
        if tracker and not tracker.__elvuiSkinned then
            tracker:StripTextures()
            tracker:SetTemplate("Transparent")
            tracker.__elvuiSkinned = true
        end

        -- Add box
        local addFrame = _G.TallymasterAddFrame
        if addFrame and not addFrame.__elvuiSkinned then
            addFrame:StripTextures()
            addFrame:SetTemplate("Transparent")
            if _G.TallymasterAddFrameEditBox then S:HandleEditBox(_G.TallymasterAddFrameEditBox) end
            if _G.TallymasterAddFrameCloseButton then S:HandleCloseButton(_G.TallymasterAddFrameCloseButton) end
            if _G.TallymasterAddFrameAddButton then S:HandleButton(_G.TallymasterAddFrameAddButton) end
            addFrame.__elvuiSkinned = true
        end
    end

    local EP = LibStub("LibElvUIPlugin-1.0", true)
    if EP then
        EP:RegisterPlugin(ADDON, skin)
    else
        skin()
    end
end
