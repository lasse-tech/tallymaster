-- Runs inside wow-ui-sim (`make test`). The addon's private table is out of
-- reach here, so every test drives the addon through what a player or another
-- addon can see: slash commands, named frames, LibDataBroker and TallymasterDB.

local HEARTHSTONE = 6948

local function charKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function addViaWindow(text)
    TallymasterAddFrameEditBox:SetText(text)
    TallymasterAddFrameAddButton:Click()
end

test("registers both slash commands", function()
    assertEquals("/tally", SLASH_TALLYMASTERTALLY1)
    assertEquals("/tallymaster", SLASH_TALLYMASTERTALLYMASTER1)
    assertType("function", SlashCmdList.TALLYMASTERTALLY)
end)

test("creates SavedVariables with defaults on first login", function()
    assertType("table", TallymasterDB)
    local profile = TallymasterDB.profiles.Default
    assertEquals("char", profile.scope)
    assertEquals("alpha", profile.sortMode)
    assertType("table", TallymasterDB.global.entries)
end)

test("publishes a LibDataBroker launcher", function()
    local ldb = LibStub("LibDataBroker-1.1")
    local launcher = ldb:GetDataObjectByName("Tallymaster")
    assertNotNil(launcher)
    assertEquals("launcher", launcher.type)
end)

test("shows the empty tracker after login", function()
    assertNotNil(TallymasterTrackerFrame)
    assertTrue(TallymasterTrackerFrame:IsShown())
end)

test("/tally opens and closes the add window", function()
    SlashCmdList.TALLYMASTERTALLY("")
    assertTrue(TallymasterAddFrame:IsShown())
    SlashCmdList.TALLYMASTERTALLY("")
    assertFalse(TallymasterAddFrame:IsShown())
end)

test("adding an item by ID stores and shows it", function()
    SlashCmdList.TALLYMASTERTALLY("")
    addViaWindow(tostring(HEARTHSTONE))

    local entry = TallymasterDB.global.entries["item:" .. HEARTHSTONE]
    assertNotNil(entry)
    assertEquals("item", entry.type)
    assertEquals(HEARTHSTONE, entry.id)
    assertEquals(C_Item.GetItemInfo(HEARTHSTONE), entry.originalName)
    assertFalse(TallymasterAddFrame:IsShown())

    local charDB = next(TallymasterDB.char) and select(2, next(TallymasterDB.char))
    assertTrue(charDB.visible["item:" .. HEARTHSTONE])
end)

-- Bag events only schedule a debounced refresh (C_Timer, 0.1 s of wall clock),
-- which the simulator's async runner does not wait for. Showing the tracker
-- refreshes synchronously, so hide and show it to take a fresh snapshot.
test("counts a tracked item in the bags", function()
    A_Admin.ClearBags()
    A_Admin.AddBagItem(0, 1, HEARTHSTONE, 1)
    SlashCmdList.TALLYMASTERTALLY("show")
    if not TallymasterTrackerFrame:IsShown() then
        SlashCmdList.TALLYMASTERTALLY("show")
    end
    assertTrue(TallymasterTrackerFrame:IsShown())

    local counts = TallymasterDB.global.charCounts[charKey()]
    assertNotNil(counts)
    assertEquals(1, counts["item:" .. HEARTHSTONE])
end)

-- C_Item.GetItemCount already includes equipped items; adding them again made
-- a single equipped trinket show as 2 (incudex/tallymaster#9).
test("counts an equipped item once", function()
    local TRINKET = 250223
    A_Admin.ClearBags()
    A_Admin.EquipItem(INVSLOT_TRINKET1 or 13, TRINKET)

    SlashCmdList.TALLYMASTERTALLY("")
    addViaWindow(tostring(TRINKET))
    assertNotNil(TallymasterDB.global.entries["item:" .. TRINKET])

    SlashCmdList.TALLYMASTERTALLY("show")
    if not TallymasterTrackerFrame:IsShown() then
        SlashCmdList.TALLYMASTERTALLY("show")
    end

    local counts = TallymasterDB.global.charCounts[charKey()]
    A_Admin.UnequipItem(INVSLOT_TRINKET1 or 13)
    assertEquals(1, counts["item:" .. TRINKET])
end)

test("/tally known opens the known list", function()
    SlashCmdList.TALLYMASTERTALLY("known")
    assertNotNil(TallymasterKnownListFrame)
    assertTrue(TallymasterKnownListFrame:IsShown())
end)
