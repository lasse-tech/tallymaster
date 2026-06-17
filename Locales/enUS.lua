local ADDON = ...
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON, "enUS", true, true)
if not L then return end

L["Tallymaster"] = true
L["Add item, currency or collectible"] = true
L["Type a name or ID, then press Enter"] = true
L["Add"] = true
L["Known items"] = true
L["Search"] = true
L["Name"] = true
L["Count"] = true
L["Toggle tracker"] = true

L["Open Add window"] = true
L["Toggle known items"] = true

L["Click"] = true
L["Shift-Click"] = true
L["Ctrl-Click"] = true
L["Right-Click"] = true
L["Options"] = true

L["Quality"] = true
L["Item level"] = true
L["Type"] = true
L["Stack"] = true
L["Sell"] = true
L["Expansion"] = true
L["Bind"] = true
L["Respect quality (count only this tier)"] = true
L["When on, this entry counts only the exact crafting quality you added. When off, it counts every quality of the item."] = true
L["All categories"] = true
L["Uncategorized"] = true

L["The ID %d matches both an item and a currency. Which do you mean?"] = true
L["Item"] = true
L["Currency"] = true

L["Count scope"] = true
L["Where item counts are summed from."] = true
L["Per character"] = true
L["Account-wide (all characters)"] = true
L["Sort order"] = true
L["Alphabetical"] = true
L["By count"] = true
L["Group by category"] = true
L["When off, the tracker shows a single flat list instead of category groups."] = true
L["Show item tooltip"] = true
L["Show a tooltip when hovering an item in the tracker. When account-wide, it lists each character's count."] = true
L["Show counts in tooltip"] = true
L["Include each character's count (grouped by realm) in the tracker tooltip."] = true
L["Show counts on item tooltips"] = true
L["Add the per-character count breakdown to the standard game item tooltip (for tracked items)."] = true
L["Show minimap button"] = true
L["Allow ElvUI to skin this addon"] = true
L["Requires a /reload to take effect."] = true

L["Currencies"] = true
L["Mounts"] = true
L["Transmog"] = true
L["Battle Pets"] = true
L["Knowledge"] = true

L["No items tracked yet."] = true
L["Type /tally, click the minimap icon, or use the Add keybinding, then enter an item's name or ID."] = true
L["Tip: with the Add window open, Shift-click an item in your bags to copy its name into the box."] = true

L["Could not find anything matching '%s'."] = true
L["Already tracking %s."] = true
L["Now tracking %s."] = true
L["Still loading data for that ID — try again in a moment."] = true
