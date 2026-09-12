local ADDON, T = ...

local Compat = {}
T.Compat = Compat

-- Everything the retail and Classic clients disagree about lives here, so the
-- rest of the addon can stay flavour-blind. Two rules come out of comparing the
-- per-client API dumps of Midnight, Mists Classic and Classic Era:
--
--  * Probe the function, never the namespace. C_MountJournal, C_PetJournal and
--    C_TransmogCollection are present in every flavour, Classic Era included,
--    where none of those systems exist in the game at all. A namespace guard
--    passes there and then errors on the function that is actually missing.
--  * Classic keeps the pre-10.0 currency globals, and they return a tuple where
--    retail returns a table.

local function apiFunction(namespace, name)
    local ns = _G[namespace]
    local f = ns and ns[name]
    if type(f) == "function" then return f end
    return nil
end

--------------------------------------------------------------------------------
-- Currencies
--------------------------------------------------------------------------------

-- Retail lists currencies through C_CurrencyInfo and hands back a table. Classic
-- only has the old globals, where GetCurrencyListInfo returns
-- name, isHeader, isExpanded, isUnused, isWatched, count, icon.
local getCurrencyInfo = apiFunction("C_CurrencyInfo", "GetCurrencyInfo")
local getListSize     = apiFunction("C_CurrencyInfo", "GetCurrencyListSize")
local getListInfo     = apiFunction("C_CurrencyInfo", "GetCurrencyListInfo")
local getListLink     = apiFunction("C_CurrencyInfo", "GetCurrencyListLink")

local listInfoReturnsTable = getListInfo ~= nil

getListSize = getListSize or _G.GetCurrencyListSize
getListInfo = getListInfo or _G.GetCurrencyListInfo
getListLink = getListLink or _G.GetCurrencyListLink

-- True where the client can enumerate the currency list at all. Classic Era has
-- C_CurrencyInfo.GetCurrencyInfo but no list, because vanilla has no currencies:
-- adding one by ID still resolves, adding one by name cannot.
Compat.hasCurrencyList = getListSize ~= nil and getListInfo ~= nil

function Compat:GetCurrencyInfo(currencyID)
    if not getCurrencyInfo then return nil end
    return getCurrencyInfo(currencyID)
end

function Compat:GetCurrencyListSize()
    if not getListSize then return 0 end
    return getListSize() or 0
end

function Compat:GetCurrencyListInfo(index)
    if not getListInfo then return nil end
    if listInfoReturnsTable then return getListInfo(index) end

    local name, isHeader, _, _, _, count, icon = getListInfo(index)
    if not name then return nil end
    return {
        name       = name,
        isHeader   = isHeader and true or false,
        quantity   = count,
        iconFileID = icon,
    }
end

function Compat:GetCurrencyListLink(index)
    if not getListLink then return nil end
    return getListLink(index)
end

--------------------------------------------------------------------------------
-- Containers
--------------------------------------------------------------------------------

-- Enum.BagIndex is renumbered between the flavours, and each client only names
-- the containers it actually has, so resolve by name and keep both sets:
--   retail   Keyring=-1, CharacterBankTab_1..6=6..11, AccountBankTab_1..5=12..16
--   Classic  Bank=-1, Keyring=-2, Reagentbank=-3, BankBag_1..7=6..12,
--            AccountBankTab_1..5=13..17
-- The purely negative marker values (Bankbag, Characterbanktab, Accountbanktab)
-- are type sentinels rather than container indices and are deliberately left out.
local EXTRA_BAGS = {
    "ReagentBag",

    -- retail bank
    "CharacterBankTab_1", "CharacterBankTab_2", "CharacterBankTab_3",
    "CharacterBankTab_4", "CharacterBankTab_5", "CharacterBankTab_6",

    -- Classic bank
    "Bank", "Reagentbank", "Keyring",
    "BankBag_1", "BankBag_2", "BankBag_3", "BankBag_4",
    "BankBag_5", "BankBag_6", "BankBag_7",

    -- both, but not at the same indices
    "AccountBankTab_1", "AccountBankTab_2", "AccountBankTab_3",
    "AccountBankTab_4", "AccountBankTab_5",
}

local scanBags

-- Every container worth walking slot by slot: the backpack, the four carried
-- bags, and whatever else this client names.
function Compat:ScanBags()
    if scanBags then return scanBags end
    scanBags = { 0, 1, 2, 3, 4 }
    local bagIndex = Enum and Enum.BagIndex
    for _, name in ipairs(EXTRA_BAGS) do
        local index = bagIndex and bagIndex[name]
        if index then scanBags[#scanBags + 1] = index end
    end
    return scanBags
end

--------------------------------------------------------------------------------
-- Crafting quality
--------------------------------------------------------------------------------

local reagentQuality = apiFunction("C_TradeSkillUI", "GetItemReagentQualityByItemInfo")
local craftedQuality = apiFunction("C_TradeSkillUI", "GetItemCraftedQualityByItemInfo")

-- Quality tiers arrived with Dragonflight. Neither Classic flavour has the
-- functions, so entries there never carry a craftingQuality and every tier code
-- path — the markup, the "respect quality" checkbox, the name-based count —
-- stays dormant on its own.
Compat.hasCraftingQuality = (reagentQuality or craftedQuality) ~= nil

function Compat:CraftingQuality(itemInfo)
    local quality
    if reagentQuality then quality = reagentQuality(itemInfo) end
    if not quality and craftedQuality then quality = craftedQuality(itemInfo) end
    return quality
end

--------------------------------------------------------------------------------
-- Collections
--------------------------------------------------------------------------------

local getMountInfoByID    = apiFunction("C_MountJournal", "GetMountInfoByID")
local getPetInfoBySpecies = apiFunction("C_PetJournal", "GetPetInfoBySpeciesID")
local getNumCollectedInfo = apiFunction("C_PetJournal", "GetNumCollectedInfo")
local playerHasTransmog   = apiFunction("C_TransmogCollection", "PlayerHasTransmog")

-- Where the system exists but holds nothing — mounts and pets under Classic Era,
-- appearances before the Legion wardrobe — these simply answer zero, which is
-- the honest count.
function Compat:MountCollected(mountID)
    if not getMountInfoByID then return false end
    local _, _, _, _, _, _, _, _, _, _, isCollected = getMountInfoByID(mountID)
    return isCollected and true or false
end

function Compat:MountName(mountID)
    if not getMountInfoByID then return nil end
    return (getMountInfoByID(mountID))
end

function Compat:PetsCollected(speciesID)
    if not getNumCollectedInfo then return 0 end
    return getNumCollectedInfo(speciesID) or 0
end

function Compat:PetName(speciesID)
    if not getPetInfoBySpecies then return nil end
    return (getPetInfoBySpecies(speciesID))
end

function Compat:HasTransmog(itemID)
    if not playerHasTransmog then return false end
    return playerHasTransmog(itemID) and true or false
end
